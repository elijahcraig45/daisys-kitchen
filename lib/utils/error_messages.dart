import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// User-friendly error messages for common Firebase and app errors
/// Translates technical errors into pirate-themed, helpful messages
class ErrorMessages {
  /// Get user-friendly error message from Firebase Auth exception
  static String fromFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with these credentials, matey. Time to sign up!';
      case 'wrong-password':
        return 'Wrong password, sailor! Try again or reset yer password.';
      case 'email-already-in-use':
        return 'This email be already registered. Try signing in instead!';
      case 'invalid-email':
        return 'That email address doesn\'t look right, captain.';
      case 'weak-password':
        return 'Yer password be too weak! Make it stronger to protect yer recipes.';
      case 'operation-not-allowed':
        return 'This sign-in method is not allowed. Contact support, matey.';
      case 'user-disabled':
        return 'This account has been disabled. Walk the plank? Contact support!';
      case 'network-request-failed':
        return 'No wind in the sails! Check yer internet connection.';
      case 'too-many-requests':
        return 'Too many attempts, sailor! Take a breather and try again later.';
      case 'popup-closed-by-user':
        return 'Sign-in cancelled. Come back when ye\'re ready!';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email but different credentials.';
      default:
        return 'Shiver me timbers! Sign-in failed: ${e.message ?? "Unknown error"}';
    }
  }

  /// Get user-friendly error message from Firestore exception
  static String fromFirestoreException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Ye don\'t have permission for this operation. Sign in or check yer credentials!';
      case 'not-found':
        return 'The requested recipe has sailed away (not found).';
      case 'already-exists':
        return 'This recipe already exists in the galley!';
      case 'resource-exhausted':
        return 'Too many requests, sailor! The kitchen is overwhelmed. Try again shortly.';
      case 'failed-precondition':
        return 'Operation failed - check the recipe requirements.';
      case 'aborted':
        return 'Operation was aborted. The seas were too rough - try again!';
      case 'out-of-range':
        return 'Invalid data range. Check yer inputs, matey!';
      case 'unimplemented':
        return 'This feature hasn\'t been built yet. Stay tuned!';
      case 'internal':
        return 'The ship\'s systems encountered an error. Our crew is on it!';
      case 'unavailable':
        return 'The galley is temporarily closed. Check yer connection or try again!';
      case 'data-loss':
        return 'Blimey! Data may have been lost. Contact support immediately!';
      case 'unauthenticated':
        return 'Ye need to sign in first, sailor!';
      case 'deadline-exceeded':
        return 'Operation took too long - the tide has turned. Try again!';
      case 'cancelled':
        return 'Operation was cancelled. No harm done!';
      default:
        return 'Database error: ${e.message ?? "Unknown error"}';
    }
  }

  /// Generic error message for network issues
  static String networkError() {
    return 'Can\'t reach the open seas! Check yer internet connection and try again.';
  }

  /// Generic error message for validation errors
  static String validationError(String field) {
    return 'The $field needs fixin\', captain! Check the requirements.';
  }

  /// Success message for recipe operations
  static String recipeCreated() {
    return 'Recipe added to the galley! Bon appétit, matey! 🏴‍☠️';
  }

  static String recipeUpdated() {
    return 'Recipe updated successfully! The crew will love this! ⚓';
  }

  static String recipeDeleted() {
    return 'Recipe sent to Davy Jones\' locker (deleted).';
  }

  static String recipeImported(int count) {
    return 'Ahoy! Imported $count recipe${count == 1 ? '' : 's'} into the galley! 🍴';
  }

  static String recipeExported(int count) {
    return 'Exported $count recipe${count == 1 ? '' : 's'} for safekeeping! 📦';
  }

  /// Generic success message
  static String success(String operation) {
    return '$operation completed successfully! Fair winds and following seas! ⛵';
  }

  /// Generic error message
  static String genericError() {
    return 'Shiver me timbers! Something went wrong. Try again or contact the crew.';
  }
}
