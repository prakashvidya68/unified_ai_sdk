import '../error/error_types.dart';
import 'authentication.dart';

/// Configuration for an AI provider.
///
/// [ProviderConfig] contains all the information needed to initialize and
/// configure an AI provider, including authentication credentials, provider-specific
/// settings, and operational parameters like timeouts.
///
/// **Key Features:**
/// - **Authentication**: Required authentication mechanism (API keys, custom headers, etc.)
/// - **Settings**: Provider-specific configuration (base URLs, model defaults, etc.)
/// - **Timeout**: Request timeout for this provider
/// - **Immutable**: All fields are final for thread safety
///
/// **Example usage:**
/// ```dart
/// // Basic configuration with API key
/// final config = ProviderConfig(
///   id: 'openai',
///   auth: ApiKeyAuth(apiKey: 'sk-abc123'),
/// );
///
/// // Configuration with custom settings and timeout
/// final configWithSettings = ProviderConfig(
///   id: 'anthropic',
///   auth: ApiKeyAuth(
///     apiKey: 'sk-ant-abc123',
///     headerName: 'x-api-key',
///   ),
///   settings: {
///     'baseUrl': 'https://api.anthropic.com/v1',
///     'defaultModel': 'claude-3-opus-20240229',
///   },
///   timeout: Duration(seconds: 60),
/// );
/// ```
class ProviderConfig {
  /// Unique identifier for this provider configuration.
  ///
  /// This ID should match the provider's [AiProvider.id] and is used to:
  /// - Register the provider in the [ProviderRegistry]
  /// - Reference the provider in API calls
  /// - Map configuration to provider instances
  ///
  /// Common examples: `'openai'`, `'anthropic'`, `'google'`, `'cohere'`
  ///
  /// Must be non-empty and should be lowercase, kebab-case, or snake_case.
  final String id;

  /// Authentication mechanism for this provider.
  ///
  /// Defines how to authenticate requests to this provider's API. Common types:
  /// - [ApiKeyAuth] - For providers using API keys (OpenAI, Anthropic, etc.)
  /// - [CustomHeaderAuth] - For providers with custom authentication schemes
  ///
  /// This is required and cannot be null.
  final Authentication auth;

  /// Provider-specific settings and configuration.
  ///
  /// A flexible map for provider-specific configuration options. Common settings:
  /// - `'baseUrl'` - Custom API base URL (if different from default)
  /// - `'defaultModel'` - Default model to use if not specified in requests
  /// - `'organization'` - Organization ID (for OpenAI)
  /// - `'project'` - Project ID (for Google Vertex AI)
  /// - Any other provider-specific options
  ///
  /// Defaults to an empty map if not provided.
  ///
  /// **Example:**
  /// ```dart
  /// settings: {
  ///   'baseUrl': 'https://api.example.com/v1',
  ///   'defaultModel': 'gpt-4',
  ///   'organization': 'org-abc123',
  /// }
  /// ```
  final Map<String, dynamic> settings;

  /// Request timeout for this provider.
  ///
  /// Maximum time to wait for a response from the provider's API before
  /// timing out. If `null`, the SDK's default timeout will be used.
  ///
  /// **Note:** This timeout applies to individual requests, not retries.
  /// The retry mechanism may make multiple attempts within the retry window.
  ///
  /// **Example:**
  /// ```dart
  /// timeout: Duration(seconds: 30), // 30 second timeout
  /// timeout: Duration(minutes: 2),  // 2 minute timeout
  /// ```
  final Duration? timeout;

  /// Creates a new [ProviderConfig] instance.
  ///
  /// **Parameters:**
  /// - [id]: Unique provider identifier. Must not be empty.
  /// - [auth]: Authentication mechanism. Required.
  /// - [settings]: Provider-specific settings. Defaults to empty map.
  /// - [timeout]: Request timeout. Optional, defaults to `null`.
  ///
  /// **Throws:**
  /// - [ClientError] if [id] is empty
  ///
  /// **Example:**
  /// ```dart
  /// final config = ProviderConfig(
  ///   id: 'openai',
  ///   auth: ApiKeyAuth(apiKey: 'sk-abc123'),
  ///   settings: {'defaultModel': 'gpt-4'},
  ///   timeout: Duration(seconds: 30),
  /// );
  /// ```
  ProviderConfig({
    required this.id,
    required this.auth,
    Map<String, dynamic>? settings,
    this.timeout,
  }) : settings = settings != null
            ? Map<String, dynamic>.unmodifiable(settings)
            : const <String, dynamic>{} {
    if (id.isEmpty) {
      throw ClientError(
        message: 'Provider ID cannot be empty',
        code: 'INVALID_PROVIDER_ID',
      );
    }
  }

