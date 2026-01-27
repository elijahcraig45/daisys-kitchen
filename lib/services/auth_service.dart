import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'admin_config.dart';
import 'logger_service.dart';

/// Authentication service for Firebase Auth with enhanced error handling
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();
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
      LoggerService.info('Attempting Google sign-in', 'Auth');
      
      if (kIsWeb) {
        // Web: Use Firebase Auth popup directly
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        
        final userCredential = await _auth.signInWithPopup(googleProvider);
        
        // Update user profile in Firestore
        if (userCredential.user != null) {
          await _updateUserProfile(userCredential.user!);
          LoggerService.success(
            'User signed in: ${userCredential.user!.email}',
            'Auth',
          );
        }
        
        return userCredential;
      } else {
        // Mobile/Desktop: Use google_sign_in package
        final GoogleSignInAccount? googleUser = await _googleSignIn?.signIn();
        if (googleUser == null) {
          LoggerService.info('User cancelled Google sign-in', 'Auth');
          return null;
        }

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
          LoggerService.success(
            'User signed in: ${userCredential.user!.email}',
            'Auth',
          );
        }

        return userCredential;
      }
    } on FirebaseAuthException catch (e) {
      LoggerService.error(
        'Firebase auth error during Google sign-in: ${e.code}',
        error: e,
        tag: 'Auth',
      );
      rethrow;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error signing in with Google',
        error: e,
        stackTrace: stackTrace,
        tag: 'Auth',
      );
      rethrow;
    }
  }

  /// Sign in anonymously (for public viewing)
  Future<UserCredential?> signInAnonymously() async {
    try {
      LoggerService.info('Attempting anonymous sign-in', 'Auth');
      final credential = await _auth.signInAnonymously();
      LoggerService.success('Anonymous sign-in successful', 'Auth');
      return credential;
    } on FirebaseAuthException catch (e) {
      LoggerService.error(
        'Firebase auth error during anonymous sign-in: ${e.code}',
        error: e,
        tag: 'Auth',
      );
      return null;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error signing in anonymously',
        error: e,
        stackTrace: stackTrace,
        tag: 'Auth',
      );
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      LoggerService.info('Signing out user', 'Auth');
      await _googleSignIn?.signOut();
      await _auth.signOut();
      LoggerService.success('User signed out successfully', 'Auth');
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error during sign out',
        error: e,
        stackTrace: stackTrace,
        tag: 'Auth',
      );
      rethrow;
    }
  }

  /// Update user profile in Firestore with error handling
  Future<void> _updateUserProfile(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'isAdmin': _adminEmails.contains(user.email),
        'lastSignIn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      LoggerService.debug('User profile updated in Firestore', 'Auth');
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Failed to update user profile: ${e.code}',
        error: e,
        tag: 'Auth',
      );
      // Don't rethrow - profile update failure shouldn't block sign-in
    } catch (e) {
      LoggerService.error(
        'Unexpected error updating user profile',
        error: e,
        tag: 'Auth',
      );
      // Don't rethrow - profile update failure shouldn't block sign-in
    }
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
