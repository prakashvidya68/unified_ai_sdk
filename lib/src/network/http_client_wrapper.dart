import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../error/error_mapper.dart';
import 'request_interceptor.dart';
import 'response_interceptor.dart';

/// Wrapper around [http.Client] that provides convenient methods for making
/// HTTP requests with default headers, error handling, and streaming support.
///
/// [HttpClientWrapper] simplifies HTTP communication by:
/// - Merging default headers with request-specific headers
/// - Providing consistent error handling
/// - Supporting both regular and streaming requests
/// - Handling JSON encoding automatically
/// - Supporting request/response interceptors for extensibility
///
/// **Example usage:**
/// ```dart
/// final wrapper = HttpClientWrapper(
///   client: http.Client(),
///   defaultHeaders: {
///     'Authorization': 'Bearer sk-abc123',
///     'Content-Type': 'application/json',
///   },
/// );
///
/// // Make a POST request
/// final response = await wrapper.post(
///   'https://api.example.com/v1/chat',
///   body: {'message': 'Hello'},
/// );
///
/// // Make a streaming request
/// final stream = wrapper.postStream(
///   'https://api.example.com/v1/chat/stream',
///   body: {'message': 'Hello'},
/// );
/// await for (final chunk in stream) {
///   // Process chunk
/// }
/// ```
class HttpClientWrapper {
  /// The underlying HTTP client used for making requests.
  ///
  /// Can be a standard [http.Client] or a custom implementation for testing
  /// or advanced use cases (e.g., custom timeouts, connection pooling).
  final http.Client _client;

  /// Default headers to include in all requests.
  ///
  /// These headers are merged with request-specific headers, with
  /// request-specific headers taking precedence.
  ///
  /// Common default headers:
  /// - `Authorization`: API key or bearer token
  /// - `Content-Type`: Usually `application/json`
  /// - `User-Agent`: SDK identification
  final Map<String, String> defaultHeaders;

  /// List of request interceptors to apply before sending requests.
  ///
  /// Interceptors are applied in order, allowing each to modify the request.
  /// Common use cases: authentication, logging, request ID generation.
  final List<RequestInterceptor> requestInterceptors;

  /// List of response interceptors to apply after receiving responses.
  ///
  /// Interceptors are applied in order, allowing each to process the response.
  /// Common use cases: logging, error preprocessing, metadata extraction.
  final List<ResponseInterceptor> responseInterceptors;

  /// Creates a new [HttpClientWrapper] instance.
  ///
  /// **Parameters:**
  /// - [client]: The HTTP client to use for requests. Required.
  /// - [defaultHeaders]: Default headers to include in all requests.
  ///   Defaults to empty map if not provided.
  /// - [requestInterceptors]: List of request interceptors to apply before
  ///   sending requests. Defaults to empty list if not provided.
  /// - [responseInterceptors]: List of response interceptors to apply after
  ///   receiving responses. Defaults to empty list if not provided.
  ///
  /// **Example:**
  /// ```dart
  /// final wrapper = HttpClientWrapper(
  ///   client: http.Client(),
  ///   defaultHeaders: {
  ///     'Authorization': 'Bearer sk-abc123',
  ///     'Content-Type': 'application/json',
  ///   },
  ///   requestInterceptors: [
  ///     AuthInterceptor(),
  ///     RequestIdInterceptor(),
  ///   ],
  ///   responseInterceptors: [
  ///     LoggingInterceptor(),
  ///   ],
  /// );
  /// ```
  HttpClientWrapper({
    required http.Client client,
    Map<String, String>? defaultHeaders,
    List<RequestInterceptor>? requestInterceptors,
    List<ResponseInterceptor>? responseInterceptors,
  })  : _client = client,
        defaultHeaders = defaultHeaders ?? const {},
        requestInterceptors = requestInterceptors ?? const [],
        responseInterceptors = responseInterceptors ?? const [];

