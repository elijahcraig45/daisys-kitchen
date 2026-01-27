import 'dart:async';
import 'package:flutter/foundation.dart';
// Note: app_links package not currently installed
// import 'package:app_links/app_links.dart';

/// Service to handle deep linking for the Recipe Keeper app.
/// 
/// Supports the following URL patterns:
/// - daisyskitchen://recipe/{id} - Navigate to a specific recipe
/// - daisyskitchen://recipe/{id}/cook - Navigate to cooking mode for a recipe
/// - daisyskitchen://recipe/{id}/edit - Navigate to edit a recipe
/// - daisyskitchen://category/{category} - Navigate to a category
/// - https://recipes.daisyskitchen.app/recipe/{id} - Universal link for recipe
/// 
/// TODO: Add app_links package to pubspec.yaml to enable deep linking
class DeepLinkService {
  // static final AppLinks _appLinks = AppLinks();
  // ignore: unused_field
  static StreamSubscription? _linkSubscription;
  // ignore: unused_field
  static bool _hasProcessedInitialUri = false;

  /// Initialize deep linking and listen for incoming links
  static Future<void> initialize({
    required Function(Uri) onLinkReceived,
  }) async {
    debugPrint('🏴‍☠️ Deep linking is temporarily disabled - app_links package not installed');
    
    // TODO: Uncomment when app_links is added to dependencies
    /*
    try {
      // Get the initial link if app was opened via deep link
      if (!_hasProcessedInitialUri) {
        final initialUri = await _appLinks.getInitialLink();
        _hasProcessedInitialUri = true;
        
        if (initialUri != null) {
          debugPrint('🏴‍☠️ Received initial deep link: $initialUri');
          onLinkReceived(initialUri);
        }
      }

      // Listen to link stream while app is running
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          debugPrint('🏴‍☠️ Received deep link while running: $uri');
          onLinkReceived(uri);
        },
        onError: (Object err) {
          debugPrint('🏴‍☠️ Deep link error: $err');
        },
      );
    } catch (e) {
      debugPrint('🏴‍☠️ Error initializing deep links: $e');
    }
    */
  }

  /// Dispose of the link subscription
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }

  /// Parse a deep link URI and extract navigation information
  /// Returns a map with 'path' and optional 'parameters'
  static Map<String, dynamic>? parseDeepLink(Uri uri) {
    debugPrint('🏴‍☠️ Parsing deep link: $uri');
    debugPrint('  Scheme: ${uri.scheme}');
    debugPrint('  Host: ${uri.host}');
    debugPrint('  Path: ${uri.path}');
    debugPrint('  Segments: ${uri.pathSegments}');

    // Handle custom scheme: daisyskitchen://
    if (uri.scheme == 'daisyskitchen') {
      return _parseCustomScheme(uri);
    }

    // Handle universal links: https://recipes.daisyskitchen.app/
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == 'recipes.daisyskitchen.app') {
      return _parseUniversalLink(uri);
    }

    debugPrint('🏴‍☠️ Unrecognized deep link format');
    return null;
  }

  static Map<String, dynamic>? _parseCustomScheme(Uri uri) {
    final segments = uri.pathSegments;
    
    if (segments.isEmpty) {
      // daisyskitchen:// -> home
      return {'path': '/'};
    }

    // daisyskitchen://recipe/{id}
    // daisyskitchen://recipe/{id}/cook
    // daisyskitchen://recipe/{id}/edit
    if (segments[0] == 'recipe' && segments.length >= 2) {
      final recipeId = segments[1];
      
      if (segments.length >= 3) {
        if (segments[2] == 'cook') {
          return {'path': '/recipe/$recipeId/cook', 'id': recipeId};
        } else if (segments[2] == 'edit') {
          return {'path': '/recipe/$recipeId/edit', 'id': recipeId};
        }
      }
      
      return {'path': '/recipe/$recipeId', 'id': recipeId};
    }

    // daisyskitchen://category/{category}
    if (segments[0] == 'category' && segments.length >= 2) {
      final category = segments[1];
      return {'path': '/category/$category', 'category': category};
    }

    return null;
  }

  static Map<String, dynamic>? _parseUniversalLink(Uri uri) {
    final segments = uri.pathSegments;
    
    if (segments.isEmpty) {
      return {'path': '/'};
    }

    // Same pattern as custom scheme for universal links
    if (segments[0] == 'recipe' && segments.length >= 2) {
      final recipeId = segments[1];
      
      if (segments.length >= 3) {
        if (segments[2] == 'cook') {
          return {'path': '/recipe/$recipeId/cook', 'id': recipeId};
        } else if (segments[2] == 'edit') {
          return {'path': '/recipe/$recipeId/edit', 'id': recipeId};
        }
      }
      
      return {'path': '/recipe/$recipeId', 'id': recipeId};
    }

    if (segments[0] == 'category' && segments.length >= 2) {
      final category = segments[1];
      return {'path': '/category/$category', 'category': category};
    }

    return null;
  }
}
