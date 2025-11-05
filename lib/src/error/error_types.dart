import 'ai_exception.dart';

/// Exception thrown for transient/retryable errors.
///
/// These are errors that are typically temporary and may succeed if retried.
/// Common causes include:
/// - Network timeouts or connection issues
/// - Provider server errors (HTTP 5xx)
/// - Temporary service unavailability
///
/// **Example usage:**
/// ```dart
/// throw TransientError(
///   message: 'Request timed out',
///   code: 'TIMEOUT',
///   provider: 'openai',
/// );
/// ```
///
/// Retry logic should typically retry these errors with exponential backoff.
class TransientError extends AiException {
  /// Creates a new [TransientError] instance.
  ///
  /// [message] is required. All other fields are optional.
  TransientError({
    required super.message,
    super.code,
    super.provider,
    super.providerError,
    super.requestId,
  }) : super();
}

/// Exception thrown when rate limits or quotas are exceeded.
///
/// This exception is thrown when:
/// - Rate limit is exceeded (HTTP 429)
/// - API quota is exhausted
/// - Too many requests in a time window
///
/// **Example usage:**
/// ```dart
/// throw QuotaError(
///   message: 'Rate limit exceeded',
///   code: 'RATE_LIMIT',
///   provider: 'openai',
///   retryAfter: DateTime.now().add(Duration(seconds: 60)),
/// );
/// ```
///
/// The [retryAfter] field indicates when it's safe to retry the request.
/// If null, the caller should implement their own backoff strategy.
class QuotaError extends AiException {
  /// Optional timestamp indicating when it's safe to retry the request.
  ///
  /// This is typically parsed from the `Retry-After` HTTP header.
  /// If provided, callers should wait until this time before retrying.
  /// If null, implement a custom backoff strategy.
  final DateTime? retryAfter;

  /// Creates a new [QuotaError] instance.
  ///
  /// [message] is required. [retryAfter] and all other fields are optional.
  QuotaError({
    required super.message,
    super.code,
    super.provider,
    super.providerError,
    super.requestId,
    this.retryAfter,
  }) : super();

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (retryAfter != null) {
      json['retryAfter'] = retryAfter!.toIso8601String();
    }
    return json;
  }

  @override
  String toString() {
    final base = super.toString();
    if (retryAfter != null) {
      return '$base (retryAfter: ${retryAfter!.toIso8601String()})';
    }
    return base;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuotaError &&
        super == other &&
        other.retryAfter == retryAfter;
  }

  @override
  int get hashCode {
    return Object.hash(super.hashCode, retryAfter);
  }
}

/// Exception thrown for authentication and authorization failures.
///
/// This exception is thrown when:
/// - Invalid or missing API key (HTTP 401)
/// - Insufficient permissions (HTTP 403)
/// - Authentication token expired
/// - Invalid credentials
///
/// **Example usage:**
/// ```dart
/// throw AuthError(
///   message: 'Invalid API key',
///   code: 'INVALID_API_KEY',
///   provider: 'openai',
/// );
/// ```
///
/// These errors should NOT be retried - the authentication issue must be
/// resolved before making new requests.
class AuthError extends AiException {
  /// Creates a new [AuthError] instance.
  ///
  /// [message] is required. All other fields are optional.
  AuthError({
    required super.message,
    super.code,
    super.provider,
    super.providerError,
    super.requestId,
  }) : super();
}

/// Exception thrown for client-side errors (invalid requests).
///
/// This exception is thrown when:
/// - Invalid request parameters (HTTP 400)
/// - Request validation failures
/// - Malformed request data
/// - Resource not found (HTTP 404)
/// - Request conflicts (HTTP 409)
///
/// **Example usage:**
/// ```dart
/// throw ClientError(
///   message: 'Invalid model specified',
///   code: 'INVALID_MODEL',
///   provider: 'openai',
/// );
/// ```
///
/// These errors indicate a problem with the request itself and should NOT
/// be retried without fixing the request.
class ClientError extends AiException {
  /// Creates a new [ClientError] instance.
  ///
  /// [message] is required. All other fields are optional.
  ClientError({
    required super.message,
    super.code,
    super.provider,
    super.providerError,
    super.requestId,
  }) : super();
}

/// Exception thrown when a provider doesn't support a requested operation.
///
/// This exception is thrown when:
/// - Provider doesn't support the requested capability
/// - Feature is not available for the selected provider
/// - Operation is not implemented by the provider
///
/// **Example usage:**
/// ```dart
/// throw CapabilityError(
///   message: 'Provider does not support streaming',
///   code: 'STREAMING_NOT_SUPPORTED',
///   provider: 'cohere',
/// );
/// ```
///
/// This error indicates that the provider cannot perform the requested
/// operation, and retrying will not help. The caller should either use
/// a different provider or adjust their request.
class CapabilityError extends AiException {
  /// Creates a new [CapabilityError] instance.
  ///
  /// [message] is required. All other fields are optional.
  CapabilityError({
    required super.message,
    super.code,
    super.provider,
    super.providerError,
    super.requestId,
  }) : super();
}
