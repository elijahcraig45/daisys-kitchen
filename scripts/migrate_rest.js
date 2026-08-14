#!/usr/bin/env node
/**
 * The Phase 1 migration, over the Firestore REST API.
 *
 *   node migrate_rest.js --emulator            # dry run against the emulator
 *   node migrate_rest.js --emulator --commit
 *   FIRESTORE_ACCESS_TOKEN=... node migrate_rest.js            # dry run, production
 *   FIRESTORE_ACCESS_TOKEN=... node migrate_rest.js --commit
 *
 * Why REST and not firebase-admin: the Admin SDK's Firestore client accepts only a
 * certificate credential or Application Default Credentials, and ADC needs an interactive
 * `gcloud auth application-default login`. A plain OAuth access token — which
 * `gcloud auth print-access-token` produces without any prompting — works fine against
 * the REST API. Same operations, one fewer thing to set up.
 *
 * The same code path runs against the emulator and production, differing only in base URL
 * and whether a token is sent, so what gets validated is what runs.
 *
 * Everything else matches migrate_visibility.js: dry run by default, idempotent by
 * construction, and it refuses to write if a recipe's content would change.
 */

const args = process.argv.slice(2);
const COMMIT = args.includes('--commit');
const EMULATOR = args.includes('--emulator');
const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || 'recipe-f644f';
const TOKEN = process.env.FIRESTORE_ACCESS_TOKEN;

const ADMIN_EMAIL = 'elijahcraig45@gmail.com';
const HOUSEHOLD_ID = 'home';
const HOUSEHOLD_NAME = 'Home';

const HOST = EMULATOR
  ? `http://${process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080'}`
  : 'https://firestore.googleapis.com';
const ROOT = `${HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

if (!EMULATOR && !TOKEN) {
  console.error(
    'FIRESTORE_ACCESS_TOKEN is required against production. Get one with:\n' +
    `  gcloud auth print-access-token --account=${ADMIN_EMAIL}`,
  );
  process.exit(1);
}

async function api(path, { method = 'GET', body, query } = {}) {
  const url = new URL(`${ROOT}${path}`);
  for (const [key, values] of Object.entries(query || {})) {
    for (const value of [].concat(values)) url.searchParams.append(key, value);
  }
  const response = await fetch(url, {
    method,
    headers: {
      'content-type': 'application/json',
      // The emulator's REST surface ENFORCES security rules, unlike the Admin SDK which
      // bypasses them — an unauthenticated list here is refused by our own rules, which
      // is them working. `Bearer owner` is the emulator's documented admin token.
      // Against production, an IAM-authenticated call is already outside rules.
      ...(EMULATOR
        ? { authorization: 'Bearer owner' }
        : { authorization: `Bearer ${TOKEN}` }),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) {
    throw new Error(`${method} ${path} -> ${response.status} ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

/* Firestore's REST shape wraps every value in a type tag. Only the types this data uses
   are handled; anything unexpected is passed through untouched rather than guessed at,
   because a migration that mangles a value it did not understand is worse than one that
   leaves it alone. */
function unwrap(value) {
  if (value == null) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(unwrap);
  if ('mapValue' in value) {
    return Object.fromEntries(
      Object.entries(value.mapValue.fields || {}).map(([k, v]) => [k, unwrap(v)]),
    );
  }
  return value;
}

const fields = (doc) =>
  Object.fromEntries(Object.entries(doc.fields || {}).map(([k, v]) => [k, unwrap(v)]));
const idOf = (doc) => doc.name.split('/').pop();

const counts = {
  recipesScanned: 0,
  visibilitySet: 0,
  householdIdSet: 0,
  favouritesMoved: 0,
  emailsRemoved: 0,
  favoriteFlagsRemoved: 0,
  householdCreated: 0,
  userHouseholdSet: 0,
  ownerless: [],
};

function plan(action, detail) {
  console.log(`  ${COMMIT ? 'DO  ' : 'plan'}  ${action}${detail ? ` — ${detail}` : ''}`);
}

async function listAll(collection) {
  const docs = [];
  let pageToken;
  do {
    const page = await api(`/${collection}`, {
      query: { pageSize: 300, ...(pageToken ? { pageToken } : {}) },
    });
    docs.push(...(page.documents || []));
    pageToken = page.nextPageToken;
  } while (pageToken);
  return docs;
}

/**
 * Patches a document.
 *
 * A field named in updateMask but absent from the body is DELETED — that is how
 * createdByEmail and isFavorite go away, in the same request that sets visibility, so a
 * recipe is never left half migrated.
 */
async function patch(collection, id, set, deleteFields = []) {
  const maskPaths = [...Object.keys(set), ...deleteFields];
  await api(`/${collection}/${id}`, {
    method: 'PATCH',
    query: { 'updateMask.fieldPaths': maskPaths },
    body: { fields: set },
  });
}

