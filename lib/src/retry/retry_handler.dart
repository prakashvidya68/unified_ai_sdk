import 'dart:async';

import '../error/error_types.dart';
import 'retry_policy.dart';

/// Handler for executing operations with automatic retry logic.
///
/// [RetryHandler] wraps operations in retry logic based on a [RetryPolicy].
/// It automatically retries failed operations according to the policy's
/// configuration, using exponential backoff with jitter.
///
/// **Key Features:**
/// - Automatic retry with exponential backoff
/// - Respects [QuotaError.retryAfter] when provided
/// - Tracks and rethrows the last exception if all retries fail
/// - Handles both [Exception] and other error types
///
/// **Example usage:**
/// ```dart
/// final policy = RetryPolicy.defaults();
/// final handler = RetryHandler(policy: policy);
///
/// // Execute an operation with automatic retry
/// final result = await handler.execute(() async {
///   return await someApiCall();
/// });
///
/// // With custom policy
/// final customPolicy = RetryPolicy(
///   maxAttempts: 5,
///   initialDelay: Duration(milliseconds: 200),
/// );
/// final customHandler = RetryHandler(policy: customPolicy);
/// ```
class RetryHandler {
  /// The retry policy to use for determining retry behavior.
  final RetryPolicy policy;

  /// Creates a new [RetryHandler] instance.
  ///
  /// **Parameters:**
  /// - [policy]: The retry policy to use. Required.
  ///
  /// **Example:**
  /// ```dart
  /// final handler = RetryHandler(
  ///   policy: RetryPolicy.defaults(),
  /// );
  /// ```
  RetryHandler({
    required this.policy,
  });

  /// Executes an operation with automatic retry logic.
  ///
  /// This method will:
  /// 1. Execute the operation
  /// 2. If it succeeds, return the result immediately
  /// 3. If it fails, check if the error should be retried
  /// 4. If retryable, wait for the calculated delay (respecting retryAfter)
  /// 5. Retry up to [policy.maxAttempts] times
  /// 6. If all retries fail, throw the last exception
  ///
  /// **Retry Behavior:**
  /// - Uses [RetryPolicy.canRetry] to determine if an error should be retried
  /// - Uses [RetryPolicy.getDelay] for exponential backoff delays
  /// - For [QuotaError] with [retryAfter], waits until that time (or uses
  ///   calculated delay, whichever is longer)
  /// - Non-[Exception] errors are wrapped and checked against the policy
  ///
  /// **Parameters:**
  /// - [operation]: A function that returns a [Future<T>] to execute.
  ///   This function will be called multiple times if retries occur.
  ///
  /// **Returns:**
  /// The result of the operation if it succeeds.
  ///
  /// **Throws:**
  /// The last exception encountered if all retry attempts fail, or the
  /// original exception if it's not retryable.
  ///
  /// **Example:**
  /// ```dart
  /// final handler = RetryHandler(policy: RetryPolicy.defaults());
  ///
  /// try {
  ///   final result = await handler.execute(() async {
  ///     return await apiClient.getData();
  ///   });
  ///   print('Success: $result');
  /// } on AuthError {
  ///   print('Authentication failed - not retried');
  /// } on TransientError {
  ///   print('All retries failed');
  /// }
  /// ```
  Future<T> execute<T>(Future<T> Function() operation) async {
    Exception? lastException;
    int attemptNumber = 0;

    // Try the operation up to maxAttempts times
    while (attemptNumber < policy.maxAttempts) {
      try {
        // Execute the operation
        final result = await operation();
        // Success - return immediately
        return result;
      } catch (error) {
        // Convert error to Exception if needed
        final exception =
            error is Exception ? error : Exception(error.toString());

        lastException = exception;

        // Check if we should retry this error
        // attemptNumber is the current attempt (0-based)
        // For the first failure, attemptNumber=0 means we'll retry (if allowed)
        if (!policy.canRetry(exception, attemptNumber)) {
          // Not retryable or max attempts reached - throw immediately
          throw exception;
        }

        // Calculate delay for next retry
        Duration delay = policy.getDelay(attemptNumber);

        // Special handling for QuotaError with retryAfter
        if (exception is QuotaError && exception.retryAfter != null) {
          final now = DateTime.now();
          final retryAfterTime = exception.retryAfter!;

          // If retryAfter is in the future, use it (or the calculated delay, whichever is longer)
          if (retryAfterTime.isAfter(now)) {
            final retryAfterDelay = retryAfterTime.difference(now);
            // Use the longer of the two delays
            if (retryAfterDelay > delay) {
              delay = retryAfterDelay;
            }
          }
          // If retryAfter is in the past, use the calculated delay
        }

        // Increment attempt number for next iteration
        attemptNumber++;

        // Check if we've reached max attempts
        if (attemptNumber >= policy.maxAttempts) {
          // No more retries - throw the last exception
          throw exception;
        }

        // Wait before retrying
        await Future<void>.delayed(delay);
      }
    }

    // This should never be reached due to the checks above, but Dart
    // requires a return or throw statement
    throw lastException ?? Exception('Retry failed with unknown error');
  }
}
