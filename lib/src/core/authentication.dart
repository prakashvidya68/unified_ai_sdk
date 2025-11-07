import '../error/error_types.dart';

/// Abstract base class for authentication mechanisms.
///
/// Authentication classes are responsible for generating HTTP headers
/// required to authenticate requests with AI providers. Different providers
/// may use different authentication schemes (API keys, OAuth tokens, custom headers, etc.).
///
/// **Design Principles:**
/// - **Provider-agnostic**: Works with any authentication scheme
/// - **Header-based**: Generates HTTP headers for authentication
/// - **Extensible**: Easy to add new authentication types
///
/// **Example usage:**
/// ```dart
/// // API Key authentication (most common)
/// final auth = ApiKeyAuth(apiKey: 'sk-...');
/// final headers = auth.buildHeaders();
/// // Returns: {'Authorization': 'Bearer sk-...'}
///
/// // Custom headers (for providers with unique auth schemes)
/// final customAuth = CustomHeaderAuth({
///   'X-API-Key': 'custom-key',
///   'X-Client-ID': 'client-123',
/// });
/// final headers = customAuth.buildHeaders();
/// ```
abstract class Authentication {
  /// Builds HTTP headers required for authentication.
  ///
  /// Returns a map of header name-value pairs that should be included
  /// in HTTP requests to authenticate with the provider.
  ///
  /// **Returns:**
  /// A map of HTTP headers. Header names should be valid HTTP header names
  /// (typically camelCase or kebab-case). Values should be strings.
  ///
  /// **Example:**
  /// ```dart
  /// final headers = auth.buildHeaders();
  /// // Returns: {'Authorization': 'Bearer sk-abc123'}
  /// ```
  Map<String, String> buildHeaders();
}

/// API key-based authentication using Bearer token format.
///
/// This is the most common authentication method used by AI providers
/// like OpenAI, Anthropic, etc. The API key is sent in the `Authorization`
/// header with the `Bearer` prefix.
///
/// **Example usage:**
/// ```dart
/// // Standard Authorization header
/// final auth = ApiKeyAuth(apiKey: 'sk-abc123');
/// final headers = auth.buildHeaders();
/// // Returns: {'Authorization': 'Bearer sk-abc123'}
///
/// // Custom header name (e.g., for Anthropic)
/// final anthropicAuth = ApiKeyAuth(
///   apiKey: 'sk-ant-...',
///   headerName: 'x-api-key',
/// );
/// final headers = anthropicAuth.buildHeaders();
/// // Returns: {'x-api-key': 'Bearer sk-ant-...'}
/// ```
class ApiKeyAuth implements Authentication {
  /// The API key to use for authentication.
  ///
  /// This should be kept secure and never exposed in client-side code
  /// or public repositories. Common patterns:
  /// - OpenAI: `sk-...`
  /// - Anthropic: `sk-ant-...`
  /// - Cohere: `...`
  final String apiKey;

  /// The HTTP header name to use for the API key.
  ///
  /// Defaults to `'Authorization'` which is the standard for Bearer tokens.
  /// Some providers may use different header names:
  /// - `'Authorization'` - Standard (default)
  /// - `'x-api-key'` - Anthropic, some others
  /// - `'X-API-Key'` - Alternative format
  final String headerName;

  /// Creates a new [ApiKeyAuth] instance.
  ///
  /// **Parameters:**
  /// - [apiKey]: The API key to use for authentication. Must not be empty.
  /// - [headerName]: The HTTP header name. Defaults to `'Authorization'`.
  ///
  /// **Throws:**
  /// - [ClientError] if [apiKey] is empty
  ///
  /// **Example:**
  /// ```dart
  /// // Standard OpenAI-style authentication
  /// final auth = ApiKeyAuth(apiKey: 'sk-abc123');
  ///
  /// // Anthropic-style with custom header
  /// final anthropicAuth = ApiKeyAuth(
  ///   apiKey: 'sk-ant-abc123',
  ///   headerName: 'x-api-key',
  /// );
  /// ```
  ApiKeyAuth({
    required this.apiKey,
    this.headerName = 'Authorization',
  }) {
    if (apiKey.isEmpty) {
      throw ClientError(
        message: 'API key cannot be empty',
        code: 'INVALID_API_KEY',
      );
    }
    if (headerName.isEmpty) {
      throw ClientError(
        message: 'Header name cannot be empty',
        code: 'INVALID_HEADER_NAME',
      );
    }
  }

