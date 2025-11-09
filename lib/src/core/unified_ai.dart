import '../error/error_types.dart';
import '../models/requests/chat_request.dart';
import '../models/requests/embedding_request.dart';
import '../models/requests/image_request.dart';
import '../models/responses/chat_response.dart';
import '../models/responses/embedding_response.dart';
import '../models/responses/image_response.dart';
import '../orchestrator/provider_registry.dart';
import '../providers/base/ai_provider.dart';
import '../providers/anthropic/anthropic_provider.dart';
import '../providers/openai/openai_provider.dart';
import '../retry/retry_handler.dart';
import 'config.dart';
import 'provider_config.dart';

/// Main entry point for the Unified AI SDK.
///
/// [UnifiedAI] is a singleton class that provides a unified interface for
/// interacting with multiple AI providers. It manages provider registration,
/// request routing, retry logic, and caching.
///
/// **Key Features:**
/// - Singleton pattern for global access
/// - Provider management and registration
/// - Automatic retry with exponential backoff
/// - Unified API across different AI providers
/// - Provider-agnostic interface
///
/// **Initialization:**
/// ```dart
/// await UnifiedAI.init(
///   UnifiedAIConfig(
///     defaultProvider: 'openai',
///     perProviderConfig: {
///       'openai': ProviderConfig(
///         id: 'openai',
///         auth: ApiKeyAuth(apiKey: 'sk-abc123'),
///       ),
///     },
///   ),
/// );
/// ```
///
/// **Usage:**
/// ```dart
/// final ai = UnifiedAI.instance;
/// // Use ai.chat(), ai.embed(), etc. (methods will be added in later steps)
/// ```
///
/// **Thread Safety:**
/// This class is not thread-safe. Initialize it once at application startup
/// and use the singleton instance throughout your application.
class UnifiedAI {
  /// Singleton instance of [UnifiedAI].
  ///
  /// This is `null` until [init] is called. Use [instance] to access
  /// the singleton with automatic null checking.
  static UnifiedAI? _instance;

  /// Configuration used to initialize the SDK.
  final UnifiedAIConfig _config;

  /// Registry for managing AI providers.
  final ProviderRegistry _registry;

  /// Handler for executing operations with automatic retry logic.
  final RetryHandler _retryHandler;

  /// Private constructor for singleton pattern.
  ///
  /// Use [init] to create and initialize the instance.
  UnifiedAI._({
    required UnifiedAIConfig config,
    required ProviderRegistry registry,
    required RetryHandler retryHandler,
  })  : _config = config,
        _registry = registry,
        _retryHandler = retryHandler;

  /// Gets the singleton instance of [UnifiedAI].
  ///
  /// **Throws:**
  /// - [StateError] if [init] has not been called yet
  ///
  /// **Example:**
  /// ```dart
  /// final ai = UnifiedAI.instance;
  /// ```
  static UnifiedAI get instance {
    if (_instance == null) {
      throw StateError(
        'UnifiedAI has not been initialized. Call UnifiedAI.init() first.',
      );
    }
    return _instance!;
  }

  /// Initializes the Unified AI SDK with the given configuration.
  ///
  /// This method:
  /// 1. Creates a [ProviderRegistry] for managing providers
  /// 2. Creates a [RetryHandler] from the retry policy
  /// 3. Creates and initializes providers from the configuration
  /// 4. Registers all providers in the registry
  /// 5. Returns the singleton instance
  ///
  /// **Parameters:**
  /// - [config]: The configuration for the SDK, including provider configs,
  ///   retry policy, cache settings, etc.
  ///
  /// **Returns:**
  /// The initialized [UnifiedAI] singleton instance.
  ///
  /// **Throws:**
  /// - [StateError] if [init] has already been called
  /// - [ClientError] if provider creation or initialization fails
  /// - [AuthError] if provider authentication fails
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
  ///
  /// final ai = await UnifiedAI.init(config);
  /// ```
  static Future<UnifiedAI> init(UnifiedAIConfig config) async {
    // Check if already initialized
    if (_instance != null) {
      throw StateError(
        'UnifiedAI has already been initialized. '
        'Call UnifiedAI.dispose() first if you need to reinitialize.',
      );
    }

    // Build dependencies
    final registry = ProviderRegistry();
    final retryHandler = RetryHandler(policy: config.retryPolicy);

    // Create and initialize providers from config
    for (final providerConfig in config.perProviderConfig.values) {
      final provider = _createProvider(providerConfig);
      await provider.init(providerConfig);
      registry.register(provider);
    }

    // Create singleton instance
    _instance = UnifiedAI._(
      config: config,
      registry: registry,
      retryHandler: retryHandler,
    );

    return _instance!;
  }

