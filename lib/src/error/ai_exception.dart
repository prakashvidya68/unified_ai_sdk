/// Base exception class for all AI SDK errors.
///
/// This abstract class provides a common structure for all exceptions thrown
/// by the Unified AI SDK. It captures essential error information including
/// the error message, optional error code, provider information, and the
/// original provider error for debugging purposes.
///
/// **Example usage:**
/// ```dart
/// throw AiException(
///   message: 'Failed to connect to provider',
///   code: 'CONNECTION_ERROR',
///   provider: 'openai',
///   requestId: 'req-123',
/// );
/// ```
///
/// Specific exception types (like [TransientError], [AuthError], etc.) extend
/// this class to provide more context and allow for better error handling.
abstract class AiException implements Exception {
  /// Human-readable error message describing what went wrong.
  ///
  /// This is the primary error message that should be displayed to users
  /// or logged. It should be clear and actionable when possible.
  final String message;

  /// Optional error code identifying the type of error.
  ///
  /// Provides a machine-readable identifier for the error type. Common codes:
  /// - `CONNECTION_ERROR` - Network/connection issues
  /// - `AUTH_ERROR` - Authentication failures
  /// - `RATE_LIMIT` - Rate limiting errors
  /// - `SERVER_ERROR` - Provider server errors
  /// - `VALIDATION_ERROR` - Request validation errors
  final String? code;

  /// Optional identifier of the AI provider that generated this error.
  ///
  /// Useful for debugging and logging to identify which provider's API
  /// returned the error. Examples: "openai", "anthropic", "google"
  final String? provider;

  /// Optional original error object from the provider.
  ///
  /// Contains the raw error response or exception from the provider's API.
  /// This can be useful for debugging provider-specific issues. The type
  /// is dynamic to accommodate different provider error formats.
  final dynamic providerError;

  /// Optional request identifier for correlating errors with requests.
  ///
  /// If the provider returns a request ID, it should be captured here.
  /// This allows for easier debugging by correlating errors with specific
  /// API requests in provider logs.
  final String? requestId;

  /// Creates a new [AiException] instance.
  ///
  /// [message] is required. All other fields are optional but provide
  /// valuable context for debugging and error handling.
  AiException({
    required this.message,
    this.code,
    this.provider,
    this.providerError,
    this.requestId,
  }) : assert(message.isNotEmpty, 'message must not be empty');

  /// Returns a string representation of this exception.
  ///
  /// The format includes the exception type name, message, and optionally
  /// the code and provider if they are present.
  ///
  /// **Example output:**
  /// ```
  /// AiException: Failed to connect to provider (code: CONNECTION_ERROR, provider: openai)
  /// ```
  @override
  String toString() {
    final parts = <String>[message];

    if (code != null) {
      parts.add('code: $code');
    }

    if (provider != null) {
      parts.add('provider: $provider');
    }

    if (requestId != null) {
      parts.add('requestId: $requestId');
    }

    final details = parts.length > 1 ? ' (${parts.skip(1).join(', ')})' : '';

    return '${runtimeType}: $message$details';
  }

  /// Returns a JSON-serializable representation of this exception.
  ///
  /// Useful for logging, telemetry, or error reporting systems that need
  /// structured error data.
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "message": "Failed to connect",
  ///   "code": "CONNECTION_ERROR",
  ///   "provider": "openai",
  ///   "requestId": "req-123"
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'type': runtimeType.toString(),
      'message': message,
      if (code != null) 'code': code,
      if (provider != null) 'provider': provider,
      if (requestId != null) 'requestId': requestId,
      if (providerError != null) 'providerError': providerError,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiException &&
        other.runtimeType == runtimeType &&
        other.message == message &&
        other.code == code &&
        other.provider == provider &&
        other.requestId == requestId &&
        other.providerError == providerError;
  }

  @override
  int get hashCode {
    return Object.hash(
        runtimeType, message, code, provider, requestId, providerError);
  }
}
