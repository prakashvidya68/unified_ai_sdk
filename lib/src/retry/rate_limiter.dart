import 'dart:async';
import 'dart:math';

import '../error/error_types.dart';

/// Rate limiter using the token bucket algorithm.
///
/// [RateLimiter] controls the rate at which operations can be performed by
/// limiting the number of requests that can be made within a time window.
/// This helps prevent hitting provider rate limits and ensures smooth
/// operation of the SDK.
///
/// **Token Bucket Algorithm:**
/// - The bucket has a maximum capacity ([maxRequests])
/// - Tokens are added to the bucket at a constant rate (based on [window])
/// - When [acquire] is called, it attempts to consume a token
/// - If tokens are available, the request proceeds immediately
/// - If no tokens are available, the request waits until a token is available
///
/// **Key Features:**
/// - **Thread-safe**: Safe to use from multiple concurrent operations
/// - **Fair queuing**: Requests are served in order (FIFO)
/// - **Automatic refill**: Tokens are refilled continuously based on time window
/// - **Configurable**: Adjustable rate limits per provider or operation
///
/// **Example usage:**
/// ```dart
/// // Create a rate limiter: 10 requests per second
/// final limiter = RateLimiter(
///   maxRequests: 10,
///   window: Duration(seconds: 1),
/// );
///
/// // Acquire a token before making a request
/// await limiter.acquire();
/// await makeApiCall();
///
/// // Or wrap operations
/// await limiter.acquire();
/// final response = await httpClient.get(url);
/// ```
///
/// **Rate Limit Examples:**
/// ```dart
/// // OpenAI: 60 requests per minute
/// final openaiLimiter = RateLimiter(
///   maxRequests: 60,
///   window: Duration(minutes: 1),
/// );
///
/// // Anthropic: 50 requests per minute
/// final anthropicLimiter = RateLimiter(
///   maxRequests: 50,
///   window: Duration(minutes: 1),
/// );
///
/// // Per-second rate limiting
/// final perSecondLimiter = RateLimiter(
///   maxRequests: 5,
///   window: Duration(seconds: 1),
/// );
/// ```
class RateLimiter {
  /// Maximum number of requests allowed in the time window.
  ///
  /// This is the bucket capacity - the maximum number of tokens that can
  /// be stored. Once this many tokens are consumed, requests must wait
  /// until tokens are refilled.
  ///
  /// Must be greater than 0.
  final int maxRequests;

  /// Time window for rate limiting.
  ///
  /// This determines how quickly tokens are refilled. The refill rate is
  /// calculated as: `maxRequests / window`. For example:
  /// - `maxRequests: 60, window: Duration(minutes: 1)` = 1 request per second
  /// - `maxRequests: 10, window: Duration(seconds: 1)` = 10 requests per second
  ///
  /// Must be greater than Duration.zero.
  final Duration window;

  /// Current number of available tokens in the bucket.
  ///
  /// This is updated as tokens are consumed and refilled.
  double _tokens;

  /// Timestamp of the last token refill.
  ///
  /// Used to calculate how many tokens should be added based on elapsed time.
  DateTime _lastRefill;

  /// Queue of pending requests waiting for tokens.
  ///
  /// When tokens are not available, requests are queued here and processed
  /// in FIFO order when tokens become available.
  final List<Completer<void>> _waitQueue = [];

  /// Timer for processing the wait queue.
  ///
  /// Used to schedule queue processing when tokens become available.
  Timer? _queueTimer;

  /// Creates a new [RateLimiter] instance.
  ///
  /// **Parameters:**
  /// - [maxRequests]: Maximum number of requests allowed in the time window.
  ///   Must be greater than 0.
  /// - [window]: Time window for rate limiting. Must be greater than Duration.zero.
  ///
  /// **Throws:**
  /// - [ClientError] if [maxRequests] <= 0
  /// - [ClientError] if [window] <= Duration.zero
  ///
  /// **Example:**
  /// ```dart
  /// // 10 requests per second
  /// final limiter = RateLimiter(
  ///   maxRequests: 10,
  ///   window: Duration(seconds: 1),
  /// );
  ///
  /// // 60 requests per minute
  /// final limiter2 = RateLimiter(
  ///   maxRequests: 60,
  ///   window: Duration(minutes: 1),
  /// );
  /// ```
  RateLimiter({
    required this.maxRequests,
    required this.window,
  })  : _tokens = maxRequests.toDouble(),
        _lastRefill = DateTime.now() {
    // Validate maxRequests
    if (maxRequests <= 0) {
      throw ClientError(
        message: 'maxRequests must be greater than 0, got $maxRequests',
        code: 'INVALID_MAX_REQUESTS',
      );
    }

    // Validate window
    if (window <= Duration.zero) {
      throw ClientError(
        message: 'window must be greater than Duration.zero, got $window',
        code: 'INVALID_WINDOW',
      );
    }
  }

