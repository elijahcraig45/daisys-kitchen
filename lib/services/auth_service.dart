import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'admin_config.dart';

/// Authentication service for Firebase Auth
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Admin user IDs - loaded from admin_config.dart (gitignored)
  static final Set<String> _adminEmails = AdminConfig.adminEmails;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if current user is admin
  bool get isAdmin {
    final user = currentUser;
    if (user == null) return false;
    return _adminEmails.contains(user.email);
  }

  /// Check if current user is signed in
  bool get isSignedIn => currentUser != null;

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: Use Firebase Auth popup directly
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        
        final userCredential = await _auth.signInWithPopup(googleProvider);
        
        // Update user profile in Firestore
        if (userCredential.user != null) {
          await _updateUserProfile(userCredential.user!);
        }
        
        return userCredential;
      } else {
        // Mobile: Use google_sign_in package
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // User canceled

        // Obtain auth details
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // Create credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase
        final userCredential = await _auth.signInWithCredential(credential);

        // Update user profile in Firestore
        if (userCredential.user != null) {
          await _updateUserProfile(userCredential.user!);
        }

        return userCredential;
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow; // Re-throw so the UI can show the error
    }
  }

  /// Sign in anonymously (for public viewing)
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  /// Update user profile in Firestore
  Future<void> _updateUserProfile(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'isAdmin': _adminEmails.contains(user.email),
      'lastSignIn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user display name
  String get displayName {
    final user = currentUser;
    if (user == null) return 'Guest';
    return user.displayName ?? user.email ?? 'User';
  }

  /// Get user photo URL
  String? get photoURL => currentUser?.photoURL;
}
