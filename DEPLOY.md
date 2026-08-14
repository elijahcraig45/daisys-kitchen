# Deploying this

Everything below is built and tested locally. Nothing here has been deployed yet.

CI (`.github/workflows/deploy.yml`) deploys **hosting only** on a push to `main`. Rules,
indexes and functions are manual. Every `firebase` command needs the
`env -u GOOGLE_APPLICATION_CREDENTIALS` prefix — this machine exports a *work*
service-account key that firebase-tools prefers over the personal login, and without it
you get 401s that look like a login problem while `firebase login:list` cheerfully shows
the right account.

## 0. Rotate the Gemini API key — do this first

The current key has been served to every visitor of the site: it was in Firebase Remote
Config, which is delivered to the client, and `gemini_service.dart` put it in a request
URL. Treat it as public.

1. Delete the existing key in Google AI Studio and create a new one.
2. Give it to the functions, not to Remote Config:
   ```
   cd functions
   env -u GOOGLE_APPLICATION_CREDENTIALS firebase functions:secrets:set GEMINI_API_KEY
   ```
3. Delete `gemini_api_key` from Remote Config. `gemini_model` and `gemini_enabled` stay —
   a model name is not a secret and a kill switch is useful.

Nothing else in this list depends on the key, so the rest can proceed either way. The
exposure only stops when the old key is dead.

## 1. Indexes

Three composite indexes, required by the scoped recipe queries. Without them those queries
return `400 FAILED_PRECONDITION` — they do not merely run slowly.

```
env -u GOOGLE_APPLICATION_CREDENTIALS firebase deploy --only firestore:indexes
```

Wait for them to finish building in the console before step 3.

## 2. Migration

Adds `visibility: "public"` to the existing recipes, moves shared favourites to their
owners, strips `createdByEmail`, and creates the household.

```
cd scripts && npm install
node migrate_visibility.js                 # dry run, writes nothing
```

Read the plan. Then, ideally against a restored export first:

```
gcloud firestore export gs://<bucket>/pre-visibility --project recipe-f644f
env -u GOOGLE_APPLICATION_CREDENTIALS firebase emulators:start --only firestore --import <export>
node migrate_visibility.js --commit --emulator
node verify_migration.js
```

Then production:

```
node migrate_visibility.js --commit
node migrate_visibility.js --commit          # must report "changes 0"
```

It is idempotent, so the second run is the check rather than a risk. `npm run test:migration`
runs the whole sequence against a seeded emulator, including the awkward rows.

## 3. Rules

Safe once step 2 has run: before that, tightening the rules would hide recipes that have no
`visibility` yet.

```
env -u GOOGLE_APPLICATION_CREDENTIALS firebase deploy --only firestore:rules
```

Verify first — this is the deploy where a mistake is a data leak rather than a bug:

```
cd test/rules && npm install && env -u GOOGLE_APPLICATION_CREDENTIALS npm test   # 39 tests
```

## 4. Functions

`geminiProxy`, `recipeAutofillProxy`, and the four household functions.

```
env -u GOOGLE_APPLICATION_CREDENTIALS firebase deploy --only functions
```

The secret from step 0 must already be set, or `geminiProxy` deploys with nothing bound.

## 5. Hosting

Deploy functions and hosting **back to back**. `recipeAutofillProxy` changed from an HTTP
function to a callable, so the currently-live bundle calls an endpoint the new functions do
not expose, and the new bundle calls a callable the old functions do not have. Importing a
recipe from a link is broken in the gap, whichever order you use.

Easiest: push to `main` and let CI build and deploy hosting.

Locally is a trap worth knowing about: a machine-global `flutter config --build-dir` sends
output to `server/build/web`, while `firebase.json` serves `build/web`, so a local
`firebase deploy --only hosting` publishes stale or missing files. CI is unaffected because
it starts from a fresh checkout.

## 6. Afterwards, in the console

- **App Check** on Firestore and Functions, so requests must come from the real app rather
  than a script with the project id. Ship the client attestation first and turn
  **enforcement** on second, or the app locks itself out.
- **A budget alert** on the billing account. Everything here is designed to sit inside the
  free tiers — functions scale to zero, AI is limited to two accounts — but Blaze is
  pay-as-you-go and an alert is the difference between noticing and finding out.
- **Set `isAdmin: true`** on your own `users/{uid}` document, by hand. The client can no
  longer write that field, which is the point: anything that can write it can promote
  itself. Nothing needs an admin until a report is filed.

## Re-hosted recipe images — two steps left

`cacheRecipeImage` is deployed and refuses unauthenticated callers, but it cannot copy
anything until the project has a Storage bucket. Everything else for it is live.

**1. Create the bucket.** The Cloud Storage for Firebase API is not enabled, and the
bucket's location is permanent once chosen — so this is a deliberate decision rather than
something to script. Firebase console → Storage → Get started, and pick **us-central1** to
match the functions; a cross-region read is billed as egress.

The bucket will be `recipe-f644f.firebasestorage.app`. If it comes out as something else,
the function names what it tried in the error rather than failing quietly, and
`RECIPE_IMAGE_BUCKET` overrides it. Then:

```
env -u GOOGLE_APPLICATION_CREDENTIALS firebase deploy --only storage
```

`storage.rules` denies every read and write: the only writer is the function via the Admin
SDK, and reads go through the download token in each `cachedImageUrl`. Verify both after
deploying — a token URL should return the image with
`access-control-allow-origin: *`, and the same object by plain path should 403.

**2. Clean three live recipes.** `updateRecipe` used to write `updatedByEmail`, and recipes
are world-readable when public, so an address is on three of them right now. The write is
gone and the rules refuse it, but the stored values need deleting:

```
cd scripts
export FIRESTORE_ACCESS_TOKEN=$(gcloud auth print-access-token --account=elijahcraig45@gmail.com)
node cleanup_recipes.js                # dry run: 3 emails, 2 unusable imageUrls
node cleanup_recipes.js --commit
node cleanup_recipes.js --commit        # must report "already clean"
```

It also empties two `imageUrl` values that cannot render — a truncated `data:` URI and an
`example.com` placeholder — so the app draws its own placeholder instead of a broken image.
Recipes and users were backed up to `~/Documents/personalDev/recipes-backups` first.

Existing images are copied lazily: opening one of your own recipes fires the call once per
session, and saving one does too. Nothing to run.

## The wall calendar

Separate repo, separate deploy, and it no longer cares about the order above: it tries the
filtered query and falls back to the unfiltered one, so it works before the indexes exist,
before the migration runs, and after the rules tighten. Push it whenever.

## What is not built

- Weekly-ad matching and rebuy suggestions (Phase 4). Deferred deliberately — see
  `specs/community-and-lists/tasks.md` for the reasoning.
- A Gemini fallback for ingredients the parser cannot read (T3.5), and the wall's grocery
  page (T3.6). Both deferred with reasons in the same file.
- Self-serve account deletion. The privacy page says so plainly rather than implying a
  button that does not exist.
