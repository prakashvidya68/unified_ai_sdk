/// Mapper for converting between unified SDK models and xAI-specific models.
///
/// This class provides bidirectional conversion between the provider-agnostic
/// SDK models ([ChatRequest], [ChatResponse], [ImageRequest], [ImageResponse])
/// and xAI-specific models ([XAIChatRequest], [XAIChatResponse], etc.).

import '../../error/error_types.dart';
import '../../models/common/message.dart';
import '../../models/common/usage.dart';
import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/requests/image_request.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/base_enums.dart';
import '../base/provider_mapper.dart';
import 'xai_models.dart';

/// Mapper for converting between unified SDK models and xAI-specific models.
///
/// Implements [ProviderMapper] to provide xAI-specific conversion logic.
/// This class uses a singleton pattern and provides instance methods for
/// converting between unified SDK models and xAI-specific formats.
class XAIMapper implements ProviderMapper {
  /// Private constructor to enforce singleton pattern.
  XAIMapper._();

  /// Singleton instance for instance-based usage.
  static final XAIMapper instance = XAIMapper._();

  @override
  XAIChatRequest mapChatRequest(ChatRequest request, {String? defaultModel}) {
    return _mapChatRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  ChatResponse mapChatResponse(dynamic response) {
    if (response is! XAIChatResponse) {
      throw ArgumentError(
          'Expected XAIChatResponse, got ${response.runtimeType}');
    }
    return _mapChatResponseImpl(response);
  }

  @override
  dynamic mapEmbeddingRequest(EmbeddingRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'xAI does not support embeddings',
      code: 'EMBEDDING_NOT_SUPPORTED',
      provider: 'xai',
    );
  }

  @override
  EmbeddingResponse mapEmbeddingResponse(dynamic response) {
    throw CapabilityError(
      message: 'xAI does not support embeddings',
      code: 'EMBEDDING_NOT_SUPPORTED',
      provider: 'xai',
    );
  }

