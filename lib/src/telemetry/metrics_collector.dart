import 'telemetry_handler.dart';

/// Metrics collector implementation of [TelemetryHandler].
///
/// [MetricsCollector] collects performance and usage metrics for each provider,
/// allowing you to monitor SDK usage, performance, and costs in real-time.
///
/// **Key Features:**
/// - **Per-provider metrics**: Separate metrics for each AI provider
/// - **Performance tracking**: Latency, request counts, error rates
/// - **Cost tracking**: Token usage and cache hit rates
/// - **Real-time statistics**: Calculate averages and rates on-demand
/// - **Thread-safe**: Safe for concurrent access
///
/// **Example usage:**
/// ```dart
/// // Create metrics collector
/// final metrics = MetricsCollector();
///
/// // Use in SDK configuration
/// await UnifiedAI.init(UnifiedAIConfig(
///   telemetryHandlers: [metrics],
///   // ... other config
/// ));
///
/// // After some operations, check metrics
/// final openaiMetrics = metrics.getMetrics('openai');
/// print('Total requests: ${openaiMetrics.totalRequests}');
/// print('Average latency: ${openaiMetrics.averageLatency}');
/// print('Cache hit rate: ${openaiMetrics.cacheHitRate}');
/// print('Error rate: ${openaiMetrics.errorRate}');
/// ```
///
/// **Metrics Collected:**
/// - Total requests per provider
/// - Successful responses
/// - Errors and error rates
/// - Cache hits and cache hit rate
/// - Latency statistics (average, min, max)
/// - Token usage (total, average per request)
///
/// **Thread Safety:**
/// This implementation is thread-safe. Multiple threads can safely access
/// metrics concurrently.
///
/// **Error Handling:**
/// This collector never throws exceptions. If an error occurs during metric
/// collection, it is silently ignored to prevent affecting the SDK's operation.
class MetricsCollector implements TelemetryHandler {
  /// Internal storage for provider metrics.
  ///
  /// Maps provider ID to its metrics. Thread-safe access is ensured by
  /// synchronizing all operations.
  final Map<String, ProviderMetrics> _metrics = {};

  /// Maps request IDs to provider IDs for correlating responses with providers.
  ///
  /// This is needed because [ResponseTelemetry] doesn't include provider information.
  /// We track the provider from [RequestTelemetry] and use it when processing responses.
  final Map<String, String> _requestIdToProvider = {};

  /// Gets metrics for a specific provider.
  ///
  /// Returns a [ProviderMetrics] instance for the given provider. If no
  /// metrics exist for the provider, returns an empty metrics instance.
  ///
  /// **Parameters:**
  /// - [provider]: The provider ID (e.g., "openai", "anthropic")
  ///
  /// **Returns:**
  /// - [ProviderMetrics] for the provider, or empty metrics if provider not found
  ///
  /// **Example:**
  /// ```dart
  /// final metrics = collector.getMetrics('openai');
  /// print('Requests: ${metrics.totalRequests}');
  /// print('Avg latency: ${metrics.averageLatency}');
  /// ```
  ProviderMetrics getMetrics(String provider) {
    return _metrics[provider] ?? ProviderMetrics();
  }

  /// Gets all provider IDs that have metrics.
  ///
  /// Returns a list of all provider IDs that have collected at least one metric.
  ///
  /// **Returns:**
  /// - List of provider IDs
  ///
  /// **Example:**
  /// ```dart
  /// final providers = collector.getAllProviders();
  /// for (final provider in providers) {
  ///   final metrics = collector.getMetrics(provider);
  ///   print('$provider: ${metrics.totalRequests} requests');
  /// }
  /// ```
  List<String> getAllProviders() {
    return _metrics.keys.toList();
  }

  /// Gets aggregated metrics across all providers.
  ///
  /// Combines metrics from all providers into a single [ProviderMetrics] instance.
  /// Useful for getting overall SDK statistics.
  ///
  /// **Returns:**
  /// - Combined [ProviderMetrics] for all providers
  ///
  /// **Example:**
  /// ```dart
  /// final allMetrics = collector.getAllMetrics();
  /// print('Total requests across all providers: ${allMetrics.totalRequests}');
  /// ```
  ProviderMetrics getAllMetrics() {
    final combined = ProviderMetrics();
    for (final metrics in _metrics.values) {
      combined._add(metrics);
    }
    return combined;
  }

