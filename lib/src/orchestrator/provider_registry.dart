import '../error/error_types.dart';
import '../providers/base/ai_provider.dart';

/// Registry for managing AI providers.
///
/// The [ProviderRegistry] is responsible for storing and retrieving AI providers
/// by their unique identifiers. It also provides capability-based lookup to find
/// providers that support specific operations.
///
/// **Key Features:**
/// - Register providers with unique IDs
/// - Retrieve providers by ID
/// - Find providers by capability (chat, embedding, image generation, etc.)
/// - Prevent duplicate registrations
/// - Query registered provider information
///
/// **Example usage:**
/// ```dart
/// final registry = ProviderRegistry();
///
/// // Register providers
/// final openAI = OpenAIProvider();
/// await openAI.init(config);
/// registry.register(openAI);
///
/// final anthropic = AnthropicProvider();
/// await anthropic.init(config);
/// registry.register(anthropic);
///
/// // Retrieve by ID
/// final provider = registry.get('openai');
/// if (provider != null) {
///   final response = await provider.chat(request);
/// }
///
/// // Find providers by capability
/// final chatProviders = registry.getByCapability('chat');
/// // Returns providers that support chat
/// ```
///
/// **Thread Safety:**
/// This class is not thread-safe. If you need thread-safe access, wrap it
/// with synchronization primitives or use it within a single isolate.
class ProviderRegistry {
  /// Internal map storing providers by their ID.
  final Map<String, AiProvider> _providers = {};

  /// Registers a provider with the registry.
  ///
  /// The provider's [AiProvider.id] is used as the unique key. If a provider
  /// with the same ID is already registered, a [ClientError] is thrown.
  ///
  /// **Parameters:**
  /// - [provider]: The provider instance to register. Must have a unique ID.
  ///
  /// **Throws:**
  /// - [ClientError] if a provider with the same ID is already registered
  ///
  /// **Example:**
  /// ```dart
  /// final provider = OpenAIProvider();
  /// await provider.init(config);
  /// registry.register(provider);
  /// ```
  void register(AiProvider provider) {
    if (provider.id.isEmpty) {
      throw ClientError(
        message: 'Provider ID cannot be empty',
        code: 'INVALID_PROVIDER_ID',
      );
    }

    if (_providers.containsKey(provider.id)) {
      throw ClientError(
        message: 'Provider with ID "${provider.id}" is already registered',
        code: 'DUPLICATE_PROVIDER',
        provider: provider.id,
      );
    }

    _providers[provider.id] = provider;
  }

  /// Retrieves a provider by its ID.
  ///
  /// Returns the provider if found, or `null` if no provider with the given ID
  /// is registered. The lookup is case-sensitive.
  ///
  /// **Parameters:**
  /// - [providerId]: The unique identifier of the provider to retrieve
  ///
  /// **Returns:**
  /// The [AiProvider] instance if found, or `null` if not registered
  ///
  /// **Example:**
  /// ```dart
  /// final provider = registry.get('openai');
  /// if (provider != null) {
  ///   // Use provider
  /// }
  /// ```
  AiProvider? get(String providerId) {
    return _providers[providerId];
  }

  /// Retrieves all providers that support the specified capability.
  ///
  /// Returns a list of providers that have the requested capability enabled.
  /// The capability string should match one of the supported capability names:
  /// - `'chat'` - providers that support chat/text generation
  /// - `'embed'` or `'embedding'` - providers that support embeddings
  /// - `'image'` or `'imageGeneration'` - providers that support image generation
  /// - `'tts'` - providers that support text-to-speech
  /// - `'stt'` - providers that support speech-to-text
  /// - `'streaming'` - providers that support streaming responses
  ///
  /// **Parameters:**
  /// - [capability]: The capability name to search for (case-insensitive)
  ///
  /// **Returns:**
  /// A list of providers that support the capability, or an empty list if none found
  ///
  /// **Example:**
  /// ```dart
  /// // Find all providers that support chat
  /// final chatProviders = registry.getByCapability('chat');
  ///
  /// // Find providers that support embeddings
  /// final embeddingProviders = registry.getByCapability('embedding');
  ///
  /// // Find providers that support streaming
  /// final streamingProviders = registry.getByCapability('streaming');
  /// ```
  List<AiProvider> getByCapability(String capability) {
    final normalizedCapability = capability.toLowerCase().trim();

    return _providers.values.where((provider) {
      final caps = provider.capabilities;

      switch (normalizedCapability) {
        case 'chat':
          return caps.supportsChat;
        case 'embed':
        case 'embedding':
          return caps.supportsEmbedding;
        case 'image':
        case 'imagegeneration':
          return caps.supportsImageGeneration;
        case 'tts':
          return caps.supportsTTS;
        case 'stt':
          return caps.supportsSTT;
        case 'streaming':
          return caps.supportsStreaming;
        default:
          // Unknown capability - return false (no providers match)
          return false;
      }
    }).toList();
  }

