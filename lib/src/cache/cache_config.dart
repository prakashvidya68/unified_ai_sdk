import '../core/constants.dart';

/// Types of cache backends supported by the SDK.
///
/// Different cache backends provide different trade-offs between performance,
/// persistence, and complexity:
///
/// - [none] - No caching (all requests go to providers)
/// - [memory] - In-memory cache (fast, but lost on app restart)
/// - [objectbox] - Persistent cache using ObjectBox (survives app restarts)
/// - [custom] - Custom cache implementation provided by the user
enum CacheBackendType {
  /// No caching - all requests are sent directly to providers.
  ///
  /// Use this when you want to disable caching entirely, such as during
  /// development or when you need real-time data without any caching layer.
  none,

  /// In-memory cache - fast but temporary.
  ///
  /// Data is stored in RAM and is lost when the application restarts.
  /// Best for:
  /// - Development and testing
  /// - Short-lived applications
  /// - When persistence is not required
  memory,

  /// ObjectBox persistent cache - survives app restarts.
  ///
  /// Uses ObjectBox database for persistent storage. Data survives
  /// application restarts and provides good performance.
  /// Best for:
  /// - Production applications
  /// - When you need cache persistence
  /// - Long-running applications
  objectbox,

  /// Custom cache implementation.
  ///
  /// Allows you to provide your own cache backend implementation.
  /// Use this when you need a specific caching solution not covered
  /// by the built-in options.
  custom,
}

/// Configuration for the SDK's caching system.
///
/// [CacheConfig] controls how responses are cached to reduce API costs
/// and improve response times. It specifies the cache backend type, default
/// time-to-live (TTL) for cached entries, and maximum cache size.
///
/// **Key Features:**
/// - **Backend selection**: Choose between memory, persistent, or no cache
/// - **TTL management**: Set default expiration time for cached entries
/// - **Size limits**: Control maximum cache size to prevent memory issues
/// - **Immutable**: All fields are final for thread safety
///
/// **Example usage:**
/// ```dart
/// // Use default configuration (memory cache, 1 hour TTL)
/// final config = CacheConfig.defaults();
///
/// // Custom memory cache with shorter TTL
/// final memoryConfig = CacheConfig(
///   backend: CacheBackendType.memory,
///   defaultTTL: Duration(minutes: 30),
///   maxSizeMB: 50,
/// );
///
/// // Persistent cache with longer TTL
/// final persistentConfig = CacheConfig(
///   backend: CacheBackendType.objectbox,
///   defaultTTL: Duration(hours: 24),
///   maxSizeMB: 500,
/// );
///
/// // Disable caching
/// final noCacheConfig = CacheConfig(
///   backend: CacheBackendType.none,
///   defaultTTL: Duration.zero,
///   maxSizeMB: 0,
/// );
/// ```
class CacheConfig {
  /// The cache backend type to use.
  ///
  /// Determines how cached data is stored:
  /// - [CacheBackendType.none] - No caching
  /// - [CacheBackendType.memory] - In-memory cache
  /// - [CacheBackendType.objectbox] - Persistent cache
  /// - [CacheBackendType.custom] - Custom implementation
  final CacheBackendType backend;

  /// Default time-to-live (TTL) for cached entries.
  ///
  /// Determines how long cached responses remain valid before expiring.
  /// After this duration, cached entries are considered stale and will
  /// be refreshed from the provider.
  ///
  /// **Note:** Individual cache entries can override this with their own TTL.
  ///
  /// **Example:**
  /// ```dart
  /// defaultTTL: Duration(hours: 1),  // Cache for 1 hour
  /// defaultTTL: Duration(minutes: 30), // Cache for 30 minutes
  /// defaultTTL: Duration(days: 1),  // Cache for 1 day
  /// ```
  final Duration defaultTTL;

