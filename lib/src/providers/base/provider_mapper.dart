/// Abstract interface for provider-specific mappers.
///
/// This interface defines the contract for converting between unified SDK models
/// and provider-specific API formats. Each provider (OpenAI, Anthropic, etc.)
/// implements this interface to handle their specific conversion logic.
///
/// **Design Pattern:** Strategy Pattern + Adapter Pattern
///
/// This abstraction allows:
/// - Consistent mapper interface across all providers
/// - Easy testing with mock mappers
/// - Dependency injection in providers
/// - Type safety when working with mappers
///
/// **Example usage:**
/// ```dart
/// class OpenAIProvider extends AiProvider {
///   final ProviderMapper _mapper = OpenAIMapper();
///
///   @override
///   Future<ChatResponse> chat(ChatRequest request) async {
///     final providerRequest = _mapper.mapChatRequest(request, defaultModel: 'gpt-4');
///     // Make API call...
///     final providerResponse = /* parse response */;
///     return _mapper.mapChatResponse(providerResponse);
///   }
/// }
/// ```
import 'dart:typed_data';

import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/requests/image_request.dart';
import '../../models/requests/stt_request.dart';
import '../../models/requests/tts_request.dart';
import '../../models/responses/audio_response.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/responses/transcription_response.dart';

/// Abstract interface for converting between unified SDK models and provider-specific formats.
///
/// Each provider implements this interface to handle conversion between:
/// - SDK models (ChatRequest, ChatResponse, etc.) - used by users
/// - Provider-specific models - used for API communication
///
/// **Note:** The return types are `dynamic` because each provider has different
/// provider-specific model types. The implementing classes should document
/// their specific return types.
abstract class ProviderMapper {
  /// Converts a unified [ChatRequest] to a provider-specific request format.
  ///
  /// This method handles:
  /// - Converting SDK models to provider-specific format
  /// - Extracting provider-specific options from [providerOptions]
  /// - Handling default model selection
  ///
  /// **Parameters:**
  /// - [request]: The unified SDK chat request
  /// - [defaultModel]: Optional default model to use if request.model is null
  ///
  /// **Returns:**
  /// A provider-specific request object ready to be sent to the provider's API
  ///
  /// **Throws:**
  /// - [ClientError] if the request is invalid or missing required fields
  dynamic mapChatRequest(ChatRequest request, {String? defaultModel});

  /// Converts a provider-specific chat response to a unified [ChatResponse].
  ///
  /// This method handles:
  /// - Converting provider-specific response format to SDK models
  /// - Normalizing response structure
  /// - Setting provider identifier
  ///
  /// **Parameters:**
  /// - [response]: The provider-specific response object (from API)
  ///
  /// **Returns:**
  /// A unified [ChatResponse] that can be used by SDK users
  ChatResponse mapChatResponse(dynamic response);

  /// Converts a unified [EmbeddingRequest] to a provider-specific request format.
  ///
  /// **Parameters:**
  /// - [request]: The unified SDK embedding request
  /// - [defaultModel]: Optional default model to use if request.model is null
  ///
  /// **Returns:**
  /// A provider-specific request object ready to be sent to the provider's API
  ///
  /// **Throws:**
  /// - [ClientError] if the request is invalid or missing required fields
  dynamic mapEmbeddingRequest(EmbeddingRequest request, {String? defaultModel});

  /// Converts a provider-specific embedding response to a unified [EmbeddingResponse].
  ///
  /// **Parameters:**
  /// - [response]: The provider-specific response object (from API)
  ///
  /// **Returns:**
  /// A unified [EmbeddingResponse] that can be used by SDK users
  EmbeddingResponse mapEmbeddingResponse(dynamic response);

  /// Converts a unified [ImageRequest] to a provider-specific request format.
  ///
  /// This method handles:
  /// - Converting SDK models to provider-specific format
  /// - Extracting provider-specific options from [providerOptions]
  /// - Handling default model selection
  /// - Converting image size enums to API format
  ///
  /// **Parameters:**
  /// - [request]: The unified SDK image request
  /// - [defaultModel]: Optional default model to use if request.model is null
  ///
  /// **Returns:**
  /// A provider-specific request object ready to be sent to the provider's API
  ///
  /// **Throws:**
  /// - [ClientError] if the request is invalid or missing required fields
  dynamic mapImageRequest(ImageRequest request, {String? defaultModel});

  /// Converts a provider-specific image response to a unified [ImageResponse].
  ///
  /// This method handles:
  /// - Converting provider-specific response format to SDK models
  /// - Normalizing response structure
  /// - Setting provider identifier
  /// - Handling both URL and base64 image formats
  ///
  /// **Parameters:**
  /// - [response]: The provider-specific response object (from API)
  ///
  /// **Returns:**
  /// A unified [ImageResponse] that can be used by SDK users
  ImageResponse mapImageResponse(dynamic response);

  /// Converts a unified [TtsRequest] to a provider-specific request format.
  ///
  /// **Parameters:**
  /// - [request]: The unified SDK TTS request
  /// - [defaultModel]: Optional default model to use if request.model is null
  ///
  /// **Returns:**
  /// A provider-specific request object ready to be sent to the provider's API
  ///
  /// **Throws:**
  /// - [ClientError] if the request is invalid or missing required fields
  dynamic mapTtsRequest(TtsRequest request, {String? defaultModel});

  /// Converts a provider-specific TTS response to unified [AudioResponse].
  ///
  /// **Parameters:**
  /// - [response]: The HTTP response containing audio bytes
  /// - [audioBytes]: The audio data as bytes
  /// - [request]: The original TTS request (for metadata)
  ///
  /// **Returns:**
  /// A unified [AudioResponse] that can be used by SDK users
  AudioResponse mapTtsResponse(
      dynamic response, Uint8List audioBytes, TtsRequest request);

  /// Converts a unified [SttRequest] to a provider-specific request format.
  ///
  /// **Parameters:**
  /// - [request]: The unified SDK STT request
  /// - [defaultModel]: Optional default model to use if request.model is null
  ///
  /// **Returns:**
  /// A provider-specific request object ready to be sent to the provider's API
  ///
  /// **Throws:**
  /// - [ClientError] if the request is invalid or missing required fields
  dynamic mapSttRequest(SttRequest request, {String? defaultModel});

  /// Converts a provider-specific STT response to unified [TranscriptionResponse].
  ///
  /// **Parameters:**
  /// - [response]: The provider-specific response object (from API)
  /// - [request]: The original STT request (for metadata)
  ///
  /// **Returns:**
  /// A unified [TranscriptionResponse] that can be used by SDK users
  TranscriptionResponse mapSttResponse(dynamic response, SttRequest request);
}
