import '../cache/cache_config.dart';
import '../error/error_types.dart';
import '../retry/retry_policy.dart';
import '../telemetry/telemetry_handler.dart';
import 'provider_config.dart';

/// Configuration for the Unified AI SDK.
///
/// [UnifiedAIConfig] is the main configuration class used to initialize
/// the SDK. It contains all the settings needed to set up providers,
/// caching, telemetry, and retry policies.
///
/// **Key Features:**
/// - **Provider configuration**: Map of provider configurations
/// - **Caching**: Cache configuration for response caching
/// - **Telemetry**: List of telemetry handlers for observability
/// - **Retry policy**: Configuration for retry behavior
/// - **Default provider**: Optional default provider ID
///
/// **Example usage:**
/// ```dart
/// final config = UnifiedAIConfig(
///   defaultProvider: 'openai',
///   perProviderConfig: {
///     'openai': ProviderConfig(
///       id: 'openai',
///       auth: ApiKeyAuth(apiKey: 'sk-abc123'),
///     ),
///     'anthropic': ProviderConfig(
///       id: 'anthropic',
///       auth: ApiKeyAuth(
///         apiKey: 'sk-ant-abc123',
///         headerName: 'x-api-key',
///       ),
///     ),
///   },
///   cache: CacheConfig.defaults(),
///   retryPolicy: RetryPolicy.defaults(),
/// );
///
/// await UnifiedAI.init(config);
/// ```
class UnifiedAIConfig {
  /// Optional default provider ID.
  ///
  /// When specified, this provider will be used for requests when no
  /// explicit provider is specified. Must match a key in [perProviderConfig].
  ///
  /// If `null`, the SDK will use intelligent routing to select a provider
  /// based on the request type and provider capabilities.
  ///
  /// **Example:**
  /// ```dart
  /// defaultProvider: 'openai', // Use OpenAI as default
  /// ```
  final String? defaultProvider;

  /// Map of provider configurations.
  ///
  /// Each entry maps a provider ID to its configuration. The provider ID
  /// should match the [ProviderConfig.id] and the [AiProvider.id] of the
  /// provider instance.
  ///
  /// **Required:** At least one provider must be configured.
  ///
  /// **Example:**
  /// ```dart
  /// perProviderConfig: {
  ///   'openai': ProviderConfig(
  ///     id: 'openai',
  ///     auth: ApiKeyAuth(apiKey: 'sk-abc123'),
  ///   ),
  ///   'anthropic': ProviderConfig(
  ///     id: 'anthropic',
  ///     auth: ApiKeyAuth(apiKey: 'sk-ant-abc123'),
  ///   ),
  /// }
  /// ```
  final Map<String, ProviderConfig> perProviderConfig;

  /// Cache configuration.
  ///
  /// Controls how responses are cached to reduce API costs and improve
  /// response times. Defaults to [CacheConfig.defaults()] if not specified.
  ///
  /// **Example:**
  /// ```dart
  /// cache: CacheConfig(
  ///   backend: CacheBackendType.memory,
  ///   defaultTTL: Duration(hours: 1),
  ///   maxSizeMB: 100,
  /// ),
  /// ```
  final CacheConfig cache;

  /// List of telemetry handlers.
  ///
  /// Telemetry handlers are used for logging, metrics collection, and
  /// observability. Multiple handlers can be registered to send telemetry
  /// to different destinations (console, metrics service, etc.).
  ///
  /// Defaults to an empty list if not specified. Handlers will be created
  /// when telemetry system is implemented (Step 19.1).
  ///
  /// **Example:**
  /// ```dart
  /// telemetryHandlers: [
  ///   ConsoleLogger(),
  ///   MetricsCollector(),
  /// ],
  /// ```
  final List<TelemetryHandler> telemetryHandlers;

  /// Retry policy configuration.
  ///
  /// Defines how the SDK should retry failed requests. Controls retry
  /// attempts, backoff strategy, and which errors should be retried.
  ///
  /// Defaults to [RetryPolicy.defaults()] if not specified.
  ///
  /// **Example:**
  /// ```dart
  /// retryPolicy: RetryPolicy(
  ///   maxAttempts: 3,
  ///   initialDelay: Duration(milliseconds: 100),
  /// ),
  /// ```
  final RetryPolicy retryPolicy;

