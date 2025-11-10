import '../error/ai_exception.dart';

/// Abstract interface for telemetry handlers in the Unified AI SDK.
///
/// [TelemetryHandler] provides a pluggable system for observing and monitoring
/// SDK operations. Implementations can log events, collect metrics, send data
/// to analytics services, or perform any other observability tasks.
///
/// **Key Features:**
/// - **Request tracking**: Monitor when requests start
/// - **Response tracking**: Track successful responses with latency and usage
/// - **Error tracking**: Capture and analyze errors
/// - **Pluggable design**: Easy to integrate with logging, analytics, or monitoring services
///
/// **Example implementations:**
/// - [ConsoleLogger]: Logs events to console for debugging
/// - [MetricsCollector]: Collects performance metrics and statistics
/// - Custom handlers: Integrate with Sentry, Firebase Analytics, Datadog, etc.
///
/// **Example usage:**
/// ```dart
/// // Create a custom telemetry handler
/// class CustomTelemetryHandler implements TelemetryHandler {
///   @override
///   Future<void> onRequest(RequestTelemetry event) async {
///     // Send to analytics service
///     await analytics.track('ai_request', {
///       'provider': event.provider,
///       'operation': event.operation,
///     });
///   }
///
///   @override
///   Future<void> onResponse(ResponseTelemetry event) async {
///     // Track performance metrics
///     await metrics.recordLatency(event.latency);
///   }
///
///   @override
///   Future<void> onError(ErrorTelemetry event) async {
///     // Report errors to error tracking service
///     await errorTracker.report(event.error);
///   }
/// }
///
/// // Use in SDK configuration
/// await UnifiedAI.init(UnifiedAIConfig(
///   telemetryHandlers: [CustomTelemetryHandler()],
///   // ... other config
/// ));
/// ```
///
/// **Thread Safety:**
/// Implementations should be thread-safe if used in multi-threaded environments.
/// The SDK may call telemetry methods from different threads or isolates.
///
/// **Error Handling:**
/// Telemetry handlers should not throw exceptions. If an error occurs in a
/// handler, it should be logged internally and not propagate to the SDK.
/// The SDK will catch and ignore any exceptions thrown by telemetry handlers
/// to ensure they don't affect application functionality.
abstract class TelemetryHandler {
  /// Called when a new request is initiated.
  ///
  /// This method is invoked at the start of any SDK operation (chat, embed,
  /// image generation, etc.) before the actual API call is made.
  ///
  /// **Use cases:**
  /// - Log request initiation
  /// - Track request counts per provider/operation
  /// - Start performance timers
  /// - Send analytics events
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<void> onRequest(RequestTelemetry event) async {
  ///   print('[${event.timestamp}] Starting ${event.operation} with ${event.provider}');
  ///   await analytics.track('request_started', {
  ///     'request_id': event.requestId,
  ///     'provider': event.provider,
  ///     'operation': event.operation,
  ///   });
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: The request telemetry event containing request details
  ///
  /// **Note:** This method should not throw exceptions. Any errors should be
  /// handled internally to prevent affecting the SDK's operation.
  Future<void> onRequest(RequestTelemetry event);

  /// Called when a request completes successfully.
  ///
  /// This method is invoked after a successful API response is received,
  /// providing information about the response including latency, token usage,
  /// and whether the response was served from cache.
  ///
  /// **Use cases:**
  /// - Track response times and latency
  /// - Monitor token usage and costs
  /// - Calculate cache hit rates
  /// - Send success metrics to analytics
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<void> onResponse(ResponseTelemetry event) async {
  ///   print('Request ${event.requestId} completed in ${event.latency}');
  ///   await metrics.recordLatency(event.latency);
  ///   if (event.cached) {
  ///     await metrics.incrementCacheHits();
  ///   }
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: The response telemetry event containing response details
  ///
  /// **Note:** This method should not throw exceptions. Any errors should be
  /// handled internally to prevent affecting the SDK's operation.
  Future<void> onResponse(ResponseTelemetry event);

  /// Called when a request fails with an error.
  ///
  /// This method is invoked when an exception occurs during an SDK operation,
  /// providing information about the error including the exception type, message,
  /// and context.
  ///
  /// **Use cases:**
  /// - Log errors for debugging
  /// - Track error rates by provider/operation
  /// - Send errors to error tracking services (Sentry, Crashlytics, etc.)
  /// - Alert on critical errors
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<void> onError(ErrorTelemetry event) async {
  ///   print('Error in request ${event.requestId}: ${event.error}');
  ///   await errorTracker.report(
  ///     event.error,
  ///     context: {
  ///       'request_id': event.requestId,
  ///       'provider': event.provider,
  ///       'operation': event.operation,
  ///     },
  ///   );
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [event]: The error telemetry event containing error details
  ///
  /// **Note:** This method should not throw exceptions. Any errors should be
  /// handled internally to prevent affecting the SDK's operation.
  Future<void> onError(ErrorTelemetry event);
}

/// Telemetry event representing the start of a request.
///
/// Contains information about a request before it is sent to the provider,
/// including the request ID, provider, operation type, and timestamp.
///
/// **Example:**
/// ```dart
/// final event = RequestTelemetry(
///   requestId: 'req-123',
///   provider: 'openai',
///   operation: 'chat',
///   timestamp: DateTime.now(),
///   metadata: {'model': 'gpt-4'},
/// );
/// ```
class RequestTelemetry {
  /// Unique identifier for this request.
  ///
  /// Used to correlate request, response, and error events. Generated by
  /// the SDK for each operation.
  final String requestId;

  /// The AI provider handling this request.
  ///
  /// Examples: "openai", "anthropic", "google", "cohere"
  final String provider;

  /// The type of operation being performed.
  ///
  /// Examples: "chat", "embed", "image", "tts", "stt"
  final String operation;

  /// Timestamp when the request was initiated.
  ///
  /// Used for latency calculations and chronological ordering of events.
  final DateTime timestamp;

  /// Optional additional metadata about the request.
  ///
  /// Can include model name, request parameters, or other contextual information.
  /// Useful for filtering and analysis in telemetry systems.
  final Map<String, dynamic>? metadata;

  /// Creates a new [RequestTelemetry] instance.
  ///
  /// **Parameters:**
  /// - [requestId]: Unique identifier for this request. Required.
  /// - [provider]: The AI provider handling this request. Required.
  /// - [operation]: The type of operation. Required.
  /// - [timestamp]: When the request was initiated. Defaults to current time.
  /// - [metadata]: Optional additional metadata.
  RequestTelemetry({
    required this.requestId,
    required this.provider,
    required this.operation,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Converts this [RequestTelemetry] to a JSON map.
  ///
  /// Useful for serialization, logging, or sending to analytics services.
  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'provider': provider,
      'operation': operation,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'RequestTelemetry(requestId: $requestId, provider: $provider, operation: $operation, timestamp: $timestamp)';
  }
}

/// Telemetry event representing a successful response.
///
/// Contains information about a completed request including latency, token
/// usage, and whether the response was served from cache.
///
/// **Example:**
/// ```dart
/// final event = ResponseTelemetry(
///   requestId: 'req-123',
///   latency: Duration(milliseconds: 1500),
///   tokensUsed: 250,
///   cached: false,
/// );
/// ```
class ResponseTelemetry {
  /// Unique identifier for the request that generated this response.
  ///
  /// Matches the [RequestTelemetry.requestId] from the corresponding request.
  final String requestId;

  /// Time taken to complete the request.
  ///
  /// Measured from request initiation to response receipt. Includes network
  /// latency and provider processing time.
  final Duration latency;

  /// Number of tokens used in this request/response.
  ///
  /// Includes both prompt tokens (input) and completion tokens (output).
  /// Useful for cost tracking and usage monitoring.
  final int? tokensUsed;

  /// Whether this response was served from cache.
  ///
  /// `true` if the response was retrieved from cache without making an API call.
  /// `false` if a new API call was made to the provider.
  final bool cached;

  /// Optional additional metadata about the response.
  ///
  /// Can include model name, finish reason, or other response details.
  final Map<String, dynamic>? metadata;

  /// Creates a new [ResponseTelemetry] instance.
  ///
  /// **Parameters:**
  /// - [requestId]: Unique identifier matching the request. Required.
  /// - [latency]: Time taken to complete the request. Required.
  /// - [tokensUsed]: Number of tokens used. Optional.
  /// - [cached]: Whether response was from cache. Defaults to false.
  /// - [metadata]: Optional additional metadata.
  const ResponseTelemetry({
    required this.requestId,
    required this.latency,
    this.tokensUsed,
    this.cached = false,
    this.metadata,
  });

  /// Converts this [ResponseTelemetry] to a JSON map.
  ///
  /// Useful for serialization, logging, or sending to analytics services.
  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'latency': latency.inMilliseconds,
      if (tokensUsed != null) 'tokensUsed': tokensUsed,
      'cached': cached,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'ResponseTelemetry(requestId: $requestId, latency: ${latency.inMilliseconds}ms, tokensUsed: $tokensUsed, cached: $cached)';
  }
}

/// Telemetry event representing a request error.
///
/// Contains information about an error that occurred during an SDK operation,
/// including the exception, provider, operation, and timestamp.
///
/// **Example:**
/// ```dart
/// final event = ErrorTelemetry(
///   requestId: 'req-123',
///   provider: 'openai',
///   operation: 'chat',
///   error: AuthError(message: 'Invalid API key'),
///   timestamp: DateTime.now(),
/// );
/// ```
class ErrorTelemetry {
  /// Unique identifier for the request that generated this error.
  ///
  /// Matches the [RequestTelemetry.requestId] from the corresponding request.
  final String requestId;

  /// The AI provider where the error occurred.
  ///
  /// Examples: "openai", "anthropic", "google", "cohere"
  final String? provider;

  /// The type of operation that failed.
  ///
  /// Examples: "chat", "embed", "image", "tts", "stt"
  final String? operation;

  /// The exception that was thrown.
  ///
  /// Typically an [AiException] or one of its subclasses, but can be any
  /// exception type for maximum flexibility.
  final Object error;

  /// Timestamp when the error occurred.
  ///
  /// Used for chronological ordering and time-based analysis of errors.
  final DateTime timestamp;

  /// Optional additional metadata about the error.
  ///
  /// Can include retry attempts, request details, or other contextual information.
  final Map<String, dynamic>? metadata;

  /// Creates a new [ErrorTelemetry] instance.
  ///
  /// **Parameters:**
  /// - [requestId]: Unique identifier matching the request. Required.
  /// - [error]: The exception that was thrown. Required.
  /// - [provider]: The AI provider where the error occurred. Optional.
  /// - [operation]: The type of operation that failed. Optional.
  /// - [timestamp]: When the error occurred. Defaults to current time.
  /// - [metadata]: Optional additional metadata.
  ErrorTelemetry({
    required this.requestId,
    required this.error,
    this.provider,
    this.operation,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Converts this [ErrorTelemetry] to a JSON map.
  ///
  /// Useful for serialization, logging, or sending to error tracking services.
  /// The error is converted to a string representation for JSON compatibility.
  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      if (provider != null) 'provider': provider,
      if (operation != null) 'operation': operation,
      'error': error.toString(),
      'errorType': error.runtimeType.toString(),
      if (error is AiException) 'errorCode': (error as AiException).code,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'ErrorTelemetry(requestId: $requestId, provider: $provider, operation: $operation, error: $error, timestamp: $timestamp)';
  }
}