  /// Creates a provider instance from a [ProviderConfig].
  ///
  /// This factory method determines which provider class to instantiate
  /// based on the provider ID in the config.
  ///
  /// **Parameters:**
  /// - [config]: The provider configuration containing the provider ID
  ///
  /// **Returns:**
  /// An initialized [AiProvider] instance (not yet initialized with config).
  ///
  /// **Throws:**
  /// - [ClientError] if the provider ID is not recognized or not yet implemented
  ///
  /// **Supported Providers:**
  /// - `'openai'` → [OpenAIProvider]
  /// - `'anthropic'` → [AnthropicProvider]
  /// - More providers will be added in future steps
  static AiProvider _createProvider(ProviderConfig config) {
    switch (config.id) {
      case 'openai':
        return OpenAIProvider();
      case 'anthropic':
        return AnthropicProvider();
      // Add more providers here as they are implemented
      // case 'google':
      //   return GoogleProvider();
      default:
        throw ClientError(
          message: 'Unknown provider ID: "${config.id}". '
              'Supported providers: openai, anthropic',
          code: 'UNKNOWN_PROVIDER',
        );
    }
  }

  /// Gets the configuration used to initialize the SDK.
  UnifiedAIConfig get config => _config;

  /// Gets the provider registry.
  ///
  /// This can be used to query registered providers, but typically
  /// you should use the high-level methods like [chat] and [embed]
  /// instead of accessing the registry directly.
  ProviderRegistry get registry => _registry;

  /// Gets the retry handler.
  ///
  /// This is used internally by the SDK to wrap operations with retry logic.
  /// Typically, you don't need to access this directly.
  RetryHandler get retryHandler => _retryHandler;

  /// Gets a provider by its ID.
  ///
  /// **Parameters:**
  /// - [id]: The provider ID to look up
  ///
  /// **Returns:**
  /// The provider if found, `null` otherwise.
  ///
  /// **Example:**
  /// ```dart
  /// final provider = UnifiedAI.instance.getProvider('openai');
  /// if (provider != null) {
  ///   print('Provider: ${provider.name}');
  /// }
  /// ```
  AiProvider? getProvider(String id) {
    return _registry.get(id);
  }

  /// Gets all registered provider IDs.
  ///
  /// **Returns:**
  /// A list of all registered provider IDs.
  ///
  /// **Example:**
  /// ```dart
  /// final providers = UnifiedAI.instance.availableProviders;
  /// print('Available providers: ${providers.join(", ")}');
  /// ```
  List<String> get availableProviders => _registry.getAllIds();

  /// Sends a chat request to an AI provider and returns the response.
  ///
  /// This is the main method for interacting with AI chat models. It handles
  /// provider selection, automatic retries, and error handling.
  ///
  /// **Parameters:**
  /// - [provider]: Optional provider ID to use. If not specified, uses
  ///   [config.defaultProvider]. If no default provider is configured,
  ///   throws [ClientError].
  /// - [request]: The chat request containing messages and generation parameters.
  ///
  /// **Returns:**
  /// A [ChatResponse] containing the AI model's response.
  ///
  /// **Throws:**
  /// - [ClientError] if no provider is specified and no default provider is configured
  /// - [ClientError] if the specified provider is not found
  /// - [CapabilityError] if the selected provider doesn't support chat
  /// - [AuthError] if authentication fails (after retries)
  /// - [QuotaError] if rate limits are exceeded (after retries)
  /// - [TransientError] if all retry attempts fail
  ///
  /// **Example:**
  /// ```dart
  /// final ai = UnifiedAI.instance;
  ///
  /// // Use default provider
  /// final response = await ai.chat(
  ///   request: ChatRequest(
  ///     messages: [
  ///       Message(role: Role.user, content: 'Hello!'),
  ///     ],
  ///   ),
  /// );
  ///
  /// // Use specific provider
  /// final response2 = await ai.chat(
  ///   provider: 'openai',
  ///   request: ChatRequest(
  ///     messages: [
  ///       Message(role: Role.user, content: 'Explain quantum computing'),
  ///     ],
  ///     maxTokens: 500,
  ///   ),
  /// );
  /// ```
  Future<ChatResponse> chat({
    String? provider,
    required ChatRequest request,
  }) async {
    return _retryHandler.execute(() async {
      final selectedProvider =
          _getProvider(provider ?? _config.defaultProvider);
      return await selectedProvider.chat(request);
    });
  }

  /// Generates embeddings for text inputs using an AI provider.
  ///
  /// This method converts text inputs into vector representations (embeddings)
  /// that capture semantic meaning. It handles provider selection, automatic
  /// retries, and error handling.
  ///
  /// **Parameters:**
  /// - [provider]: Optional provider ID to use. If not specified, uses
  ///   [config.defaultProvider]. If no default provider is configured,
  ///   throws [ClientError].
  /// - [request]: The embedding request containing text inputs and model parameters.
  ///
  /// **Returns:**
  /// An [EmbeddingResponse] containing the embedding vectors.
  ///
  /// **Throws:**
  /// - [ClientError] if no provider is specified and no default provider is configured
  /// - [ClientError] if the specified provider is not found
  /// - [CapabilityError] if the selected provider doesn't support embeddings
  /// - [AuthError] if authentication fails (after retries)
  /// - [QuotaError] if rate limits are exceeded (after retries)
  /// - [TransientError] if all retry attempts fail
  ///
  /// **Example:**
  /// ```dart
  /// final ai = UnifiedAI.instance;
  ///
  /// // Use default provider
  /// final response = await ai.embed(
  ///   request: EmbeddingRequest(
  ///     inputs: ['Hello, world!', 'How are you?'],
  ///     model: 'text-embedding-3-small',
  ///   ),
  /// );
  ///
  /// // Use specific provider
  /// final response2 = await ai.embed(
  ///   provider: 'openai',
  ///   request: EmbeddingRequest(
  ///     inputs: ['Single text input'],
  ///   ),
  /// );
  ///
  /// // Access embedding vectors
  /// for (final embedding in response.vectors) {
  ///   print('Dimension: ${embedding.dimension}');
  ///   print('Vector length: ${embedding.vector.length}');
  /// }
  /// ```
  Future<EmbeddingResponse> embed({
    String? provider,
    required EmbeddingRequest request,
  }) async {
    return _retryHandler.execute(() async {
      final selectedProvider =
          _getProvider(provider ?? _config.defaultProvider);
      return await selectedProvider.embed(request);
    });
  }

