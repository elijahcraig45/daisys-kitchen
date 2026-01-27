import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:recipe_keeper/services/logger_service.dart';

/// Service to monitor network connectivity
/// Helps provide better UX when offline
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivityController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  Timer? _checkTimer;

  /// Stream of connectivity status changes
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Current connectivity status
  bool get isOnline => _isOnline;

  /// Initialize connectivity monitoring
  void initialize() {
    LoggerService.info('Initializing connectivity monitoring', 'Connectivity');
    
    // For web, we can use navigator.onLine
    if (kIsWeb) {
      _checkWebConnectivity();
      // Check every 30 seconds
      _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _checkWebConnectivity();
      });
    }
  }

  void _checkWebConnectivity() {
    // On web, we assume online by default
    // In a production app, you might ping your backend
    final wasOnline = _isOnline;
    _isOnline = true; // Simplified for now
    
    if (wasOnline != _isOnline) {
      LoggerService.info(
        'Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}',
        'Connectivity',
      );
      _connectivityController.add(_isOnline);
    }
  }

  /// Manually set connectivity status (useful for testing or advanced checks)
  void setConnectivity(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      LoggerService.info(
        'Connectivity manually set: ${_isOnline ? "ONLINE" : "OFFLINE"}',
        'Connectivity',
      );
      _connectivityController.add(_isOnline);
    }
  }

  /// Dispose of resources
  void dispose() {
    _checkTimer?.cancel();
    _connectivityController.close();
  }
}
