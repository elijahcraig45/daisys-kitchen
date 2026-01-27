# 🍳 Recipe Keeper - Modern Recipe Management

A full-stack Flutter web application for managing and organizing recipes with AI-powered features, real-time cloud sync, and an intuitive cooking mode interface.

**✨ [Live Demo](https://recipe-f644f.web.app)** ✨

<div align="center">
  
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Cloud-FFCA28?logo=firebase)](https://firebase.google.com)
[![Gemini AI](https://img.shields.io/badge/Gemini-AI%20Powered-4285F4?logo=google)](https://ai.google.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## 🎯 Key Features

### 🤖 AI-Powered Intelligence
- **Smart Recipe Extraction**: Paste any recipe URL or raw text - Gemini AI automatically extracts structured data with both customary and metric measurements
- **Grammar Enhancement**: AI-powered verification fixes typos, improves clarity, and standardizes formatting
- **Dual Unit Conversion**: Automatically adds metric equivalents to US measurements (cups → ml, oz → grams, etc.)

### 🔥 Core Functionality
- **Cloud Sync**: Real-time synchronization across all devices via Firebase Firestore
- **Cooking Mode**: Distraction-free, step-by-step walkthrough with integrated timers
- **Import/Export**: JSON-based backup and sharing of your recipe collection
- **Smart Search**: Filter by category, cuisine, difficulty, favorites, or free text
- **Responsive Design**: Optimized for desktop, tablet, and mobile browsers

### 🎨 User Experience
- **Modern Material Design 3** with custom color theming
- **Offline-First Architecture**: Works without internet, syncs when connected
- **Google Sign-In**: Secure authentication with Firebase Auth
- **Private by Default**: Firestore security rules ensure recipes are user-scoped

---

## 🏗️ Architecture & Technical Stack

### Frontend
- **Flutter 3.24+** with Material Design 3
- **Riverpod 2.6+** for state management and dependency injection
- **GoRouter** for declarative navigation and deep linking
- **Progressive Web App** with service worker caching

### Backend & Services
- **Firebase Firestore** - NoSQL cloud database with real-time sync
- **Firebase Authentication** - Google OAuth integration
- **Firebase Hosting** - Global CDN for web deployment
- **Firebase Remote Config** - Dynamic configuration (AI API keys)
- **Google Gemini AI** - Recipe extraction and enhancement (free tier)

### Data Layer
- **Isar-Compatible Models** with JSON serialization
- **Build Runner** for code generation
- **Conditional Imports** for web/native platform abstractions

### CI/CD
- **GitHub Actions** automated deployment pipeline
- **Firebase Tools** for hosting and Firestore rules
- **Secrets Management** via GitHub environment variables

---

## 🚀 Quick Start

### For End Users

Simply visit **[recipe-f644f.web.app](https://recipe-f644f.web.app)** and sign in with Google to start managing your recipes immediately.

### For Developers

#### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.24.0+
- [Firebase](https://console.firebase.google.com/) account
- [Git](https://git-scm.com/)
- (Optional) [Gemini API Key](https://makersuite.google.com/app/apikey) for AI features

#### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/recipe-keeper.git
   cd recipe-keeper
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**

   Create a Firebase project with:
   - **Authentication** → Enable Google Sign-In provider
   - **Firestore Database** → Start in production mode
   - **Hosting** → Initialize for web deployment
   - **Remote Config** (optional) → For AI features

4. **Set up environment files**

   ```bash
   # Copy templates
   cp lib/services/firebase_service.template.dart lib/services/firebase_service.dart
   cp lib/services/admin_config.template.dart lib/services/admin_config.dart
   ```

   Edit with your credentials:
   - `firebase_service.dart`: Firebase project configuration
   - `admin_config.dart`: Admin email list

5. **Configure Gemini AI (Optional)**

   For AI-powered recipe extraction:
   
   1. Get free API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
   2. In Firebase Console → Remote Config, add:
      - Parameter: `gemini_api_key`
      - Value: Your API key
      - Default: Empty string
   3. Publish changes

   📖 See [GEMINI_SETUP.md](GEMINI_SETUP.md) for detailed setup

6. **Deploy Firestore security rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

7. **Run locally**
   ```bash
   flutter run -d chrome
   ```

8. **Generate code** (if modifying models)
   ```bash
   dart run build_runner watch --delete-conflicting-outputs
   ```

---

## 📁 Project Structure

```
recipe-keeper/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── router.dart               # GoRouter configuration
│   ├── models/                   # Data models (Recipe, Ingredient, Step)
│   │   ├── recipe.dart
│   │   ├── ingredient.dart
│   │   └── recipe_step.dart
│   ├── providers/                # Riverpod state management
│   │   ├── firebase_providers.dart
│   │   ├── gemini_providers.dart
│   │   └── recipe_provider.dart
│   ├── screens/                  # UI screens
│   │   ├── home_screen.dart
│   │   ├── recipe_editor_screen.dart
│   │   ├── recipe_detail_screen.dart
│   │   └── cooking_mode_screen.dart
│   ├── services/                 # Business logic & APIs
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── gemini_service.dart
│   │   ├── remote_config_service.dart
│   │   ├── import_export_service.dart
│   │   └── recipe_autofill_service.dart
│   ├── widgets/                  # Reusable UI components
│   └── utils/                    # Helpers and utilities
├── firestore.rules               # Firestore security rules
├── firebase.json                 # Firebase configuration
├── .github/workflows/            # CI/CD pipelines
│   └── deploy.yml
└── pubspec.yaml                  # Flutter dependencies
```

---

## 🔒 Security & Privacy

- 🔐 **Authentication Required**: All data access requires Google Sign-In
- 🚫 **User-Scoped Data**: Firestore rules prevent cross-user data access
- 🔑 **No Credentials in Code**: Sensitive config injected via CI/CD secrets
- 🛡️ **HTTPS Only**: Enforced by Firebase Hosting
- 📝 **Audit Trail**: All recipes track creation/update timestamps

---

## 🚢 Deployment

### Automated (GitHub Actions)

Push to `main` branch triggers automatic deployment:

```bash
git push origin main
```

The workflow:
1. Builds Flutter web release bundle
2. Injects Firebase credentials from secrets
3. Runs code generation
4. Deploys to Firebase Hosting

### Manual Deployment

```bash
# Build production bundle
flutter build web --release

# Deploy to Firebase
firebase deploy --only hosting
```

---

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage

# Analyze code quality
flutter analyze
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide
- Run `flutter analyze` before committing
- Use `dart format .` for consistent formatting
- Write tests for new features
- Update documentation as needed

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Flutter Team** for the amazing cross-platform framework
- **Firebase** for backend infrastructure
- **Google Gemini AI** for intelligent recipe processing
- **Material Design** for UI/UX guidelines
- Home cooks everywhere who inspired this project ❤️

---

## 📬 Contact & Support

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/recipe-keeper/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/recipe-keeper/discussions)

---

<div align="center">

**Made with ❤️ and Flutter** | **Powered by Firebase ☁️**

⭐ Star this repo if you find it useful!

</div>
