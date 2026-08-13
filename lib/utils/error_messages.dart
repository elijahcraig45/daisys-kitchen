import 'package:firebase_auth/firebase_auth.dart';

/// User-friendly error messages for common Firebase and app errors
/// Translates technical errors into clear, actionable messages
class ErrorMessages {
  /// Get user-friendly error message from Firebase Auth exception
  static String fromFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with these credentials. Try signing up instead.';
      case 'wrong-password':
        return 'Incorrect password. Try again or reset your password.';
      case 'email-already-in-use':
        return 'That email is already registered. Try signing in instead.';
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'weak-password':
        return 'That password is too weak. Please choose a stronger one.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'popup-closed-by-user':
        return 'Sign-in cancelled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email but different credentials.';
      default:
        return 'Sign-in failed: ${e.message ?? "unknown error"}';
    }
  }

  /// Get user-friendly error message from Firestore exception
  static String fromFirestoreException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission for this action. Try signing in again.';
      case 'not-found':
        return 'That recipe could not be found.';
      case 'already-exists':
        return 'That recipe already exists.';
      case 'resource-exhausted':
        return 'Too many requests. Please try again shortly.';
      case 'failed-precondition':
        return 'The action could not be completed. Check the recipe details.';
      case 'aborted':
        return 'The action was interrupted. Please try again.';
      case 'out-of-range':
        return 'One of the values is out of range. Please check your input.';
      case 'unimplemented':
        return 'This feature is not available yet.';
      case 'internal':
        return 'An internal error occurred. Please try again later.';
      case 'unavailable':
        return 'The service is temporarily unavailable. Please try again.';
      case 'data-loss':
        return 'Data may have been lost. Please contact support.';
      case 'unauthenticated':
        return 'Please sign in to continue.';
      case 'deadline-exceeded':
        return 'That took too long to complete. Please try again.';
      case 'cancelled':
        return 'The action was cancelled.';
      default:
        return 'Database error: ${e.message ?? "Unknown error"}';
    }
  }

  /// Generic error message for network issues
  static String networkError() {
    return 'No connection. Check your internet and try again.';
  }

  /// Generic error message for validation errors
  static String validationError(String field) {
    return 'Please check the $field and try again.';
  }

  /// Success message for recipe operations
  static String recipeCreated() {
    return 'Recipe added to your collection.';
  }

  static String recipeUpdated() {
    return 'Recipe updated.';
  }

  static String recipeDeleted() {
    return 'Recipe deleted.';
  }

  static String recipeImported(int count) {
    return 'Imported $count recipe${count == 1 ? '' : 's'}.';
  }

  static String recipeExported(int count) {
    return 'Exported $count recipe${count == 1 ? '' : 's'}.';
  }

  /// Generic success message
  static String success(String operation) {
    return '$operation completed.';
  }

  /// Generic error message
  static String genericError() {
    return 'Something went wrong. Please try again.';
  }
}
