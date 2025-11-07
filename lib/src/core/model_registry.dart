import '../providers/base/ai_provider.dart';
import '../providers/base/model_fetcher.dart';

/// Registry for managing and discovering models across all providers.
///
/// The [ModelRegistry] provides a unified interface for:
/// - Fetching available models from all providers
/// - Caching model lists with TTL
/// - Filtering models by provider or type
/// - Refreshing models on demand
///
/// **Design Pattern:** Facade Pattern
///
/// This class acts as a facade over individual provider model fetching,
/// providing a single entry point for model discovery across the entire SDK.
///
/// **Example usage:**
/// ```dart
/// final registry = ModelRegistry(providerRegistry);
///
/// // Fetch models for all providers
/// await registry.refreshAllModels();
///
/// // Get models for a specific provider
/// final openaiModels = registry.getModels('openai');
///
/// // Get all text models across all providers
/// final textModels = registry.getModelsByType('text');
/// ```
class ModelRegistry {
  /// Provider registry to access all registered providers.
  final Map<String, AiProvider> _providers;

  /// Cache of models by provider ID.
  final Map<String, List<String>> _modelCache = {};

  /// Timestamps of last fetch by provider ID.
  final Map<String, DateTime> _fetchTimestamps = {};

  /// Cache TTL for model lists (24 hours).
  static const Duration _cacheTTL = Duration(hours: 24);

  /// Creates a new [ModelRegistry] instance.
  ///
  /// **Parameters:**
  /// - [providers]: Map of provider ID to provider instance
  ///
  /// **Example:**
  /// ```dart
  /// final registry = ModelRegistry(providerRegistry.getAllProviders());
  /// ```
  ModelRegistry(this._providers);

  /// Fetches models for all providers that support dynamic model discovery.
  ///
  /// This method iterates through all registered providers and fetches models
  /// from those that implement [ModelFetcher]. Models are cached for [cacheTTL]
  /// duration.
  ///
  /// **Parameters:**
  /// - [forceRefresh]: If true, bypasses cache and forces a fresh fetch
  ///
  /// **Returns:**
  /// A map of provider ID to list of model IDs
  ///
  /// **Example:**
  /// ```dart
  /// final models = await registry.refreshAllModels();
  /// print('OpenAI models: ${models['openai']?.length}');
  /// ```
  Future<Map<String, List<String>>> refreshAllModels({
    bool forceRefresh = false,
  }) async {
    final results = <String, List<String>>{};

    for (final entry in _providers.entries) {
      final providerId = entry.key;
      final provider = entry.value;

      // Skip if not a ModelFetcher
      if (provider is! ModelFetcher) {
        continue;
      }

      // Check cache if not forcing refresh
      if (!forceRefresh && _isCacheValid(providerId)) {
        results[providerId] = _modelCache[providerId] ?? [];
        continue;
      }

      try {
        final fetcher = provider as ModelFetcher;
        final models = await fetcher.fetchAvailableModels();
        _modelCache[providerId] = models;
        _fetchTimestamps[providerId] = DateTime.now();

        // Update provider capabilities cache
        provider.capabilities.updateModels(models);

        results[providerId] = models;
      } on Exception {
        // On error, use fallback models from capabilities
        final fallbackModels = provider.capabilities.fallbackModels;
        results[providerId] = fallbackModels;
        _modelCache[providerId] = fallbackModels;
      }
    }

    return results;
  }

  /// Gets models for a specific provider.
  ///
  /// Returns cached models if available and valid, otherwise returns
  /// fallback models from provider capabilities.
  ///
  /// **Parameters:**
  /// - [providerId]: The provider identifier (e.g., 'openai')
  ///
  /// **Returns:**
  /// List of model IDs for the provider, or empty list if provider not found
  ///
  /// **Example:**
  /// ```dart
  /// final models = registry.getModels('openai');
  /// print('Available models: ${models.length}');
  /// ```
  List<String> getModels(String providerId) {
    // Check cache first
    if (_isCacheValid(providerId) && _modelCache.containsKey(providerId)) {
      return _modelCache[providerId]!;
    }

    // Fall back to provider capabilities
    final provider = _providers[providerId];
    if (provider != null) {
      return provider.capabilities.supportedModels;
    }

    return [];
  }

  /// Gets all models across all providers.
  ///
  /// Returns a flattened list of all model IDs from all providers.
  ///
  /// **Returns:**
  /// List of all model IDs (may contain duplicates if multiple providers
  /// support the same model name)
  ///
  /// **Example:**
  /// ```dart
  /// final allModels = registry.getAllModels();
  /// print('Total models: ${allModels.length}');
  /// ```
  List<String> getAllModels() {
    final allModels = <String>[];
    for (final providerId in _providers.keys) {
      allModels.addAll(getModels(providerId));
    }
    return allModels;
  }

  /// Gets models filtered by type across all providers.
  ///
  /// **Parameters:**
  /// - [type]: Model type ('text', 'embedding', 'image', 'tts', 'stt', 'other')
  ///
  /// **Returns:**
  /// List of model IDs that match the specified type
  ///
  /// **Example:**
  /// ```dart
  /// final textModels = registry.getModelsByType('text');
  /// print('Text models: ${textModels.length}');
  /// ```
  List<String> getModelsByType(String type) {
    final filteredModels = <String>[];

    for (final entry in _providers.entries) {
      final provider = entry.value;
      if (provider is! ModelFetcher) {
        continue;
      }

      final fetcher = provider as ModelFetcher;
      final models = getModels(entry.key);
      for (final modelId in models) {
        if (fetcher.inferModelType(modelId) == type) {
          filteredModels.add(modelId);
        }
      }
    }

    return filteredModels;
  }

  /// Clears the cache for a specific provider or all providers.
  ///
  /// **Parameters:**
  /// - [providerId]: Optional provider ID. If null, clears cache for all providers.
  ///
  /// **Example:**
  /// ```dart
  /// registry.clearCache('openai'); // Clear OpenAI cache
  /// registry.clearCache(); // Clear all caches
  /// ```
  void clearCache([String? providerId]) {
    if (providerId != null) {
      _modelCache.remove(providerId);
      _fetchTimestamps.remove(providerId);
      _providers[providerId]?.capabilities.clearCache();
    } else {
      _modelCache.clear();
      _fetchTimestamps.clear();
      for (final provider in _providers.values) {
        provider.capabilities.clearCache();
      }
    }
  }

  /// Checks if the cache is valid for a provider.
  ///
  /// Returns true if cached models exist and haven't expired.
  bool _isCacheValid(String providerId) {
    final timestamp = _fetchTimestamps[providerId];
    if (timestamp == null || !_modelCache.containsKey(providerId)) {
      return false;
    }
    return DateTime.now().difference(timestamp) < _cacheTTL;
  }

  /// Gets the cache TTL for model lists.
  static Duration get cacheTTL => _cacheTTL;
}