  /// Creates a new [UnifiedAIConfig] instance.
  ///
  /// **Parameters:**
  /// - [defaultProvider]: Optional default provider ID. Must match a key
  ///   in [perProviderConfig] if provided.
  /// - [perProviderConfig]: Map of provider configurations. Required and
  ///   must not be empty.
  /// - [cache]: Cache configuration. Defaults to [CacheConfig.defaults()].
  /// - [telemetryHandlers]: List of telemetry handlers. Defaults to empty list.
  /// - [retryPolicy]: Retry policy configuration. Defaults to [RetryPolicy.defaults()].
  ///
  /// **Throws:**
  /// - [ClientError] if [perProviderConfig] is empty
  /// - [ClientError] if [defaultProvider] is specified but not found in [perProviderConfig]
  ///
  /// **Example:**
  /// ```dart
  /// final config = UnifiedAIConfig(
  ///   defaultProvider: 'openai',
  ///   perProviderConfig: {
  ///     'openai': ProviderConfig(
  ///       id: 'openai',
  ///       auth: ApiKeyAuth(apiKey: 'sk-abc123'),
  ///     ),
  ///   },
  /// );
  /// ```
  UnifiedAIConfig({
    this.defaultProvider,
    required this.perProviderConfig,
    CacheConfig? cache,
    List<TelemetryHandler>? telemetryHandlers,
    RetryPolicy? retryPolicy,
  })  : cache = cache ?? CacheConfig.defaults(),
        telemetryHandlers = telemetryHandlers ?? const [],
        retryPolicy = retryPolicy ?? RetryPolicy.defaults() {
    // Validate that at least one provider is configured
    if (perProviderConfig.isEmpty) {
      throw ClientError(
        message: 'At least one provider must be configured',
        code: 'INVALID_CONFIG',
      );
    }

    // Validate that default provider exists in config
    if (defaultProvider != null &&
        !perProviderConfig.containsKey(defaultProvider)) {
      throw ClientError(
        message:
            'Default provider "$defaultProvider" not found in perProviderConfig',
        code: 'INVALID_DEFAULT_PROVIDER',
      );
    }

    // Validate that all provider config IDs match their map keys
    for (final entry in perProviderConfig.entries) {
      if (entry.key != entry.value.id) {
        throw ClientError(
          message:
              'Provider config ID "${entry.value.id}" does not match map key "${entry.key}"',
          code: 'MISMATCHED_PROVIDER_ID',
        );
      }
    }
  }

  /// Creates a copy of this [UnifiedAIConfig] with the given fields replaced.
  ///
  /// Returns a new instance with updated fields. Fields not specified remain
  /// unchanged. Useful for creating variations of a configuration.
  ///
  /// **Example:**
  /// ```dart
  /// final baseConfig = UnifiedAIConfig(
  ///   perProviderConfig: {...},
  /// );
  ///
  /// // Create a copy with different default provider
  /// final configWithDefault = baseConfig.copyWith(
  ///   defaultProvider: 'openai',
  /// );
  ///
  /// // Create a copy with different cache config
  /// final configWithCache = baseConfig.copyWith(
  ///   cache: CacheConfig(backend: CacheBackendType.objectbox),
  /// );
  /// ```
  UnifiedAIConfig copyWith({
    String? defaultProvider,
    Map<String, ProviderConfig>? perProviderConfig,
    CacheConfig? cache,
    List<TelemetryHandler>? telemetryHandlers,
    RetryPolicy? retryPolicy,
    bool clearDefaultProvider = false,
  }) {
    return UnifiedAIConfig(
      defaultProvider: clearDefaultProvider
          ? null
          : (defaultProvider ?? this.defaultProvider),
      perProviderConfig: perProviderConfig ?? this.perProviderConfig,
      cache: cache ?? this.cache,
      telemetryHandlers: telemetryHandlers ?? this.telemetryHandlers,
      retryPolicy: retryPolicy ?? this.retryPolicy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedAIConfig &&
        other.defaultProvider == defaultProvider &&
        _mapEquals(other.perProviderConfig, perProviderConfig) &&
        other.cache == cache &&
        _listEquals(other.telemetryHandlers, telemetryHandlers) &&
        other.retryPolicy == retryPolicy;
  }

  @override
  int get hashCode {
    return Object.hash(
      defaultProvider,
      Object.hashAll(
          perProviderConfig.entries.map((e) => Object.hash(e.key, e.value))),
      cache,
      Object.hashAll(telemetryHandlers),
      retryPolicy,
    );
  }

  @override
  String toString() {
    final providerCount = perProviderConfig.length;
    final providerList = perProviderConfig.keys.join(', ');
    final defaultStr =
        defaultProvider != null ? ' (default: $defaultProvider)' : '';
    final telemetryCount = telemetryHandlers.length;

    return 'UnifiedAIConfig('
        '$providerCount provider(s): [$providerList]$defaultStr, '
        'cache: $cache, '
        'telemetry: $telemetryCount handler(s), '
        'retryPolicy: configured)';
  }

  /// Helper method to compare maps for equality.
  bool _mapEquals(
      Map<String, ProviderConfig> a, Map<String, ProviderConfig> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Helper method to compare lists for equality.
  bool _listEquals(List<TelemetryHandler> a, List<TelemetryHandler> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
