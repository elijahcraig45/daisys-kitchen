import 'package:flutter/foundation.dart' show kIsWeb;

// Check if running on web
bool get isWeb => kIsWeb;

// Platform-specific implementations
class PlatformInfo {
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb;
}
