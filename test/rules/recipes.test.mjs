/**
 * Security rules tests.
 *
 * These exist because rules are the one artifact here where a mistake is a data leak
 * rather than a bug, and because there is no other way to check them: the Firestore
 * emulator started with `--only firestore` does not compile the rules file at all.
 * Confirmed by planting a call to an undefined function and watching the emulator
 * start happily. `initializeTestEnvironment` uploads the rules, so invalid syntax
 * fails here — which makes this both the correctness check and the only syntax check.
 *
 * Run: cd test/rules && npm test
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import test, { before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(here, '..', '..', 'firestore.rules'), 'utf8');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'daisys-rules-test',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});

after(async () => {
  await env?.cleanup();
});

function recipeDoc(overrides = {}) {
  return {
    title: 'Lemon Orzo',
    description: 'A weeknight thing.',
    servings: 4,
    ingredients: [{ name: 'orzo', amount: '1', unit: 'cup' }],
    steps: [{ stepNumber: 1, instruction: 'Boil it.' }],
    createdBy: 'henry',
    createdByName: 'Henry',
    visibility: 'private',
    ...overrides,
  };
}

/* Fixtures are rebuilt for every test with rules disabled, so each test starts from a
   known database and none of them depend on the order they run in. */
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/henry'), {
      email: 'henry@example.com', displayName: 'Henry', householdId: 'home',
    });
    await setDoc(doc(db, 'users/tee'), {
      email: 'tee@example.com', displayName: 'Tee', householdId: 'home',
    });
    await setDoc(doc(db, 'users/stranger'), {
      email: 'stranger@example.com', displayName: 'Stranger',
    });
    await setDoc(doc(db, 'users/loner'), {
      email: 'loner@example.com', displayName: 'Loner',
    });
    await setDoc(doc(db, 'users/boss'), {
      email: 'boss@example.com', displayName: 'Boss', isAdmin: true,
    });
    await setDoc(doc(db, 'households/home'), {
      name: 'Home', createdBy: 'henry', memberUids: ['henry', 'tee'],
    });
    await setDoc(doc(db, 'recipes/pub'), recipeDoc({ visibility: 'public' }));
    await setDoc(doc(db, 'recipes/hh'), recipeDoc({ visibility: 'household', householdId: 'home' }));
    await setDoc(doc(db, 'recipes/priv'), recipeDoc({ visibility: 'private' }));
    await setDoc(doc(db, 'recipes/legacy'), { title: 'Legacy', createdBy: 'henry' });
    await setDoc(doc(db, 'groceryLists/home-list'), { householdId: 'home', name: 'Groceries' });
  });
});

const as = (uid, opts = {}) =>
  env.authenticatedContext(uid, {
    email: `${uid}@example.com`,
    email_verified: true,
    firebase: { sign_in_provider: 'google.com' },
    ...opts,
  }).firestore();
const asAnon = () =>
  env.authenticatedContext('ghost', {
    firebase: { sign_in_provider: 'anonymous' },
  }).firestore();
const asVisitor = () => env.unauthenticatedContext().firestore();

/* ---------- reading recipes (R1.4) ---------- */

test('a visitor reads public recipes only', async () => {
  await assertSucceeds(getDoc(doc(asVisitor(), 'recipes/pub')));
  await assertFails(getDoc(doc(asVisitor(), 'recipes/hh')));
  await assertFails(getDoc(doc(asVisitor(), 'recipes/priv')));
});

test('a household member reads the household recipe', async () => {
  await assertSucceeds(getDoc(doc(as('tee'), 'recipes/hh')));
});

test('a stranger cannot read another household recipe', async () => {
  await assertFails(getDoc(doc(as('stranger'), 'recipes/hh')));
});

test('the owner reads their own private recipe, nobody else does', async () => {
  await assertSucceeds(getDoc(doc(as('henry'), 'recipes/priv')));
  await assertFails(getDoc(doc(as('tee'), 'recipes/priv')));
});

test('an admin can read anything', async () => {
  await assertSucceeds(getDoc(doc(as('boss'), 'recipes/priv')));
});

test('a recipe with no visibility is treated as private, not public', async () => {
  await assertFails(getDoc(doc(asVisitor(), 'recipes/legacy')));
});

test('two users with no household do not share one', async () => {
  // The null check in sharesHousehold(). Without it, "no household" equals "no
  // household" and strangers would read each other's profiles and private recipes.
  await assertFails(getDoc(doc(as('stranger'), 'users/loner')));
});

test('a constrained public query succeeds where an open one fails', async () => {
  // Rules do not filter: an unconstrained collection read is refused outright, which is
  // why the client and the wall calendar both have to ask for visibility == public.
  const recipes = collection(asVisitor(), 'recipes');
  await assertFails(getDocs(recipes));
  await assertSucceeds(getDocs(query(recipes, where('visibility', '==', 'public'))));
});

