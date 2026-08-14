#!/usr/bin/env node
/**
 * Strips fields off live recipes that should never have been there.
 *
 *   FIRESTORE_ACCESS_TOKEN=$(gcloud auth print-access-token) node cleanup_recipes.js
 *   FIRESTORE_ACCESS_TOKEN=... node cleanup_recipes.js --commit
 *
 * Same shape as migrate_rest.js — REST rather than the Admin SDK because a plain OAuth
 * access token works without an interactive ADC login, dry run by default, and idempotent
 * so a second run reports zero changes.
 *
 * Three things, all found on production data:
 *
 *   1. updatedByEmail. Recipes are world-readable when public, so this published the
 *      author's address. createdByEmail was removed from the schema for that reason; the
 *      update path in firestore_service.dart kept writing this one. Both the write and a
 *      rules refusal are fixed, but the values already stored have to be deleted.
 *
 *   2. imageUrl values that cannot be an image: a truncated `data:image/svg+xml` URI, and
 *      https://example.com/... placeholders that never existed. These render as a broken
 *      image rather than the app's own placeholder, which looks worse than no image.
 *
 * Nothing here touches recipe content. It refuses to run if it would.
 */

const args = process.argv.slice(2);
const COMMIT = args.includes('--commit');
const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || 'recipe-f644f';
const TOKEN = process.env.FIRESTORE_ACCESS_TOKEN;

const ROOT =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

if (!TOKEN) {
  console.error(
    'FIRESTORE_ACCESS_TOKEN is required. Get one with:\n' +
    '  gcloud auth print-access-token --account=elijahcraig45@gmail.com',
  );
  process.exit(1);
}

const CONTENT_FIELDS = ['title', 'ingredients', 'steps', 'description', 'notes'];

async function api(path, { method = 'GET', body, query } = {}) {
  const url = new URL(`${ROOT}${path}`);
  for (const [key, values] of Object.entries(query || {})) {
    for (const value of [].concat(values)) url.searchParams.append(key, value);
  }
  const response = await fetch(url, {
    method,
    headers: { 'content-type': 'application/json', authorization: `Bearer ${TOKEN}` },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) {
    throw new Error(`${method} ${path} -> ${response.status} ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

const unwrap = (v) =>
  v == null ? null : 'stringValue' in v ? v.stringValue : 'booleanValue' in v ? v.booleanValue : v;
const idOf = (doc) => doc.name.split('/').pop();

/** True for an imageUrl the app can never render. */
function isUnusableImage(url) {
  if (typeof url !== 'string' || url === '') return false;
  if (url.startsWith('data:')) return true;               // truncated inline SVG
  if (/^https?:\/\/(www\.)?example\.com\//i.test(url)) return true;
  return false;
}

const counts = { scanned: 0, emailsRemoved: 0, imagesCleared: 0 };

async function main() {
  console.log(`${COMMIT ? 'COMMITTING to' : 'DRY RUN against'} ${PROJECT_ID}\n`);

  const docs = [];
  let pageToken;
  do {
    const page = await api('/recipes', {
      query: { pageSize: 300, ...(pageToken ? { pageToken } : {}) },
    });
    docs.push(...(page.documents || []));
    pageToken = page.nextPageToken;
  } while (pageToken);

  counts.scanned = docs.length;

  for (const doc of docs) {
    const id = idOf(doc);
    const fields = doc.fields || {};
    const remove = [];
    const set = {};

    if ('updatedByEmail' in fields) {
      remove.push('updatedByEmail');
      counts.emailsRemoved += 1;
      console.log(`  ${COMMIT ? 'DO  ' : 'plan'}  ${id}: delete updatedByEmail`);
    }
    if ('createdByEmail' in fields) {
      remove.push('createdByEmail');
      counts.emailsRemoved += 1;
      console.log(`  ${COMMIT ? 'DO  ' : 'plan'}  ${id}: delete createdByEmail`);
    }

    const imageUrl = unwrap(fields.imageUrl);
    if (isUnusableImage(imageUrl)) {
      // Emptied rather than deleted, because '' is already what the rest of the data uses
      // for "no image" and the app checks for it.
      set.imageUrl = { stringValue: '' };
      counts.imagesCleared += 1;
      console.log(
        `  ${COMMIT ? 'DO  ' : 'plan'}  ${id}: clear unusable imageUrl ` +
        `(${String(imageUrl).slice(0, 42)}…)`,
      );
    }

    if (!remove.length && !Object.keys(set).length) continue;

    const touching = [...remove, ...Object.keys(set)].filter((f) => CONTENT_FIELDS.includes(f));
    if (touching.length) {
      throw new Error(`refusing to continue: would modify ${touching.join(', ')} on ${id}`);
    }

    if (COMMIT) {
      await api(`/recipes/${id}`, {
        method: 'PATCH',
        query: { 'updateMask.fieldPaths': [...Object.keys(set), ...remove] },
        body: { fields: set },
      });
    }
  }

  console.log('\nsummary');
  for (const [key, value] of Object.entries(counts)) {
    console.log(`  ${key.padEnd(16)} ${value}`);
  }
  const changes = counts.emailsRemoved + counts.imagesCleared;
  if (!COMMIT) {
    console.log('\nNothing was written. Re-run with --commit to apply.');
  } else if (changes === 0) {
    console.log('\nNothing to do — already clean.');
  }
}

main().then(
  () => process.exit(0),
  (err) => {
    console.error('\ncleanup failed:', err.message);
    process.exit(1);
  },
);