  /// Acquires a token from the rate limiter.
  ///
  /// This method blocks until a token is available. If tokens are available
  /// immediately, the method returns right away. If no tokens are available,
  /// the method waits until tokens are refilled and then returns.
  ///
  /// **Token Refill:**
  /// Tokens are refilled continuously based on elapsed time since the last
  /// refill. The refill rate is `maxRequests / window`. For example:
  /// - If `maxRequests: 10` and `window: 1 second`, tokens refill at 10/second
  /// - If `maxRequests: 60` and `window: 1 minute`, tokens refill at 1/second
  ///
  /// **Concurrency:**
  /// This method is safe to call concurrently from multiple async operations.
  /// Requests are queued and processed in FIFO order.
  ///
  /// **Returns:**
  /// A [Future] that completes when a token has been acquired.
  ///
  /// **Example:**
  /// ```dart
  /// final limiter = RateLimiter(
  ///   maxRequests: 10,
  ///   window: Duration(seconds: 1),
  /// );
  ///
  /// // Acquire token before making request
  /// await limiter.acquire();
  /// final response = await httpClient.get(url);
  ///
  /// // Multiple concurrent requests
  /// await Future.wait([
  ///   limiter.acquire().then((_) => makeRequest1()),
  ///   limiter.acquire().then((_) => makeRequest2()),
  ///   limiter.acquire().then((_) => makeRequest3()),
  /// ]);
  /// ```
  Future<void> acquire() async {
    // Refill tokens based on elapsed time
    _refillTokens();

    // Check if tokens are available
    if (_tokens >= 1.0) {
      // Token available - consume it immediately
      _tokens -= 1.0;
      return;
    }

    // No tokens available - queue the request
    final completer = Completer<void>();
    _waitQueue.add(completer);

    // Schedule queue processing if not already scheduled
    _scheduleQueueProcessing();

    // Wait for token to become available
    await completer.future;
  }

  /// Schedules queue processing when tokens become available.
  ///
  /// This method calculates when the next token will be available and
  /// schedules a timer to process the wait queue at that time.
  void _scheduleQueueProcessing() {
    // Don't schedule if already scheduled or queue is empty
    if (_queueTimer != null || _waitQueue.isEmpty) {
      return;
    }

    // Calculate when the next token will be available
    final tokensNeeded = 1.0 - _tokens;
    final refillRate = maxRequests / window.inMilliseconds;
    final waitTimeMs = (tokensNeeded / refillRate).ceil();
    final waitDuration = Duration(milliseconds: max(waitTimeMs, 1));

    // Schedule token refill and queue processing
    _queueTimer = Timer(waitDuration, () {
      _queueTimer = null;
      _processWaitQueue();
    });
  }

  /// Refills tokens based on elapsed time since last refill.
  ///
  /// This method calculates how many tokens should be added based on the
  /// time that has passed and the refill rate. Tokens are capped at [maxRequests].
  void _refillTokens() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefill);

    if (elapsed <= Duration.zero) {
      return; // No time has passed
    }

    // Calculate refill rate: tokens per millisecond
    final refillRate = maxRequests / window.inMilliseconds;

    // Calculate tokens to add based on elapsed time
    final tokensToAdd = elapsed.inMilliseconds * refillRate;

    // Add tokens (capped at maxRequests)
    _tokens = (_tokens + tokensToAdd).clamp(0.0, maxRequests.toDouble());
    _lastRefill = now;
  }

  /// Processes the wait queue, granting tokens to waiting requests.
  ///
  /// This method is called when tokens become available. It refills tokens,
  /// then grants tokens to queued requests in FIFO order until tokens are
  /// exhausted or the queue is empty.
  void _processWaitQueue() {
    // Refill tokens first
    _refillTokens();

    // Process queue while tokens are available
    while (_waitQueue.isNotEmpty && _tokens >= 1.0) {
      // Remove and complete the first waiting request
      final completer = _waitQueue.removeAt(0);
      _tokens -= 1.0;
      completer.complete();
    }

    // If there are still requests waiting, schedule another refill
    if (_waitQueue.isNotEmpty) {
      _scheduleQueueProcessing();
    }
  }

  /// Gets the current number of available tokens.
  ///
  /// This is a snapshot at the time of the call. Tokens are continuously
  /// refilled, so this value may change immediately after the call.
  ///
  /// **Returns:**
  /// The number of available tokens (may be fractional due to continuous refill).
  double get availableTokens {
    _refillTokens();
    return _tokens;
  }

  /// Gets the number of requests currently waiting for tokens.
  ///
  /// **Returns:**
  /// The number of requests in the wait queue.
  int get waitingRequests => _waitQueue.length;

  /// Resets the rate limiter to its initial state.
  ///
  /// This refills the bucket to full capacity and clears the wait queue.
  /// Useful for testing or when rate limits need to be reset.
  ///
  /// **Note:** This method should be used with caution in production, as it
  /// can cause a burst of requests if called while requests are queued.
  void reset() {
    _tokens = maxRequests.toDouble();
    _lastRefill = DateTime.now();
    _waitQueue.clear();
    _queueTimer?.cancel();
    _queueTimer = null;
  }

  @override
  String toString() {
    return 'RateLimiter(maxRequests: $maxRequests, window: $window, '
        'availableTokens: ${availableTokens.toStringAsFixed(2)}, '
        'waitingRequests: $waitingRequests)';
  }
}
