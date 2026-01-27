import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'logger_service.dart';

/// Service for managing Firebase Remote Config
/// Stores app configuration like API keys in the cloud
class RemoteConfigService {
  static RemoteConfigService? _instance;
  static RemoteConfigService get instance {
    _instance ??= RemoteConfigService._();
    return _instance!;
  }

  RemoteConfigService._();

  FirebaseRemoteConfig? _remoteConfig;
  bool _initialized = false;

  /// Initialize Remote Config with defaults
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set config settings
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1), // Cache for 1 hour
        ),
      );

      // Set default values (used when no remote value exists)
      await _remoteConfig!.setDefaults({
        'gemini_api_key': '',
        'gemini_model': 'gemini-1.5-flash',
        'gemini_enabled': true,
      });

      // Fetch and activate latest values
      await _remoteConfig!.fetchAndActivate();
      
      _initialized = true;
      LoggerService.success('Remote Config initialized', 'RemoteConfig');
    } catch (e) {
      LoggerService.error('Failed to initialize Remote Config', error: e, tag: 'RemoteConfig');
      _initialized = false;
    }
  }

  /// Get Gemini API key from remote config
  String get geminiApiKey {
    if (!_initialized || _remoteConfig == null) {
      LoggerService.warning('Remote Config not initialized', 'RemoteConfig');
      return '';
    }
    return _remoteConfig!.getString('gemini_api_key');
  }

  /// Get Gemini model name from remote config
  String get geminiModel {
    if (!_initialized || _remoteConfig == null) {
      return 'gemini-1.5-flash';
    }
    return _remoteConfig!.getString('gemini_model');
  }

  /// Check if Gemini is enabled
  bool get geminiEnabled {
    if (!_initialized || _remoteConfig == null) {
      return false;
    }
    return _remoteConfig!.getBool('gemini_enabled');
  }

  /// Check if Remote Config is initialized
  bool get isInitialized => _initialized;

  /// Force fetch latest config (bypasses cache)
  Future<void> refresh() async {
    if (!_initialized || _remoteConfig == null) {
      await initialize();
      return;
    }

    try {
      await _remoteConfig!.fetchAndActivate();
      LoggerService.success('Remote Config refreshed', 'RemoteConfig');
    } catch (e) {
      LoggerService.error('Failed to refresh Remote Config', error: e, tag: 'RemoteConfig');
    }
  }
}
