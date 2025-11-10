import '../../core/provider_config.dart';
import '../../error/error_types.dart';
import '../../models/common/capabilities.dart';
import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/requests/image_request.dart';
import '../../models/requests/stt_request.dart';
import '../../models/requests/tts_request.dart';
import '../../models/responses/audio_response.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/chat_stream_event.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/responses/transcription_response.dart';

/// Base interface for all AI providers.
///
/// This abstract class defines the contract that all AI providers must implement.
/// It provides a unified API for interacting with different AI services (OpenAI,
/// Anthropic, Google, etc.) while allowing each provider to implement the
/// details of their specific API.
///
/// **Design Principles:**
/// - **Provider-agnostic**: All providers implement the same interface
/// - **Capability-based**: Providers declare what they support via [capabilities]
/// - **Error handling**: All methods throw [AiException] subtypes
/// - **Optional features**: Methods like [chatStream] are optional and can return null
///
/// **Example usage:**
/// ```dart
/// class MyProvider extends AiProvider {
///   @override
///   String get id => 'my-provider';
///
///   @override
///   String get name => 'My AI Provider';
///
///   @override
///   ProviderCapabilities get capabilities => ProviderCapabilities(
///     supportsChat: true,
///     supportsEmbedding: true,
///   );
///
///   @override
///   Future<void> init(ProviderConfig config) async {
///     // Initialize provider with config
///   }
///
///   @override
///   Future<ChatResponse> chat(ChatRequest request) async {
///     // Implement chat functionality
///   }
/// }
/// ```
abstract class AiProvider {
  /// Unique identifier for this provider.
  ///
  /// Used internally to reference the provider. Should be lowercase, kebab-case
  /// or snake_case. Examples: 'openai', 'anthropic', 'google-gemini', 'cohere'
  ///
  /// Must be unique across all registered providers.
  String get id;

  /// Human-readable name for this provider.
  ///
  /// Display name for the provider. Examples: 'OpenAI', 'Anthropic Claude',
  /// 'Google Gemini', 'Cohere'
  String get name;

  /// Capabilities supported by this provider.
  ///
  /// Defines what operations this provider can perform. Used by the SDK to
  /// validate requests and route operations to appropriate providers.
  ///
  /// **Example:**
  /// ```dart
  /// ProviderCapabilities(
  ///   supportsChat: true,
  ///   supportsEmbedding: true,
  ///   supportsStreaming: true,
  ///   supportedModels: ['gpt-4', 'gpt-3.5-turbo'],
  /// )
  /// ```
  ProviderCapabilities get capabilities;

