import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase initialization service
/// 
/// SETUP INSTRUCTIONS:
/// 1. Copy this file to `firebase_service.dart` in the same directory
/// 2. Replace the placeholder values below with your Firebase project configuration
/// 3. Get your config from: https://console.firebase.google.com/
///    - Go to Project Settings > General
///    - Scroll to "Your apps" section
///    - Select your web app or add a new one
///    - Copy the firebaseConfig values
class FirebaseService {
  static Future<void> initialize() async {
    if (kIsWeb) {
      // Web configuration - Replace these values with your Firebase project config
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "YOUR_API_KEY",
          authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
          projectId: "YOUR_PROJECT_ID",
          storageBucket: "YOUR_PROJECT_ID.firebasestorage.app",
          messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
          appId: "YOUR_APP_ID",
        ),
      );
    } else {
      // Mobile/Desktop will use google-services.json / GoogleService-Info.plist
      await Firebase.initializeApp();
    }
  }
}
