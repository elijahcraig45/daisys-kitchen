# 🍳 Daisy's Kitchen

A Flutter web app for collecting, searching and cooking from your own recipe book, with
AI-assisted recipe capture and real-time cloud sync.

**[recipe-f644f.web.app](https://recipe-f644f.web.app)**

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.41+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Cloud-FFCA28?logo=firebase)](https://firebase.google.com)
[![Gemini AI](https://img.shields.io/badge/Gemini-AI%20Powered-4285F4?logo=google)](https://ai.google.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#license)

</div>

---

## Features

### Recipe capture
- **AI extraction** — paste a recipe URL or raw text and Gemini structures it into
  ingredients, steps, timings and servings.
- **HTML fallback** — when AI is unavailable, Tasty Recipes print layouts are parsed
  directly, via a Cloud Function proxy that works around browser CORS.
- **Grammar and unit clean-up** — an AI pass tidies phrasing and adds metric
  equivalents alongside customary measurements.

### Everyday use
- **Cooking mode** — distraction-free, step-by-step walkthrough with built-in timers.
- **Search** — matches recipe names, ingredients, tags, descriptions, categories and
  cuisines, with category, difficulty and favourites filters.
- **Import / export** — JSON backup and sharing of your collection.
- **Cloud sync** — real-time updates across devices via Firestore, with offline
  persistence enabled so the app keeps working without a connection.
- **Light and dark themes**, following your system setting.

---

## Tech stack

| Layer | Choice |
|---|---|
| UI | Flutter (Material 3), custom theme in `lib/theme/app_theme.dart` |
| State | Riverpod — all filter state lives in providers, not widget state |
| Routing | GoRouter |
| Data | Cloud Firestore (single `recipes` collection), real-time streams |
| Auth | Firebase Auth, Google sign-in |
| Config | Firebase Remote Config (Gemini keys) |
| AI | Google Gemini |
| Hosting | Firebase Hosting, deployed by GitHub Actions |

`RecipeMapper` (`lib/services/recipe_mapper.dart`) owns the Firestore document shape and
is kept free of Firebase singletons so it can be unit tested. Note that
`Recipe.toJson()` is a *separate* representation used by import/export — changing the
model means updating both.

---

## Getting started

### Prerequisites
- Flutter SDK 3.24+ (developed against 3.41)
- A Firebase project
- Optionally, a [Gemini API key](https://aistudio.google.com/app/apikey) for AI features

### Setup

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Generate code** — `*.g.dart` files are gitignored, so this is required before the
   first build and after any model change:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

3. **Configure Firebase** — enable Google sign-in, create a Firestore database, and
   initialise Hosting. Then fill in the two gitignored config files from their
   templates:
   ```bash
   cp lib/services/firebase_service.template.dart lib/services/firebase_service.dart
   cp lib/services/admin_config.template.dart lib/services/admin_config.dart
   ```
   `firebase_service.dart` holds your Firebase project config; `admin_config.dart`
   lists admin email addresses.

4. **Configure Gemini (optional)** — keys are read from **Firebase Remote Config**, not
   from a file. In the Firebase console add:

   | Parameter | Value |
   |---|---|
   | `gemini_api_key` | your API key |
   | `gemini_model` | e.g. `gemini-2.5-flash` |
   | `gemini_enabled` | `true` |

   Publish the changes. Without a key the app runs fine; AI features are simply
   disabled.

5. **Deploy the security rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

6. **Run**
   ```bash
   flutter run -d chrome
   ```

---

## Development

```bash
flutter test                                              # unit tests
flutter analyze                                           # static analysis
dart format lib test                                      # formatting
dart run build_runner watch --delete-conflicting-outputs  # regenerate on change
```

Follow [Effective Dart](https://dart.dev/guides/language/effective-dart). Take colours
from the theme (`Theme.of(context).colorScheme` or the `context.colors` /
`context.statusColors` extensions) rather than `Colors.*` literals — hardcoded colours
are what previously broke dark mode. Show user feedback through `SnackBarHelper` and log
through `LoggerService`.

---

## Deployment

Pushing to `main` triggers `.github/workflows/deploy.yml`, which writes the two config
files from GitHub secrets, runs code generation, builds the web bundle and deploys to
Firebase Hosting.

Hosting is **all** CI deploys. Rules and functions are manual:

```bash
firebase deploy --only firestore:rules
firebase deploy --only functions
firebase deploy --only hosting        # manual hosting deploy, after flutter build web --release
```

---

## Access model

This is a **shared** recipe book rather than a set of private collections — worth
understanding before you put anything sensitive in it:

- Recipes are **publicly readable**, including by signed-out visitors.
- Creating a recipe requires signing in, and stamps you as its creator.
- Editing and deleting are limited to the recipe's creator or an admin. Recipes created
  before creator tracking existed remain editable by any signed-in user.
- **Favourites are a shared flag** on the recipe document, not per-user state, so any
  signed-in user can toggle one and everybody sees the change.
- Admin status is resolved two ways: `firestore.rules` reads `users/{uid}.isAdmin`,
  which is written at sign-in from the email list in `admin_config.dart`.

---

## Credits

Headings are set in [Source Serif 4](https://github.com/adobe-fonts/source-serif) by
Frank Grießhammer, used under the SIL Open Font License 1.1. The bundled file is
instanced to a single weight and subset to Latin; the licence is included at
`assets/fonts/OFL.txt`.

## License

MIT. (A `LICENSE` file has not been added to the repository yet.)