  /// Generates images from text prompts using an AI provider.
  ///
  /// This method converts text descriptions into images using AI models like
  /// DALL-E, Stable Diffusion, or Midjourney. It handles provider selection,
  /// automatic retries, and error handling.
  ///
  /// **Parameters:**
  /// - [provider]: Optional provider ID to use. If not specified, uses
  ///   [config.defaultProvider]. If no default provider is configured,
  ///   throws [ClientError].
  /// - [request]: The image generation request containing prompt and parameters.
  ///
  /// **Returns:**
  /// An [ImageResponse] containing the generated image assets.
  ///
  /// **Throws:**
  /// - [ClientError] if no provider is specified and no default provider is configured
  /// - [ClientError] if the specified provider is not found
  /// - [CapabilityError] if the selected provider doesn't support image generation
  /// - [AuthError] if authentication fails (after retries)
  /// - [QuotaError] if rate limits are exceeded (after retries)
  /// - [TransientError] if all retry attempts fail
  ///
  /// **Example:**
  /// ```dart
  /// final ai = UnifiedAI.instance;
  ///
  /// // Use default provider
  /// final response = await ai.generateImage(
  ///   request: ImageRequest(
  ///     prompt: 'A beautiful sunset over the ocean',
  ///     size: ImageSize.w1024h1024,
  ///     n: 1,
  ///   ),
  /// );
  ///
  /// // Use specific provider
  /// final response2 = await ai.generateImage(
  ///   provider: 'openai',
  ///   request: ImageRequest(
  ///     prompt: 'A futuristic cityscape',
  ///     size: ImageSize.w512h512,
  ///     quality: 'hd',
  ///   ),
  /// );
  ///
  /// // Access generated images
  /// for (final asset in response.assets) {
  ///   if (asset.url != null) {
  ///     print('Image URL: ${asset.url}');
  ///   } else if (asset.base64 != null) {
  ///     print('Base64 image data available');
  ///   }
  /// }
  /// ```
  Future<ImageResponse> generateImage({
    String? provider,
    required ImageRequest request,
  }) async {
    return _retryHandler.execute(() async {
      final selectedProvider =
          _getProvider(provider ?? _config.defaultProvider);
      return await selectedProvider.generateImage(request);
    });
  }

  /// Gets a provider by ID, throwing appropriate errors if not found.
  ///
  /// This is a helper method that wraps [getProvider] with error handling.
  /// It throws [ClientError] if the provider ID is null or the provider
  /// is not found in the registry.
  ///
  /// **Parameters:**
  /// - [providerId]: The provider ID to look up. Can be `null`.
  ///
  /// **Returns:**
  /// The [AiProvider] instance if found.
  ///
  /// **Throws:**
  /// - [ClientError] if [providerId] is `null`
  /// - [ClientError] if the provider is not found in the registry
  AiProvider _getProvider(String? providerId) {
    if (providerId == null) {
      throw ClientError(
        message: 'No provider specified and no default provider configured. '
            'Either specify a provider or set defaultProvider in UnifiedAIConfig.',
        code: 'NO_PROVIDER_SPECIFIED',
      );
    }

    final provider = _registry.get(providerId);
    if (provider == null) {
      final availableProviders = _registry.getAllIds();
      throw ClientError(
        message: 'Provider "$providerId" not found. '
            'Available providers: ${availableProviders.isEmpty ? "none" : availableProviders.join(", ")}',
        code: 'PROVIDER_NOT_FOUND',
      );
    }

    return provider;
  }

  /// Disposes the SDK instance and cleans up resources.
  ///
  /// This method should be called when the SDK is no longer needed,
  /// typically at application shutdown. After calling this, you can
  /// call [init] again to reinitialize the SDK.
  ///
  /// **Note:** This is a placeholder for now. Full cleanup (cache clearing,
  /// etc.) will be implemented in later steps.
  ///
  /// **Example:**
  /// ```dart
  /// await UnifiedAI.instance.dispose();
  /// ```
  Future<void> dispose() async {
    // TODO: Add cleanup logic (cache clearing, etc.) in later steps
    _instance = null;
  }
}
