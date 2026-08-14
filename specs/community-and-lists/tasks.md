# Tasks — community, households, and grocery lists

Status: draft, awaiting review
Satisfies: `requirements.md` · Designed in: `design.md`

Work top to bottom. Each task cites the requirements it satisfies; commits cite the task
id (`T1.4`). A task is done when its requirements' acceptance criteria pass, not when the
code is written.

---

## Phase 0 — hosting safety

These are live exposures, not new-feature work, and community access makes each of them
worse. They come first.

### T0.1 Rotate the Gemini API key — R1.8
**Henry, in the console, before anything else.** The current key has been served to every
visitor of a public site via Remote Config and must be treated as compromised. Rotate it,
and keep the new value out of Remote Config — T0.2 puts it in Secret Manager.

### T0.2 Move Gemini server-side and gate it — R1.8, R1.9
`functions/index.js`: callable `geminiProxy`, key from Secret Manager via `defineSecret`,
allowlist checked against `users/{uid}.aiEnabled` read server-side, seeded from addresses
in function config. `lib/services/gemini_service.dart` calls the function rather than
`generativelanguage.googleapis.com`. `isEnabled` becomes "am I allowed", from the user's
own profile, so the UI hides the feature instead of offering it and failing. Delete
`gemini_api_key` from Remote Config once deployed; leave `gemini_model` and
`gemini_enabled`.
Verify: signed out → refused; signed in and not allowlisted → refused *by the function*,
not just hidden in the UI; allowlisted → autofill works end to end.

### T0.3 Close the autofill proxy — R1.10
`functions/index.js`. Require auth, gate on the same allowlist, add the SSRF guard
(resolve host; reject loopback, RFC1918, link-local including 169.254.169.254, IPv6
unique-local and `.internal`; `redirect: 'manual'` with a re-check per hop), cap the body
at 2 MB, and narrow CORS to the app's origin.
`wallCalendar/app/browser_service.py::_assert_public()` is the reference implementation.
Verify: unauthenticated → refused; `http://169.254.169.254/…` → refused; a public URL that
redirects to `127.0.0.1` → refused at the hop, not followed.

### T0.4 General limits — R1.11, R1.12
Size caps in `firestore.rules` on recipe writes (title, description, notes, ingredient and
step counts) and an `https:`-only check on `imageUrl`. Enable App Check for Firestore and
Functions — ship the client attestation first and turn on **enforcement** second, or the
app locks itself out. Set a budget alert on the billing account.

---

## Phase 1 — accounts, visibility, and the email fix

### T1.1 Reconcile the two admin mechanisms — R1.13
`lib/services/auth_service.dart`. `isAdmin` compares the email against
`AdminConfig.adminEmails`; rules read `users/{uid}.isAdmin`. Make the app read the
Firestore field.

Note `AdminConfig` can **not** remain a client-written seed: R1.12 closed the hole that
let the client write `isAdmin` at all, so `_updateUserProfile` no longer sets it. Admin is
set in Firestore directly. `AdminConfig` is then documentation of who should be one, or it
goes away.
Do this first: everything below leans on `isAdmin()`.

### T1.2 Add the new fields to both document shapes — R1.1
`lib/models/recipe.dart`, `lib/services/recipe_mapper.dart`.
Add `visibility`, `householdId`, `forkedFrom`. Remove `isFavorite` from the Firestore
shape. Mirror in `Recipe.toJson()` — import/export uses a *different* shape and silently
drops what is not there. Then
`dart run build_runner build --delete-conflicting-outputs`.
Absent or unrecognised `visibility` reads as `private`, never `public`.

### T1.3 Move favourites to a per-user subcollection — R1.2
`lib/services/firestore_service.dart`, `lib/providers/firebase_providers.dart`.
Read and write `users/{uid}/favorites/{recipeId}`. The favourites filter already lives in
a Riverpod `StateProvider`, so only the provider's source changes — screens and
`recipe_card.dart` should need no edit. If a screen does need editing, it was keeping its
own copy of filter state and that is the bug to fix.

### T1.4 Stop publishing email addresses — R1.3
`lib/services/firestore_service.dart:113` writes `createdByEmail`; drop it. Anywhere
attribution is displayed, use `createdByName`. Leave `email` in the user's own profile
document — T1.7 stops it being readable by others.

### T1.5 Declare the composite indexes — R1.4, R2.1
Create `firestore.indexes.json` with the four indexes in `design.md`, and add
`"indexes": "firestore.indexes.json"` under `firestore` in `firebase.json`.
Deploy before any filtered query ships, or it fails at runtime with
`FAILED_PRECONDITION`:
`env -u GOOGLE_APPLICATION_CREDENTIALS firebase deploy --only firestore:indexes`.

