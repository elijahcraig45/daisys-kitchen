# 🍳 Daisy's Kitchen

A delightfully modern recipe management app that helps you keep all your culinary treasures organized, searchable, and accessible from anywhere. Built with Flutter and Firebase for a seamless experience across all your devices and now fully themed with the **Blue Glitter Banner** palette to match Daisy’s Kitchen branding.

**✨ [Try it live!](https://recipe-f644f.web.app)** ✨

---

## 💠 Theme & Design Language

| Role | Color | Hex |
| --- | --- | --- |
| Primary / App Bars | ![#025159](https://via.placeholder.com/12/025159/000000?text=+) Blue-glitter-banner-1 | `#025159` |
| Accent / Links | ![#3E848C](https://via.placeholder.com/12/3E848C/000000?text=+) Blue-glitter-banner-2 | `#3E848C` |
| Surfaces / Cards | ![#7AB8BF](https://via.placeholder.com/12/7AB8BF/000000?text=+) Blue-glitter-banner-3 | `#7AB8BF` |
| Backgrounds | ![#C4EEF2](https://via.placeholder.com/12/C4EEF2/000000?text=+) Blue-glitter-banner-4 | `#C4EEF2` |
| Highlight / FAB | ![#A67458](https://via.placeholder.com/12/A67458/000000?text=+) Blue-glitter-banner-5 | `#A67458` |

The Flutter `ThemeData` is generated from custom light/dark `ColorScheme`s so every Material component (inputs, cards, chips, FABs, info chips, etc.) inherits the Daisy’s Kitchen palette automatically.

---

## 🔧 Technical Highlights

- **Flutter 3.x + Material 3** with custom `ColorScheme`s, `SegmentedButton`s, responsive layouts, and Riverpod-powered view models.
- **Firestore data model** with Isar-compatible entities (Recipes, Ingredients, RecipeSteps) and JSON serialization handled via `build_runner`.
- **Dual-unit ingredient support** with automatic conversions between US customary and metric systems, plus per-step ingredient linking.
- **Autofill by link** pipeline that fetches print-friendly recipe pages through a secure Firebase Cloud Function proxy, parses HTML via `package:html`, and hydrates the editor with parsed data (title, description, image, steps, ingredients, timers).
- **Firebase Hosting + GitHub Actions** CI deploy (`.github/workflows/deploy.yml`) builds the Flutter web bundle, injects secrets (Firebase service/admin configs), and publishes to `recipe-f644f`.
- **Reusable services** (Auth, Firestore, Import/Export, Database) abstract Firebase, Google Sign-In, and platform storage differences.
- **Progressive Web App** support via Flutter web service worker & cached asset manifest.

---

## ✨ Feature Overview

- 📱 **Cross-platform UI**: Fully responsive layouts for web, tablet, and phones.
- 🔐 **Google Sign-In**: Firebase Auth + secure Firestore rules keep data private per user.
- ☁️ **Realtime Sync**: Recipes saved to Cloud Firestore with created/updated timestamps.
- 🧑‍🍳 **Recipe Editor**:
  - Live preview card.
  - Ingredient + step builders with reorder controls.
  - Step timers, per-step ingredients, and linked quantities.
  - Autofill from print recipe URLs with unit conversion + secondary measurement display.
- 🍽️ **Cooking Mode**: Large-type, timer-aware walkthrough with chip summaries of per-step ingredients.
- 🧭 **Search & Filters**: Quick filtering by tags, category, cuisine, difficulty, favorites.
- 📤 **Import/Export**: Share + back up your recipe collection via JSON.
- 🤖 **Admin Controls**: Template-driven admin email list to gate special features.

---

## Getting Started

### For Users

Just visit **[recipe-f644f.web.app](https://recipe-f644f.web.app)** and sign in with your Google account to start managing your recipes!

### For Developers

Want to run your own instance or contribute? Here's how to get started:

#### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24.0 or higher)
- A [Firebase](https://console.firebase.google.com/) account
- Git

#### Quick Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/elijahcraig45/daisys-kitchen.git
   cd daisys-kitchen
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase**
   
   Create a new Firebase project and enable:
   - **Authentication** → Google Sign-In provider
   - **Firestore Database** → Start in production mode
   
   Then configure your app:
   ```bash
   # Copy template files
   cp lib/services/firebase_service.template.dart lib/services/firebase_service.dart
   cp lib/services/admin_config.template.dart lib/services/admin_config.dart
   ```
   
   Edit both files with your Firebase credentials and admin email.

4. **Deploy Firestore rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

5. **Run the app**
   ```bash
   flutter run -d chrome  # or ios, android, macos, etc.
   ```

6. **Enable recipe autofill proxy (optional but recommended)**
   ```bash
   cd functions
   npm install
   npm run deploy   # deploys recipeAutofillProxy https function
   ```

   When running locally on web:
   ```bash
   flutter run -d chrome \
     --dart-define=RECIPE_AUTOFILL_PROXY_URL=https://<your-cloud-function-url>
   ```

### Local Development Tips

- `dart run build_runner watch --delete-conflicting-outputs` to keep generated files in sync.
- `flutter analyze` and `dart format .` before committing.
- Use `firebase emulators:start` if you want to test Firestore/Auth locally.

### Deployment

- **CI/CD**: Pushing to `main` triggers `.github/workflows/deploy.yml`, which:
  1. Sets up Flutter.
  2. Injects `firebase_service.dart` and `admin_config.dart` via GitHub secrets.
  3. Runs `flutter pub get`, `build_runner`, and `flutter build web --release`.
  4. Deploys `build/web` to Firebase Hosting with `firebase-tools`.
- **Manual deploy**:
  ```bash
  flutter build web --release
  firebase deploy --only hosting --project recipe-f644f
  ```

---

## Architecture

```
lib/
├── models/          # Data models (Recipe, Ingredient, Step)
├── providers/       # Riverpod state management
├── screens/         # UI screens and views
├── services/        # Firebase, Auth, and Database services
└── main.dart        # Application entry point
```

## Built With

- **[Flutter](https://flutter.dev/)** — Beautiful native apps from a single codebase
- **[Riverpod](https://riverpod.dev/)** — Scoped state management powering providers and controllers
- **[GoRouter](https://pub.dev/packages/go_router)** — Declarative navigation stacks and URL routing
- **[Firebase Auth](https://firebase.google.com/products/auth)** — Secure user authentication
- **[Cloud Firestore](https://firebase.google.com/products/firestore)** — Scalable NoSQL database
- **[Firebase Hosting](https://firebase.google.com/products/hosting)** — Fast and secure web hosting
- **[Firebase Functions](https://firebase.google.com/products/functions)** — Recipe autofill proxy to bypass CORS safely
- **[Isar](https://isar.dev/)** — Local persistence for offline work / exports
- **[HTML + HTTP packages](https://pub.dev/packages/html)** — HTML parsing and network calls for recipe autofill

---

## Security & Privacy

Your data security is important:
- 🔐 All recipes require authentication to access
- 🚫 Firestore security rules prevent unauthorized access
- 🔑 Firebase credentials are never committed to the repository
- 👤 Each user can only see and modify their own recipes

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/elijahcraig45/daisys-kitchen/issues).

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

Built with ❤️ for home cooks everywhere who believe recipes are meant to be savored, shared, and cherished.

---

**Made with Flutter** 💙 | **Powered by Firebase** ☁️