  @override
  XAIImageRequest mapImageRequest(ImageRequest request, {String? defaultModel}) {
    return _mapImageRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  ImageResponse mapImageResponse(dynamic response) {
    if (response is! XAIImageResponse) {
      throw ArgumentError(
          'Expected XAIImageResponse, got ${response.runtimeType}');
    }
    return _mapImageResponseImpl(response);
  }

  // Private implementation methods

  XAIChatRequest _mapChatRequestImpl(
    ChatRequest request, {
    String? defaultModel,
  }) {
    // Convert Message objects to xAI message format
    final messages = request.messages.map((msg) {
      final messageMap = <String, dynamic>{
        'role': _mapRoleToXAI(msg.role),
        'content': msg.content,
      };
      if (msg.name != null) {
        messageMap['name'] = msg.name;
      }
      // Merge any metadata into the message
      if (msg.meta != null) {
        messageMap.addAll(msg.meta!);
      }
      return messageMap;
    }).toList();

    // Extract xAI-specific options from providerOptions
    final xaiOptions =
        request.providerOptions?['xai'] ?? <String, dynamic>{};

    // Determine model - use request.model, then defaultModel, or throw error
    final model = request.model ?? defaultModel;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in ChatRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Build xAI request
    return XAIChatRequest(
      model: model,
      messages: messages,
      temperature: request.temperature,
      maxTokens: request.maxTokens,
      topP: request.topP,
      n: request.n,
      stop: request.stop,
      user: request.user ?? xaiOptions['user'] as String?,
      stream: xaiOptions['stream'] as bool?,
    );
  }

  ChatResponse _mapChatResponseImpl(XAIChatResponse response) {
    // Convert xAI choices to SDK choices
    final choices = response.choices.map((choice) {
      // Convert xAI message map to Message object
      final messageMap = choice.message;
      final role = _mapRoleFromXAI(messageMap['role'] as String);
      final content = messageMap['content'] as String? ?? '';

      // Extract name if present
      final name = messageMap['name'] as String?;

      // Extract any additional fields as metadata
      final meta = <String, dynamic>{};
      messageMap.forEach((key, value) {
        if (key != 'role' && key != 'content' && key != 'name') {
          meta[key] = value;
        }
      });

      final message = Message(
        role: role,
        content: content,
        name: name,
        meta: meta.isEmpty ? null : meta,
      );

      return ChatChoice(
        index: choice.index,
        message: message,
        finishReason: choice.finishReason,
      );
    }).toList();

    // Convert xAI usage to SDK usage
    final usage = Usage(
      promptTokens: response.usage.promptTokens,
      completionTokens: response.usage.completionTokens,
      totalTokens: response.usage.totalTokens,
    );

    // Convert timestamp from Unix seconds to DateTime
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(response.created * 1000);

    // Build metadata from xAI-specific fields
    final metadata = <String, dynamic>{
      'object': response.object,
      'created': response.created,
    };

    return ChatResponse(
      id: response.id,
      choices: choices,
      usage: usage,
      model: response.model,
      provider: 'xai',
      timestamp: timestamp,
      metadata: metadata,
    );
  }

  /// Maps SDK [Role] enum to xAI role string.
  ///
  /// xAI uses lowercase strings: "system", "user", "assistant"
  String _mapRoleToXAI(Role role) {
    switch (role) {
      case Role.system:
        return 'system';
      case Role.user:
        return 'user';
      case Role.assistant:
        return 'assistant';
      case Role.function:
        return 'assistant'; // xAI doesn't have a function role, use assistant
    }
  }

  /// Maps xAI role string to SDK [Role] enum.
  ///
  /// Handles xAI's role strings: "system", "user", "assistant"
  Role _mapRoleFromXAI(String role) {
    switch (role.toLowerCase()) {
      case 'system':
        return Role.system;
      case 'user':
        return Role.user;
      case 'assistant':
        return Role.assistant;
      default:
        throw ClientError(
          message: 'Unknown xAI role: $role',
          code: 'INVALID_ROLE',
        );
    }
  }


  /// Maps SDK [ImageRequest] to xAI image generation request format.
  XAIImageRequest _mapImageRequestImpl(
    ImageRequest request, {
    String? defaultModel,
  }) {
    // Determine model - default to flux-pro if not specified
    final model = request.model ?? defaultModel ?? 'flux-pro';

    // Convert ImageSize enum to string format
    String? sizeString;
    if (request.size != null) {
      sizeString = request.size!.toString(); // Already in "WIDTHxHEIGHT" format
    }

    // Extract xAI-specific options
    final xaiOptions =
        request.providerOptions?['xai'] ?? <String, dynamic>{};

    return XAIImageRequest(
      prompt: request.prompt,
      model: model,
      n: request.n,
      size: sizeString,
      quality: request.quality ?? xaiOptions['quality'] as String?,
      style: request.style ?? xaiOptions['style'] as String?,
      responseFormat: xaiOptions['response_format'] as String? ??
          xaiOptions['responseFormat'] as String?,
    );
  }

  /// Maps xAI image generation response to SDK [ImageResponse].
  ImageResponse _mapImageResponseImpl(XAIImageResponse response) {
    // Convert xAI image data to SDK ImageAsset
    final assets = response.data.map((imageData) {
      return ImageAsset(
        url: imageData.url,
        base64: imageData.b64Json,
        revisedPrompt: imageData.revisedPrompt,
      );
    }).toList();

    // Extract model from response (if available) or use default
    // xAI may not return the model in the response, so we'll use a default
    final model = 'flux-pro'; // Default, could be enhanced to track from request

    // Build metadata from xAI-specific fields
    final metadata = <String, dynamic>{
      'created': response.created,
    };

    return ImageResponse(
      assets: assets,
      model: model,
      provider: 'xai',
      metadata: metadata,
    );
  }
}

