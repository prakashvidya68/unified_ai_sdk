import 'package:http/http.dart' as http;

/// Interface for intercepting and modifying HTTP responses after they are received.
///
/// Response interceptors allow you to process responses before they are returned
/// to the caller. Common use cases include:
/// - Logging response details
/// - Extracting response metadata
/// - Modifying response bodies
/// - Handling specific response headers
/// - Error preprocessing
///
/// **Design Pattern:** Chain of Responsibility
///
/// **Example usage:**
/// ```dart
/// class LoggingInterceptor implements ResponseInterceptor {
///   @override
///   Future<http.Response> onResponse(http.Response response) async {
///     print('Response: ${response.statusCode} ${response.request?.url}');
///     return response;
///   }
/// }
///
/// class RateLimitInterceptor implements ResponseInterceptor {
///   @override
///   Future<http.Response> onResponse(http.Response response) async {
///     final retryAfter = response.headers['retry-after'];
///     if (retryAfter != null) {
///       // Handle rate limiting
///     }
///     return response;
///   }
/// }
/// ```
abstract class ResponseInterceptor {
  /// Intercepts and optionally modifies an HTTP response after it is received.
  ///
  /// This method is called for every HTTP response received through the
  /// [HttpClientWrapper]. You can inspect or modify the response before it
  /// is returned to the caller.
  ///
  /// **Parameters:**
  /// - [response]: The HTTP response to intercept. Can be modified if needed.
  ///
  /// **Returns:**
  /// The (possibly modified) HTTP response. Typically returns the same response
  /// instance, but can return a new response if needed.
  ///
  /// **Note:** Modifying responses is less common than modifying requests.
  /// Most interceptors will just inspect the response and return it unchanged.
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<http.Response> onResponse(http.Response response) async {
  ///   // Log response
  ///   print('Status: ${response.statusCode}');
  ///
  ///   // Extract metadata
  ///   final requestId = response.headers['x-request-id'];
  ///
  ///   // Return response (possibly modified)
  ///   return response;
  /// }
  /// ```
  Future<http.Response> onResponse(http.Response response);
}