  /// Initializes the provider with configuration.
  ///
  /// Called once when the provider is registered. Should perform any necessary
  /// setup such as:
  /// - Validating authentication credentials
  /// - Setting up HTTP clients
  /// - Configuring base URLs
  /// - Loading provider-specific settings
  ///
  /// **Parameters:**
  /// - [config]: Provider configuration containing authentication, settings, etc.
  ///
  /// **Throws:**
  /// - [AuthError] if authentication is invalid
  /// - [ClientError] if configuration is invalid
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<void> init(ProviderConfig config) async {
  ///   _apiKey = (config.auth as ApiKeyAuth).apiKey;
  ///   _baseUrl = config.settings['baseUrl'] ?? 'https://api.example.com';
  ///   // Perform initialization
  /// }
  /// ```
  Future<void> init(ProviderConfig config);

  /// Generates a chat completion response.
  ///
  /// Sends a conversation to the AI model and returns the generated response.
  /// This is the primary method for text generation and conversational AI.
  ///
  /// **Parameters:**
  /// - [request]: The chat request containing messages and generation parameters
  ///
  /// **Returns:**
  /// A [ChatResponse] containing the generated text and metadata
  ///
  /// **Throws:**
  /// - [CapabilityError] if provider doesn't support chat (check [capabilities.supportsChat])
  /// - [AuthError] if authentication fails
  /// - [QuotaError] if rate limit is exceeded
  /// - [TransientError] for retryable errors
  /// - [ClientError] for invalid requests
  ///
  /// **Example:**
  /// ```dart
  /// final request = ChatRequest(
  ///   messages: [
  ///     Message(role: Role.user, content: 'Hello!'),
  ///   ],
  /// );
  /// final response = await provider.chat(request);
  /// print(response.choices.first.message.content);
  /// ```
  Future<ChatResponse> chat(ChatRequest request);

  /// Generates a streaming chat completion response.
  ///
  /// Similar to [chat], but returns responses incrementally as they are generated.
  /// Useful for real-time UI updates where users see text appear progressively.
  ///
  /// **Streaming Flow:**
  /// The stream emits multiple [ChatStreamEvent] objects:
  /// - Content events: `delta` contains text chunks, `done: false`
  /// - Final event: `delta: null`, `done: true` (may include metadata like usage stats)
  ///
  /// **Parameters:**
  /// - [request]: The chat request containing messages and generation parameters
  ///
  /// **Returns:**
  /// A [Stream] of [ChatStreamEvent] objects. The default implementation throws
  /// [UnsupportedError] if streaming is not supported. Providers should override
  /// this method to provide streaming support.
  ///
  /// **Throws:**
  /// - [UnsupportedError] if streaming is not supported (default implementation)
  /// - [CapabilityError] if streaming is requested but not supported (check [capabilities.supportsStreaming])
  /// - Same exceptions as [chat] for authentication, quota, and other errors
  ///
  /// **Note:**
  /// - Check [capabilities.supportsStreaming] before calling this method
  /// - Providers that support streaming must override this method
  /// - The default implementation throws [UnsupportedError] to make it clear
  ///   that streaming must be explicitly implemented
  ///
  /// **Example:**
  /// ```dart
  /// if (provider.capabilities.supportsStreaming) {
  ///   final stream = provider.chatStream(request);
  ///   await for (final event in stream) {
  ///     if (event.delta != null) {
  ///       print(event.delta);  // Print incremental text
  ///     }
  ///     if (event.done) {
  ///       print('Stream completed');
  ///       if (event.metadata != null) {
  ///         print('Usage: ${event.metadata!['usage']}');
  ///       }
  ///       break;
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// **Provider Implementation:**
  /// ```dart
  /// @override
  /// Stream<ChatStreamEvent> chatStream(ChatRequest request) async* {
  ///   // Validate capability
  ///   validateCapability('streaming');
  ///
  ///   // Make streaming request
  ///   final stream = await _makeStreamingRequest(request);
  ///
  ///   // Parse and yield events
  ///   await for (final chunk in stream) {
  ///     final event = _parseStreamChunk(chunk);
  ///     if (event != null) {
  ///       yield event;
  ///     }
  ///   }
  ///
  ///   // Yield final event
  ///   yield ChatStreamEvent(delta: null, done: true);
  /// }
  /// ```
  Stream<ChatStreamEvent> chatStream(ChatRequest request) {
    throw UnsupportedError(
      'Streaming not supported by provider $id. '
      'Override chatStream() to provide streaming support.',
    );
  }

  /// Generates embeddings for the given text inputs.
  ///
  /// Converts text into vector representations that capture semantic meaning.
  /// Embeddings are useful for semantic search, similarity matching, and clustering.
  ///
  /// **Parameters:**
  /// - [request]: The embedding request containing text inputs
  ///
  /// **Returns:**
  /// An [EmbeddingResponse] containing the vector embeddings
  ///
  /// **Throws:**
  /// - [CapabilityError] if provider doesn't support embeddings (check [capabilities.supportsEmbedding])
  /// - Same exceptions as [chat] for authentication, quota, and other errors
  ///
  /// **Example:**
  /// ```dart
  /// final request = EmbeddingRequest(
  ///   inputs: ['Hello world', 'How are you?'],
  ///   model: 'text-embedding-3-small',
  /// );
  /// final response = await provider.embed(request);
  /// final vectors = response.embeddings;
  /// ```
  Future<EmbeddingResponse> embed(EmbeddingRequest request);

  /// Generates an image from a text prompt.
  ///
  /// Creates images using text-to-image models like DALL-E, Stable Diffusion, etc.
  ///
  /// **Parameters:**
  /// - [request]: The image generation request containing prompt and parameters
  ///
  /// **Returns:**
  /// An [ImageResponse] containing the generated image(s)
  ///
  /// **Throws:**
  /// - [CapabilityError] if provider doesn't support image generation (check [capabilities.supportsImageGeneration])
  /// - Same exceptions as [chat] for authentication, quota, and other errors
  ///
  /// **Example:**
  /// ```dart
  /// final request = ImageRequest(
  ///   prompt: 'A beautiful sunset over mountains',
  ///   size: ImageSize.w1024h1024,
  /// );
  /// final response = await provider.generateImage(request);
  /// final imageUrl = response.assets.first.url;
  /// ```
  Future<ImageResponse> generateImage(ImageRequest request);

  /// Converts text to speech audio.
  ///
  /// Generates audio from text using text-to-speech models.
  ///
  /// **Parameters:**
  /// - [request]: The TTS request containing text and voice parameters
  ///
  /// **Returns:**
  /// An [AudioResponse] containing the generated audio bytes
  ///
  /// **Throws:**
  /// - [CapabilityError] if provider doesn't support TTS (check [capabilities.supportsTTS])
  /// - Same exceptions as [chat] for authentication, quota, and other errors
  ///
  /// **Example:**
  /// ```dart
  /// final request = TtsRequest(
  ///   text: 'Hello, world!',
  ///   voice: 'alloy',
  /// );
  /// final response = await provider.tts(request);
  /// await File('output.mp3').writeAsBytes(response.bytes);
  /// ```
  Future<AudioResponse> tts(TtsRequest request);

  /// Converts speech to text (transcription).
  ///
  /// Transcribes audio recordings into text using speech-to-text models.
  ///
  /// **Parameters:**
  /// - [request]: The STT request containing audio data and transcription parameters
  ///
  /// **Returns:**
  /// A [TranscriptionResponse] containing the transcribed text and metadata
  ///
  /// **Throws:**
  /// - [CapabilityError] if provider doesn't support STT (check [capabilities.supportsSTT])
  /// - Same exceptions as [chat] for authentication, quota, and other errors
  ///
  /// **Example:**
  /// ```dart
  /// final audioBytes = File('recording.mp3').readAsBytesSync();
  /// final request = SttRequest(
  ///   audio: Uint8List.fromList(audioBytes),
  ///   language: 'en',
  /// );
  /// final response = await provider.stt(request);
  /// print(response.text);
  /// ```
  Future<TranscriptionResponse> stt(SttRequest request);

  /// Performs a health check on the provider.
  ///
  /// Optional method to verify that the provider is accessible and functioning.
  /// Can be used for monitoring, diagnostics, or determining provider availability.
  ///
  /// **Returns:**
  /// `true` if the provider is healthy and accessible, `false` otherwise.
  ///
  /// **Note:**
  /// Default implementation returns `true`. Providers can override to perform
  /// actual health checks (e.g., ping endpoint, verify credentials).
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<bool> healthCheck() async {
  ///   try {
  ///     final response = await _http.get('$_baseUrl/health');
  ///     return response.statusCode == 200;
  ///   } catch (_) {
  ///     return false;
  ///   }
  /// }
  /// ```
  Future<bool> healthCheck() async {
    return true;
  }

  /// Cleans up resources used by the provider.
  ///
  /// Called when the provider is being removed or the SDK is shutting down.
  /// Should close HTTP clients, cancel ongoing requests, and release resources.
  ///
  /// **Note:**
  /// Default implementation does nothing. Providers should override to clean up
  /// resources like HTTP clients, streams, timers, etc.
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<void> dispose() async {
  ///   _httpClient.close();
  ///   await _streamController.close();
  /// }
  /// ```
  Future<void> dispose() async {
    // Default: no cleanup needed
  }

  /// Validates that the provider supports the requested operation.
  ///
  /// Helper method to check capabilities before attempting operations.
  /// Throws [CapabilityError] if the operation is not supported.
  ///
  /// **Parameters:**
  /// - [operation]: The operation name ('chat', 'embed', 'image', 'tts', 'stt', 'streaming')
  ///
  /// **Throws:**
  /// - [CapabilityError] if the operation is not supported
  ///
  /// **Example:**
  /// ```dart
  /// void someMethod() {
  ///   validateCapability('chat');
  ///   // Now safe to call chat()
  /// }
  /// ```
  void validateCapability(String operation) {
    switch (operation) {
      case 'chat':
        if (!capabilities.supportsChat) {
          throw CapabilityError(
            message: 'Provider $id does not support chat',
            code: 'CHAT_NOT_SUPPORTED',
            provider: id,
          );
        }
        break;
      case 'embed':
      case 'embedding':
        if (!capabilities.supportsEmbedding) {
          throw CapabilityError(
            message: 'Provider $id does not support embeddings',
            code: 'EMBEDDING_NOT_SUPPORTED',
            provider: id,
          );
        }
        break;
      case 'image':
      case 'imageGeneration':
        if (!capabilities.supportsImageGeneration) {
          throw CapabilityError(
            message: 'Provider $id does not support image generation',
            code: 'IMAGE_GENERATION_NOT_SUPPORTED',
            provider: id,
          );
        }
        break;
      case 'tts':
        if (!capabilities.supportsTTS) {
          throw CapabilityError(
            message: 'Provider $id does not support text-to-speech',
            code: 'TTS_NOT_SUPPORTED',
            provider: id,
          );
        }
        break;
      case 'stt':
        if (!capabilities.supportsSTT) {
          throw CapabilityError(
            message: 'Provider $id does not support speech-to-text',
            code: 'STT_NOT_SUPPORTED',
            provider: id,
          );
        }
        break;
      case 'streaming':
        if (!capabilities.supportsStreaming) {
          throw CapabilityError(
            message: 'Provider $id does not support streaming',
            code: 'STREAMING_NOT_SUPPORTED',
            provider: id,
          );
        }
        break;
      default:
        // Unknown operation - don't throw, let provider handle it
        break;
    }
  }
}
