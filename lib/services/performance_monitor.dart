import 'package:flutter/foundation.dart';
import 'package:recipe_keeper/services/logger_service.dart';

/// Performance monitoring service to track operation timings
/// Helps identify bottlenecks and slow operations
class PerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, List<int>> _metrics = {};

  /// Start timing an operation
  static void startOperation(String operationName) {
    if (!kDebugMode) return; // Only track in debug mode
    _startTimes[operationName] = DateTime.now();
  }

  /// End timing an operation and log the duration
  static void endOperation(String operationName, {String? tag}) {
    if (!kDebugMode) return;
    
    final startTime = _startTimes[operationName];
    if (startTime == null) {
      LoggerService.warning(
        'Attempted to end operation "$operationName" that was never started',
        'Performance',
      );
      return;
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    _startTimes.remove(operationName);

    // Track metrics
    _metrics[operationName] ??= [];
    _metrics[operationName]!.add(duration);

    // Log if operation took too long
    if (duration > 1000) {
      LoggerService.warning(
        '$operationName took ${duration}ms - consider optimization',
        tag ?? 'Performance',
      );
    } else if (duration > 100) {
      LoggerService.debug(
        '$operationName completed in ${duration}ms',
        tag ?? 'Performance',
      );
    }
  }

  /// Get average duration for an operation
  static double? getAverageDuration(String operationName) {
    final metrics = _metrics[operationName];
    if (metrics == null || metrics.isEmpty) return null;
    
    final sum = metrics.reduce((a, b) => a + b);
    return sum / metrics.length;
  }

  /// Log performance summary
  static void logSummary() {
    if (!kDebugMode) return;
    
    LoggerService.info('=== Performance Summary ===', 'Performance');
    for (final entry in _metrics.entries) {
      final avg = getAverageDuration(entry.key);
      LoggerService.info(
        '${entry.key}: avg ${avg?.toStringAsFixed(0)}ms (${entry.value.length} samples)',
        'Performance',
      );
    }
  }

  /// Clear all metrics
  static void clearMetrics() {
    _startTimes.clear();
    _metrics.clear();
  }
}