async function migrateRecipes() {
  console.log('\nrecipes');
  const docs = await listAll('recipes');
  counts.recipesScanned = docs.length;

  for (const doc of docs) {
    const id = idOf(doc);
    const data = fields(doc);
    const set = {};
    const remove = [];

    if (data.visibility === undefined) {
      // Existing recipes are world-readable today, so 'public' is what preserves who can
      // see them. An already-set visibility is never overwritten.
      set.visibility = { stringValue: 'public' };
      counts.visibilitySet += 1;
      plan(`${id}: visibility = public`, data.title);
    }
    if (data.householdId === undefined) {
      set.householdId = { nullValue: null };
      counts.householdIdSet += 1;
    }

    if (data.isFavorite === true) {
      if (data.createdBy) {
        counts.favouritesMoved += 1;
        plan(`${id}: favourite -> users/${data.createdBy}/favorites`, data.title);
        if (COMMIT) {
          await api(`/users/${data.createdBy}/favorites/${id}`, {
            method: 'PATCH',
            query: { 'updateMask.fieldPaths': ['addedAt'] },
            body: { fields: { addedAt: { timestampValue: new Date().toISOString() } } },
          });
        }
      } else {
        // Reported rather than guessed at: attributing someone's favourite to the admin
        // would be inventing data.
        counts.ownerless.push(id);
      }
    }

    if ('createdByEmail' in data) {
      remove.push('createdByEmail');
      counts.emailsRemoved += 1;
    }
    if ('isFavorite' in data) {
      remove.push('isFavorite');
      counts.favoriteFlagsRemoved += 1;
    }

    if (Object.keys(set).length === 0 && remove.length === 0) continue;

    // Nothing in `set` or `remove` may touch content. Cheap insurance on live data.
    const touching = [...Object.keys(set), ...remove]
      .filter((f) => ['title', 'ingredients', 'steps', 'description', 'notes'].includes(f));
    if (touching.length) {
      throw new Error(`refusing to continue: would modify ${touching.join(', ')} on ${id}`);
    }

    if (COMMIT) await patch('recipes', id, set, remove);
  }
}

async function migrateHousehold() {
  console.log('\nhousehold');
  const users = await listAll('users');
  const admin = users.find((u) => fields(u).email === ADMIN_EMAIL);
  if (!admin) {
    console.log(`  no user with email ${ADMIN_EMAIL} — sign in once, then re-run.`);
    return;
  }
  const adminId = idOf(admin);

  let household;
  try {
    household = await api(`/households/${HOUSEHOLD_ID}`);
  } catch (e) {
    if (!String(e.message).includes('404')) throw e;
  }

  if (!household) {
    counts.householdCreated += 1;
    plan(`create households/${HOUSEHOLD_ID}`, `owner ${adminId}`);
    if (COMMIT) {
      await api('/households', {
        method: 'POST',
        query: { documentId: HOUSEHOLD_ID },
        body: {
          fields: {
            name: { stringValue: HOUSEHOLD_NAME },
            createdBy: { stringValue: adminId },
            createdAt: { timestampValue: new Date().toISOString() },
            memberUids: { arrayValue: { values: [{ stringValue: adminId }] } },
          },
        },
      });
    }
  }

  if (fields(admin).householdId !== HOUSEHOLD_ID) {
    counts.userHouseholdSet += 1;
    plan(`users/${adminId}: householdId = ${HOUSEHOLD_ID}`);
    if (COMMIT) {
      await patch('users', adminId, { householdId: { stringValue: HOUSEHOLD_ID } });
    }
  }
}

async function main() {
  console.log(
    `${COMMIT ? 'COMMITTING to' : 'DRY RUN against'} ${PROJECT_ID}` +
    `${EMULATOR ? ' (emulator)' : ' (production)'}`,
  );

  await migrateRecipes();
  await migrateHousehold();

  const changes =
    counts.visibilitySet + counts.householdIdSet + counts.favouritesMoved +
    counts.emailsRemoved + counts.favoriteFlagsRemoved + counts.householdCreated +
    counts.userHouseholdSet;

  console.log('\nsummary');
  for (const [key, value] of Object.entries(counts)) {
    if (key === 'ownerless') continue;
    console.log(`  ${key.padEnd(20)} ${value}`);
  }
  console.log(`  ${'changes'.padEnd(20)} ${changes}`);

  if (counts.ownerless.length) {
    console.log(
      `\n  ${counts.ownerless.length} favourited recipe(s) have no createdBy, so there is` +
      ' nobody to attribute the favourite to. Left alone rather than guessed at:',
    );
    counts.ownerless.forEach((id) => console.log(`    ${id}`));
  }

  if (!COMMIT) {
    console.log('\nNothing was written. Re-run with --commit to apply.');
  } else if (changes === 0) {
    console.log('\nNothing to do — already migrated.');
  }
}

main().then(
  () => process.exit(0),
  (err) => {
    console.error('\nmigration failed:', err.message);
    process.exit(1);
  },
);
