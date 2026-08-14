# Requirements — community, households, and grocery lists

Status: draft, awaiting review
Owner: Henry Craig

## Why

Daisy's Kitchen is today a single shared space. There is one global `recipes`
collection, world-readable, and `isFavorite` is a flag on the recipe document rather
than per-user state. Firebase Auth is wired up, but nothing is scoped to the person
signed in.

The goal is a real multi-user app: a personal collection, a community library people
publish into and pull from, households that share a recipe log and a grocery list, and
grocery lists that know what is on offer this week.

The wall calendar (`~/Documents/personalDev/calendar/wallCalendar`) reads this app's
recipes over the Firestore REST API with no credentials, so it constrains the design
rather than merely consuming it. See R1.7.

## Requirement ids

`R<phase>.<n>`. Tasks in `tasks.md` cite these; commits cite tasks.

---

## Phase 1 — accounts, visibility, and the email fix

### R1.1 A recipe has an owner and a visibility

- **Given** any recipe document
- **When** it is read
- **Then** it carries `visibility` of exactly `public`, `household` or `private`,
  a `householdId` (null for public or private), and a `createdBy` uid.

Notes: absent or unrecognised `visibility` must be treated as `private` by the client,
never as `public` — an unreadable value should hide a recipe, not publish one.

### R1.2 Favourites are per person

- **Given** two signed-in users A and B, and a public recipe R
- **When** A favourites R
- **Then** R appears in A's favourites and does not appear in B's
- **And** the recipe document itself is unchanged.

Today `isFavorite` lives on the recipe and any signed-in user may toggle it — the rules
carve out `togglesFavoriteOnly()` precisely because it is shared state. That carve-out
is removed by this requirement.

### R1.3 A user's email address is not public

- **Given** a signed-out visitor, or a signed-in user who is not in my household
- **When** they read any document available to them
- **Then** my email address does not appear in the response.

This is a live defect, not a new feature. `firestore.rules` currently has
`allow read: if true` on `users/{userId}` and `_updateUserProfile` writes `email` into
it; recipes additionally stamp `createdByEmail` and are world-readable. Attribution must
use `createdByName` only.

### R1.4 Reading a recipe requires the right to read it

- **Given** recipes with each visibility
- **When** they are queried by a signed-out visitor
- **Then** only `public` recipes are returned
- **When** queried by a household member
- **Then** `public` plus that household's `household` recipes are returned
- **When** queried by the owner
- **Then** their own `private` recipes are returned too
- **And** a non-member never receives another household's recipes.

### R1.5 Only a durable account may publish

- **Given** a user signed in anonymously
- **When** they attempt to create a recipe with `visibility: public`
- **Then** the write is rejected.

Anonymous auth is enabled. An anonymous account is disposable, so publishing from one
into a shared library is an abuse vector with no accountability.

### R1.6 The migration is safe and repeatable

- **Given** the production recipe collection
- **When** the migration runs, twice
- **Then** every recipe has `visibility: public` and `householdId: null`
- **And** any recipe with `isFavorite: true` has an entry in its owner's `favorites`
- **And** no document retains `createdByEmail`
- **And** the second run changes nothing
- **And** no recipe is deleted and no title, ingredient or step is altered.

### R1.7 The wall calendar keeps working

- **Given** the tightened rules are deployed
- **When** the wall calendar loads `/recipes`
- **Then** it still lists the public recipes.

Firestore requires a query to be constrained so that every document it could return
satisfies the read rule. An unconstrained "list the collection" call from an
unauthenticated client is therefore rejected outright once R1.4 lands — it does not
merely filter. The wall's query must add `visibility == "public"` and must be deployed
**before** the rules.

### R1.8 The Gemini API key is never sent to a browser

- **Given** the deployed web app
- **When** anyone loads it, signed in or not, and inspects network traffic or app state
- **Then** no Gemini API key is present.

This is a live defect. `remote_config_service.dart` fetches `gemini_api_key` from Firebase
Remote Config, and `gemini_service.dart:223` builds
`…/models/$_model:generateContent?key=$_apiKey` and calls Google directly **from the
client**. Remote Config values are delivered to every client and the key appears in a
request URL, so on a public site the key is public — extractable without signing in, and
usable by anyone, anywhere, against Henry's billing account, with no further connection to
this app.

Consequences that follow, and which R1.9 depends on: the existing key must be treated as
compromised and rotated, and any per-user restriction on AI features is unenforceable
while the key lives in the client — a check running in the attacker's browser, guarding a
key the attacker already has, is not a control.

### R1.9 AI features are limited to named accounts

- **Given** a signed-in user who is not on the AI allowlist
- **When** they attempt to use recipe autofill or any other Gemini-backed feature
- **Then** the request is refused **server-side**
- **And** the UI does not offer the feature rather than offering it and failing
- **Given** a user on the allowlist
- **Then** the feature works normally.