/* ---------- writing recipes ---------- */

test('publishing requires a durable account (R1.5)', async () => {
  await assertFails(
    setDoc(doc(asAnon(), 'recipes/new1'), recipeDoc({ createdBy: 'ghost', visibility: 'public' })),
  );
  // ...but an anonymous account may still keep private recipes.
  await assertSucceeds(
    setDoc(doc(asAnon(), 'recipes/new2'), recipeDoc({ createdBy: 'ghost', visibility: 'private' })),
  );
});

test('a household recipe must name your own household', async () => {
  await assertFails(
    setDoc(doc(as('stranger'), 'recipes/new3'),
      recipeDoc({ createdBy: 'stranger', visibility: 'household', householdId: 'home' })),
  );
  await assertSucceeds(
    setDoc(doc(as('henry'), 'recipes/new4'),
      recipeDoc({ createdBy: 'henry', visibility: 'household', householdId: 'home' })),
  );
});

test('an unrecognised visibility is refused on write', async () => {
  await assertFails(
    setDoc(doc(as('henry'), 'recipes/new5'), recipeDoc({ visibility: 'everyone' })),
  );
});

test('favourites no longer let anyone write anyone else recipe (R1.2)', async () => {
  // The old rules carved out isFavorite so any signed-in user could write any recipe.
  await assertFails(updateDoc(doc(as('tee'), 'recipes/pub'), { isFavorite: true }));
});

test('ownership cannot be transferred by an update', async () => {
  await assertFails(updateDoc(doc(as('henry'), 'recipes/pub'), { createdBy: 'tee' }));
});

test('size caps and image urls are enforced on create and update', async () => {
  await assertFails(
    setDoc(doc(as('henry'), 'recipes/new6'), recipeDoc({ title: 'x'.repeat(201) })),
  );
  await assertFails(
    setDoc(doc(as('henry'), 'recipes/new7'), recipeDoc({ imageUrl: 'javascript:alert(1)' })),
  );
  await assertFails(updateDoc(doc(as('henry'), 'recipes/pub'), { notes: 'x'.repeat(5001) }));
  await assertSucceeds(
    setDoc(doc(as('henry'), 'recipes/new8'), recipeDoc({ imageUrl: 'https://x.test/a.jpg' })),
  );
});

/* ---------- profiles and privileges (R1.3, R1.12) ---------- */

test('a stranger cannot read my profile, so my email is not public (R1.3)', async () => {
  // This assertion was the other way round before R1.3: users/{uid} was world-readable
  // and those documents hold an email address.
  await assertFails(getDoc(doc(as('stranger'), 'users/henry')));
  await assertFails(getDoc(doc(asVisitor(), 'users/henry')));
});

test('I can read my own profile, and my household can', async () => {
  await assertSucceeds(getDoc(doc(as('henry'), 'users/henry')));
  await assertSucceeds(getDoc(doc(as('tee'), 'users/henry')));
});

test('a user cannot promote themselves (R1.12)', async () => {
  await assertFails(updateDoc(doc(as('stranger'), 'users/stranger'), { isAdmin: true }));
  await assertFails(updateDoc(doc(as('stranger'), 'users/stranger'), { aiEnabled: true }));
  await assertFails(updateDoc(doc(as('stranger'), 'users/stranger'), { householdId: 'home' }));
  await assertSucceeds(updateDoc(doc(as('stranger'), 'users/stranger'), { displayName: 'S' }));
});

test('a new account cannot create itself with privileges', async () => {
  await assertFails(setDoc(doc(as('fresh'), 'users/fresh'), { email: 'f@x', isAdmin: true }));
  await assertFails(setDoc(doc(as('fresh'), 'users/fresh'), { email: 'f@x', aiEnabled: true }));
  await assertFails(setDoc(doc(as('fresh'), 'users/fresh'), { email: 'f@x', householdId: 'home' }));
  await assertSucceeds(setDoc(doc(as('fresh'), 'users/fresh'), { email: 'f@x' }));
});

test('a profile cannot be deleted, so a claim cannot be reset by recreating it', async () => {
  await assertFails(deleteDoc(doc(as('henry'), 'users/henry')));
});

test('favourites are private to their owner', async () => {
  await assertSucceeds(setDoc(doc(as('henry'), 'users/henry/favorites/pub'), { addedAt: 1 }));
  await assertFails(setDoc(doc(as('tee'), 'users/henry/favorites/pub'), { addedAt: 1 }));
  await assertFails(getDoc(doc(as('tee'), 'users/henry/favorites/pub')));
});

/* ---------- households ---------- */

test('only members read a household', async () => {
  await assertSucceeds(getDoc(doc(as('henry'), 'households/home')));
  await assertFails(getDoc(doc(as('stranger'), 'households/home')));
});