  /// Builds HTTP headers with the API key in Bearer token format.
  ///
  /// Returns a map containing a single header entry. The value is formatted
  /// as `'Bearer <apiKey>'` when using the default `Authorization` header,
  /// or just the API key for custom headers (to allow more flexibility).
  ///
  /// **Returns:**
  /// A map with the header name and Bearer-formatted value
  ///
  /// **Example:**
  /// ```dart
  /// final auth = ApiKeyAuth(apiKey: 'sk-abc123');
  /// final headers = auth.buildHeaders();
  /// // Returns: {'Authorization': 'Bearer sk-abc123'}
  /// ```
  @override
  Map<String, String> buildHeaders() {
    // For Authorization header, use Bearer format
    // For custom headers (like x-api-key), use the key directly
    final value =
        headerName.toLowerCase() == 'authorization' ? 'Bearer $apiKey' : apiKey;

    return {headerName: value};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiKeyAuth &&
        other.apiKey == apiKey &&
        other.headerName == headerName;
  }

  @override
  int get hashCode => Object.hash(apiKey, headerName);

  @override
  String toString() {
    // Don't expose the full API key in toString for security
    final maskedKey = apiKey.length > 8
        ? '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}'
        : '***';
    return 'ApiKeyAuth(headerName: $headerName, apiKey: $maskedKey)';
  }
}

/// Custom header-based authentication for providers with unique auth schemes.
///
/// This class allows you to specify arbitrary HTTP headers for authentication.
/// Useful for providers that don't follow standard Bearer token authentication
/// or require multiple headers.
///
/// **Example usage:**
/// ```dart
/// // Single custom header
/// final auth = CustomHeaderAuth({
///   'X-API-Key': 'custom-key-value',
/// });
///
/// // Multiple headers (e.g., API key + client ID)
/// final multiHeaderAuth = CustomHeaderAuth({
///   'X-API-Key': 'api-key-value',
///   'X-Client-ID': 'client-123',
///   'X-Client-Secret': 'secret-456',
/// });
///
/// final headers = multiHeaderAuth.buildHeaders();
/// // Returns all specified headers
/// ```
class CustomHeaderAuth implements Authentication {
  /// Map of HTTP header names to their values.
  ///
  /// Each entry in this map will be added as an HTTP header to requests.
  /// Header names should be valid HTTP header names (case-insensitive, but
  /// conventionally camelCase or kebab-case).
  ///
  /// **Example:**
  /// ```dart
  /// {
  ///   'X-API-Key': 'sk-abc123',
  ///   'X-Client-ID': 'client-123',
  /// }
  /// ```
  final Map<String, String> headers;

  /// Creates a new [CustomHeaderAuth] instance.
  ///
  /// **Parameters:**
  /// - [headers]: Map of header name-value pairs. Must not be empty.
  ///
  /// **Throws:**
  /// - [ClientError] if [headers] is empty
  ///
  /// **Example:**
  /// ```dart
  /// final auth = CustomHeaderAuth({
  ///   'X-API-Key': 'custom-key',
  ///   'X-Client-ID': 'client-123',
  /// });
  /// ```
  CustomHeaderAuth(this.headers) {
    if (headers.isEmpty) {
      throw ClientError(
        message: 'Headers map cannot be empty',
        code: 'INVALID_HEADERS',
      );
    }

    // Validate that all header names and values are non-empty
    for (final entry in headers.entries) {
      if (entry.key.isEmpty) {
        throw ClientError(
          message: 'Header name cannot be empty',
          code: 'INVALID_HEADER_NAME',
        );
      }
      if (entry.value.isEmpty) {
        throw ClientError(
          message: 'Header value cannot be empty for header "${entry.key}"',
          code: 'INVALID_HEADER_VALUE',
        );
      }
    }
  }

  /// Returns the custom headers map.
  ///
  /// **Returns:**
  /// A copy of the headers map to prevent external modification
  ///
  /// **Example:**
  /// ```dart
  /// final auth = CustomHeaderAuth({'X-API-Key': 'key'});
  /// final headers = auth.buildHeaders();
  /// // Returns: {'X-API-Key': 'key'}
  /// ```
  @override
  Map<String, String> buildHeaders() {
    // Return a copy to prevent external modification
    return Map<String, String>.from(headers);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomHeaderAuth && _mapEquals(other.headers, headers);
  }

  @override
  int get hashCode {
    // Generate hash from sorted entries for consistency
    final entries = headers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Object.hashAll(entries.map((e) => Object.hash(e.key, e.value)));
  }

  @override
  String toString() {
    final headerNames = headers.keys.join(', ');
    return 'CustomHeaderAuth(headers: [$headerNames])';
  }

  /// Helper method to compare maps for equality.
  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