  /// Returns a list of all registered provider IDs.
  ///
  /// The IDs are returned in no particular order. Use this to enumerate
  /// all registered providers or check how many providers are registered.
  ///
  /// **Returns:**
  /// A list of provider IDs (strings)
  ///
  /// **Example:**
  /// ```dart
  /// final ids = registry.getAllIds();
  /// print('Registered providers: ${ids.join(", ")}');
  /// // Output: Registered providers: openai, anthropic, google
  /// ```
  List<String> getAllIds() {
    return _providers.keys.toList();
  }

  /// Returns a list of all registered providers.
  ///
  /// Useful when you need to iterate over all providers or perform bulk
  /// operations.
  ///
  /// **Returns:**
  /// A list of all registered [AiProvider] instances
  ///
  /// **Example:**
  /// ```dart
  /// final allProviders = registry.getAll();
  /// for (final provider in allProviders) {
  ///   print('${provider.name} (${provider.id})');
  /// }
  /// ```
  List<AiProvider> getAll() {
    return _providers.values.toList();
  }

  /// Checks if a provider with the given ID is registered.
  ///
  /// **Parameters:**
  /// - [providerId]: The provider ID to check
  ///
  /// **Returns:**
  /// `true` if a provider with the ID is registered, `false` otherwise
  ///
  /// **Example:**
  /// ```dart
  /// if (registry.has('openai')) {
  ///   // Provider is registered
  /// }
  /// ```
  bool has(String providerId) {
    return _providers.containsKey(providerId);
  }

  /// Returns the number of registered providers.
  ///
  /// **Returns:**
  /// The count of registered providers
  ///
  /// **Example:**
  /// ```dart
  /// print('${registry.count} providers registered');
  /// ```
  int get count => _providers.length;

  /// Unregisters a provider by ID.
  ///
  /// Removes the provider from the registry and optionally disposes of it.
  /// If the provider is not registered, this method does nothing.
  ///
  /// **Parameters:**
  /// - [providerId]: The ID of the provider to unregister
  /// - [dispose]: Whether to call [AiProvider.dispose] on the provider before
  ///   removing it. Defaults to `true`.
  ///
  /// **Returns:**
  /// `true` if the provider was found and removed, `false` if it wasn't registered
  ///
  /// **Example:**
  /// ```dart
  /// // Remove provider and clean up resources
  /// final removed = registry.unregister('openai', dispose: true);
  /// ```
  Future<bool> unregister(String providerId, {bool dispose = true}) async {
    final provider = _providers.remove(providerId);
    if (provider != null) {
      if (dispose) {
        await provider.dispose();
      }
      return true;
    }
    return false;
  }

  /// Clears all registered providers.
  ///
  /// Removes all providers from the registry and optionally disposes of them.
  /// After calling this method, the registry will be empty.
  ///
  /// **Parameters:**
  /// - [dispose]: Whether to call [AiProvider.dispose] on each provider before
  ///   removing it. Defaults to `true`.
  ///
  /// **Example:**
  /// ```dart
  /// // Clear all providers and clean up resources
  /// await registry.clear(dispose: true);
  /// ```
  Future<void> clear({bool dispose = true}) async {
    if (dispose) {
      for (final provider in _providers.values) {
        await provider.dispose();
      }
    }
    _providers.clear();
  }

  @override
  String toString() {
    final ids = _providers.keys.toList()..sort();
    return 'ProviderRegistry(${ids.length} providers: ${ids.join(", ")})';
  }
}
