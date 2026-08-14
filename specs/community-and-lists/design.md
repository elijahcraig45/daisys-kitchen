# Design — community, households, and grocery lists

Status: draft, awaiting review
Satisfies: `requirements.md`

## Data model

```
users/{uid}
  email, displayName, photoURL, isAdmin, lastSignIn    # existing
  householdId: string | null                            # new

users/{uid}/favorites/{recipeId}      { addedAt }
users/{uid}/savedRecipes/{recipeId}   { savedAt, authorUid, authorName }
users/{uid}/staples/{canonicalName}   { addedAt }

households/{householdId}
  name, createdBy, createdAt
  memberUids: [uid]

householdInvites/{code}
  householdId, createdBy, createdAt, expiresAt

recipes/{recipeId}
  ...existing...
  visibility: "public" | "household" | "private"
  householdId: string | null
  forkedFrom: recipeId | null
  createdBy, createdByName          # createdByEmail removed (R1.3)
  # isFavorite removed from the document (R1.2)

groceryLists/{listId}
  householdId, name, createdAt, updatedAt
groceryLists/{listId}/items/{itemId}
  display, canonicalName, quantity, unit, unitFamily, aisle,
  extraTerms: [{quantity, unit}],    # R3.5, when families cannot combine
  sources: [{recipeId, title}], raw: [string],
  done, doneAt, addedBy, staple

groceryHistory/{householdId}/purchases/{purchaseId}
  canonicalName, doneAt, quantity, unit

reports/{reportId}
  recipeId, reportedBy, reason, createdAt, resolvedAt, resolvedBy
```

`memberUids` is an array so rules can authorise with
`request.auth.uid in resource.data.memberUids` — no `get()` per document.

`extraTerms` exists because R3.5 forbids inventing a cup-to-gram conversion. An item is
`2.5 cups` **plus** `200 g`, held as data rather than collapsed.

## Queries, and the indexes they require

Rules do not filter a query — Firestore rejects any query that could return a document
the reader may not read. So each scope is its own constrained query, merged in the
client. Firestore's `Filter.or` exists but interacts poorly with rules evaluation and
buys nothing here.

| Scope | Query | Composite index |
|---|---|---|
| Community | `visibility == "public"` order by `createdAt` desc | `visibility ASC, createdAt DESC` |
| My recipes | `createdBy == uid` order by `createdAt` desc | `createdBy ASC, createdAt DESC` |
| Household | `householdId == myHouseholdId` order by `createdAt` desc | `householdId ASC, createdAt DESC` |
| Saved | fetched by id from `users/{uid}/savedRecipes` | none |

**`firestore.indexes.json` does not exist and `firebase.json` does not reference one.**
Today's single `orderBy('createdAt')` is served by an automatic single-field index, so
nothing has needed it yet. Create the file, add `"indexes": "firestore.indexes.json"`
under `firestore` in `firebase.json`, and deploy with `--only firestore:indexes`
**before** the queries ship.

Confirmed against the live database rather than assumed — running the community query
today returns:

```
HTTP 400  FAILED_PRECONDITION
"The query requires an index. You can create it here: https://console.firebase.google.com/…"
```

So the index is a hard blocker, not a performance note: the query does not work at all
without it. The unauthenticated `:runQuery` call itself was verified working (HTTP 200,
returning `[{document, readTime}, …]`), which is what the wall's change depends on.

## firestore.rules