  /// Creates a copy of this [ProviderConfig] with the given fields replaced.
  ///
  /// Returns a new instance with updated fields. Fields not specified remain
  /// unchanged. Useful for creating variations of a configuration.
  ///
  /// **Example:**
  /// ```dart
  /// final baseConfig = ProviderConfig(
  ///   id: 'openai',
  ///   auth: ApiKeyAuth(apiKey: 'sk-abc123'),
  /// );
  ///
  /// // Create a copy with different timeout
  /// final configWithTimeout = baseConfig.copyWith(
  ///   timeout: Duration(seconds: 60),
  /// );
  ///
  /// // Create a copy with additional settings
  /// final configWithSettings = baseConfig.copyWith(
  ///   settings: {'defaultModel': 'gpt-4'},
  /// );
  /// ```
  ProviderConfig copyWith({
    String? id,
    Authentication? auth,
    Map<String, dynamic>? settings,
    Duration? timeout,
    bool clearTimeout = false,
  }) {
    return ProviderConfig(
      id: id ?? this.id,
      auth: auth ?? this.auth,
      settings: settings ?? this.settings,
      timeout: clearTimeout ? null : (timeout ?? this.timeout),
    );
  }

  /// Converts this [ProviderConfig] to a JSON-serializable map.
  ///
  /// Useful for serialization, logging, or configuration persistence.
  /// Note that [auth] is serialized as a map, and [timeout] is converted
  /// to milliseconds.
  ///
  /// **Returns:**
  /// A map containing all configuration fields in a JSON-friendly format
  ///
  /// **Example:**
  /// ```dart
  /// final config = ProviderConfig(
  ///   id: 'openai',
  ///   auth: ApiKeyAuth(apiKey: 'sk-abc123'),
  ///   timeout: Duration(seconds: 30),
  /// );
  /// final json = config.toJson();
  /// // {
  /// //   'id': 'openai',
  /// //   'auth': {...},
  /// //   'settings': {},
  /// //   'timeout': 30000
  /// // }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth': _authToJson(auth),
      'settings': Map<String, dynamic>.from(settings),
      if (timeout != null) 'timeout': timeout!.inMilliseconds,
    };
  }

  /// Creates a [ProviderConfig] from a JSON map.
  ///
  /// **Note:** This is a basic implementation. For full deserialization,
  /// you may need to handle authentication types explicitly based on your
  /// serialization format.
  ///
  /// **Parameters:**
  /// - [json]: Map containing configuration data
  ///
  /// **Throws:**
  /// - [ClientError] if JSON is invalid or missing required fields
  ///
  /// **Example:**
  /// ```dart
  /// final json = {
  ///   'id': 'openai',
  ///   'auth': {'type': 'apiKey', 'apiKey': 'sk-abc123'},
  ///   'settings': {'defaultModel': 'gpt-4'},
  ///   'timeout': 30000,
  /// };
  /// final config = ProviderConfig.fromJson(json);
  /// ```
  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw ClientError(
        message: 'Provider ID is required in JSON',
        code: 'INVALID_JSON',
      );
    }

    // Parse authentication (simplified - assumes ApiKeyAuth format)
    final authJson = json['auth'] as Map<String, dynamic>?;
    if (authJson == null) {
      throw ClientError(
        message: 'Authentication is required in JSON',
        code: 'INVALID_JSON',
      );
    }

    final auth = _authFromJson(authJson);

    // Parse settings
    final settingsJson = json['settings'];
    final settings = settingsJson != null
        ? Map<String, dynamic>.from(settingsJson as Map)
        : <String, dynamic>{};

    // Parse timeout
    final timeoutMs = json['timeout'] as int?;
    final timeout =
        timeoutMs != null ? Duration(milliseconds: timeoutMs) : null;

    return ProviderConfig(
      id: id,
      auth: auth,
      settings: settings,
      timeout: timeout,
    );
  }

  /// Helper method to serialize authentication to JSON.
  static Map<String, dynamic> _authToJson(Authentication auth) {
    if (auth is ApiKeyAuth) {
      return {
        'type': 'apiKey',
        'apiKey': auth.apiKey,
        'headerName': auth.headerName,
      };
    } else if (auth is CustomHeaderAuth) {
      return {
        'type': 'custom',
        'headers': Map<String, String>.from(auth.headers),
      };
    } else {
      // Fallback for unknown auth types
      return {
        'type': 'unknown',
        'toString': auth.toString(),
      };
    }
  }

  /// Helper method to deserialize authentication from JSON.
  static Authentication _authFromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'apiKey':
        return ApiKeyAuth(
          apiKey: json['apiKey'] as String,
          headerName: json['headerName'] as String? ?? 'Authorization',
        );
      case 'custom':
        final headers = json['headers'] as Map<String, dynamic>?;
        if (headers == null) {
          throw ClientError(
            message: 'Headers are required for custom authentication',
            code: 'INVALID_JSON',
          );
        }
        return CustomHeaderAuth(
          Map<String, String>.from(
            headers.map((k, v) => MapEntry(k, v.toString())),
          ),
        );
      default:
        throw ClientError(
          message: 'Unknown authentication type: $type',
          code: 'INVALID_AUTH_TYPE',
        );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProviderConfig &&
        other.id == id &&
        other.auth == auth &&
        _mapEquals(other.settings, settings) &&
        other.timeout == timeout;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      auth,
      Object.hashAll(settings.entries.map((e) => Object.hash(e.key, e.value))),
      timeout,
    );
  }

  @override
  String toString() {
    final timeoutStr = timeout != null ? '${timeout!.inSeconds}s' : 'default';
    final settingsStr =
        settings.isEmpty ? 'none' : '${settings.length} setting(s)';
    return 'ProviderConfig(id: $id, timeout: $timeoutStr, settings: $settingsStr)';
  }

  /// Helper method to compare maps for equality.
  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
