import '../../retry/rate_limiter.dart';

/// Factory for creating rate limiters for AI providers.
///
/// This factory provides default rate limit configurations for different
/// providers and allows customization via settings. Rate limits help prevent
/// hitting provider API limits and ensure smooth operation.
///
/// **Default Rate Limits:**
/// - OpenAI: 60 requests per minute
/// - Anthropic: 50 requests per minute
/// - Google: 60 requests per minute
/// - Cohere: 100 requests per minute
///
/// **Customization:**
/// Rate limits can be customized via `ProviderConfig.settings`:
/// - `'rateLimiter'`: Provide a custom `RateLimiter` instance
/// - `'rateLimitMaxRequests'`: Maximum requests in the window
/// - `'rateLimitWindow'`: Time window (as `Duration` or milliseconds)
///
/// **Example:**
/// ```dart
/// // Use default rate limiter for OpenAI
/// final limiter = RateLimiterFactory.create('openai', {});
///
/// // Custom rate limiter via settings
/// final customLimiter = RateLimiterFactory.create('openai', {
///   'rateLimitMaxRequests': 100,
///   'rateLimitWindow': Duration(minutes: 1),
/// });
///
/// // Provide custom RateLimiter instance
/// final providedLimiter = RateLimiterFactory.create('openai', {
///   'rateLimiter': RateLimiter(
///     maxRequests: 200,
///     window: Duration(minutes: 1),
///   ),
/// });
/// ```
class RateLimiterFactory {
  /// Default rate limits per provider (requests per minute).
  ///
  /// These are conservative defaults based on typical free/tier-1 API limits.
  /// Higher-tier accounts may have higher limits, which can be configured
  /// via settings.
  static const Map<String, int> _defaultRpm = {
    'openai': 60,
    'anthropic': 50,
    'google': 60,
    'cohere': 100,
    'xai': 60,
  };

  /// Creates a rate limiter for the specified provider.
  ///
  /// **Priority:**
  /// 1. If `settings['rateLimiter']` is a `RateLimiter`, use it directly
  /// 2. If `settings['rateLimitMaxRequests']` and `settings['rateLimitWindow']`
  ///    are provided, create a custom rate limiter
  /// 3. Otherwise, use provider-specific defaults
  ///
  /// **Parameters:**
  /// - [providerId]: The provider ID (e.g., 'openai', 'anthropic')
  /// - [settings]: Provider settings map from `ProviderConfig`
  ///
  /// **Returns:**
  /// A `RateLimiter` instance, or `null` if rate limiting is disabled
  /// (when `settings['rateLimiter']` is explicitly set to `null`).
  ///
  /// **Example:**
  /// ```dart
  /// // Default rate limiter
  /// final limiter = RateLimiterFactory.create('openai', {});
  ///
  /// // Custom rate limiter
  /// final customLimiter = RateLimiterFactory.create('openai', {
  ///   'rateLimitMaxRequests': 100,
  ///   'rateLimitWindow': Duration(minutes: 1),
  /// });
  ///
  /// // Disable rate limiting
  /// final noLimiter = RateLimiterFactory.create('openai', {
  ///   'rateLimiter': null,
  /// });
  /// ```
  static RateLimiter? create(String providerId, Map<String, dynamic> settings) {
    // Check if a custom RateLimiter instance is provided
    final providedLimiter = settings['rateLimiter'];
    if (providedLimiter is RateLimiter) {
      return providedLimiter;
    }
    if (providedLimiter == null && settings.containsKey('rateLimiter')) {
      // Explicitly disabled
      return null;
    }

    // Check for custom rate limit configuration
    final maxRequests = settings['rateLimitMaxRequests'] as int?;
    final window = settings['rateLimitWindow'];

    if (maxRequests != null && window != null) {
      // Custom configuration provided
      Duration windowDuration;
      if (window is Duration) {
        windowDuration = window;
      } else if (window is int) {
        // Assume milliseconds
        windowDuration = Duration(milliseconds: window);
      } else {
        throw ArgumentError(
          'rateLimitWindow must be a Duration or int (milliseconds), got ${window.runtimeType}',
        );
      }

      return RateLimiter(
        maxRequests: maxRequests,
        window: windowDuration,
      );
    }

    // Use provider-specific default
    final defaultRpm = _defaultRpm[providerId.toLowerCase()];
    if (defaultRpm == null) {
      // Unknown provider - no rate limiting by default
      return null;
    }

    return RateLimiter(
      maxRequests: defaultRpm,
      window: const Duration(minutes: 1),
    );
  }
}
