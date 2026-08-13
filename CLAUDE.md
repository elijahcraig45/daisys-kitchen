# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

"Daisy's Kitchen" (`recipe_keeper`) — Flutter **web** app on Firebase, live at https://recipe-f644f.web.app.
The parent workspace `CLAUDE.md` (`~/Documents/personalDev/`) is also loaded; this file covers only this repo.

## Commands

```bash
dart run build_runner build --delete-conflicting-outputs   # REQUIRED before first build — *.g.dart is gitignored
flutter run -d chrome
flutter test                                               # 20 tests: RecipeMapper + Validators
flutter analyze                                            # ~7 issues, all pre-existing infos
flutter build web --release
firebase deploy --only hosting                             # see build-dir gotcha below
firebase deploy --only firestore:rules                     # rules are NOT in CI
firebase deploy --only functions                           # functions/ are NOT in CI
```

**Firebase CLI auth trap:** this machine exports `GOOGLE_APPLICATION_CREDENTIALS` pointing at a *work*
service-account key, and firebase-tools prefers it over the personal login — every command against
`recipe-f644f` then fails with a 401 that looks like a login problem even though `firebase login:list` shows
`elijahcraig45@gmail.com`. Prefix deploys with `env -u GOOGLE_APPLICATION_CREDENTIALS`. If a 401 persists after
that, the stored personal token has expired: `firebase login --reauth` (interactive).

**Local deploy trap:** a machine-global setting in `~/.config/flutter/settings` sets `"build-dir": "server/build"`,
so `flutter build web` writes to `server/build/web` while `firebase.json` serves `build/web`. A local
`firebase deploy --only hosting` will publish stale or missing output. Copy the bundle before deploying, or run
`flutter config --build-dir=build` — but that setting is machine-global and would move output paths for every
other Flutter repo here too (e.g. `cfb_tank/`). CI is unaffected (fresh checkout, no such setting). Note
`.gitignore` has root-anchored `/build/`, which does not cover `server/build/`.

Push to `main` triggers `.github/workflows/deploy.yml`: it writes `firebase_service.dart` and `admin_config.dart`
from GitHub secrets, runs build_runner, builds web, and deploys **hosting only**.

## Architecture

**One data path.** `firebase_providers.dart` → `FirestoreService` → a single global `recipes` collection.
`home_screen.dart` watches `recipesStreamProvider` for load/error state and reads
`firestoreFilteredRecipesProvider` for the rendered list. All filter state (search, category, difficulty,
favourites) lives in Riverpod `StateProvider`s in `firebase_providers.dart` — screens must not keep their own
copies, since that is exactly how the search box ended up wired to a provider nothing read.

**`RecipeMapper` owns the Firestore document shape** (`lib/services/recipe_mapper.dart`). It is deliberately free
of Firebase singletons and server timestamps so it can be unit tested; `FirestoreService` stamps `createdAt` /
`updatedAt` / authorship. `createdAt` is written **only on create** — the stream orders by it, so restamping on
update would shuffle edited recipes to the top. Note that `Recipe.toJson()` (json_serializable) is a *different*
shape, used by import/export; changing the model means updating both.

**Theming is centralised in `lib/theme/app_theme.dart`.** `AppTheme.light` / `AppTheme.dark`, plus an
`AppSemanticColors` `ThemeExtension` for success/warning/info (Material has no such tokens) and a `BuildContext`
extension exposing `context.colors` and `context.statusColors`. Screens should take every colour from those —
do not reintroduce `Colors.red`-style literals, which is what broke dark mode before. `AppTheme.maxContentWidth`
(1200) caps page measure on wide displays.

**Fonts must be bundled.** Web renders through CanvasKit, which cannot see system faces — naming `Georgia` or
`serif` silently falls back to Roboto. Headings use `DaisySerif` (`assets/fonts/DaisySerif-SemiBold.ttf`: Source
Serif 4 instanced to wght 600 / opsz 20 and subset to Latin, 55KB, SIL OFL 1.1 — license kept beside it).
Only weight 600 ships, so avoid asking the serif styles for other weights.

**Autofill chain** (`recipe_autofill_service.dart`): Gemini first; on failure falls back to HTML parsing that only
recognizes `.tasty-recipes` print layouts. The HTML fetch goes through the `recipeAutofillProxy` Cloud Function
(`functions/index.js`, us-central1) to dodge browser CORS. Override with
`--dart-define=RECIPE_AUTOFILL_PROXY_URL=...`.

## Configuration

- `lib/services/firebase_service.dart` and `admin_config.dart` are gitignored — copy from the `.template.dart`
  siblings locally; CI injects them from secrets.
- **Gemini keys come from Firebase Remote Config**, not a file: `gemini_api_key`, `gemini_model`,
  `gemini_enabled` (see `remote_config_service.dart`). `gemini_config.dart` is gitignored and imported by nothing.

## Security model (README overstates this)

Recipes are **not** user-scoped. `firestore.rules`: `recipes` is world-readable; create requires
`createdBy == auth.uid`; update is limited to the creator or an admin, with one carve-out — any signed-in user may
toggle `isFavorite` alone, because favourites are a shared flag on the recipe document rather than per-user state.
Recipes predating the `createdBy` field stay editable by any signed-in user so old data is not frozen. Admin is
resolved two different ways: rules read `users/{uid}.isAdmin`, while `auth_service.dart` checks the email against
`AdminConfig.adminEmails`.

## Conventions

From `.github/instructions/piractInstruction.instructions.md` (Copilot custom instructions, `applyTo: '**'`):
prefer minimal, surgical changes over rewrites; avoid over-engineering; SOLID and self-explanatory naming;
**no comments unless they explain a non-obvious "why"**.

User-facing copy is warm, plain and professional — full sentences, no exclamation marks, no emoji, no themed
phrasing. The app is **Daisy's Kitchen** (`AppConstants.appName`); "Recipe Keeper" survives only as the Dart
package name and a few class names. An earlier pirate voice was deliberately retired; do not reintroduce it.

All user feedback goes through `SnackBarHelper.showSuccess/showError/showInfo/showWarning` rather than inline
`SnackBar`s, so status colours stay themed. Logging goes through `LoggerService.info/success/warning/error` with a
tag string, not `print`. Service methods swallow errors and return `null` / `false` / `[]` after logging rather
than throwing — follow that pattern in `services/`. Shared helpers in `utils/`: `RetryHelper`, `Validators`,
`Debouncer`, `SnackbarHelper`, `ErrorMessages`.
