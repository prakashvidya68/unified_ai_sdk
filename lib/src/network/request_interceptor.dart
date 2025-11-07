import 'package:http/http.dart' as http;

/// Interface for intercepting and modifying HTTP requests before they are sent.
///
/// Request interceptors allow you to modify requests before they reach the
/// server. Common use cases include:
/// - Adding authentication headers
/// - Adding request IDs for tracing
/// - Logging request details
/// - Modifying request URLs or bodies
/// - Adding custom headers
///
/// **Design Pattern:** Chain of Responsibility
///
/// **Example usage:**
/// ```dart
/// class AuthInterceptor implements RequestInterceptor {
///   final String apiKey;
///
///   AuthInterceptor(this.apiKey);
///
///   @override
///   Future<http.Request> onRequest(http.Request request) async {
///     request.headers['Authorization'] = 'Bearer $apiKey';
///     return request;
///   }
/// }
///
/// class RequestIdInterceptor implements RequestInterceptor {
///   @override
///   Future<http.Request> onRequest(http.Request request) async {
///     request.headers['X-Request-ID'] = _generateRequestId();
///     return request;
///   }
/// }
/// ```
abstract class RequestInterceptor {
  /// Intercepts and optionally modifies an HTTP request before it is sent.
  ///
  /// This method is called for every HTTP request made through the
  /// [HttpClientWrapper]. You can modify the request (headers, body, URL, etc.)
  /// or return it unchanged.
  ///
  /// **Parameters:**
  /// - [request]: The HTTP request to intercept. Can be modified in-place.
  ///
  /// **Returns:**
  /// The (possibly modified) HTTP request. Typically returns the same request
  /// instance after modifications, but can return a new request if needed.
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<http.Request> onRequest(http.Request request) async {
  ///   // Add custom header
  ///   request.headers['X-Custom-Header'] = 'value';
  ///
  ///   // Modify URL if needed
  ///   // final newUri = request.url.replace(path: '/new/path');
  ///   // request = http.Request(request.method, newUri)..headers.addAll(request.headers);
  ///
  ///   return request;
  /// }
  /// ```
  Future<http.Request> onRequest(http.Request request);
}