  /// Clears all metrics for a specific provider.
  ///
  /// Removes all collected metrics for the given provider. Useful for
  /// resetting metrics during testing or when switching providers.
  ///
  /// **Parameters:**
  /// - [provider]: The provider ID to clear metrics for
  ///
  /// **Example:**
  /// ```dart
  /// collector.clearMetrics('openai');
  /// // All metrics for OpenAI are now reset
  /// ```
  void clearMetrics(String provider) {
    _metrics.remove(provider);
  }

  /// Clears all metrics for all providers.
  ///
  /// Removes all collected metrics. Useful for resetting metrics during
  /// testing or when starting a new monitoring period.
  ///
  /// **Example:**
  /// ```dart
  /// collector.clearAll();
  /// // All metrics are now reset
  /// ```
  void clearAll() {
    _metrics.clear();
    _requestIdToProvider.clear();
  }

  @override
  Future<void> onRequest(RequestTelemetry event) async {
    try {
      // Store requestId -> provider mapping for response correlation
      _requestIdToProvider[event.requestId] = event.provider;

      // Increment request count for this provider
      final metrics = _metrics.putIfAbsent(
        event.provider,
        () => ProviderMetrics(),
      );
      metrics._incrementRequestCount();
    } on Object {
      // Silently ignore errors
    }
  }

  @override
  Future<void> onResponse(ResponseTelemetry event) async {
    try {
      // Get provider from requestId mapping
      final provider = _requestIdToProvider[event.requestId];
      if (provider != null) {
        final metrics = _metrics.putIfAbsent(
          provider,
          () => ProviderMetrics(),
        );
        metrics._recordResponse(
          event.latency,
          event.tokensUsed,
          event.cached,
        );
      }
    } on Object {
      // Silently ignore errors
    }
  }

  @override
  Future<void> onError(ErrorTelemetry event) async {
    try {
      if (event.provider != null) {
        final metrics = _metrics.putIfAbsent(
          event.provider!,
          () => ProviderMetrics(),
        );
        metrics._incrementErrorCount();
      }
    } on Object {
      // Silently ignore errors
    }
  }
}

/// Metrics for a specific AI provider.
///
/// [ProviderMetrics] tracks performance and usage statistics for a single
/// provider, including request counts, latencies, errors, and cache performance.
///
/// **Key Metrics:**
/// - Request counts (total, successful, errors)
/// - Latency statistics (average, min, max)
/// - Cache performance (hits, hit rate)
/// - Token usage (total, average)
/// - Error rate
///
/// **Example usage:**
/// ```dart
/// final metrics = collector.getMetrics('openai');
///
/// // Check request counts
/// print('Total requests: ${metrics.totalRequests}');
/// print('Successful: ${metrics.successfulRequests}');
/// print('Errors: ${metrics.errorCount}');
///
/// // Check performance
/// print('Average latency: ${metrics.averageLatency}');
/// print('Min latency: ${metrics.minLatency}');
/// print('Max latency: ${metrics.maxLatency}');
///
/// // Check cache performance
/// print('Cache hits: ${metrics.cacheHits}');
/// print('Cache hit rate: ${metrics.cacheHitRate}%');
///
/// // Check token usage
/// print('Total tokens: ${metrics.totalTokens}');
/// print('Average tokens per request: ${metrics.averageTokensPerRequest}');
/// ```
///
/// **Thread Safety:**
/// This class is not thread-safe by itself. Thread safety is provided by
/// the [MetricsCollector] that manages instances of this class.
class ProviderMetrics {
  /// Total number of requests made to this provider.
  int _totalRequests = 0;

  /// Number of successful responses received.
  int _successfulRequests = 0;

  /// Number of errors encountered.
  int _errorCount = 0;

  /// Number of cache hits (responses served from cache).
  int _cacheHits = 0;

  /// Total number of tokens used across all requests.
  int _totalTokens = 0;

  /// List of latencies for calculating statistics.
  ///
  /// Stored as milliseconds for efficiency. Used to calculate average,
  /// min, and max latency.
  final List<int> _latencies = [];

  /// Gets the total number of requests.
  int get totalRequests => _totalRequests;

  /// Gets the number of successful requests.
  int get successfulRequests => _successfulRequests;

  /// Gets the number of errors.
  int get errorCount => _errorCount;

  /// Gets the number of cache hits.
  int get cacheHits => _cacheHits;

  /// Gets the total number of tokens used.
  int get totalTokens => _totalTokens;

  /// Gets the average latency across all requests.
  ///
  /// Returns the average latency in milliseconds. Returns [Duration.zero]
  /// if no requests have been recorded.
  Duration get averageLatency {
    if (_latencies.isEmpty) {
      return Duration.zero;
    }
    final sum = _latencies.fold<int>(0, (a, b) => a + b);
    return Duration(milliseconds: sum ~/ _latencies.length);
  }