The allowlist starts as two accounts. It must be changeable without a code deploy, and it
must be enforced where the key lives (R1.8) rather than in the client.

### R1.10 The autofill proxy is not an open proxy

- **Given** the `recipeAutofillProxy` Cloud Function
- **When** an unauthenticated caller requests any URL
- **Then** the request is refused
- **When** an authorised caller requests a private, loopback, link-local or
  cloud-metadata address, directly or via a redirect
- **Then** the request is refused
- **And** a response larger than a fixed cap is truncated or refused.

Also live. The function is `onRequest` with `cors: true` and
`Access-Control-Allow-Origin: *`, takes an arbitrary `url`, validates only that the
protocol is http or https, follows redirects, and returns the body — so anyone on the
internet can make Henry's project fetch any URL on his bill, and use it to reach things
his function can reach but they cannot.

The obvious escalation — reading the instance metadata service for a service-account
token — is blocked, but by GCP's own requirement for a `Metadata-Flavor: Google` header
that this code has no way to send, not by anything in the code. That is luck, and it
should not be the control.

### R1.11 A public app has basic abuse limits

- **Given** the app is publicly reachable
- **Then** Firestore and Functions accept requests only from the real app (App Check)
- **And** a recipe cannot be written with unbounded field sizes or an unbounded number of
  ingredients or steps
- **And** a billing alert exists on the project.

Community features mean strangers can write to the database. Nothing today caps document
size, so a single write could be a megabyte of text repeated as often as someone likes.

### R1.12 A user cannot grant themselves privileges

- **Given** any signed-in user
- **When** they write their own `users/{uid}` document, on create or on update
- **Then** they cannot set `isAdmin` or `aiEnabled`
- **And** they can still change their display name and photo.

Live escalation, found while adding `aiEnabled` to the write denylist and confirmed
with a rules test. `users/{userId}` allowed `write` on the whole document, and
`isAdmin()` in those same rules resolves admin by **reading that field** — so any
signed-in user could set `isAdmin: true` on themselves and then edit or delete every
recipe in the database. `aiEnabled` has the same shape: it gates paid AI calls, so
client control of it defeats the server-side check entirely.

Consequence: `auth_service.dart::_updateUserProfile` can no longer write `isAdmin` from
`AdminConfig.adminEmails` on sign-in. Admin is set in Firestore directly, which is also
the single source R1.13 asks for.

### R1.13 Admin is resolved one way

- **Given** the rules and the app
- **When** either decides whether a user is an admin
- **Then** both consult the same source.

Rules read `users/{uid}.isAdmin`; `auth_service.dart` compares the email against
`AdminConfig.adminEmails`. Household and visibility rules will lean on admin, so the
two must agree first.

---

## Phase 2 — community and households

### R2.1 Browse the community library

- **Given** public recipes from several authors
- **When** I open the community view
- **Then** I see them attributed by display name, and can filter and search as I can
  my own collection.

### R2.2 Publish and unpublish

- **Given** a recipe I own
- **When** I set its visibility
- **Then** it moves between private, my household, and public
- **And** unpublishing removes it from the community view without deleting it
- **And** anyone who saved it keeps a usable copy (see R2.4).

### R2.3 Save a community recipe

- **Given** a public recipe I do not own
- **When** I save it
- **Then** it appears in my collection
- **And** it still belongs to its author
- **And** corrections the author makes later are reflected in what I see.

### R2.4 Editing a saved recipe forks it

- **Given** a saved recipe I do not own
- **When** I change anything about it
- **Then** an independent copy is created, owned by me, recording `forkedFrom`
- **And** the original is untouched
- **And** my collection now shows my copy instead of the reference.

This is the "save now, fork on first edit" decision. A save is a bookmark so fixes
reach me; the fork happens the moment I need it to be mine.

### R2.5 A household is created and joined by code

- **Given** I am signed in with a durable account
- **When** I create a household
- **Then** I am its first member, and I can produce a short invite code
- **When** another user enters that code
- **Then** they join, and both of us see the household's recipes and lists
- **And** a member can leave
- **And** an expired or unknown code is refused with a clear message.

### R2.6 Anything public can be reported and taken down

- **Given** a public recipe
- **When** any signed-in user reports it
- **Then** the report is recorded with the reporter, the recipe and a reason
- **And** an admin can see reports and unpublish or delete the recipe
- **And** the reporter's identity is not visible to the author.

This is the minimum that makes a public library shippable rather than a full moderation
system. It is deliberately small: a report path and an admin action, no queues, no
automated classification, no appeals. Without it there is no way to remove something
except by editing the database by hand.

### R2.7 Household membership is exclusive

