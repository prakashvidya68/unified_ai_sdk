import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai_exception.dart';
import 'error_types.dart';

/// Maps HTTP responses and generic exceptions to specific [AiException] types.
///
/// This utility class provides centralized error mapping logic to convert
/// provider API errors and network exceptions into typed exceptions that
/// can be handled appropriately by retry logic and error handlers.
///
/// **Example usage:**
/// ```dart
/// try {
///   final response = await http.get(uri);
///   if (response.statusCode >= 400) {
///     throw ErrorMapper.mapHttpError(response, 'openai');
///   }
/// } catch (e) {
///   throw ErrorMapper.mapException(e, 'openai');
/// }
/// ```
class ErrorMapper {
  /// Maps an HTTP response to an appropriate [AiException] type.
  ///
  /// Maps HTTP status codes to exception types:
  /// - **429 (Too Many Requests)** → [QuotaError] with parsed `retryAfter`
  /// - **401, 403 (Unauthorized/Forbidden)** → [AuthError]
  /// - **5xx (Server Errors)** → [TransientError] (retryable)
  /// - **4xx (Client Errors)** → [ClientError]
  ///
  /// Attempts to parse error messages from the response body. If the response
  /// contains JSON with an `error` object, it extracts the message and type.
  /// Falls back to using the response body as the message if parsing fails.
  ///
  /// **Parameters:**
  /// - [response]: The HTTP response object
  /// - [provider]: The identifier of the AI provider (e.g., 'openai', 'anthropic')
  ///
  /// **Returns:**
  /// An [AiException] instance appropriate for the HTTP status code.
  ///
  /// **Example:**
  /// ```dart
  /// final response = http.Response('{"error": {"message": "Rate limit exceeded"}}', 429);
  /// final error = ErrorMapper.mapHttpError(response, 'openai');
  /// // Returns QuotaError with message "Rate limit exceeded"
  /// ```
  static AiException mapHttpError(http.Response response, String provider) {
    final statusCode = response.statusCode;
    final headers = response.headers;
    final body = response.body;

    // Extract error details from response body
    String message = body.isNotEmpty ? body : 'HTTP $statusCode';
    String? errorCode;
    dynamic providerError;
    String? requestId;

    try {
      final json = jsonDecode(body) as Map<String, dynamic>?;
      if (json != null) {
        // Try common error response formats
        final errorObj = json['error'];
        if (errorObj != null) {
          if (errorObj is String) {
            message = errorObj;
          } else if (errorObj is Map) {
            message = errorObj['message'] as String? ?? message;
            errorCode = errorObj['code'] is String
                ? (errorObj['code'] as String)
                : errorCode;
            providerError = errorObj;
          }
        }

        // Check for direct 'code' and 'error' fields (xAI format)
        if (json.containsKey('code')) {
          final codeValue = json['code'];
          errorCode = codeValue is String
              ? codeValue
              : (codeValue is int ? codeValue.toString() : errorCode);
        }
        if (json.containsKey('error') && json['error'] is String) {
          message = json['error'] as String;
        }

        // Check for 'message' field
        if (json.containsKey('message')) {
          message = json['message'] as String? ?? message;
        }

        // Extract request ID if present
        requestId = json['request_id'] as String? ??
            json['requestId'] as String? ??
            json['id'] as String?;
      }
    } on Exception catch (e) {
      log('Error parsing JSON: $e');
      // If JSON parsing fails, use the body as-is
      // This handles plain text error responses
    }

    // Map status codes to exception types
    if (statusCode == 429) {
      // Rate limit exceeded
      final retryAfter = _parseRetryAfter(headers);
      return QuotaError(
        message: message,
        code: errorCode ?? 'RATE_LIMIT',
        provider: provider,
        providerError: providerError,
        requestId: requestId,
        retryAfter: retryAfter,
      );
    }

    if (statusCode == 401 || statusCode == 403) {
      // Authentication/authorization errors
      return AuthError(
        message: message,
        code: errorCode ?? (statusCode == 401 ? 'UNAUTHORIZED' : 'FORBIDDEN'),
        provider: provider,
        providerError: providerError,
        requestId: requestId,
      );
    }

    if (statusCode >= 500) {
      // Server errors - transient and retryable
      return TransientError(
        message: message,
        code: errorCode ?? 'SERVER_ERROR',
        provider: provider,
        providerError: providerError,
        requestId: requestId,
      );
    }

    // Default to client error for 4xx status codes
    return ClientError(
      message: message,
      code: errorCode ?? 'CLIENT_ERROR',
      provider: provider,
      providerError: providerError,
      requestId: requestId,
    );
  }