  /// Makes a POST request to the specified URL.
  ///
  /// Merges [defaultHeaders] with the provided [headers], with [headers]
  /// taking precedence. If [body] is provided, it will be JSON-encoded
  /// automatically if it's a Map or List.
  ///
  /// **Parameters:**
  /// - [url]: The URL to make the request to
  /// - [headers]: Optional request-specific headers (merged with defaults)
  /// - [body]: Optional request body. If it's a Map or List, it will be
  ///   JSON-encoded. If it's a String, it will be sent as-is. If it's
  ///   null, no body will be sent.
  ///
  /// **Returns:**
  /// A [Future] that completes with the HTTP response
  ///
  /// **Throws:**
  /// - [SocketException] or [TimeoutException] for network errors
  /// - [FormatException] for JSON encoding errors
  /// - Various [AiException] subtypes for HTTP errors (via [ErrorMapper])
  ///
  /// **Example:**
  /// ```dart
  /// final response = await wrapper.post(
  ///   'https://api.example.com/v1/chat',
  ///   headers: {'X-Custom-Header': 'value'},
  ///   body: {'message': 'Hello'},
  /// );
  ///
  /// if (response.statusCode == 200) {
  ///   final json = jsonDecode(response.body);
  ///   // Process response
  /// }
  /// ```
  ///
  /// Makes a GET request to the specified URL.
  ///
  /// Merges [defaultHeaders] with the provided [headers], with [headers]
  /// taking precedence.
  ///
  /// **Parameters:**
  /// - [url]: The URL to make the request to
  /// - [headers]: Optional request-specific headers (merged with defaults)
  ///
  /// **Returns:**
  /// A [Future] that completes with the HTTP response
  ///
  /// **Throws:**
  /// - [SocketException] or [TimeoutException] for network errors
  /// - Various [AiException] subtypes for HTTP errors (via [ErrorMapper])
  ///
  /// **Example:**
  /// ```dart
  /// final response = await wrapper.get(
  ///   'https://api.example.com/v1/models',
  ///   headers: {'X-Custom-Header': 'value'},
  /// );
  ///
  /// if (response.statusCode == 200) {
  ///   final json = jsonDecode(response.body);
  ///   // Process response
  /// }
  /// ```
  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final mergedHeaders = _mergeHeaders(headers);

      var request = http.Request('GET', Uri.parse(url))
        ..headers.addAll(mergedHeaders);

      for (final interceptor in requestInterceptors) {
        request = await interceptor.onRequest(request);
      }

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      var processedResponse = response;
      for (final interceptor in responseInterceptors) {
        processedResponse = await interceptor.onResponse(processedResponse);
      }

