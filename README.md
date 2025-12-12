# 🍳 Daisy's Kitchen

A beautiful, modern recipe management app built with Flutter and Firebase. Keep all your favorite recipes organized, searchable, and accessible from anywhere!

## ✨ Features

- 📱 **Cross-platform**: Works on web, mobile, and desktop
- 🔐 **Google Sign-In**: Secure authentication with your Google account
- ☁️ **Cloud Sync**: All recipes stored in Firebase Firestore
- 🔍 **Smart Search**: Find recipes by name, ingredients, or tags
- ⭐ **Favorites**: Mark your go-to recipes for quick access
- 📂 **Categories**: Organize by cuisine, meal type, or custom categories
- ⏱️ **Cooking Mode**: Step-by-step instructions with timers
- 📤 **Import/Export**: Backup and share recipes via JSON
- 🎨 **Modern UI**: Clean, intuitive interface with responsive design
- 👨‍💼 **Admin Controls**: Manage recipes with admin privileges

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.24.0 or higher)
- Firebase account
- Google account for authentication

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/elijahcraig45/daisys-kitchen.git
   cd daisys-kitchen
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   
   a. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   
   b. Enable Google Sign-In:
      - Go to Authentication > Sign-in method
      - Enable Google provider
   
   c. Create a Firestore database:
      - Go to Firestore Database
      - Create database in production mode
   
   d. Set up Firebase for your app:
      ```bash
      # Copy the template files
      cp lib/services/firebase_service.template.dart lib/services/firebase_service.dart
      cp lib/services/admin_config.template.dart lib/services/admin_config.dart
      ```
   
   e. Edit `lib/services/firebase_service.dart` with your Firebase config:
      - Get your config from Firebase Console > Project Settings > General
      - Replace the placeholder values with your actual Firebase config
   
   f. Edit `lib/services/admin_config.dart` with your admin email:
      - Replace 'your-admin-email@example.com' with your Google account email

4. **Deploy Firestore security rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

5. **Run the app**
   ```bash
   # Web
   flutter run -d chrome
   
   # iOS
   flutter run -d ios
   
   # Android
   flutter run -d android
   ```

### Deploy to Firebase Hosting

1. **Build for web**
   ```bash
   flutter build web --release
   ```

2. **Deploy**
   ```bash
   firebase deploy --only hosting
   ```

3. **Configure OAuth for production**
   - Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   - Find your OAuth 2.0 Client ID
   - Add your hosting URLs to authorized origins and redirect URIs

## 📁 Project Structure

```
lib/
├── models/           # Data models (Recipe, Ingredient, etc.)
├── providers/        # Riverpod providers for state management
├── screens/          # UI screens
├── services/         # Firebase, Auth, and Database services
└── main.dart         # App entry point

firestore.rules       # Firestore security rules
firebase.json         # Firebase configuration
```

## 🔒 Security

- Firebase secrets (firebase_service.dart) are gitignored
- Admin emails (admin_config.dart) are gitignored
- Use template files to set up your own configuration
- Firestore rules enforce authentication and authorization

## 🛠️ Technologies

- **Flutter**: Cross-platform UI framework
- **Firebase Auth**: User authentication
- **Cloud Firestore**: NoSQL database
- **Firebase Hosting**: Web hosting
- **Riverpod**: State management
- **GoRouter**: Navigation
- **Isar**: Local database (optional offline support)

## 📝 License

This project is open source and available under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 👩‍🍳 About

Daisy's Kitchen is a labor of love for home cooks who want a simple, beautiful way to organize their recipes. Built with ❤️ using Flutter.

---

**Note**: Remember to set up your own Firebase project and keep your firebase_service.dart and admin_config.dart files private!