test('a household is created with yourself as the only member', async () => {
  await assertSucceeds(
    setDoc(doc(as('stranger'), 'households/new'),
      { name: 'Theirs', createdBy: 'stranger', memberUids: ['stranger'] }),
  );
  await assertFails(
    setDoc(doc(as('stranger'), 'households/sneaky'),
      { name: 'Sneaky', createdBy: 'stranger', memberUids: ['stranger', 'henry'] }),
  );
});

test('a stranger cannot add themselves to someone else household', async () => {
  await assertFails(
    updateDoc(doc(as('stranger'), 'households/home'),
      { memberUids: ['henry', 'tee', 'stranger'] }),
  );
});

test('a member may rename but not change membership', async () => {
  await assertSucceeds(updateDoc(doc(as('henry'), 'households/home'), { name: 'Our Kitchen' }));
  await assertFails(updateDoc(doc(as('henry'), 'households/home'), { memberUids: ['henry'] }));
});

test('invite codes are unreadable by clients', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'householdInvites/ABC123'), { householdId: 'home' });
  });
  await assertFails(getDoc(doc(as('stranger'), 'householdInvites/ABC123')));
  await assertFails(getDoc(doc(as('henry'), 'householdInvites/ABC123')));
});

/* ---------- reports (R2.6) ---------- */

test('anyone signed in can report, only an admin can read reports', async () => {
  await assertSucceeds(
    setDoc(doc(as('stranger'), 'reports/rep1'),
      { recipeId: 'pub', reportedBy: 'stranger', reason: 'spam' }),
  );
  // The author must not be able to see who reported them.
  await assertFails(getDoc(doc(as('henry'), 'reports/rep1')));
  await assertSucceeds(getDoc(doc(as('boss'), 'reports/rep1')));
});

test('a report cannot be filed in someone else name', async () => {
  await assertFails(
    setDoc(doc(as('stranger'), 'reports/rep2'),
      { recipeId: 'pub', reportedBy: 'henry', reason: 'framing' }),
  );
});

/* ---------- grocery lists (R3.1) ---------- */

test('household members share a grocery list, strangers get nothing', async () => {
  await assertSucceeds(getDoc(doc(as('tee'), 'groceryLists/home-list')));
  await assertFails(getDoc(doc(as('stranger'), 'groceryLists/home-list')));
});

test('list items follow the list household', async () => {
  await assertSucceeds(
    setDoc(doc(as('tee'), 'groceryLists/home-list/items/i1'), { display: 'Orzo' }),
  );
  await assertFails(
    setDoc(doc(as('stranger'), 'groceryLists/home-list/items/i2'), { display: 'Sneaky' }),
  );
});

test('a user with no household cannot create a list', async () => {
  await assertFails(
    setDoc(doc(as('loner'), 'groceryLists/nope'), { householdId: null, name: 'Mine' }),
  );
});

test('purchase history is household-scoped', async () => {
  await assertSucceeds(
    setDoc(doc(as('henry'), 'groceryHistory/home/purchases/p1'), { canonicalName: 'orzo' }),
  );
  await assertFails(
    setDoc(doc(as('stranger'), 'groceryHistory/home/purchases/p2'), { canonicalName: 'orzo' }),
  );
});

test('the ingredient cache is readable but never client-writable', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'ingredientCache/abc'), { quantity: 1 });
  });
  const snap = await assertSucceeds(getDoc(doc(as('henry'), 'ingredientCache/abc')));
  assert.equal(snap.data().quantity, 1);
  await assertFails(setDoc(doc(as('henry'), 'ingredientCache/def'), { quantity: 2 }));
});

/* ---------- save and fork (R2.3, R2.4) ---------- */

test('saving a community recipe writes only to my own shelf', async () => {
  await assertSucceeds(
    setDoc(doc(as('stranger'), 'users/stranger/savedRecipes/pub'),
      { savedAt: 1, authorUid: 'henry', authorName: 'Henry' }),
  );
  // ...and touches nothing on the recipe itself.
  await assertFails(updateDoc(doc(as('stranger'), 'recipes/pub'), { title: 'Mine now' }));
});

test('a fork is a new recipe owned by the forker, starting private', async () => {
  await assertSucceeds(
    setDoc(doc(as('stranger'), 'recipes/forked'),
      recipeDoc({ createdBy: 'stranger', visibility: 'private', forkedFrom: 'pub' })),
  );
});

test('a fork cannot claim someone else as its author', async () => {
  await assertFails(
    setDoc(doc(as('stranger'), 'recipes/forged'),
      recipeDoc({ createdBy: 'henry', visibility: 'private', forkedFrom: 'pub' })),
  );
});

test('a saved reference cannot be written to someone else shelf', async () => {
  await assertFails(
    setDoc(doc(as('stranger'), 'users/henry/savedRecipes/pub'), { savedAt: 1 }),
  );
});