Replaces the current file. `isAdmin()` keeps reading `users/{uid}.isAdmin`, and
`auth_service.dart` is changed to read the same field rather than comparing emails
(R1.12).

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }

    // An anonymous account is disposable, so it may not publish (R1.5).
    function durableAccount() {
      return signedIn() &&
             request.auth.token.firebase.sign_in_provider != 'anonymous';
    }

    function isAdmin() {
      return signedIn() &&
             exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }

    function myHouseholdId() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.householdId;
    }

    // Both sides must be non-null, or two users with no household would match
    // each other and read one another's profiles.
    function sharesHousehold(otherHouseholdId) {
      return signedIn() &&
             otherHouseholdId != null &&
             myHouseholdId() == otherHouseholdId;
    }

    match /users/{userId} {
      // R1.3: no longer world-readable. Emails were public before this.
      allow read: if signedIn() &&
                     (request.auth.uid == userId ||
                      sharesHousehold(resource.data.householdId) ||
                      isAdmin());
      // householdId is set by the join/leave Cloud Function, not by the client.
      allow create: if signedIn() && request.auth.uid == userId;
      allow update: if signedIn() && request.auth.uid == userId &&
                       !request.resource.data.diff(resource.data)
                          .affectedKeys().hasAny(['householdId', 'isAdmin']);

      match /favorites/{recipeId} {
        allow read, write: if signedIn() && request.auth.uid == userId;
      }
      match /savedRecipes/{recipeId} {
        allow read, write: if signedIn() && request.auth.uid == userId;
      }
      match /staples/{name} {
        allow read, write: if signedIn() && request.auth.uid == userId;
      }
    }

    match /recipes/{recipeId} {
      function owns() { return signedIn() && resource.data.createdBy == request.auth.uid; }

      // R1.4. Note the absence of a default: an unrecognised visibility is not
      // public, which is the safe direction to fail.
      allow read: if resource.data.visibility == 'public' ||
                     owns() ||
                     (resource.data.visibility == 'household' &&
                      sharesHousehold(resource.data.householdId)) ||
                     isAdmin();

      allow create: if signedIn() &&
                       request.resource.data.createdBy == request.auth.uid &&
                       request.resource.data.visibility in ['public', 'household', 'private'] &&
                       (request.resource.data.visibility != 'public' || durableAccount());

      // The togglesFavoriteOnly() carve-out is deliberately gone: favourites are
      // per-user now (R1.2), so no one needs to write someone else's recipe.
      allow update: if owns() || isAdmin();
      allow delete: if owns() || isAdmin();

      match /comments/{commentId} {
        allow read: if true;
        allow create: if durableAccount();
        allow update: if signedIn() && request.auth.uid == resource.data.userId;
        allow delete: if (signedIn() && request.auth.uid == resource.data.userId) || isAdmin();
      }
      match /ratings/{ratingId} {
        allow read: if true;
        allow create, update: if durableAccount() && ratingId == request.auth.uid;
        allow delete: if signedIn() && ratingId == request.auth.uid;
      }
    }

    match /households/{householdId} {
      allow read: if signedIn() && request.auth.uid in resource.data.memberUids;
      allow create: if durableAccount() &&
                       request.resource.data.memberUids == [request.auth.uid] &&
                       request.resource.data.createdBy == request.auth.uid;
      // Membership changes go through the Cloud Function; a member may rename.
      allow update: if signedIn() && request.auth.uid in resource.data.memberUids &&
                       !request.resource.data.diff(resource.data)
                          .affectedKeys().hasAny(['memberUids', 'createdBy']);
      allow delete: if false;
    }

    // No client access at all. Reading these would let anyone enumerate invite
    // codes; joining goes through the Cloud Function, which runs with admin
    // privileges and does not need a rule.
    match /householdInvites/{code} {
      allow read, write: if false;
    }

    // A reporter may file one and never read the pile; only admins read reports, so
    // an author cannot see who reported them (R2.6).
    match /reports/{reportId} {
      allow create: if durableAccount() &&
                       request.resource.data.reportedBy == request.auth.uid;
      allow read, update: if isAdmin();
      allow delete: if false;
    }

    match /groceryLists/{listId} {
      function memberOfList() {
        return signedIn() && sharesHousehold(resource.data.householdId);
      }
      allow read, update, delete: if memberOfList();
      allow create: if signedIn() &&
                       request.resource.data.householdId == myHouseholdId();

      match /items/{itemId} {
        function memberOfParent() {
          return signedIn() && sharesHousehold(
            get(/databases/$(database)/documents/groceryLists/$(listId)).data.householdId);
        }
        allow read, write: if memberOfParent();
      }
    }

    match /groceryHistory/{householdId}/purchases/{purchaseId} {
      allow read, write: if signedIn() && sharesHousehold(householdId);
    }
  }
}
```

Rules `get()` calls are billed and count against a per-request limit (10 for a single
document read). `sharesHousehold()` costs one `get()`; the grocery item rule costs two.
That is within budget but is the reason `memberUids` is an array rather than a
subcollection.

## Hosting safety (R1.8–R1.11)

Three pre-existing exposures, all of which get worse the moment strangers can use the
app. None were introduced by this work.

### The Gemini key must move server-side (R1.8, R1.9)

Today `remote_config_service.dart` fetches `gemini_api_key` and `gemini_service.dart:223`
calls Google **from the browser**:

```dart
final url = '$_baseUrl/models/$_model:generateContent?key=$_apiKey';
```

Remote Config is delivered to every client, and the key then appears in a request URL. On
a public site that key is public. It needs no sign-in to obtain and works from anywhere
once obtained.

This also settles *how* AI can be restricted to named accounts: it cannot be done in the
client. A client-side allowlist is a check running on the attacker's machine, guarding a
key the attacker already holds.

Design:

1. **Rotate the existing key.** It has been served to every visitor of a public site and
   must be treated as compromised. This is a console action for Henry, and it should
   happen before the rest of this phase rather than after.
2. New callable function `geminiProxy` (`functions/index.js`, us-central1). It holds the
   key in **Secret Manager** via `defineSecret`, never in Remote Config, and never returns
   it. `onCall` gives an authenticated context for free.
3. It checks the caller against an allowlist and refuses otherwise. Source of truth is
   `users/{uid}.aiEnabled`, a boolean the function reads server-side, seeded from a list
   of addresses in function config so it is changeable without a code deploy (R1.9).
4. `gemini_service.dart` calls the function instead of Google. `isEnabled` becomes "am I
   allowed", read from the user's own profile document, so the UI can hide the feature
   rather than offer it and fail.
5. Remove `gemini_api_key` from Remote Config. `gemini_model` and `gemini_enabled` may
   stay — a model name is not a secret and a kill switch is useful.

The allowlist starts as Henry's account and one other. The exact addresses go in
`functions/.env` / Secret Manager rather than this document.

### The autofill proxy needs closing (R1.10)

`recipeAutofillProxy` is `onRequest` with `cors: true` and
`Access-Control-Allow-Origin: *`, accepts any `url`, checks only the protocol, follows
redirects, and returns the body. Anyone on the internet can make this project fetch
anything, on Henry's bill, from Google's network.

The metadata-service escalation — fetching
`169.254.169.254/computeMetadata/v1/…/token` for a service-account credential — fails
only because GCP requires a `Metadata-Flavor: Google` header that this code never sends.
That is a happy accident, not a control, and it should not be relied on.

Design:

- Require authentication. Convert to `onCall`, or verify a Firebase ID token in the
  handler; either way, unauthenticated callers are refused.
- Gate on the same AI allowlist — autofill is an AI feature and the same two accounts use
  it.
- **SSRF guard**: resolve the hostname, reject loopback, private (RFC1918), link-local
  (169.254/16, including the metadata address), unique-local IPv6 and `.internal`; use
  `redirect: 'manual'` and re-run the check on every hop rather than trusting the first.
  `wallCalendar/app/browser_service.py::_assert_public()` already implements exactly this
  and is the reference.
- Cap the response body (say 2 MB) and keep the existing timeout.
- Replace `Access-Control-Allow-Origin: *` with the app's origin. Not a security control
  for non-browser callers, but it stops casual use from other sites.

### General limits (R1.11)

- **Firebase App Check** on Firestore and Functions, so requests must come from the real
  app rather than a script with the project id. This is the single highest-leverage
  safeguard for a public Firebase app; enforcement should be enabled only after the
  client is attesting, or it locks out the app.
- **Size caps in rules** on recipe writes: bound `title`, `description`, `notes`, and the
  number of `ingredients` and `steps`. Nothing caps them today, so one write can be a
  megabyte, repeatedly. Cheap to express as `request.resource.data.title.size() < 200`.
- **Budget alert** on the billing account. Blaze is pay-as-you-go and every item above is
  ultimately a spending risk.
- Validate `imageUrl` is `https:` on write; the app renders it, so a `javascript:` or
  `data:` value has no business being stored.

## Household join — a Cloud Function, not a rule

Letting a client add itself to `memberUids` requires a rule permissive enough for a
non-member to write the household document, and verifying the invite code inside rules
means trusting a code the writer supplies. Instead, a callable function
(`joinHousehold`, us-central1, beside `recipeAutofillProxy`) validates the code with
admin privileges and performs both writes: append to `memberUids`, set the user's
`householdId`. `leaveHousehold` reverses it.

Functions are **not in CI**. Deploy with
`env -u GOOGLE_APPLICATION_CREDENTIALS firebase deploy --only functions`.

## Migration (R1.6)

One-off Node script, `scripts/migrate_visibility.js`, using `firebase-admin`, with
`--dry-run` as the default and `--commit` required to write.

1. Every `recipes/*`: set `visibility: 'public'`, `householdId: null`,
   `forkedFrom: null` where absent. Never overwrite an existing `visibility`.
2. Where `isFavorite == true`, write `users/{createdBy}/favorites/{recipeId}`. Recipes
   predating `createdBy` have no owner — report them and assign to the admin uid.
3. Remove `createdByEmail` and `isFavorite` with `FieldValue.delete()`.
4. Create Henry's household, set `householdId` on his user doc.
5. Print a per-step count and a total, and exit non-zero if any recipe would lose a
   title, ingredient or step.

Idempotent by construction: every step is conditional on the field's current state, so a
second run reports zero changes (R1.6).

Verify against an export restored into the emulator before production:
`gcloud firestore export`, then `firebase emulators:start --import`.

## Wall calendar contract (R1.7)

`wallCalendar/app/recipes_service.py` currently calls the REST **documents.list**
endpoint:

```
GET /v1/projects/recipe-f644f/databases/(default)/documents/recipes?pageSize=100
```

That endpoint takes no filter, so this is not a matter of adding a parameter — it must
move to `:runQuery` with a structured query:

```
POST /v1/projects/recipe-f644f/databases/(default)/documents:runQuery
{ "structuredQuery": {
    "from": [{"collectionId": "recipes"}],
    "where": {"fieldFilter": {"field": {"fieldPath": "visibility"},
                              "op": "EQUAL",
                              "value": {"stringValue": "public"}}},
    "orderBy": [{"field": {"fieldPath": "createdAt"}, "direction": "DESCENDING"}]
} }
```

The response shape changes from `{"documents": [...]}` to `[{"document": {...}}, ...]`,
with entries that carry no `document` key when the result set is empty — `_shape()` must
tolerate that. Paging changes from `pageToken` to `offset`/`limit`.

Deploy order is not negotiable: **wall query → indexes → rules → hosting**. The wall's
Recipes page goes blank between the rules deploy and the wall deploy if done the other
way round.

Phase 3 adds the wall's first credential: a service account on `recipe-f644f` with
`roles/datastore.user`, key at `wallCalendar/secrets/`, backed up to the private
`wallCalendar-secrets` repo. `google-auth` is already a dependency. Public recipes stay
readable without it, so an expired key degrades the grocery list and not the recipes.

## Ingredient parsing (R3.3–R3.5)

`lib/services/ingredient_parser.dart`, pure and free of Firebase singletons so it unit
tests like `RecipeMapper`.

```dart
ParsedAmount parseAmount(String raw)   // {quantity?, unit?, note?, unparsed}
String canonicalName(String name)
String? aisleFor(String canonicalName)
List<ListItem> combine(Iterable<ParsedIngredient>)
```

Order matters, because these inputs overlap:

1. Strip a parenthetical metric equivalent — `1.5 cups (180g)` keeps `1.5 cups`. The
   parenthetical is a restatement, not a second quantity.
2. Mixed fraction `1 1/4` → 1.25; bare fraction `1/2` → 0.5; unicode `½` → 0.5;
   decimal `1.5`; range `2-3` → take the upper bound and note it.
3. Unit synonyms to a canonical token: `cups|cup|c` → `cup`;
   `tablespoons|tablespoon|tbsp|T` → `tbsp`; `grams|gram|g` → `g`. Volume, weight and
   count are separate families and never convert between each other (R3.5).
4. `to taste`, `—`, `-`, empty → no quantity, and the item still appears (R3.4).
5. If the amount yielded nothing, try the **name** — real data has
   `amount: '—', name: '1/2 cup breadcrumbs (plain or panko)'` — and if a quantity is
   found there, strip it from the display name.
6. `canonicalName` lowercases, drops anything after a comma or in parentheses
   (`all-purpose flour (spooned & leveled)` → `all-purpose flour`), strips trailing
   `for cooking`/`for the crust`/`optional`, and singularises a trailing `s` only for a
   known-safe set — never blindly, or `molasses` becomes `molasse`.

Aisles are a static ordered map (produce, bakery, meat, dairy, frozen, pantry, spices,
other) matched on keyword. It will be wrong sometimes; being wrong in a fixed order is
still better for shopping than alphabetical.

**Gemini** (already configured via Remote Config) is consulted **only** for lines steps
1–6 leave unresolved, and the answer is cached in Firestore keyed by the raw string so
it is paid for once per distinct ingredient across all users. If `gemini_enabled` is
false or the call fails, the item is listed unparsed — never blocked.

## Flipp matching (R4.1–R4.3)

`lib/services/flipp_service.dart`. No key, and the endpoint sends
`access-control-allow-origin: *` and answers preflight, so the web app calls it
directly — unlike the HTML autofill path, no proxy function is needed. If that header is
ever withdrawn, the fallback is a proxy modelled on `recipeAutofillProxy`.

- `GET backflipp.wishabi.com/flipp/items/search?locale=en-us&postal_code={zip}&q={term}`
  → `items[]` with `name`, `current_price`, `post_price_text` (`/lb.`), `valid_from`,
  `valid_to`, `sale_story`, `merchant_id`.
- `merchant` is null on items. Names come from
  `GET /flipp/data?locale=en-us&postal_code={zip}` → `flyers[]`, giving
  `merchant_id → merchant`. Cache for a day; flyers turn over weekly.

Scoring, deliberately conservative:

- Tokenise both sides, drop stopwords and the store's own brand tokens.
- Score = (matched tokens / list-item tokens), requiring **every** token of the list item
  to appear. `chicken thighs` therefore does not match `chicken soup`, while
  `Publix Chicken Thighs` does.
- Reject anything below the floor, prefer the lowest unit price among survivors, and
  discard offers whose `valid_to` has passed.
- Always display the flyer's own `name` next to the price, so a wrong match reads as
  obviously wrong rather than as a fact about groceries (R4.2).

## Rebuy cadence (R4.4)

From `groceryHistory`: per `canonicalName`, sort `doneAt`, take gaps, use the **median**
(robust to a holiday or a bulk buy in a way the mean is not). Fewer than three purchases
means two gaps at most, which is not a habit — say nothing. Surface as a suggestion with
its reasoning shown ("about every 6 days, last bought 8 days ago") and require a tap.

## Conventions this follows

From the repo's own instructions: surgical changes over rewrites, no comments except for
a non-obvious "why", `SnackBarHelper` for all user feedback, `LoggerService` with a tag
rather than `print`, and services that log and return `null`/`false`/`[]` rather than
throwing. Filter state stays in the Riverpod providers in `firebase_providers.dart`;
screens do not keep their own copies. New user-facing copy is warm, plain, and free of
emoji and exclamation marks.

`RecipeMapper` owns the Firestore shape and `Recipe.toJson()` is a separate
json_serializable shape used by import/export — the new fields go in **both**, and
`dart run build_runner build --delete-conflicting-outputs` regenerates `*.g.dart`, which
is gitignored.