  /// Maximum cache size in megabytes.
  ///
  /// When the cache reaches this size, the least recently used (LRU) entries
  /// will be evicted to make room for new entries.
  ///
  /// **Note:** This is a soft limit. The actual cache size may temporarily
  /// exceed this value during eviction cycles.
  ///
  /// **Example:**
  /// ```dart
  /// maxSizeMB: 100,  // 100 MB cache limit
  /// maxSizeMB: 500,  // 500 MB cache limit
  /// maxSizeMB: 0,    // No size limit (use with caution)
  /// ```
  final int maxSizeMB;

  /// Creates a new [CacheConfig] instance.
  ///
  /// **Parameters:**
  /// - [backend]: The cache backend type. Required.
  /// - [defaultTTL]: Default time-to-live for cached entries. Required.
  /// - [maxSizeMB]: Maximum cache size in megabytes. Defaults to 100.
  ///
  /// **Example:**
  /// ```dart
  /// final config = CacheConfig(
  ///   backend: CacheBackendType.memory,
  ///   defaultTTL: Duration(hours: 1),
  ///   maxSizeMB: 100,
  /// );
  /// ```
  const CacheConfig({
    required this.backend,
    required this.defaultTTL,
    this.maxSizeMB = 100,
  }) : assert(maxSizeMB >= 0, 'maxSizeMB must be non-negative');

  /// Creates a [CacheConfig] with default values.
  ///
  /// Returns a configuration suitable for most use cases:
  /// - Backend: [CacheBackendType.memory] (in-memory cache)
  /// - Default TTL: 1 hour (from [defaultCacheTTL] constant)
  /// - Max size: 100 MB
  ///
  /// **Example:**
  /// ```dart
  /// // Use defaults
  /// final config = CacheConfig.defaults();
  ///
  /// // Or customize
  /// final customConfig = CacheConfig(
  ///   backend: CacheBackendType.objectbox,
  ///   defaultTTL: Duration(hours: 24),
  /// );
  /// ```
  factory CacheConfig.defaults() {
    return CacheConfig(
      backend: CacheBackendType.memory,
      defaultTTL: defaultCacheTTL,
      maxSizeMB: 100,
    );
  }

  /// Creates a copy of this [CacheConfig] with the given fields replaced.
  ///
  /// Returns a new instance with updated fields. Fields not specified remain
  /// unchanged. Useful for creating variations of a configuration.
  ///
  /// **Example:**
  /// ```dart
  /// final baseConfig = CacheConfig.defaults();
  ///
  /// // Create a copy with longer TTL
  /// final longTTLConfig = baseConfig.copyWith(
  ///   defaultTTL: Duration(hours: 24),
  /// );
  ///
  /// // Create a copy with different backend
  /// final persistentConfig = baseConfig.copyWith(
  ///   backend: CacheBackendType.objectbox,
  /// );
  /// ```
  CacheConfig copyWith({
    CacheBackendType? backend,
    Duration? defaultTTL,
    int? maxSizeMB,
  }) {
    return CacheConfig(
      backend: backend ?? this.backend,
      defaultTTL: defaultTTL ?? this.defaultTTL,
      maxSizeMB: maxSizeMB ?? this.maxSizeMB,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CacheConfig &&
        other.backend == backend &&
        other.defaultTTL == defaultTTL &&
        other.maxSizeMB == maxSizeMB;
  }

  @override
  int get hashCode {
    return Object.hash(backend, defaultTTL, maxSizeMB);
  }

  @override
  String toString() {
    final ttlHours = defaultTTL.inHours;
    final ttlMinutes = defaultTTL.inMinutes % 60;
    final ttlStr = ttlHours > 0
        ? '${ttlHours}h${ttlMinutes > 0 ? ' ${ttlMinutes}m' : ''}'
        : '${ttlMinutes}m';

    return 'CacheConfig(backend: $backend, defaultTTL: $ttlStr, maxSizeMB: $maxSizeMB)';
  }
}
