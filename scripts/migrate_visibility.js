#!/usr/bin/env node
/**
 * One-off migration for Phase 1 of specs/community-and-lists.
 *
 *   node scripts/migrate_visibility.js                  # dry run, writes nothing
 *   node scripts/migrate_visibility.js --commit         # actually writes
 *   node scripts/migrate_visibility.js --commit --emulator
 *
 * Dry run is the default deliberately: this edits live recipes, and the safe mistake is
 * printing a plan nobody asked for rather than rewriting a database nobody expected.
 *
 * Idempotent by construction — every step is conditional on the field's current state, so
 * a second run reports zero changes. That is asserted rather than assumed: run it twice.
 *
 * What it does:
 *   1. recipes: set visibility 'public' and householdId null where absent. Existing
 *      recipes are world-readable today, so 'public' preserves what people can see. It
 *      never overwrites a visibility that is already set.
 *   2. recipes with isFavorite true: write users/{createdBy}/favorites/{recipeId},
 *      because that flag was shared state and is now per-user.
 *   3. recipes: delete createdByEmail and isFavorite.
 *   4. the admin's household, and householdId on their user document.
 *
 * Verify before production:
 *   gcloud firestore export gs://<bucket>/pre-visibility
 *   firebase emulators:start --only firestore --import <exported>
 *   node scripts/migrate_visibility.js --commit --emulator
 *   node scripts/migrate_visibility.js --commit --emulator    # must report 0 changes
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const args = process.argv.slice(2);
const COMMIT = args.includes('--commit');
const EMULATOR = args.includes('--emulator');
const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || 'recipe-f644f';

// The household the existing recipes' author ends up in. Everything else is derived.
const ADMIN_EMAIL = 'elijahcraig45@gmail.com';
const HOUSEHOLD_ID = 'home';
const HOUSEHOLD_NAME = 'Home';

if (EMULATOR) {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
}

initializeApp(
  EMULATOR ? { projectId: PROJECT_ID } : { credential: applicationDefault(), projectId: PROJECT_ID },
);
const db = getFirestore();

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

/** Refuses to proceed if a recipe would lose content. Cheap insurance on live data. */
function assertContentPreserved(before, after) {
  const same = (key) => JSON.stringify(before[key] ?? null) === JSON.stringify(after[key] ?? null);
  for (const key of ['title', 'ingredients', 'steps', 'description', 'notes']) {
    if (!same(key)) {
      throw new Error(`refusing to continue: ${key} would change on a migration write`);
    }
  }
}

async function migrateRecipes() {
  console.log('\nrecipes');
  const snap = await db.collection('recipes').get();
  counts.recipesScanned = snap.size;

  for (const docSnap of snap.docs) {
    const data = docSnap.data();
    const update = {};

    if (data.visibility === undefined) {
      update.visibility = 'public';
      counts.visibilitySet += 1;
      plan(`${docSnap.id}: visibility = public`, data.title);
    }
    if (data.householdId === undefined) {
      update.householdId = null;
      counts.householdIdSet += 1;
    }

    // The flag was shared: whoever wrote the recipe is the only person we can honestly
    // attribute the favourite to.
    if (data.isFavorite === true) {
      if (data.createdBy) {
        counts.favouritesMoved += 1;
        plan(`${docSnap.id}: favourite -> users/${data.createdBy}/favorites`, data.title);
        if (COMMIT) {
          await db
            .collection('users').doc(data.createdBy)
            .collection('favorites').doc(docSnap.id)
            .set({ addedAt: FieldValue.serverTimestamp() }, { merge: true });
        }
      } else {
        // Reported rather than guessed at. Assigning someone else's favourite to the
        // admin would be inventing data.
        counts.ownerless.push(docSnap.id);
      }
    }

    if ('createdByEmail' in data) {
      update.createdByEmail = FieldValue.delete();
      counts.emailsRemoved += 1;
    }
    if ('isFavorite' in data) {
      update.isFavorite = FieldValue.delete();
      counts.favoriteFlagsRemoved += 1;
    }

    if (Object.keys(update).length === 0) continue;

    assertContentPreserved(data, { ...data, ...update });
    if (COMMIT) await docSnap.ref.update(update);
  }
}

async function migrateHousehold() {
  console.log('\nhousehold');
  const users = await db.collection('users').where('email', '==', ADMIN_EMAIL).get();
  if (users.empty) {
    console.log(`  no user with email ${ADMIN_EMAIL} — sign in once, then re-run.`);
    return;
  }
  const user = users.docs[0];

  const household = await db.collection('households').doc(HOUSEHOLD_ID).get();
  if (!household.exists) {
    counts.householdCreated += 1;
    plan(`create households/${HOUSEHOLD_ID}`, `owner ${user.id}`);
    if (COMMIT) {
      await household.ref.set({
        name: HOUSEHOLD_NAME,
        createdBy: user.id,
        createdAt: FieldValue.serverTimestamp(),
        memberUids: [user.id],
      });
    }
  }

  if (user.data().householdId !== HOUSEHOLD_ID) {
    counts.userHouseholdSet += 1;
    plan(`users/${user.id}: householdId = ${HOUSEHOLD_ID}`);
    if (COMMIT) await user.ref.update({ householdId: HOUSEHOLD_ID });
  }
}

async function main() {
  console.log(
    `${COMMIT ? 'COMMITTING to' : 'DRY RUN against'} ${PROJECT_ID}` +
    `${EMULATOR ? ' (emulator)' : ''}`,
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
