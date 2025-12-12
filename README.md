# 🍳 Daisy's Kitchen

A delightfully modern recipe management app that helps you keep all your culinary treasures organized, searchable, and accessible from anywhere. Built with Flutter and Firebase for a seamless experience across all your devices.

**✨ [Try it live!](https://recipe-f644f.web.app)** ✨

## Features

- 📱 **Cross-Platform** — Works beautifully on web, mobile, and desktop
- 🔐 **Secure Authentication** — Sign in safely with your Google account  
- ☁️ **Cloud Sync** — Your recipes follow you everywhere via Firebase Firestore
- 🔍 **Smart Search** — Find recipes instantly by name, ingredients, or tags
- ⭐ **Favorites** — Mark your go-to recipes for quick access
- 📂 **Categories** — Organize by cuisine, meal type, or custom tags
- ⏱️ **Cooking Mode** — Step-by-step instructions to guide you through each recipe
- 📤 **Import/Export** — Backup and share your recipe collection
- 🎨 **Modern Design** — Clean, intuitive interface that gets out of your way
- 👨‍💼 **Admin Controls** — Manage your recipe collection with ease

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
- **[Firebase Auth](https://firebase.google.com/products/auth)** — Secure user authentication
- **[Cloud Firestore](https://firebase.google.com/products/firestore)** — Scalable NoSQL database
- **[Firebase Hosting](https://firebase.google.com/products/hosting)** — Fast and secure web hosting
- **[Riverpod](https://riverpod.dev/)** — Robust state management
- **[GoRouter](https://pub.dev/packages/go_router)** — Declarative routing

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

**Made with Flutter** 💙