### T1.6 Scope the recipe queries — R1.4
`lib/providers/firebase_providers.dart`. Replace the single unfiltered
`orderBy('createdAt')` stream with the per-scope queries in `design.md`, merged in the
client. An unconstrained collection query will be rejected outright once T1.7 lands — it
does not degrade to a filtered result.

### T1.7 Rewrite firestore.rules — R1.3, R1.4, R1.5
Replace with the rules in `design.md`. Removes `allow read: if true` on `users`, removes
the `togglesFavoriteOnly()` carve-out, and blocks anonymous accounts from publishing.
**Do not deploy yet** — T1.9 and T1.10 must land first.

### T1.8 Rules tests against the emulator — R1.3, R1.4, R1.5
New `test/rules/` using `@firebase/rules-unit-testing`. A rules mistake here is a data
leak, not a bug, so this is the highest-value test in the phase:
- signed-out reader sees only `public`
- household member sees that household's `household` recipes
- non-member does not, and cannot read a member's user document
- two users with **no** household do not match each other via `sharesHousehold`
- anonymous account cannot create a `public` recipe
- nobody but the owner writes another user's recipe

### T1.9 Migration script — R1.6
`scripts/migrate_visibility.js`, `firebase-admin`, `--dry-run` by default, `--commit` to
write. Behaviour and idempotence conditions in `design.md`. Report recipes with no
`createdBy` rather than guessing at an owner.
Verify: dry run → `gcloud firestore export` → restore into the emulator → run with
`--commit` → run again and confirm zero changes → only then production.

### T1.10 Move the wall calendar to a filtered query — R1.7
`wallCalendar/app/recipes_service.py`. Switch from the REST `documents.list` endpoint —
which takes no filter at all — to `:runQuery` with the structured query in `design.md`.
The response shape changes to `[{"document": …}, …]` and entries may lack a `document`
key; paging becomes `offset`/`limit`. Keep the wall's own suite green (97 Playwright, 72
server assertions) and its parser tests passing.

### T0.5 Deploy Phase 0 in order — R1.8, R1.10
`firebase functions:secrets:set GEMINI_API_KEY` **first** — a functions deploy with no
secret bound starts a `geminiProxy` that cannot work — then `--only functions`, then
hosting, back to back.

Autofill is broken between those last two whichever way round they go: the currently
deployed bundle calls the old HTTP endpoint and the new one calls a callable. It is a
short window, but it is not zero, so do not leave it half done.

`--only firestore:rules` can go any time; the Phase 0 rules changes are additive
(size caps, imageUrl, the privilege denylist) and break no existing client.

### T1.11 Deploy Phase 1 in order — R1.7
**`indexes (T1.5)` → `migration (T1.9)` → `wall (T1.10)` → `rules (T1.7)` → `hosting`.**

Corrected after testing the new wall query against production, where it returned
`400 FAILED_PRECONDITION`. The original order in this file put the wall first, which is
wrong twice over: the query needs the composite index to run at all, and it needs recipes
to actually carry `visibility: "public"` before it returns anything. Deploying the wall
first would have produced a blank Recipes page rather than a broken one — quieter and
harder to spot.

The migration is safe to run before the rules tighten: it only adds fields, and the
current permissive rules allow it.

Reversing rules and wall blanks the wall's Recipes page. Rules, indexes and functions are
**not** in CI. Prefix every firebase command with `env -u GOOGLE_APPLICATION_CREDENTIALS`,
and check `flutter config` has not written output to `server/build` before deploying
hosting.

---

## Phase 2 — community and households

### T2.1 Community browse — R2.1
A community view over the `visibility == "public"` query, attributed by
`createdByName`, reusing the existing search/category/difficulty providers rather than
new filter state.

### T2.2 Visibility switcher — R2.2
Private / household / public on the recipe editor. Household is unavailable, with a
reason shown, when the user has no household. Publishing requires a durable account, so
the control explains itself rather than failing on save.

### T2.3 Save a community recipe — R2.3
Write `users/{uid}/savedRecipes/{recipeId}` and include saved references in "my recipes".
A save is a reference, so the author's later corrections are what the reader sees.

### T2.4 Fork on first edit — R2.4
Intercept edit-intent on a recipe the user does not own: copy it, stamp `forkedFrom` and
`createdBy`, replace the saved reference with the copy, and tell the user plainly that
they now have their own version.

