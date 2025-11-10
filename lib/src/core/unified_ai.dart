import 'dart:math';

import '../error/ai_exception.dart';
import '../error/error_types.dart';
import '../models/requests/chat_request.dart';
import '../models/requests/embedding_request.dart';
import '../models/requests/image_request.dart';
import '../models/responses/chat_response.dart';
import '../models/responses/chat_stream_event.dart';
import '../models/responses/embedding_response.dart';
import '../models/responses/image_response.dart';
import '../orchestrator/intent_detector.dart';
import '../orchestrator/provider_registry.dart';
import '../orchestrator/request_router.dart';
import '../providers/base/ai_provider.dart';
import '../providers/anthropic/anthropic_provider.dart';
import '../providers/cohere/cohere_provider.dart';
import '../providers/google/google_provider.dart';
import '../providers/openai/openai_provider.dart';
import '../retry/retry_handler.dart';
import '../telemetry/telemetry_handler.dart';
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

  /// Router for selecting appropriate providers based on intent or explicit selection.
  final RequestRouter _router;

  /// List of telemetry handlers for observability.
  ///
  /// These handlers receive telemetry events (requests, responses, errors)
  /// for logging, metrics collection, and monitoring.
  final List<TelemetryHandler> _telemetryHandlers;

  /// Private constructor for singleton pattern.
  ///
  /// Use [init] to create and initialize the instance.
  UnifiedAI._({
    required UnifiedAIConfig config,
    required ProviderRegistry registry,
    required RetryHandler retryHandler,
    required RequestRouter router,
    required List<TelemetryHandler> telemetryHandlers,
  })  : _config = config,
        _registry = registry,
        _retryHandler = retryHandler,
        _router = router,
        _telemetryHandlers = telemetryHandlers;

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
    final intentDetector = IntentDetector();
    final router = RequestRouter(
      registry: registry,
      intentDetector: intentDetector,
    );

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
      router: router,
      telemetryHandlers: config.telemetryHandlers,
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
  /// - `'google'` → [GoogleProvider]
  /// - `'cohere'` → [CohereProvider]
  /// - More providers will be added in future steps
  static AiProvider _createProvider(ProviderConfig config) {
    switch (config.id) {
      case 'openai':
        return OpenAIProvider();
      case 'anthropic':
        return AnthropicProvider();
      case 'google':
        return GoogleProvider();
      case 'cohere':
        return CohereProvider();
      // Add more providers here as they are implemented
      default:
        throw ClientError(
          message: 'Unknown provider ID: "${config.id}". '
              'Supported providers: openai, anthropic, google, cohere',
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
  /// provider selection (explicit or automatic intent-based routing), automatic
  /// retries, and error handling.
  ///
  /// **Parameters:**
  /// - [provider]: Optional provider ID to use. If not specified, the router
  ///   will automatically detect intent from the request and select an appropriate
  ///   provider. If [config.defaultProvider] is set, it will be used as a fallback
  ///   when intent-based routing is not possible.
  /// - [request]: The chat request containing messages and generation parameters.
  ///
  /// **Returns:**
  /// A [ChatResponse] containing the AI model's response.
  ///
  /// **Throws:**
  /// - [ClientError] if explicit provider is specified but not found
  /// - [CapabilityError] if no providers support the detected capability
  /// - [CapabilityError] if the selected provider doesn't support chat
  /// - [AuthError] if authentication fails (after retries)
  /// - [QuotaError] if rate limits are exceeded (after retries)
  /// - [TransientError] if all retry attempts fail
  ///
  /// **Example:**
  /// ```dart
  /// final ai = UnifiedAI.instance;
  ///
  /// // Automatic intent-based routing (detects chat intent)
  /// final response = await ai.chat(
  ///   request: ChatRequest(
  ///     messages: [
  ///       Message(role: Role.user, content: 'Hello!'),
  ///     ],
  ///   ),
  /// );
  ///
  /// // Explicit provider selection
  /// final response2 = await ai.chat(
  ///   provider: 'openai',
  ///   request: ChatRequest(
  ///     messages: [
  ///       Message(role: Role.user, content: 'Explain quantum computing'),
  ///     ],
  ///     maxTokens: 500,
  ///   ),
  /// );
  ///
  /// // Automatic routing with image intent detection
  /// final response3 = await ai.chat(
  ///   request: ChatRequest(
  ///     messages: [
  ///       Message(role: Role.user, content: 'Draw a picture of a cat'),
  ///     ],
  ///   ),
  /// );
  /// // Automatically routes to a provider that supports image generation
  /// ```
  Future<ChatResponse> chat({
    String? provider,
    required ChatRequest request,
  }) async {
    // Generate unique request ID for this operation
    final requestId = _generateRequestId();
    final stopwatch = Stopwatch()..start();

    // Emit request telemetry event
    await _emitRequest(requestId, provider, request, 'chat');

    try {
      final response = await _retryHandler.execute(() async {
        // Use router for provider selection (handles explicit provider or intent-based routing)
        final selectedProvider = await _router.route(
          provider ?? _config.defaultProvider,
          request,
        );
        return await selectedProvider.chat(request);
      });

      // Emit response telemetry event
      await _emitResponse(
        requestId,
        stopwatch.elapsed,
        response.usage.totalTokens,
        false, // TODO: Add cache support in future step
        response.provider,
        'chat',
      );

      return response;
    } catch (error) {
      // Emit error telemetry event
      await _emitError(
        requestId,
        error,
        provider,
        'chat',
      );
      rethrow;
    }
  }

  /// Generates a streaming chat completion response.
  ///
  /// Similar to [chat], but returns responses incrementally as they are generated.
  /// This enables real-time UI updates where users see text appear progressively
  /// instead of waiting for the complete response.
  ///
  /// **Streaming Flow:**
  /// The stream emits multiple [ChatStreamEvent] objects:
  /// - Content events: `delta` contains text chunks, `done: false`
  /// - Final event: `delta: null`, `done: true` (may include metadata like usage stats)
  ///
  /// **Parameters:**
  /// - [provider]: Optional provider ID to use. If not specified, the router
  ///   will automatically detect intent from the request and select an appropriate
  ///   provider. The selected provider must support streaming (check [capabilities.supportsStreaming]).
  /// - [request]: The chat request containing messages and generation parameters.
  ///
  /// **Returns:**
  /// A [Stream] of [ChatStreamEvent] objects representing incremental updates.
  ///
  /// **Throws:**
  /// - [ClientError] if explicit provider is specified but not found
  /// - [CapabilityError] if no providers support the chat capability
  /// - [CapabilityError] if the selected provider doesn't support streaming
  /// - [AuthError] if authentication fails
  /// - [QuotaError] if rate limits are exceeded
  /// - [TransientError] for retryable errors
  ///
  /// **Example:**
  /// ```dart
  /// final ai = UnifiedAI.instance;
  ///
  /// // Automatic intent-based routing
  /// final stream = ai.chatStream(
  ///   request: ChatRequest(
  ///     messages: [
  ///       Message(role: Role.user, content: 'Tell me a story'),
  ///     ],
  ///   ),
  /// );
  ///
  /// String accumulatedText = '';
  /// await for (final event in stream) {
  ///   if (event.delta != null) {
  ///     accumulatedText += event.delta!;
  ///     print(event.delta!);  // Print incrementally
  ///   }
  ///
  ///   if (event.done) {
  ///     print('\n\nStream completed!');
  ///     if (event.metadata != null) {
  ///       final usage = event.metadata!['usage'];
  ///       print('Tokens used: ${usage['total_tokens']}');
  ///     }
  ///     break;
  ///   }
  /// }
  ///
  /// // Explicit provider selection
  /// final stream2 = ai.chatStream(
  ///   provider: 'openai',
  ///   request: ChatRequest(
  ///     messages: [
  ///       Message(role: Role.user, content: 'Hello!'),
  ///     ],
  ///   ),
  /// );
  /// ```
  Stream<ChatStreamEvent> chatStream({
    String? provider,
    required ChatRequest request,
  }) async* {
    // Generate unique request ID for this operation
    final requestId = _generateRequestId();
    final stopwatch = Stopwatch()..start();

    // Emit request telemetry event
    await _emitRequest(requestId, provider, request, 'chatStream');

    try {
      // Use router for provider selection (handles explicit provider or intent-based routing)
      final selectedProvider = await _router.route(
        provider ?? _config.defaultProvider,
        request,
      );

      // Validate that the provider supports streaming
      if (!selectedProvider.capabilities.supportsStreaming) {
        throw CapabilityError(
          message:
              'Provider "${selectedProvider.id}" does not support streaming. '
              'Use chat() for non-streaming responses.',
          code: 'STREAMING_NOT_SUPPORTED',
          provider: selectedProvider.id,
        );
      }

      // Get the stream from the provider
      final stream = selectedProvider.chatStream(request);

      // Track if we've seen the final event
      bool streamCompleted = false;
      int? tokensUsed;

      // Yield events from the provider stream
      try {
        await for (final event in stream) {
          // Track metadata from final event
          if (event.done) {
            streamCompleted = true;
            // Extract token usage from metadata if available
            if (event.metadata != null) {
              final usage = event.metadata!['usage'];
              if (usage != null && usage is Map) {
                tokensUsed = usage['total_tokens'] as int?;
              }
            }
          }

          yield event;
        }
      } catch (streamError) {
        // Emit error telemetry event
        await _emitError(
          requestId,
          streamError,
          selectedProvider.id,
          'chatStream',
        );
        rethrow;
      }

      // Emit response telemetry event if stream completed successfully
      if (streamCompleted) {
        await _emitResponse(
          requestId,
          stopwatch.elapsed,
          tokensUsed,
          false, // TODO: Add cache support in future step
          selectedProvider.id,
          'chatStream',
        );
      }
    } catch (error) {
      // Emit error telemetry event
      await _emitError(
        requestId,
        error,
        provider,
        'chatStream',
      );
      rethrow;
    }
  }

  /// Generates embeddings for text inputs using an AI provider.
  ///
  /// This method converts text inputs into vector representations (embeddings)
  /// that capture semantic meaning. It handles provider selection (explicit or
  /// automatic intent-based routing), automatic retries, and error handling.
  ///
  /// **Parameters:**
  /// - [provider]: Optional provider ID to use. If not specified, the router
  ///   will automatically detect intent from the request and select an appropriate
  ///   provider. For [EmbeddingRequest], the intent is always 'embedding'.
  /// - [request]: The embedding request containing text inputs and model parameters.
  ///
  /// **Returns:**
  /// An [EmbeddingResponse] containing the embedding vectors.
  ///
  /// **Throws:**
  /// - [ClientError] if explicit provider is specified but not found
  /// - [CapabilityError] if no providers support the embedding capability
  /// - [CapabilityError] if the selected provider doesn't support embeddings
  /// - [AuthError] if authentication fails (after retries)
  /// - [QuotaError] if rate limits are exceeded (after retries)
  /// - [TransientError] if all retry attempts fail
  ///
  /// **Example:**
  /// ```dart
  /// final ai = UnifiedAI.instance;
  ///
  /// // Automatic intent-based routing (detects embedding intent)
  /// final response = await ai.embed(
  ///   request: EmbeddingRequest(
  ///     inputs: ['Hello, world!', 'How are you?'],
  ///     model: 'text-embedding-3-small',
  ///   ),
  /// );
  ///
  /// // Explicit provider selection
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
    // Generate unique request ID for this operation
    final requestId = _generateRequestId();
    final stopwatch = Stopwatch()..start();

    // Emit request telemetry event
    await _emitRequest(requestId, provider, request, 'embed');

    try {
      final response = await _retryHandler.execute(() async {
        // Use router for provider selection (handles explicit provider or intent-based routing)
        final selectedProvider = await _router.route(
          provider ?? _config.defaultProvider,
          request,
        );
        return await selectedProvider.embed(request);
      });

      // Emit response telemetry event
      await _emitResponse(
        requestId,
        stopwatch.elapsed,
        response.usage?.totalTokens,
        false, // TODO: Add cache support in future step
        response.provider,
        'embed',
      );

      return response;
    } catch (error) {
      // Emit error telemetry event
      await _emitError(
        requestId,
        error,
        provider,
        'embed',
      );
      rethrow;
    }
  }

  /// Generates images from text prompts using an AI provider.
  ///
  /// This method converts text descriptions into images using AI models like
  /// DALL-E, Stable Diffusion, or Midjourney. It handles provider selection
  /// (explicit or automatic intent-based routing), automatic retries, and error handling.
  ///
  /// **Parameters:**
  /// - [provider]: Optional provider ID to use. If not specified, the router
  ///   will automatically detect intent from the request and select an appropriate
  ///   provider. For [ImageRequest], the intent is always 'image_generation'.
  /// - [request]: The image generation request containing prompt and parameters.
  ///
  /// **Returns:**
  /// An [ImageResponse] containing the generated image assets.
  ///
  /// **Throws:**
  /// - [ClientError] if explicit provider is specified but not found
  /// - [CapabilityError] if no providers support the image generation capability
  /// - [CapabilityError] if the selected provider doesn't support image generation
  /// - [AuthError] if authentication fails (after retries)
  /// - [QuotaError] if rate limits are exceeded (after retries)
  /// - [TransientError] if all retry attempts fail
  ///
  /// **Example:**
  /// ```dart
  /// final ai = UnifiedAI.instance;
  ///
  /// // Automatic intent-based routing (detects image_generation intent)
  /// final response = await ai.generateImage(
  ///   request: ImageRequest(
  ///     prompt: 'A beautiful sunset over the ocean',
  ///     size: ImageSize.w1024h1024,
  ///     n: 1,
  ///   ),
  /// );
  ///
  /// // Explicit provider selection
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
    // Generate unique request ID for this operation
    final requestId = _generateRequestId();
    final stopwatch = Stopwatch()..start();

    // Emit request telemetry event
    await _emitRequest(requestId, provider, request, 'image');

    try {
      final response = await _retryHandler.execute(() async {
        // Use router for provider selection (handles explicit provider or intent-based routing)
        final selectedProvider = await _router.route(
          provider ?? _config.defaultProvider,
          request,
        );
        return await selectedProvider.generateImage(request);
      });

      // Emit response telemetry event
      await _emitResponse(
        requestId,
        stopwatch.elapsed,
        null, // Image generation doesn't use tokens
        false, // TODO: Add cache support in future step
        response.provider,
        'image',
      );

      return response;
    } catch (error) {
      // Emit error telemetry event
      await _emitError(
        requestId,
        error,
        provider,
        'image',
      );
      rethrow;
    }
  }

  /// Gets the request router used for provider selection.
  ///
  /// This can be used for advanced use cases where you need to access
  /// the router directly, but typically you should use the high-level
  /// methods like [chat], [embed], and [generateImage] instead.
  ///
  /// **Returns:**
  /// The [RequestRouter] instance used by this SDK.
  RequestRouter get router => _router;

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

  /// Generates a unique request ID for tracking operations.
  ///
  /// The ID format is: `req_<timestamp>_<random>`
  ///
  /// **Returns:**
  /// A unique string identifier for the request.
  String _generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'req_${timestamp}_$random';
  }

  /// Emits a request telemetry event to all registered handlers.
  ///
  /// This method is called at the start of each SDK operation to notify
  /// telemetry handlers that a request has been initiated.
  ///
  /// **Parameters:**
  /// - [requestId]: Unique identifier for this request
  /// - [provider]: Optional provider ID (may be null before routing)
  /// - [request]: The request object (for metadata extraction)
  /// - [operation]: The operation type ('chat', 'embed', 'image')
  ///
  /// **Note:** Errors in telemetry handlers are silently ignored to prevent
  /// affecting SDK operations.
  Future<void> _emitRequest(
    String requestId,
    String? provider,
    dynamic request,
    String operation,
  ) async {
    if (_telemetryHandlers.isEmpty) return;

    // Determine provider - use explicit provider or get from router
    final finalProvider = provider ?? _config.defaultProvider;

    // If still null, we'll use 'unknown' - router will determine actual provider
    final event = RequestTelemetry(
      requestId: requestId,
      provider: finalProvider ?? 'unknown',
      operation: operation,
      metadata: _extractRequestMetadata(request),
    );

    // Emit to all handlers (errors are ignored)
    for (final handler in _telemetryHandlers) {
      try {
        await handler.onRequest(event);
      } on Object {
        // Silently ignore telemetry errors
      }
    }
  }

  /// Emits a response telemetry event to all registered handlers.
  ///
  /// This method is called after a successful SDK operation to notify
  /// telemetry handlers that a response has been received.
  ///
  /// **Parameters:**
  /// - [requestId]: Unique identifier matching the request
  /// - [latency]: Time taken to complete the request
  /// - [tokensUsed]: Number of tokens used (null if not applicable)
  /// - [cached]: Whether response was served from cache
  /// - [provider]: The provider that handled the request
  /// - [operation]: The operation type ('chat', 'embed', 'image')
  ///
  /// **Note:** Errors in telemetry handlers are silently ignored to prevent
  /// affecting SDK operations.
  Future<void> _emitResponse(
    String requestId,
    Duration latency,
    int? tokensUsed,
    bool cached,
    String provider,
    String operation,
  ) async {
    if (_telemetryHandlers.isEmpty) return;

    final event = ResponseTelemetry(
      requestId: requestId,
      latency: latency,
      tokensUsed: tokensUsed,
      cached: cached,
    );

    // Emit to all handlers (errors are ignored)
    for (final handler in _telemetryHandlers) {
      try {
        await handler.onResponse(event);
      } on Object {
        // Silently ignore telemetry errors
      }
    }
  }

  /// Emits an error telemetry event to all registered handlers.
  ///
  /// This method is called when an SDK operation fails to notify
  /// telemetry handlers that an error has occurred.
  ///
  /// **Parameters:**
  /// - [requestId]: Unique identifier matching the request
  /// - [error]: The exception that was thrown
  /// - [provider]: Optional provider ID where the error occurred
  /// - [operation]: The operation type ('chat', 'embed', 'image')
  ///
  /// **Note:** Errors in telemetry handlers are silently ignored to prevent
  /// affecting SDK operations.
  Future<void> _emitError(
    String requestId,
    Object error,
    String? provider,
    String operation,
  ) async {
    if (_telemetryHandlers.isEmpty) return;

    // Try to extract provider from error if it's an AiException
    final finalProvider = provider ??
        (error is AiException ? error.provider : null) ??
        _config.defaultProvider;

    final event = ErrorTelemetry(
      requestId: requestId,
      error: error,
      provider: finalProvider,
      operation: operation,
    );

    // Emit to all handlers (errors are ignored)
    for (final handler in _telemetryHandlers) {
      try {
        await handler.onError(event);
      } on Object {
        // Silently ignore telemetry errors
      }
    }
  }

  /// Extracts metadata from a request object for telemetry.
  ///
  /// Extracts relevant information like model name, parameters, etc.
  /// that can be useful for telemetry and analytics.
  ///
  /// **Parameters:**
  /// - [request]: The request object (ChatRequest, EmbeddingRequest, etc.)
  ///
  /// **Returns:**
  /// A map of metadata, or null if extraction fails.
  Map<String, dynamic>? _extractRequestMetadata(dynamic request) {
    try {
      final metadata = <String, dynamic>{};

      // Extract model if available
      if (request is ChatRequest && request.model != null) {
        metadata['model'] = request.model;
      } else if (request is EmbeddingRequest && request.model != null) {
        metadata['model'] = request.model;
      } else if (request is ImageRequest && request.model != null) {
        metadata['model'] = request.model;
      }

      // Extract other common fields
      if (request is ChatRequest) {
        if (request.maxTokens != null) {
          metadata['maxTokens'] = request.maxTokens;
        }
        if (request.temperature != null) {
          metadata['temperature'] = request.temperature;
        }
        metadata['messageCount'] = request.messages.length;
      } else if (request is EmbeddingRequest) {
        metadata['inputCount'] = request.inputs.length;
      } else if (request is ImageRequest) {
        if (request.size != null) {
          metadata['size'] = request.size.toString();
        }
        if (request.n != null) {
          metadata['n'] = request.n;
        }
      }

      return metadata.isEmpty ? null : metadata;
    } on Object {
      // Return null if extraction fails
      return null;
    }
  }
}
