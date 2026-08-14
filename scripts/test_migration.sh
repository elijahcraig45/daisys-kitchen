#!/usr/bin/env bash
# Exercises the migration against an emulator: seed, dry run, commit, then commit again.
#
# The second commit is the point. The migration edits live recipes, so it has to be
# re-runnable — a half-finished run followed by a retry must not double anything up, and
# "already migrated" has to be a no-op rather than an error.
#
# Run via: cd scripts && npm run test:migration
set -euo pipefail

cd "$(dirname "$0")"

echo "── seed ─────────────────────────────────────────"
node seed_migration_fixture.js

echo
echo "── dry run (must write nothing) ─────────────────"
node migrate_visibility.js --emulator

echo
echo "── commit ──────────────────────────────────────"
node migrate_visibility.js --commit --emulator

echo
echo "── commit again (must report 0 changes) ────────"
output="$(node migrate_visibility.js --commit --emulator)"
echo "$output"

if ! grep -q "changes              0" <<<"$output"; then
  echo
  echo "FAIL: the migration is not idempotent — a second run still wanted to change things."
  exit 1
fi

echo
echo "── verify the end state ────────────────────────"
node verify_migration.js