      return processedResponse;
    } on SocketException catch (e) {
      throw ErrorMapper.mapException(e, 'network');
    } on HttpException catch (e) {
      throw ErrorMapper.mapException(e, 'network');
    } on FormatException catch (e) {
      throw ErrorMapper.mapException(e, 'network');
    } catch (e) {
      if (e is Exception) {
        throw ErrorMapper.mapException(e, 'network');
      }
      rethrow;
    }
  }

  /// Makes a POST request to the specified URL.
  ///
  /// Merges [defaultHeaders] with the provided [headers], with [headers]
  /// taking precedence. If [body] is provided, it will be JSON-encoded
  /// automatically if it's a Map or List.
  ///
  /// **Parameters:**
  /// - [url]: The URL to make the request to
  /// - [headers]: Optional request-specific headers (merged with defaults)
  /// - [body]: Optional request body. If it's a Map or List, it will be
  ///   JSON-encoded. If it's a String, it will be sent as-is. If it's
  ///   null, no body will be sent.
  ///
  /// **Returns:**
  /// A [Future] that completes with the HTTP response
  ///
  /// **Throws:**
  /// - [SocketException] or [TimeoutException] for network errors
  /// - [FormatException] for JSON encoding errors
  /// - Various [AiException] subtypes for HTTP errors (via [ErrorMapper])
  ///
  /// **Example:**
  /// ```dart
  /// final response = await wrapper.post(
  ///   'https://api.example.com/v1/chat',
  ///   headers: {'X-Custom-Header': 'value'},
  ///   body: {'message': 'Hello'},
  /// );
  ///
  /// if (response.statusCode == 200) {
  ///   final json = jsonDecode(response.body);
  ///   // Process response
  /// }
  /// ```
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      // Merge default headers with request-specific headers
      final mergedHeaders = _mergeHeaders(headers);

      // Encode body if needed and set Content-Type for JSON
      final encodedBody = _encodeBody(body);
      if (body != null && (body is Map || body is List)) {
        mergedHeaders['Content-Type'] = 'application/json';
      }

      // Create request object
      var request = http.Request('POST', Uri.parse(url))
        ..headers.addAll(mergedHeaders)
        ..body = encodedBody;

      // Apply request interceptors
      for (final interceptor in requestInterceptors) {
        request = await interceptor.onRequest(request);
      }

      // Make the request
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      // Apply response interceptors
      var processedResponse = response;
      for (final interceptor in responseInterceptors) {
        processedResponse = await interceptor.onResponse(processedResponse);
      }

      return processedResponse;
    } on SocketException catch (e) {
      throw ErrorMapper.mapException(e, 'network');
    } on HttpException catch (e) {
      throw ErrorMapper.mapException(e, 'network');
    } on FormatException catch (e) {
      throw ErrorMapper.mapException(e, 'network');
    } catch (e) {
      // Re-throw AiException types as-is
      if (e is Exception) {
        throw ErrorMapper.mapException(e, 'network');
      }
      rethrow;
    }
  }

  /// Makes a streaming POST request to the specified URL.
  ///
  /// Similar to [post], but returns a stream of bytes instead of waiting
  /// for the complete response. Useful for Server-Sent Events (SSE) or
  /// other streaming protocols.
  ///
  /// **Parameters:**
  /// - [url]: The URL to make the request to
  /// - [body]: Optional request body. If it's a Map or List, it will be
  ///   JSON-encoded. If it's a String, it will be sent as-is. If it's
  ///   null, no body will be sent.
  ///
  /// **Returns:**
  /// A [Stream] of byte chunks from the response
  ///
  /// **Throws:**
  /// - [SocketException] or [TimeoutException] for network errors
  /// - [FormatException] for JSON encoding errors
  ///
  /// **Example:**
  /// ```dart
  /// final stream = wrapper.postStream(
  ///   'https://api.example.com/v1/chat/stream',
  ///   body: {'message': 'Hello'},
  /// );
  ///
  /// await for (final chunk in stream) {
  ///   // Process streaming chunk
  ///   print(String.fromCharCodes(chunk));
  /// }
  /// ```
  Stream<List<int>> postStream(
    String url, {
    Object? body,
  }) async* {
    try {
      // Merge default headers (no request-specific headers for streaming)
      final headers = Map<String, String>.from(defaultHeaders);

      // Ensure Content-Type is set for JSON body
      if (body != null && (body is Map || body is List)) {
        headers['Content-Type'] = 'application/json';
      }

      // Encode body if needed
      final encodedBody = _encodeBody(body);

      // Create request object
      var request = http.Request('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..body = encodedBody;

      // Apply request interceptors
      for (final interceptor in requestInterceptors) {
        request = await interceptor.onRequest(request);
      }

      // Make the streaming request
      final streamedResponse = await _client.send(request);

      // Stream the response body
      // Note: Response interceptors are not applied to streams as they
      // would require buffering the entire stream, which defeats the purpose
      yield* streamedResponse.stream;
    } on SocketException catch (e) {
      throw ErrorMapper.mapException(e, 'network');
    } on HttpException catch (e) {
      throw ErrorMapper.mapException(e, 'network');
    } on FormatException catch (e) {
      throw ErrorMapper.mapException(e, 'network');
    } catch (e) {
      // Re-throw AiException types as-is
      if (e is Exception) {
        throw ErrorMapper.mapException(e, 'network');
      }
      rethrow;
    }
  }

  /// Closes the underlying HTTP client and releases resources.
  ///
  /// Should be called when the wrapper is no longer needed to prevent
  /// resource leaks. After calling this method, the wrapper should not
  /// be used for making requests.
  ///
  /// **Example:**
  /// ```dart
  /// await wrapper.close();
  /// ```
  void close() {
    _client.close();
  }

  /// Merges default headers with request-specific headers.
  ///
  /// Request-specific headers take precedence over default headers.
  /// This allows overriding default headers on a per-request basis.
  ///
  /// **Parameters:**
  /// - [requestHeaders]: Optional request-specific headers
  ///
  /// **Returns:**
  /// A merged map of headers
  Map<String, String> _mergeHeaders(Map<String, String>? requestHeaders) {
    final merged = Map<String, String>.from(defaultHeaders);
    if (requestHeaders != null) {
      merged.addAll(requestHeaders);
    }
    return merged;
  }

  /// Encodes the request body to a string.
  ///
  /// If the body is a Map or List, it will be JSON-encoded.
  /// If it's already a String, it will be returned as-is.
  /// If it's null, returns an empty string.
  ///
  /// **Parameters:**
  /// - [body]: The request body to encode
  ///
  /// **Returns:**
  /// The encoded body as a string
  String _encodeBody(Object? body) {
    if (body == null) {
      return '';
    }

    if (body is String) {
      return body;
    }

    if (body is Map || body is List) {
      return jsonEncode(body);
    }

    // For other types, convert to string
    return body.toString();
  }
}