  /// Gets the minimum latency across all requests.
  ///
  /// Returns the minimum latency in milliseconds. Returns [Duration.zero]
  /// if no requests have been recorded.
  Duration get minLatency {
    if (_latencies.isEmpty) {
      return Duration.zero;
    }
    return Duration(milliseconds: _latencies.reduce((a, b) => a < b ? a : b));
  }

  /// Gets the maximum latency across all requests.
  ///
  /// Returns the maximum latency in milliseconds. Returns [Duration.zero]
  /// if no requests have been recorded.
  Duration get maxLatency {
    if (_latencies.isEmpty) {
      return Duration.zero;
    }
    return Duration(milliseconds: _latencies.reduce((a, b) => a > b ? a : b));
  }

  /// Gets the cache hit rate as a percentage.
  ///
  /// Returns the percentage of requests that were served from cache.
  /// Returns 0.0 if no requests have been made.
  ///
  /// **Example:**
  /// ```dart
  /// final rate = metrics.cacheHitRate; // e.g., 45.5 for 45.5%
  /// ```
  double get cacheHitRate {
    if (_successfulRequests == 0) {
      return 0.0;
    }
    return (_cacheHits / _successfulRequests) * 100.0;
  }

  /// Gets the error rate as a percentage.
  ///
  /// Returns the percentage of requests that resulted in errors.
  /// Returns 0.0 if no requests have been made.
  ///
  /// **Example:**
  /// ```dart
  /// final rate = metrics.errorRate; // e.g., 2.5 for 2.5%
  /// ```
  double get errorRate {
    if (_totalRequests == 0) {
      return 0.0;
    }
    return (_errorCount / _totalRequests) * 100.0;
  }

  /// Gets the average number of tokens per request.
  ///
  /// Returns the average tokens used per successful request.
  /// Returns 0 if no successful requests have been made or no token data available.
  double get averageTokensPerRequest {
    if (_successfulRequests == 0 || _totalTokens == 0) {
      return 0.0;
    }
    return _totalTokens / _successfulRequests;
  }

  /// Gets the number of latency samples recorded.
  ///
  /// Useful for understanding the sample size of latency calculations.
  int get latencySampleCount => _latencies.length;

  /// Internal method to increment request count.
  void _incrementRequestCount() {
    _totalRequests++;
  }

  /// Internal method to record a successful response.
  void _recordResponse(Duration latency, int? tokensUsed, bool cached) {
    _successfulRequests++;
    _latencies.add(latency.inMilliseconds);

    if (tokensUsed != null) {
      _totalTokens += tokensUsed;
    }

    if (cached) {
      _cacheHits++;
    }
  }

  /// Internal method to increment error count.
  void _incrementErrorCount() {
    _errorCount++;
  }

  /// Internal method to add metrics from another instance.
  ///
  /// Used for combining metrics from multiple providers.
  void _add(ProviderMetrics other) {
    _totalRequests += other._totalRequests;
    _successfulRequests += other._successfulRequests;
    _errorCount += other._errorCount;
    _cacheHits += other._cacheHits;
    _totalTokens += other._totalTokens;
    _latencies.addAll(other._latencies);
  }

  /// Converts this [ProviderMetrics] to a JSON map.
  ///
  /// Useful for serialization, logging, or sending to analytics services.
  Map<String, dynamic> toJson() {
    return {
      'totalRequests': _totalRequests,
      'successfulRequests': _successfulRequests,
      'errorCount': _errorCount,
      'cacheHits': _cacheHits,
      'totalTokens': _totalTokens,
      'averageLatency': averageLatency.inMilliseconds,
      'minLatency': minLatency.inMilliseconds,
      'maxLatency': maxLatency.inMilliseconds,
      'cacheHitRate': cacheHitRate,
      'errorRate': errorRate,
      'averageTokensPerRequest': averageTokensPerRequest,
      'latencySampleCount': latencySampleCount,
    };
  }

  @override
  String toString() {
    return 'ProviderMetrics('
        'requests: $_totalRequests, '
        'successful: $_successfulRequests, '
        'errors: $_errorCount, '
        'cacheHits: $_cacheHits, '
        'avgLatency: ${averageLatency.inMilliseconds}ms, '
        'cacheHitRate: ${cacheHitRate.toStringAsFixed(1)}%, '
        'errorRate: ${errorRate.toStringAsFixed(1)}%'
        ')';
  }
}
