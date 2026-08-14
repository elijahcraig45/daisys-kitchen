#!/usr/bin/env node
/**
 * Asserts the end state after the migration, rather than trusting its own summary counts.
 *
 * A migration that reports "3 changes" and wrote the wrong thing still reports 3 changes,
 * so this reads the data back and checks the properties that matter. Emulator only.
 */

// Emulator by default. Pass --production with FIRESTORE_ACCESS_TOKEN to check the real
// thing after a migration, which is the only way to know it did what it said.
const PRODUCTION = process.argv.includes('--production');
if (!PRODUCTION) {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
}

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const token = process.env.FIRESTORE_ACCESS_TOKEN;
initializeApp({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'recipe-f644f',
  ...(PRODUCTION && token
    ? {
        credential: {
          getAccessToken: async () => ({ access_token: token, expires_in: 3300 }),
        },
      }
    : {}),
});
const db = getFirestore();

const failures = [];
function check(label, condition, detail = '') {
  if (condition) {
    console.log(`  ok    ${label}`);
  } else {
    console.log(`  FAIL  ${label}${detail ? ` — ${detail}` : ''}`);
    failures.push(label);
  }
}

async function main() {
  const recipes = {};
  for (const d of (await db.collection('recipes').get()).docs) {
    recipes[d.id] = d.data();
  }

  check('every recipe has a visibility',
    Object.values(recipes).every((r) => typeof r.visibility === 'string'));

  check('the ordinary recipe became public', recipes.a?.visibility === 'public',
    `got ${recipes.a?.visibility}`);

  check('a deliberately private recipe was NOT republished',
    recipes.d?.visibility === 'private', `got ${recipes.d?.visibility}`);

  check('no recipe still carries createdByEmail',
    Object.values(recipes).every((r) => !('createdByEmail' in r)));

  check('no recipe still carries isFavorite',
    Object.values(recipes).every((r) => !('isFavorite' in r)));

  check('content survived: title, ingredients and steps intact',
    recipes.a?.title === 'Apple Crisp Oat Bars' &&
    recipes.a?.ingredients?.length === 1 &&
    recipes.a?.steps?.length === 1);

  const fav = await db.doc('users/henryuid/favorites/a').get();
  check('the owned favourite moved to the owner', fav.exists);

  const orphanFav = await db.collection('users').get();
  const strayFavourites = [];
  for (const u of orphanFav.docs) {
    const subs = await u.ref.collection('favorites').get();
    for (const f of subs.docs) if (f.id === 'b') strayFavourites.push(u.id);
  }
  check('the ownerless favourite was not attributed to anyone',
    strayFavourites.length === 0, `attributed to ${strayFavourites.join(', ')}`);

  const household = await db.doc('households/home').get();
  check('the household exists with the admin as its only member',
    household.exists && JSON.stringify(household.data().memberUids) === '["henryuid"]',
    JSON.stringify(household.data()?.memberUids));

  const user = await db.doc('users/henryuid').get();
  check('the admin is in the household', user.data()?.householdId === 'home');

  console.log();
  if (failures.length) {
    console.log(`${failures.length} check(s) failed`);
    process.exit(1);
  }
  console.log('end state verified');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
