/// Mapper for converting between unified SDK models and xAI-specific models.
///
/// This class provides bidirectional conversion between the provider-agnostic
/// SDK models ([ChatRequest], [ChatResponse], [ImageRequest], [ImageResponse])
/// and xAI-specific models ([XAIChatRequest], [XAIChatResponse], etc.).

import 'dart:typed_data';

import '../../error/error_types.dart';
import '../../models/common/message.dart';
import '../../models/common/usage.dart';
import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/requests/image_request.dart';
import '../../models/requests/stt_request.dart';
import '../../models/requests/tts_request.dart';
import '../../models/requests/video_analysis_request.dart';
import '../../models/requests/video_request.dart';
import '../../models/responses/audio_response.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/responses/transcription_response.dart';
import '../../models/responses/video_analysis_response.dart';
import '../../models/responses/video_response.dart';
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
  dynamic mapEmbeddingRequest(EmbeddingRequest request,
      {String? defaultModel}) {
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
  XAIImageRequest mapImageRequest(ImageRequest request,
      {String? defaultModel}) {
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
    final xaiOptions = request.providerOptions?['xai'] ?? <String, dynamic>{};

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
    // Determine model - default to grok-2-image-1212 if not specified
    final model = request.model ?? defaultModel ?? 'grok-2-image-1212';

    // Convert ImageSize enum to string format
    String? sizeString;
    if (request.size != null) {
      sizeString = request.size!.toString(); // Already in "WIDTHxHEIGHT" format
    }

    // Extract xAI-specific options
    final xaiOptions = request.providerOptions?['xai'] ?? <String, dynamic>{};

    // Note: xAI API only supports: prompt, model, n, and response_format.
    // We store size, quality, and style for SDK compatibility but they won't
    // be sent to the API (excluded in toJson()).
    // xAI REST API uses 'response_format' (Python SDK uses 'image_format' as alias).
    return XAIImageRequest(
      prompt: request.prompt,
      model: model,
      n: request.n,
      size: sizeString,
      quality: request.quality ?? xaiOptions['quality'] as String?,
      style: request.style ?? xaiOptions['style'] as String?,
      responseFormat: xaiOptions['response_format'] as String? ??
          xaiOptions['responseFormat'] as String? ??
          xaiOptions['image_format'] as String? ??
          xaiOptions['imageFormat'] as String?,
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
    final model =
        'grok-2-image-1212'; // Default, could be enhanced to track from request

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

  @override
  dynamic mapTtsRequest(TtsRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'xAI does not support text-to-speech',
      code: 'TTS_NOT_SUPPORTED',
      provider: 'xai',
    );
  }

  @override
  AudioResponse mapTtsResponse(
    dynamic response,
    Uint8List audioBytes,
    TtsRequest request,
  ) {
    throw CapabilityError(
      message: 'xAI does not support text-to-speech',
      code: 'TTS_NOT_SUPPORTED',
      provider: 'xai',
    );
  }

  @override
  dynamic mapSttRequest(SttRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'xAI does not support speech-to-text',
      code: 'STT_NOT_SUPPORTED',
      provider: 'xai',
    );
  }

  @override
  TranscriptionResponse mapSttResponse(
    dynamic response,
    SttRequest request,
  ) {
    throw CapabilityError(
      message: 'xAI does not support speech-to-text',
      code: 'STT_NOT_SUPPORTED',
      provider: 'xai',
    );
  }

  @override
  dynamic mapVideoRequest(VideoRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'xAI does not support video generation',
      code: 'VIDEO_GENERATION_NOT_SUPPORTED',
      provider: 'xai',
    );
  }

  @override
  VideoResponse mapVideoResponse(dynamic response) {
    throw CapabilityError(
      message: 'xAI does not support video generation',
      code: 'VIDEO_GENERATION_NOT_SUPPORTED',
      provider: 'xai',
    );
  }

  @override
  XAIChatRequest mapVideoAnalysisRequest(
    VideoAnalysisRequest request, {
    String? defaultModel,
  }) {
    // Determine model - default to grok-2-vision-1212 if not specified
    // For cost efficiency, could also use grok-4-fast-reasoning
    final model = request.model ?? defaultModel ?? 'grok-2-vision-1212';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in VideoAnalysisRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Extract xAI-specific options
    final xaiOptions = request.providerOptions?['xai'] ?? <String, dynamic>{};

    // Build messages for video analysis
    // xAI uses chat completions with video content in messages
    final messages = <Map<String, dynamic>>[];

    // Build user message with video content
    final content = <Map<String, dynamic>>[];

    // Add text prompt if provided via features or as a prompt
    final promptText = xaiOptions['prompt'] as String? ??
        (request.features != null && request.features!.isNotEmpty
            ? 'Analyze this video and extract: ${request.features!.join(", ")}'
            : 'Analyze this video and provide a detailed description.');

    if (promptText.isNotEmpty) {
      content.add({
        'type': 'text',
        'text': promptText,
      });
    }

    // Add video content
    if (request.videoUrl != null) {
      content.add({
        'type': 'video_url',
        'video_url': {
          'url': request.videoUrl,
        },
      });
    } else if (request.videoBase64 != null) {
      // For base64, we need to format it as data URL
      final mimeType = xaiOptions['mime_type'] as String? ?? 'video/mp4';
      content.add({
        'type': 'video_url',
        'video_url': {
          'url': 'data:$mimeType;base64,${request.videoBase64}',
        },
      });
    }

    if (content.isEmpty) {
      throw ClientError(
        message: 'Either videoUrl or videoBase64 must be provided',
        code: 'MISSING_VIDEO',
      );
    }

    messages.add({
      'role': 'user',
      'content': content,
    });

    // Build xAI request (similar to chat request but with video content)
    return XAIChatRequest(
      model: model,
      messages: messages,
      temperature: request.confidenceThreshold != null
          ? 1.0 - request.confidenceThreshold!
          : (xaiOptions['temperature'] as double?),
      maxTokens:
          xaiOptions['max_tokens'] as int? ?? xaiOptions['maxTokens'] as int?,
      topP: xaiOptions['top_p'] as double? ?? xaiOptions['topP'] as double?,
      user: xaiOptions['user'] as String?,
    );
  }

  @override
  VideoAnalysisResponse mapVideoAnalysisResponse(dynamic response) {
    if (response is! XAIChatResponse) {
      throw ArgumentError(
        'Expected XAIChatResponse, got ${response.runtimeType}',
      );
    }

    // Extract analysis text from the first choice
    String analysisText = '';
    if (response.choices.isNotEmpty) {
      final firstChoice = response.choices.first;
      final message = firstChoice.message;
      final content = message['content'] as String?;
      if (content != null) {
        analysisText = content;
      }
    }

    // Parse the analysis text to extract structured information
    // This is a simplified implementation - in practice, you might want to
    // use structured output or parse the text more intelligently
    final objects = <DetectedObject>[];
    final scenes = <DetectedScene>[];
    final actions = <DetectedAction>[];
    final text = <ExtractedText>[];
    final labels = <String>[];

    // Basic parsing - extract labels from the analysis text
    if (analysisText.isNotEmpty) {
      // Extract potential labels (simple heuristic)
      final words = analysisText.split(RegExp(r'[.,;!?\s]+'));
      for (final word in words) {
        if (word.length > 3 && word[0].toUpperCase() == word[0]) {
          labels.add(word);
        }
      }

      // If no labels found, add the full text as a label
      if (labels.isEmpty && analysisText.length < 100) {
        labels.add(analysisText);
      }
    }

    // Build metadata from xAI-specific fields
    final metadata = <String, dynamic>{
      'id': response.id,
      'object': response.object,
      'created': response.created,
      'analysis_text': analysisText,
      'usage': {
        'prompt_tokens': response.usage.promptTokens,
        'completion_tokens': response.usage.completionTokens,
        'total_tokens': response.usage.totalTokens,
      },
    };

    return VideoAnalysisResponse(
      objects: objects,
      scenes: scenes,
      actions: actions,
      text: text,
      labels: labels,
      model: response.model,
      provider: 'xai',
      timestamp: DateTime.fromMillisecondsSinceEpoch(response.created * 1000),
      metadata: metadata,
    );
  }
}
