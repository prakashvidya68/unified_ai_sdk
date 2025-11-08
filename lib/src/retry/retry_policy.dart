import 'dart:math';

import '../error/error_types.dart';

/// Policy for retrying failed operations with exponential backoff.
///
/// [RetryPolicy] defines how the SDK should retry failed requests, including:
/// - Maximum number of retry attempts
/// - Initial delay before first retry
/// - Maximum delay cap
/// - Exponential backoff multiplier
/// - Custom retry logic for specific exceptions
///
/// **Default Behavior:**
/// - Retries [TransientError] and [QuotaError] exceptions
/// - Does NOT retry [AuthError], [ClientError], or [CapabilityError]
/// - Uses exponential backoff with jitter
/// - Default: 3 attempts, 100ms initial delay, 30s max delay, 2.0 multiplier
///
/// **Example usage:**
/// ```dart
/// // Default policy
/// final policy = RetryPolicy.defaults();
///
/// // Custom policy
/// final customPolicy = RetryPolicy(
///   maxAttempts: 5,
///   initialDelay: Duration(milliseconds: 200),
///   maxDelay: Duration(seconds: 60),
///   multiplier: 1.5,
/// );
///
/// // Policy with custom retry logic
/// final smartPolicy = RetryPolicy(
///   maxAttempts: 3,
///   shouldRetry: (e) {
///     // Custom logic: retry specific client errors
///     if (e is ClientError && e.code == 'RATE_LIMIT') {
///       return true;
///     }
///     return false;
///   },
/// );
/// ```
class RetryPolicy {
  /// Maximum number of retry attempts (including the initial attempt).
  ///
  /// For example, if [maxAttempts] is 3, the operation will be tried
  /// once initially, then retried up to 2 more times if it fails.
  ///
  /// Must be at least 1. Defaults to 3.
  final int maxAttempts;

  /// Initial delay before the first retry.
  ///
  /// This is the delay after the first failure, before the second attempt.
  /// Subsequent retries will use exponential backoff based on this value.
  ///
  /// Defaults to 100 milliseconds.
  final Duration initialDelay;

  /// Maximum delay cap for exponential backoff.
  ///
  /// Even if exponential backoff would calculate a larger delay, it will
  /// be capped at this value. This prevents extremely long delays.
  ///
  /// Defaults to 30 seconds.
  final Duration maxDelay;

  /// Multiplier for exponential backoff.
  ///
  /// Each retry delay is calculated as: `initialDelay * (multiplier ^ attemptNumber)`
  /// For example, with `initialDelay: 100ms` and `multiplier: 2.0`:
  /// - Attempt 1 (first retry): 100ms
  /// - Attempt 2 (second retry): 200ms
  /// - Attempt 3 (third retry): 400ms
  ///
  /// Must be greater than 0. Defaults to 2.0.
  final double multiplier;

  /// Optional custom function to determine if an exception should be retried.
  ///
  /// If provided, this function is called for every exception to determine
  /// if it should be retried. The function should return `true` to retry,
  /// `false` to not retry.
  ///
  /// If `null`, the default retry logic is used:
  /// - Retries [TransientError] and [QuotaError]
  /// - Does NOT retry [AuthError], [ClientError], or [CapabilityError]
  ///
  /// **Note:** This function is called in addition to the default logic,
  /// not as a replacement. The default logic still applies for error types
  /// not handled by this function.
  ///
  /// **Example:**
  /// ```dart
  /// shouldRetry: (e) {
  ///   // Retry specific client errors
  ///   if (e is ClientError && e.code == 'TEMPORARY_ERROR') {
  ///     return true;
  ///   }
  ///   return false; // Use default logic for other errors
  /// }
  /// ```
  final bool Function(Exception)? shouldRetry;