  /// Maps a generic exception to an [AiException] type.
  ///
  /// Handles common exception types:
  /// - [AiException] → Returns as-is
  /// - [SocketException], [TimeoutException] → [TransientError] (network issues)
  /// - [HttpException] → [ClientError] or [TransientError] based on status code
  /// - Other exceptions → [ClientError] with 'UNKNOWN_ERROR' code
  ///
  /// **Parameters:**
  /// - [e]: The exception to map
  /// - [provider]: The identifier of the AI provider
  ///
  /// **Returns:**
  /// An [AiException] instance appropriate for the exception type.
  ///
  /// **Example:**
  /// ```dart
  /// try {
  ///   await someNetworkCall();
  /// } catch (e) {
  ///   throw ErrorMapper.mapException(e, 'openai');
  /// }
  /// ```
  static AiException mapException(dynamic e, String provider) {
    // If it's already an AiException, return as-is
    if (e is AiException) {
      return e;
    }

    // Network-related exceptions → TransientError
    if (e is SocketException) {
      return TransientError(
        message: 'Network error: ${e.message}',
        code: 'NETWORK_ERROR',
        provider: provider,
        providerError: e.toString(),
      );
    }

    // Handle timeout exceptions (check by type or message)
    if (e.toString().toLowerCase().contains('timeout') ||
        e.toString().toLowerCase().contains('timed out')) {
      return TransientError(
        message: 'Request timed out: ${e.toString()}',
        code: 'TIMEOUT',
        provider: provider,
        providerError: e.toString(),
      );
    }

    if (e is HttpException) {
      return TransientError(
        message: 'HTTP error: ${e.message}',
        code: 'HTTP_ERROR',
        provider: provider,
        providerError: e.toString(),
      );
    }

    // JSON decoding errors → ClientError
    if (e is FormatException) {
      return ClientError(
        message: 'Invalid response format: ${e.message}',
        code: 'PARSE_ERROR',
        provider: provider,
        providerError: e.toString(),
      );
    }

    // Other exceptions → ClientError with unknown code
    return ClientError(
      message: e.toString(),
      code: 'UNKNOWN_ERROR',
      provider: provider,
      providerError: e.toString(),
    );
  }

  /// Parses the `Retry-After` header from HTTP response headers.
  ///
  /// Supports two formats:
  /// - **Seconds**: A number representing seconds (e.g., "60")
  /// - **HTTP Date**: An HTTP-date string (e.g., "Wed, 21 Oct 2015 07:28:00 GMT")
  ///
  /// **Parameters:**
  /// - [headers]: The HTTP response headers
  ///
  /// **Returns:**
  /// A [DateTime] representing when it's safe to retry, or `null` if the header
  /// is missing, invalid, or cannot be parsed.
  static DateTime? _parseRetryAfter(Map<String, String> headers) {
    final retryAfterValue = headers['retry-after'] ?? headers['Retry-After'];
    if (retryAfterValue == null || retryAfterValue.isEmpty) {
      return null;
    }

    // Try parsing as seconds (integer)
    final seconds = int.tryParse(retryAfterValue);
    if (seconds != null && seconds >= 0) {
      return DateTime.now().add(Duration(seconds: seconds));
    }

    // Try parsing as HTTP date
    try {
      // HTTP date format: "Wed, 21 Oct 2015 07:28:00 GMT"
      final date = HttpDate.parse(retryAfterValue);
      // Only return if the date is in the future
      if (date.isAfter(DateTime.now())) {
        return date;
      }
    } on Exception catch (_) {
      // If parsing fails, return null
    }

    return null;
  }
}
