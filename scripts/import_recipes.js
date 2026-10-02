#!/usr/bin/env node
/**
 * Imports recipes from a JSON file into the recipes collection, over the Firestore REST API.
 *
 *   node import_recipes.js --emulator --commit
 *   FIRESTORE_ACCESS_TOKEN=... node import_recipes.js              # dry run, production
 *   FIRESTORE_ACCESS_TOKEN=... node import_recipes.js --commit
 *
 * REST rather than firebase-admin for the same reason as migrate_rest.js: a plain OAuth
 * access token from `gcloud auth print-access-token` works here, where the Admin SDK
 * would need an interactive ADC login.
 *
 * Titles already present in the collection are skipped rather than written twice, so a
 * partial run can simply be run again.
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const COMMIT = args.includes('--commit');
const EMULATOR = args.includes('--emulator');
const FILE = (args.find((a) => a.startsWith('--file=')) || '').split('=')[1]
  || path.join(__dirname, 'pdf_recipes.json');

const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || 'recipe-f644f';
const TOKEN = process.env.FIRESTORE_ACCESS_TOKEN;
const ADMIN_EMAIL = 'elijahcraig45@gmail.com';

/* Authorship is stamped here because the client's FirestoreService cannot: this runs
   outside the app. Both must match an existing account or the recipe is ownerless and
   the rules will refuse every later edit. */
const CREATED_BY = process.env.IMPORT_CREATED_BY || '9qf86mqaGwbra22Jq6UFSX40ACl1';
const CREATED_BY_NAME = process.env.IMPORT_CREATED_BY_NAME || 'Henry Craig';

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

const str = (v) => (v == null ? { nullValue: null } : { stringValue: String(v) });
const int = (v) => (v == null ? { nullValue: null } : { integerValue: String(v) });
const arr = (values) => ({ arrayValue: { values } });
const map = (fields) => ({ mapValue: { fields } });

/* Mirrors RecipeMapper.toFirestore. Fields it deliberately omits — isFavorite,
   cachedImageUrl and friends — are omitted here too, for the same reasons. */
function toDocument(recipe, now) {
  return {
    title: str(recipe.title),
    description: str(recipe.description),
    prepTimeMinutes: int(recipe.prepTimeMinutes),
    cookTimeMinutes: int(recipe.cookTimeMinutes),
    servings: int(recipe.servings),
    difficulty: str(recipe.difficulty || 'medium'),
    category: str(recipe.category),
    cuisine: str(recipe.cuisine),
    imageUrl: { nullValue: null },
    notes: str(recipe.notes),
    source: str(recipe.source),
    tags: arr((recipe.tags || []).map(str)),
    ingredients: arr((recipe.ingredients || []).map((i) => map({
      name: str(i.name),
      amount: str(i.amount ?? ''),
      unit: str(i.unit),
      notes: str(i.notes),
      measurementSystem: str('customary'),
      secondaryAmount: { nullValue: null },
      secondaryUnit: { nullValue: null },
      secondarySystem: { nullValue: null },
    }))),
    steps: arr((recipe.steps || []).map((instruction, index) => map({
      stepNumber: int(index + 1),
      title: str(''),
      instruction: str(instruction),
      timerSeconds: { nullValue: null },
      timerLabel: { nullValue: null },
      ingredientsForStep: { nullValue: null },
    }))),
    visibility: str('public'),
    householdId: { nullValue: null },
    forkedFrom: { nullValue: null },
    createdBy: str(CREATED_BY),
    createdByName: str(CREATED_BY_NAME),
    createdAt: { timestampValue: now },
    updatedAt: { timestampValue: now },
  };
}

async function listTitles() {
  const titles = new Set();
  let pageToken;
  do {
    const page = await api('/recipes', {
      query: { pageSize: 300, ...(pageToken ? { pageToken } : {}) },
    });
    for (const doc of page.documents || []) {
      const title = doc.fields?.title?.stringValue;
      if (title) titles.add(title.trim().toLowerCase());
    }
    pageToken = page.nextPageToken;
  } while (pageToken);
  return titles;
}

async function main() {
  const recipes = JSON.parse(fs.readFileSync(FILE, 'utf8'));
  console.log(`${COMMIT ? 'COMMIT' : 'DRY RUN'} — ${recipes.length} recipes from ${FILE}`);
  console.log(`target: ${EMULATOR ? 'emulator' : PROJECT_ID}\n`);

  const existing = await listTitles();
  let written = 0;
  let skipped = 0;

  for (const recipe of recipes) {
    if (existing.has(recipe.title.trim().toLowerCase())) {
      console.log(`  skip  ${recipe.title} — a recipe with this title already exists`);
      skipped += 1;
      continue;
    }
    console.log(
      `  ${COMMIT ? 'DO  ' : 'plan'}  ${recipe.title} ` +
      `(${recipe.ingredients.length} ingredients, ${recipe.steps.length} steps)`,
    );
    if (COMMIT) {
      const now = new Date().toISOString();
      await api('/recipes', { method: 'POST', body: { fields: toDocument(recipe, now) } });
      existing.add(recipe.title.trim().toLowerCase());
    }
    written += 1;
  }

  console.log(`\n${COMMIT ? 'wrote' : 'would write'} ${written}, skipped ${skipped}`);
  if (!COMMIT) console.log('Re-run with --commit to apply.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