  /// Creates a new [RetryPolicy] instance.
  ///
  /// **Parameters:**
  /// - [maxAttempts]: Maximum number of retry attempts. Must be >= 1. Defaults to 3.
  /// - [initialDelay]: Initial delay before first retry. Defaults to 100ms.
  /// - [maxDelay]: Maximum delay cap. Defaults to 30 seconds.
  /// - [multiplier]: Exponential backoff multiplier. Must be > 0. Defaults to 2.0.
  /// - [shouldRetry]: Optional custom retry logic function.
  ///
  /// **Throws:**
  /// - [ClientError] if [maxAttempts] < 1
  /// - [ClientError] if [multiplier] <= 0
  /// - [ClientError] if [initialDelay] or [maxDelay] is negative
  ///
  /// **Example:**
  /// ```dart
  /// final policy = RetryPolicy(
  ///   maxAttempts: 5,
  ///   initialDelay: Duration(milliseconds: 200),
  ///   maxDelay: Duration(seconds: 60),
  ///   multiplier: 1.5,
  /// );
  /// ```
  RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.shouldRetry,
  }) {
    // Validate maxAttempts
    if (maxAttempts < 1) {
      throw ClientError(
        message: 'maxAttempts must be at least 1, got $maxAttempts',
        code: 'INVALID_MAX_ATTEMPTS',
      );
    }

    // Validate multiplier
    if (multiplier <= 0) {
      throw ClientError(
        message: 'multiplier must be greater than 0, got $multiplier',
        code: 'INVALID_MULTIPLIER',
      );
    }

    // Validate delays are non-negative
    if (initialDelay.isNegative) {
      throw ClientError(
        message: 'initialDelay cannot be negative',
        code: 'INVALID_INITIAL_DELAY',
      );
    }

    if (maxDelay.isNegative) {
      throw ClientError(
        message: 'maxDelay cannot be negative',
        code: 'INVALID_MAX_DELAY',
      );
    }

    // Validate maxDelay >= initialDelay (logical constraint)
    if (maxDelay < initialDelay) {
      throw ClientError(
        message: 'maxDelay ($maxDelay) must be >= initialDelay ($initialDelay)',
        code: 'INVALID_DELAY_RANGE',
      );
    }
  }

  /// Factory constructor for default retry policy.
  ///
  /// Returns a [RetryPolicy] with sensible defaults:
  /// - maxAttempts: 3
  /// - initialDelay: 100ms
  /// - maxDelay: 30s
  /// - multiplier: 2.0
  /// - shouldRetry: null (uses default logic)
  ///
  /// **Example:**
  /// ```dart
  /// final policy = RetryPolicy.defaults();
  /// ```
  factory RetryPolicy.defaults() {
    return RetryPolicy();
  }

  /// Calculates the delay before the next retry attempt.
  ///
  /// Uses exponential backoff with jitter to prevent thundering herd problems.
  /// The delay is calculated as:
  /// 1. Base delay: `initialDelay * (multiplier ^ attemptNumber)`
  /// 2. Add jitter: random value between 0% and 10% of the base delay
  /// 3. Cap at maxDelay
  ///
  /// **Parameters:**
  /// - [attemptNumber]: The attempt number (0-based). For the first retry,
  ///   this should be 0, for the second retry 1, etc.
  ///
  /// **Returns:**
  /// A [Duration] representing how long to wait before the next retry.
  ///
  /// **Example:**
  /// ```dart
  /// final policy = RetryPolicy(
  ///   initialDelay: Duration(milliseconds: 100),
  ///   multiplier: 2.0,
  /// );
  ///
  /// // First retry (attemptNumber = 0)
  /// final delay1 = policy.getDelay(0); // ~100ms (with jitter)
  ///
  /// // Second retry (attemptNumber = 1)
  /// final delay2 = policy.getDelay(1); // ~200ms (with jitter)
  ///
  /// // Third retry (attemptNumber = 2)
  /// final delay3 = policy.getDelay(2); // ~400ms (with jitter)
  /// ```
  Duration getDelay(int attemptNumber) {
    if (attemptNumber < 0) {
      throw ArgumentError(
        'attemptNumber must be >= 0, got $attemptNumber',
      );
    }

    // Calculate exponential backoff: initialDelay * (multiplier ^ attemptNumber)
    final baseDelayMs =
        initialDelay.inMilliseconds * pow(multiplier, attemptNumber).toInt();

    // Add jitter: random value between 0% and 10% of base delay
    // This helps prevent thundering herd problems when multiple clients
    // retry at the same time
    final jitterRange = (baseDelayMs * 0.1).round();
    final jitter = Random().nextInt(jitterRange + 1);

    // Calculate total delay and cap at maxDelay
    final totalDelayMs = min(
      baseDelayMs + jitter,
      maxDelay.inMilliseconds,
    );

    return Duration(milliseconds: totalDelayMs);
  }

  /// Determines if an exception should be retried.
  ///
  /// This method implements the retry logic by checking:
  /// 1. If the maximum number of attempts has been reached
  /// 2. The type of exception (some errors should never be retried)
  /// 3. Custom retry logic if provided
  ///
  /// **Default Retry Logic:**
  /// - ✅ Retries [TransientError] (network issues, timeouts, 5xx errors)
  /// - ✅ Retries [QuotaError] (rate limits, but respects retryAfter if provided)
  /// - ❌ Does NOT retry [AuthError] (authentication failures)
  /// - ❌ Does NOT retry [ClientError] (invalid requests)
  /// - ❌ Does NOT retry [CapabilityError] (unsupported operations)
  ///
  /// **Parameters:**
  /// - [exception]: The exception that occurred
  /// - [attemptNumber]: The current attempt number (0-based). For the first
  ///   attempt after failure, this is 0, for the second retry it's 1, etc.
  ///
  /// **Returns:**
  /// `true` if the operation should be retried, `false` otherwise.
  ///
  /// **Example:**
  /// ```dart
  /// final policy = RetryPolicy(maxAttempts: 3);
  ///
  /// // First retry attempt (attemptNumber = 0)
  /// if (policy.canRetry(transientError, 0)) {
  ///   // Will retry (attemptNumber 0 < maxAttempts-1 = 2)
  /// }
  ///
  /// // Last retry attempt (attemptNumber = 2)
  /// if (policy.canRetry(transientError, 2)) {
  ///   // Will NOT retry (attemptNumber 2 >= maxAttempts-1 = 2)
  /// }
  /// ```
  bool canRetry(Exception exception, int attemptNumber) {
    if (attemptNumber < 0) {
      throw ArgumentError(
        'attemptNumber must be >= 0, got $attemptNumber',
      );
    }

    // Check if we've exceeded max attempts
    // attemptNumber is 0-based, so we compare with (maxAttempts - 1)
    // For maxAttempts=3: attemptNumber 0,1 are valid, 2 is the last retry
    if (attemptNumber >= maxAttempts - 1) {
      return false;
    }

    // Check custom retry logic first (if provided)
    if (shouldRetry != null) {
      final customResult = shouldRetry!(exception);
      // If custom logic explicitly says to retry, do it
      if (customResult) {
        return true;
      }
      // If custom logic says not to retry, still check default logic
      // (custom logic is additive, not replacement)
    }

    // Default retry logic based on exception type

    // Never retry authentication errors - these won't succeed on retry
    if (exception is AuthError) {
      return false;
    }

    // Never retry client errors - these indicate invalid requests
    if (exception is ClientError) {
      return false;
    }

    // Never retry capability errors - provider doesn't support the operation
    if (exception is CapabilityError) {
      return false;
    }

    // Retry transient errors - these are temporary and may succeed on retry
    if (exception is TransientError) {
      return true;
    }

    // Retry quota errors - rate limits may be temporary
    // Note: The RetryHandler should respect retryAfter if provided
    if (exception is QuotaError) {
      return true;
    }

    // For other exceptions (not AiException), don't retry by default
    // Custom shouldRetry function can override this
    return false;
  }

  /// Creates a copy of this [RetryPolicy] with the given fields replaced.
  ///
  /// Returns a new [RetryPolicy] instance with the same values as this one,
  /// except for the fields explicitly provided.
  ///
  /// **Example:**
  /// ```dart
  /// final basePolicy = RetryPolicy.defaults();
  /// final customPolicy = basePolicy.copyWith(
  ///   maxAttempts: 5,
  ///   initialDelay: Duration(milliseconds: 200),
  /// );
  /// ```
  RetryPolicy copyWith({
    int? maxAttempts,
    Duration? initialDelay,
    Duration? maxDelay,
    double? multiplier,
    bool Function(Exception)? shouldRetry,
    bool clearShouldRetry = false,
  }) {
    return RetryPolicy(
      maxAttempts: maxAttempts ?? this.maxAttempts,
      initialDelay: initialDelay ?? this.initialDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      multiplier: multiplier ?? this.multiplier,
      shouldRetry: clearShouldRetry ? null : (shouldRetry ?? this.shouldRetry),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RetryPolicy &&
        other.maxAttempts == maxAttempts &&
        other.initialDelay == initialDelay &&
        other.maxDelay == maxDelay &&
        other.multiplier == multiplier &&
        // Compare function references (they're the same if identical)
        other.shouldRetry == shouldRetry;
  }

  @override
  int get hashCode {
    return Object.hash(
      maxAttempts,
      initialDelay,
      maxDelay,
      multiplier,
      shouldRetry,
    );
  }

  @override
  String toString() {
    final shouldRetryStr = shouldRetry != null ? 'custom' : 'default';
    return 'RetryPolicy('
        'maxAttempts: $maxAttempts, '
        'initialDelay: $initialDelay, '
        'maxDelay: $maxDelay, '
        'multiplier: $multiplier, '
        'shouldRetry: $shouldRetryStr)';
  }
}
