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
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

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

/** A recipe that satisfies every limit, so tests can vary one thing at a time. */
function validRecipe(overrides = {}) {
  return {
    title: 'Lemon Orzo',
    description: 'A weeknight thing.',
    servings: 4,
    ingredients: [{ name: 'orzo', amount: '1', unit: 'cup' }],
    steps: [{ stepNumber: 1, instruction: 'Boil it.' }],
    createdBy: 'henry',
    createdByName: 'Henry',
    ...overrides,
  };
}

const asHenry = () => env.authenticatedContext('henry', { email: 'henry@example.com' }).firestore();
const asOther = () => env.authenticatedContext('other', { email: 'other@example.com' }).firestore();

test('a signed-in user can create a recipe they own', async () => {
  await assertSucceeds(setDoc(doc(asHenry(), 'recipes/r1'), validRecipe()));
});

test('createdBy must be the caller', async () => {
  await assertFails(
    setDoc(doc(asOther(), 'recipes/r2'), validRecipe({ createdBy: 'henry' })),
  );
});

test('an oversized title is refused', async () => {
  await assertFails(
    setDoc(doc(asHenry(), 'recipes/r3'), validRecipe({ title: 'x'.repeat(201) })),
  );
});

test('an empty title is refused', async () => {
  await assertFails(setDoc(doc(asHenry(), 'recipes/r4'), validRecipe({ title: '' })));
});

test('a megabyte of notes is refused', async () => {
  await assertFails(
    setDoc(doc(asHenry(), 'recipes/r5'), validRecipe({ notes: 'x'.repeat(5001) })),
  );
});

test('a hundred-and-one ingredients is refused', async () => {
  const ingredients = Array.from({ length: 101 }, (_, i) => ({ name: `i${i}` }));
  await assertFails(setDoc(doc(asHenry(), 'recipes/r6'), validRecipe({ ingredients })));
});

test('a javascript: image url is refused', async () => {
  await assertFails(
    setDoc(doc(asHenry(), 'recipes/r7'), validRecipe({ imageUrl: 'javascript:alert(1)' })),
  );
});

test('an http image url is refused, https is allowed', async () => {
  await assertFails(
    setDoc(doc(asHenry(), 'recipes/r8'), validRecipe({ imageUrl: 'http://example.com/a.jpg' })),
  );
  await assertSucceeds(
    setDoc(doc(asHenry(), 'recipes/r9'), validRecipe({ imageUrl: 'https://example.com/a.jpg' })),
  );
});

test('an absent image url is fine', async () => {
  await assertSucceeds(setDoc(doc(asHenry(), 'recipes/r10'), validRecipe()));
});

test('the owner can update, a stranger cannot', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'recipes/r11'), validRecipe());
  });
  await assertSucceeds(updateDoc(doc(asHenry(), 'recipes/r11'), { description: 'Updated.' }));
  await assertFails(updateDoc(doc(asOther(), 'recipes/r11'), { description: 'Hijacked.' }));
});

test('an update cannot exceed the limits either', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'recipes/r12'), validRecipe());
  });
  await assertFails(updateDoc(doc(asHenry(), 'recipes/r12'), { title: 'x'.repeat(201) }));
});

/* Documents today's behaviour rather than endorsing it: recipes are world-readable and
   `users` documents are too, which is why every signed-in user's email address is
   currently public. R1.3 changes both, and these two assertions are expected to be
   inverted by that work — they are here so the change is visible when it happens
   rather than silent. */
test('PRE-R1.3 recipes are world-readable', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'recipes/r13'), validRecipe());
  });
  const snap = await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'recipes/r13')));
  assert.equal(snap.data().title, 'Lemon Orzo');
});

test('PRE-R1.3 a stranger can read a user profile, including the email', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/henry'), { email: 'henry@example.com' });
  });
  const snap = await assertSucceeds(getDoc(doc(asOther(), 'users/henry')));
  assert.equal(snap.data().email, 'henry@example.com');
});
