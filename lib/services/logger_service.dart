import 'package:flutter/foundation.dart';

/// Centralized logging service for the application
/// Provides structured logging with different severity levels
class LoggerService {
  static const String _prefix = '🏴‍☠️';
  
  /// Log an informational message
  static void info(String message, [String? tag]) {
    final tagStr = tag != null ? '[$tag] ' : '';
    debugPrint('$_prefix INFO: $tagStr$message');
  }
  
  /// Log a warning message
  static void warning(String message, [String? tag]) {
    final tagStr = tag != null ? '[$tag] ' : '';
    debugPrint('$_prefix WARNING: $tagStr$message');
  }
  
  /// Log an error message with optional error object and stack trace
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    final tagStr = tag != null ? '[$tag] ' : '';
    debugPrint('$_prefix ERROR: $tagStr$message');
    
    if (error != null) {
      debugPrint('$_prefix   Error details: $error');
    }
    
    if (stackTrace != null && kDebugMode) {
      debugPrint('$_prefix   Stack trace:\n$stackTrace');
    }
  }
  
  /// Log a debug message (only in debug mode)
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag] ' : '';
      debugPrint('$_prefix DEBUG: $tagStr$message');
    }
  }
  
  /// Log a success message
  static void success(String message, [String? tag]) {
    final tagStr = tag != null ? '[$tag] ' : '';
    debugPrint('$_prefix SUCCESS: $tagStr$message');
  }
}
