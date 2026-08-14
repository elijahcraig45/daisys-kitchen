#!/usr/bin/env node
/**
 * Seeds an emulator with the awkward shapes the real database actually contains, so the
 * migration is exercised against them rather than against tidy data:
 *
 *   a  favourited, has an owner, carries createdByEmail   — the ordinary case
 *   b  favourited but has NO createdBy                    — predates the field, so there
 *                                                            is nobody to attribute the
 *                                                            favourite to
 *   c  already migrated                                    — proves idempotence
 *   d  a visibility already set to private                 — must not be overwritten to
 *                                                            public
 *
 * Emulator only: it refuses to run without FIRESTORE_EMULATOR_HOST, because seeding
 * fixtures into production would be a memorable mistake.
 */

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({ projectId: process.env.GOOGLE_CLOUD_PROJECT || 'recipe-f644f' });
const db = getFirestore();

async function main() {
  await db.collection('users').doc('henryuid').set({
    email: 'elijahcraig45@gmail.com',
    displayName: 'Henry',
  });

  await db.collection('recipes').doc('a').set({
    title: 'Apple Crisp Oat Bars',
    description: 'Real shape: has an owner and a published email.',
    ingredients: [{ name: 'All-purpose flour', amount: '1.5', unit: 'cups (180g)' }],
    steps: [{ stepNumber: 1, instruction: 'Bake it.' }],
    createdBy: 'henryuid',
    createdByEmail: 'elijahcraig45@gmail.com',
    createdByName: 'Henry',
    isFavorite: true,
  });

  await db.collection('recipes').doc('b').set({
    title: 'Orphan Bars',
    description: 'Favourited, but predates createdBy.',
    ingredients: [{ name: 'oats' }],
    steps: [{ stepNumber: 1, instruction: 'Stir.' }],
    isFavorite: true,
  });

  await db.collection('recipes').doc('c').set({
    title: 'Already Migrated',
    ingredients: [],
    steps: [],
    createdBy: 'henryuid',
    visibility: 'public',
    householdId: null,
  });

  await db.collection('recipes').doc('d').set({
    title: 'Deliberately Private',
    ingredients: [],
    steps: [],
    createdBy: 'henryuid',
    visibility: 'private',
  });

  console.log('seeded 4 recipes and 1 user');
}

main().then(() => process.exit(0), (e) => {
  console.error(e);
  process.exit(1);
});