### T2.5 Household create, invite, join, leave — R2.5, R2.7
`functions/index.js`: callable `joinHousehold` and `leaveHousehold`, validating the code
with admin privileges — see `design.md` for why this is not a rule. Client screens for
create, show code, enter code, leave. Joining while already in a household prompts to
leave first. Expired or unknown codes get a clear message.
Deploy: `firebase deploy --only functions`.

### T2.6 Report and take down — R2.6
A report action on any public recipe writing to `reports/{reportId}`
(`recipeId`, `reportedBy`, `reason`, `createdAt`), readable only by admins. An admin view
listing open reports with unpublish and delete. The reporter is never shown to the author.
Deliberately minimal: a path to remove something, not a moderation system.

---

## Phase 3 — grocery lists

### T3.1 Ingredient parser — R3.4, R3.5
`lib/services/ingredient_parser.dart`, pure, per the ordered algorithm in `design.md`.
Tests come from the **real** strings in this database: `1.5 cups (180g)`, `1 1/4 cups`,
`500 grams`, `2 tablespoons`, `1`, `to taste`, `—`, and
`amount: '—', name: '1/2 cup breadcrumbs (plain or panko)'`. Parsing must never throw.

### T3.2 Aisle map and staples — R3.6, R3.7
Static ordered aisle map with keyword matching. `users/{uid}/staples`; staples are held
separately from the buy list and can be promoted onto it.

### T3.3 Combine across recipes — R3.3, R3.5
`combine()`: merge by `canonicalName`, sum within a unit family, and record `extraTerms`
when families differ rather than converting. Sources accumulate.

### T3.4 Grocery list data and providers — R3.1, R3.2
`groceryLists` + `items`, household-scoped, Riverpod providers following
`firebase_providers.dart`. Add-from-recipe and manual entry. Rules and indexes as needed,
with emulator tests for member/non-member access.

### T3.5 Gemini fallback for unparsed lines — R3.4
Only for what T3.1 cannot resolve. Cache in Firestore keyed by the raw string so it is
paid for once across all users. Respect `gemini_enabled`; on failure list the item
unparsed rather than blocking.

### T3.6 Wall calendar grocery page — R3.8
Service account on `recipe-f644f` with `roles/datastore.user`, key in
`wallCalendar/secrets/`, backed up to `wallCalendar-secrets`. A `/groceries` page grouped
by aisle with check-off. Note the wall's rail is already at seven items with a test
asserting it fits a 600px panel — an eighth may need the rail to scroll or Groceries to
live under Recipes.

---

## Phase 4 — weekly ads and rebuy learning — DEFERRED

**Not being built now, and this is a decision rather than an omission.**

The brief for this work is a publishable, safe app with simple, effective features on a
stack that stays cheap. Phase 4 is the worst trade in the spec against that: flyer
matching plus cadence learning is the largest amount of machinery, the only dependency
with no stability guarantee (an undocumented endpoint whose permissive CORS header could
be withdrawn without notice), and the part users would notice least if it never arrived.
Rebuy learning also cannot say anything useful until a household has weeks of purchase
history, so shipping it at launch would ship a feature that does nothing yet.

Kept in the spec rather than deleted because the groundwork is genuinely done: the
endpoints are verified, the payload shapes are captured, `groceryHistory` is in the data
model, and the matching algorithm and its confidence floor are written down in
`design.md`. Picking it up later is a build, not a rediscovery.

Revisit when the lists are actually being used weekly. Until then the honest position is
that a grocery list which is correct and quick beats one that guesses at prices.

The original tasks follow, unchanged, for whoever picks this up.



### T4.1 Flipp client — R4.1, R4.3
`lib/services/flipp_service.dart`: item search plus `merchant_id → merchant` from
`/flipp/data`, cached a day. No key and no proxy needed. Degrades to no offers on any
failure or shape change.

### T4.2 Matching with a confidence floor — R4.2
Scoring per `design.md`: every token of the list item must appear, offers past
`valid_to` are discarded, and the flyer's own wording is always shown beside the price.
Test against the captured payload so the matcher needs no network.

### T4.3 Rebuy suggestions — R4.4
Median gap per item from `groceryHistory`, minimum three purchases, stated reasoning,
and a tap to accept. Never an automatic add.

---

## Before the community library is genuinely public

There is no moderation, reporting or takedown path anywhere in this spec, and Phase 2
makes user content visible to strangers. R1.5 (no anonymous publishing) is a floor, not
a moderation story. Worth deciding deliberately rather than discovering.