- **Given** I am in a household
- **When** I join another
- **Then** I am asked to leave the first, rather than silently belonging to both.

One `householdId` per user keeps the rules cheap and the semantics obvious. Multiple
households is a larger change and out of scope.

---

## Phase 3 — grocery lists

### R3.1 A household has a grocery list

- **Given** a household
- **When** any member opens the list
- **Then** they see the same items, and additions by one member appear for the others.

### R3.2 Add a recipe's ingredients to the list

- **Given** a recipe with ingredients
- **When** I add it to the list
- **Then** each ingredient becomes an item recording which recipe it came from.

### R3.3 The same ingredient from two recipes becomes one item

- **Given** two recipes both needing all-purpose flour, written as `1 cup all-purpose
  flour` and `1.5 cups (180g) all-purpose flour (spooned & leveled)`
- **When** both are added
- **Then** the list shows one flour item of `2.5 cups`
- **And** it records both recipes as sources
- **And** two ingredients whose names differ in substance — `flour` and `almond flour`,
  or `flour` and `self rising flour` — stay as separate lines.

Merging is on the canonicalised name, which strips parentheticals, anything after a
comma, and trailing "for the crust" style notes. It deliberately does **not** merge a
shorter name into a longer one that contains it. This requirement originally said `flour`
and `all-purpose flour` should combine, which sounds right until the same rule merges
`almond flour` into plain flour and quietly puts the wrong thing on the list. Same
principle as refusing to convert cups to grams: two honest lines beat one confident wrong
one.

### R3.4 Quantities are parsed from real data, not ideal data

- **Given** the amount strings that actually exist in this database —
  `1.5 cups (180g)`, `1 1/4 cups`, `500 grams`, `2 tablespoons`, `1`, `to taste`, `—`,
  and the case where the amount is `—` and the quantity sits in the name
  (`1/2 cup breadcrumbs (plain or panko)`)
- **When** each is parsed
- **Then** a quantity and unit are extracted where one exists
- **And** where none exists the item is listed without a quantity rather than guessed at
- **And** parsing never throws.

### R3.5 Units convert only within a family

- **Given** `1 cup` of an ingredient and `200 g` of the same ingredient
- **When** they are combined
- **Then** the item shows both terms
- **And** no conversion between volume and weight is invented.

Cups to grams depends on what is being measured. Guessing produces a confidently wrong
shopping list, which is worse than an honest two-part one.

### R3.6 The list is ordered for one walk through a store

- **Given** a list spanning produce, dairy, meat and pantry
- **When** it is displayed
- **Then** items are grouped by section in a consistent order.

### R3.7 Staples do not clutter the list

- **Given** ingredients I have marked as staples (salt, olive oil)
- **When** a recipe adds them
- **Then** they are held separately from the things I actually need to buy
- **And** I can still promote one onto the list when I do run out.

### R3.8 The wall can shop the list

- **Given** the household list
- **When** it is opened on the wall calendar
- **Then** items are shown grouped by section and can be checked off
- **And** a check-off on the wall appears in the app.

---

## Phase 4 — weekly ads and rebuy learning

### R4.1 List items show this week's offers

- **Given** a list containing chicken thighs, and a flyer offering them
- **When** the list is displayed
- **Then** the item shows the price, the store, the unit and the date the offer ends.

### R4.2 A match is shown, not asserted

- **Given** a list item and a candidate flyer item
- **When** confidence is below the threshold
- **Then** no offer is shown
- **And** when one is shown, the flyer's own wording is displayed alongside so a wrong
  match is visibly wrong rather than authoritative.

"Chicken" must not match "chicken soup" and be presented as fact.

### R4.3 Offers are decoration and fail quietly

- **Given** the flyer source is unreachable, has changed shape, or has withdrawn its
  permissive CORS header
- **When** the list is displayed
- **Then** the list works exactly as it does without offers, and says nothing about
  prices.

The source is an undocumented endpoint. It will break eventually.

### R4.4 The list learns what we rebuy

- **Given** an item bought at least three times
- **When** the median gap between purchases has elapsed
- **Then** it is offered as a suggestion, with its cadence stated
- **And** it is never added automatically
- **And** with fewer than three purchases nothing is claimed.

Below three points there is no median worth trusting, and a wall that invents a habit
is worse than one that waits.

---

## Out of scope

- Multiple households per user (R2.6).
- A moderation *system*. R2.6 gives a report path and an admin takedown, which is the
  floor for shipping a public library. Not in scope: review queues, automated
  classification, appeals, rate-limited reporting, or banning a user.
- Converting between volume and weight (R3.5).
- Real-time collaborative editing of a recipe.
- Any store's authenticated pricing API. Kroger's is documented and would give true
  per-store prices, but it is Kroger-only and needs a credential; flyers cover Publix,
  ALDI and Lidl too.
