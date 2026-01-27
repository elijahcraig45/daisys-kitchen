import 'package:recipe_keeper/services/logger_service.dart';

/// Utility for retrying failed operations with exponential backoff
class RetryHelper {
  /// Retry an operation with exponential backoff
  /// 
  /// [operation] - The async operation to retry
  /// [maxAttempts] - Maximum number of retry attempts (default: 3)
  /// [initialDelay] - Initial delay before first retry (default: 1 second)
  /// [maxDelay] - Maximum delay between retries (default: 10 seconds)
  /// [onRetry] - Optional callback called before each retry
  static Future<T> retry<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 10),
    void Function(int attempt, Duration delay)? onRetry,
    String? tag,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      attempt++;
      
      try {
        LoggerService.debug(
          '$operationName (attempt $attempt/$maxAttempts)',
          tag ?? 'RetryHelper',
        );
        
        return await operation();
      } catch (e, stackTrace) {
        if (attempt >= maxAttempts) {
          LoggerService.error(
            '$operationName failed after $maxAttempts attempts',
            error: e,
            stackTrace: stackTrace,
            tag: tag ?? 'RetryHelper',
          );
          rethrow;
        }

        // Calculate next delay with exponential backoff
        final nextDelay = delay * 2;
        delay = nextDelay > maxDelay ? maxDelay : nextDelay;

        LoggerService.warning(
          '$operationName failed (attempt $attempt/$maxAttempts). Retrying in ${delay.inSeconds}s...',
          tag ?? 'RetryHelper',
        );

        onRetry?.call(attempt, delay);
        await Future.delayed(delay);
      }
    }
  }

  /// Retry an operation with linear backoff (same delay between retries)
  static Future<T> retryLinear<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
    void Function(int attempt)? onRetry,
    String? tag,
  }) async {
    int attempt = 0;

    while (true) {
      attempt++;
      
      try {
        return await operation();
      } catch (e, stackTrace) {
        if (attempt >= maxAttempts) {
          LoggerService.error(
            '$operationName failed after $maxAttempts attempts',
            error: e,
            stackTrace: stackTrace,
            tag: tag ?? 'RetryHelper',
          );
          rethrow;
        }

        LoggerService.warning(
          '$operationName failed (attempt $attempt/$maxAttempts). Retrying...',
          tag ?? 'RetryHelper',
        );

        onRetry?.call(attempt);
        await Future.delayed(delay);
      }
    }
  }
}
