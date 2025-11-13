/// Mapper for converting between unified SDK models and OpenAI-specific models.
///
/// This class provides bidirectional conversion between the provider-agnostic
/// SDK models ([ChatRequest], [ChatResponse], [EmbeddingRequest], [EmbeddingResponse])
/// and OpenAI-specific models ([OpenAIChatRequest], [OpenAIChatResponse], etc.).
///
/// **Design Pattern:** Adapter/Mapper Pattern
///
/// This mapper allows the SDK to maintain a unified API while supporting
/// provider-specific features and formats. Users interact with unified models,
/// but internally the SDK converts to/from provider-specific formats.
///
/// **Example usage:**
/// ```dart
/// // SDK → OpenAI
/// final chatRequest = ChatRequest(
///   messages: [Message(role: Role.user, content: 'Hello!')],
///   temperature: 0.7,
/// );
/// final mapper = OpenAIMapper.instance;
/// final openaiRequest = mapper.mapChatRequest(chatRequest);
///
/// // OpenAI → SDK
/// final openaiResponse = OpenAIChatResponse.fromJson(apiResponse);
/// final chatResponse = mapper.mapChatResponse(openaiResponse);
/// ```

import 'dart:typed_data';

import 'package:http/http.dart' as http;

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
import 'openai_models.dart';

/// Mapper for converting between unified SDK models and OpenAI-specific models.
///
/// Implements [ProviderMapper] to provide OpenAI-specific conversion logic.
/// This class uses a singleton pattern and provides instance methods for
/// converting between unified SDK models and OpenAI-specific formats.
///
/// **Usage:**
/// ```dart
/// final mapper = OpenAIMapper.instance;
/// final request = mapper.mapChatRequest(chatRequest);
/// final response = mapper.mapChatResponse(openaiResponse);
/// ```
///
class OpenAIMapper implements ProviderMapper {
  /// Private constructor to enforce singleton pattern.
  /// Use [OpenAIMapper.instance] to access the mapper instance.
  OpenAIMapper._();

  /// Singleton instance for instance-based usage.
  ///
  /// Use this when you need to inject the mapper as a dependency or
  /// when working with the [ProviderMapper] interface.
  static final OpenAIMapper instance = OpenAIMapper._();

  // Instance methods implementing ProviderMapper interface

  @override
  OpenAIChatRequest mapChatRequest(ChatRequest request,
      {String? defaultModel}) {
    return _mapChatRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  ChatResponse mapChatResponse(dynamic response) {
    if (response is! OpenAIChatResponse) {
      throw ArgumentError(
          'Expected OpenAIChatResponse, got ${response.runtimeType}');
    }
    return _mapChatResponseImpl(response);
  }

  @override
  OpenAIEmbeddingRequest mapEmbeddingRequest(EmbeddingRequest request,
      {String? defaultModel}) {
    return _mapEmbeddingRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  EmbeddingResponse mapEmbeddingResponse(dynamic response) {
    if (response is! OpenAIEmbeddingResponse) {
      throw ArgumentError(
          'Expected OpenAIEmbeddingResponse, got ${response.runtimeType}');
    }
    return _mapEmbeddingResponseImpl(response);
  }

  @override
  OpenAIImageRequest mapImageRequest(ImageRequest request,
      {String? defaultModel}) {
    return _mapImageRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  ImageResponse mapImageResponse(dynamic response) {
    if (response is! OpenAIImageResponse) {
      throw ArgumentError(
          'Expected OpenAIImageResponse, got ${response.runtimeType}');
    }
    return _mapImageResponseImpl(response);
  }

  // Private implementation methods

  OpenAIChatRequest _mapChatRequestImpl(
    ChatRequest request, {
    String? defaultModel,
  }) {
    // Convert Message objects to OpenAI message format
    final messages = request.messages.map((msg) {
      final messageMap = <String, dynamic>{
        'role': _mapRoleToOpenAI(msg.role),
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

    // Extract OpenAI-specific options from providerOptions
    final openaiOptions =
        request.providerOptions?['openai'] ?? <String, dynamic>{};

    // Determine model - use request.model, then defaultModel, or throw error
    final model = request.model ?? defaultModel;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in ChatRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Build OpenAI request
    return OpenAIChatRequest(
      model: model,
      messages: messages,
      temperature: request.temperature,
      maxTokens: request.maxTokens,
      topP: request.topP,
      n: request.n,
      stop: request.stop,
      user: request.user,
      // OpenAI-specific fields from providerOptions
      presencePenalty: openaiOptions['presence_penalty'] as double? ??
          openaiOptions['presencePenalty'] as double?,
      frequencyPenalty: openaiOptions['frequency_penalty'] as double? ??
          openaiOptions['frequencyPenalty'] as double?,
      logitBias: openaiOptions['logit_bias'] != null
          ? Map<String, int>.from(openaiOptions['logit_bias'] as Map)
          : openaiOptions['logitBias'] != null
              ? Map<String, int>.from(openaiOptions['logitBias'] as Map)
              : null,
      stream: openaiOptions['stream'] as bool?,
      tools: openaiOptions['tools'] != null
          ? List<Map<String, dynamic>>.from(openaiOptions['tools'] as List)
          : null,
      toolChoice: openaiOptions['tool_choice'] ?? openaiOptions['toolChoice'],
      functionCall: openaiOptions['function_call'] as String? ??
          openaiOptions['functionCall'] as String?,
      functions: openaiOptions['functions'] as Map<String, dynamic>?,
    );
  }

  ChatResponse _mapChatResponseImpl(OpenAIChatResponse response) {
    // Convert OpenAI choices to SDK choices
    final choices = response.choices.map((choice) {
      // Convert OpenAI message map to Message object
      final messageMap = choice.message;
      final role = _mapRoleFromOpenAI(messageMap['role'] as String);
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

    // Convert OpenAI usage to SDK usage
    final usage = Usage(
      promptTokens: response.usage.promptTokens,
      completionTokens: response.usage.completionTokens,
      totalTokens: response.usage.totalTokens,
    );

    // Convert timestamp from Unix seconds to DateTime
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(response.created * 1000);

    // Build metadata from OpenAI-specific fields
    final metadata = <String, dynamic>{
      'object': response.object,
      'created': response.created,
      if (response.systemFingerprint != null)
        'system_fingerprint': response.systemFingerprint,
    };

    return ChatResponse(
      id: response.id,
      choices: choices,
      usage: usage,
      model: response.model,
      provider: 'openai',
      timestamp: timestamp,
      metadata: metadata,
    );
  }

  OpenAIEmbeddingRequest _mapEmbeddingRequestImpl(
    EmbeddingRequest request, {
    String? defaultModel,
  }) {
    // Determine model
    final model = request.model ?? defaultModel;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in EmbeddingRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Determine input format - OpenAI accepts both string and array
    final input =
        request.inputs.length == 1 ? request.inputs.first : request.inputs;

    // Extract OpenAI-specific options
    final openaiOptions =
        request.providerOptions?['openai'] ?? <String, dynamic>{};

    return OpenAIEmbeddingRequest(
      model: model,
      input: input,
      encodingFormat: openaiOptions['encoding_format'] as String? ??
          openaiOptions['encodingFormat'] as String?,
      dimensions: openaiOptions['dimensions'] as int?,
      user: openaiOptions['user'] as String?,
    );
  }

  EmbeddingResponse _mapEmbeddingResponseImpl(
      OpenAIEmbeddingResponse response) {
    // Convert OpenAI embeddings to SDK EmbeddingData
    final embeddings = response.data.map((embedding) {
      // Handle both List<double> and String (base64) formats
      List<double> vector;
      if (embedding.embedding is List) {
        vector = (embedding.embedding as List)
            .map((e) => (e as num).toDouble())
            .toList();
      } else if (embedding.embedding is String) {
        // Base64 format - would need decoding, but for now throw error
        // In a full implementation, you'd decode base64 here
        throw ClientError(
          message: 'Base64 embedding format not yet supported',
          code: 'UNSUPPORTED_FORMAT',
        );
      } else {
        throw ClientError(
          message: 'Invalid embedding format',
          code: 'INVALID_FORMAT',
        );
      }

      return EmbeddingData(
        vector: vector,
        dimension: vector.length,
        index: embedding.index,
      );
    }).toList();

    // Convert OpenAI usage to SDK usage
    final usage = Usage(
      promptTokens: response.usage.promptTokens,
      completionTokens: response.usage.completionTokens,
      totalTokens: response.usage.totalTokens,
    );

    return EmbeddingResponse(
      embeddings: embeddings,
      model: response.model,
      provider: 'openai',
      usage: usage,
    );
  }

  /// Maps SDK [Role] enum to OpenAI role string.
  ///
  /// OpenAI uses lowercase strings: "system", "user", "assistant", "tool", "function"
  String _mapRoleToOpenAI(Role role) {
    switch (role) {
      case Role.system:
        return 'system';
      case Role.user:
        return 'user';
      case Role.assistant:
        return 'assistant';
      case Role.function:
        return 'function'; // OpenAI uses 'function' for function calls
    }
  }

  /// Maps OpenAI role string to SDK [Role] enum.
  ///
  /// Handles OpenAI's role strings: "system", "user", "assistant", "tool", "function"
  Role _mapRoleFromOpenAI(String role) {
    switch (role.toLowerCase()) {
      case 'system':
        return Role.system;
      case 'user':
        return Role.user;
      case 'assistant':
        return Role.assistant;
      case 'function':
      case 'tool': // OpenAI sometimes uses 'tool' for tool calls
        return Role.function;
      default:
        throw ClientError(
          message: 'Unknown OpenAI role: $role',
          code: 'INVALID_ROLE',
        );
    }
  }

  /// Maps SDK [ImageRequest] to OpenAI image generation request format.
  OpenAIImageRequest _mapImageRequestImpl(
    ImageRequest request, {
    String? defaultModel,
  }) {
    // Determine model - default to dall-e-3 if not specified
    final model = request.model ?? defaultModel ?? 'dall-e-3';

    // Convert ImageSize enum to string format
    String? sizeString;
    if (request.size != null) {
      sizeString = request.size!.toString(); // Already in "WIDTHxHEIGHT" format
    }

    // Extract OpenAI-specific options
    final openaiOptions =
        request.providerOptions?['openai'] ?? <String, dynamic>{};

    // For DALL-E 3, n must be 1 (enforced by API, but we can validate)
    final int? n = request.n;
    if (model == 'dall-e-3' && n != null && n != 1) {
      throw ClientError(
        message: 'DALL-E 3 only supports generating 1 image at a time (n=1)',
        code: 'INVALID_N_VALUE',
      );
    }

    return OpenAIImageRequest(
      prompt: request.prompt,
      model: model,
      n: n,
      size: sizeString,
      quality: request.quality ?? openaiOptions['quality'] as String?,
      style: request.style ?? openaiOptions['style'] as String?,
      responseFormat: openaiOptions['response_format'] as String? ??
          openaiOptions['responseFormat'] as String?,
      user: openaiOptions['user'] as String?,
    );
  }

  /// Maps OpenAI image generation response to SDK [ImageResponse].
  ImageResponse _mapImageResponseImpl(OpenAIImageResponse response) {
    // Convert OpenAI image data to SDK ImageAsset
    final assets = response.data.map((imageData) {
      return ImageAsset(
        url: imageData.url,
        base64: imageData.b64Json,
        revisedPrompt: imageData.revisedPrompt,
        // Note: OpenAI doesn't provide width/height in the response
        // They can be inferred from the size parameter, but we don't have that here
        // Users can check the image dimensions after downloading
      );
    }).toList();

    // Extract model from response (if available) or use default
    // OpenAI doesn't return the model in the response, so we'll use a default
    // In practice, this should be tracked from the request
    final model =
        'dall-e-3'; // Default, could be enhanced to track from request

    // Build metadata from OpenAI-specific fields
    final metadata = <String, dynamic>{
      'created': response.created,
    };

    return ImageResponse(
      assets: assets,
      model: model,
      provider: 'openai',
      metadata: metadata,
    );
  }

  @override
  OpenAITtsRequest mapTtsRequest(TtsRequest request, {String? defaultModel}) {
    // Determine model
    final model = request.model ?? defaultModel ?? 'tts-1';

    // Extract OpenAI-specific options
    final openaiOptions =
        request.providerOptions?['openai'] ?? <String, dynamic>{};

    // Determine voice - use request.voice or default to 'alloy'
    final voice = request.voice ?? openaiOptions['voice'] as String? ?? 'alloy';

    // Determine response format - default to 'mp3'
    final responseFormat = openaiOptions['response_format'] as String? ??
        openaiOptions['responseFormat'] as String? ??
        'mp3';

    // Determine speed - use request.speed or default to 1.0
    final speed = request.speed ?? 1.0;

    return OpenAITtsRequest(
      model: model,
      input: request.text,
      voice: voice,
      responseFormat: responseFormat,
      speed: speed,
    );
  }

  @override
  AudioResponse mapTtsResponse(
    dynamic response,
    Uint8List audioBytes,
    TtsRequest request,
  ) {
    // Extract format from response headers or request
    final format = _extractAudioFormat(response, request);

    // Extract model from request
    final model = request.model ?? 'tts-1';

    return AudioResponse(
      bytes: audioBytes,
      format: format,
      model: model,
      provider: 'openai',
    );
  }

  /// Extracts audio format from response headers or request.
  String _extractAudioFormat(dynamic response, TtsRequest request) {
    // Try to get format from response headers
    if (response is http.Response) {
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('mp3')) return 'mp3';
      if (contentType.contains('opus')) return 'opus';
      if (contentType.contains('aac')) return 'aac';
      if (contentType.contains('flac')) return 'flac';
      if (contentType.contains('wav')) return 'wav';
    }

    // Fall back to request format or default
    final openaiOptions =
        request.providerOptions?['openai'] ?? <String, dynamic>{};
    return openaiOptions['response_format'] as String? ??
        openaiOptions['responseFormat'] as String? ??
        'mp3';
  }

  @override
  OpenAISttRequest mapSttRequest(SttRequest request, {String? defaultModel}) {
    // Determine model
    final model = request.model ?? defaultModel ?? 'whisper-1';

    // Extract OpenAI-specific options
    final openaiOptions =
        request.providerOptions?['openai'] ?? <String, dynamic>{};

    // Determine response format
    final responseFormat = openaiOptions['response_format'] as String? ??
        openaiOptions['responseFormat'] as String? ??
        'json';

    // Determine temperature
    final temperature = openaiOptions['temperature'] as double?;

    return OpenAISttRequest(
      model: model,
      audio: request.audio,
      language: request.language,
      prompt: request.prompt,
      responseFormat: responseFormat,
      temperature: temperature,
    );
  }

  @override
  TranscriptionResponse mapSttResponse(
    dynamic response,
    SttRequest request,
  ) {
    // OpenAI STT response can be JSON or plain text depending on response_format
    String text;
    String? language;

    if (response is String) {
      // Plain text response
      text = response;
    } else if (response is Map<String, dynamic>) {
      // JSON response (verbose_json format)
      text = response['text'] as String? ?? '';
      language = response['language'] as String?;
    } else {
      throw ClientError(
        message: 'Unexpected STT response format: ${response.runtimeType}',
        code: 'INVALID_RESPONSE_FORMAT',
      );
    }

    // Extract model from request
    final model = request.model ?? 'whisper-1';

    return TranscriptionResponse(
      text: text,
      language: language,
      model: model,
      provider: 'openai',
    );
  }

  @override
  OpenAIVideoRequest mapVideoRequest(VideoRequest request,
      {String? defaultModel}) {
    // Determine model - default to sora-2 (latest) if not specified
    final model = request.model ?? defaultModel ?? 'sora-2';

    // Extract OpenAI-specific options
    final openaiOptions =
        request.providerOptions?['openai'] ?? <String, dynamic>{};

    return OpenAIVideoRequest(
      prompt: request.prompt,
      model: model,
      duration: request.duration,
      aspectRatio: request.aspectRatio,
      frameRate: request.frameRate,
      quality: request.quality,
      seed: request.seed,
      user: openaiOptions['user'] as String?,
    );
  }

  @override
  VideoResponse mapVideoResponse(dynamic response) {
    if (response is! OpenAIVideoResponse) {
      throw ArgumentError(
        'Expected OpenAIVideoResponse, got ${response.runtimeType}',
      );
    }

    // Convert OpenAI video data to SDK VideoAsset
    final assets = response.data.map((videoData) {
      return VideoAsset(
        url: videoData.url,
        base64: videoData.base64,
        width: videoData.width,
        height: videoData.height,
        duration: videoData.duration,
        frameRate: videoData.frameRate,
        revisedPrompt: videoData.revisedPrompt,
      );
    }).toList();

    // Convert timestamp from Unix seconds to DateTime
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(response.created * 1000);

    // Build metadata from OpenAI-specific fields
    final metadata = <String, dynamic>{
      'id': response.id,
      'created': response.created,
    };

    return VideoResponse(
      assets: assets,
      model: response.model,
      provider: 'openai',
      timestamp: timestamp,
      metadata: metadata,
    );
  }

  @override
  OpenAIVideoAnalysisRequest mapVideoAnalysisRequest(
    VideoAnalysisRequest request, {
    String? defaultModel,
  }) {
    // Determine model - default to gpt-4o if not specified
    final model = request.model ?? defaultModel ?? 'gpt-4o';

    // Extract OpenAI-specific options
    final openaiOptions =
        request.providerOptions?['openai'] ?? <String, dynamic>{};

    // Build messages for video analysis
    // OpenAI uses chat completions with video content in messages
    final messages = <Map<String, dynamic>>[];

    // Add system message if needed (optional)
    final systemMessage = openaiOptions['system_message'] as String?;
    if (systemMessage != null && systemMessage.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': systemMessage,
      });
    }

    // Build user message with video content
    final content = <Map<String, dynamic>>[];

    // Add text prompt if provided via features or as a prompt
    final promptText = openaiOptions['prompt'] as String? ??
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
      final mimeType = openaiOptions['mime_type'] as String? ?? 'video/mp4';
      content.add({
        'type': 'video_url',
        'video_url': {
          'url': 'data:$mimeType;base64,${request.videoBase64}',
        },
      });
    }

    messages.add({
      'role': 'user',
      'content': content,
    });

    return OpenAIVideoAnalysisRequest(
      model: model,
      messages: messages,
      maxTokens: openaiOptions['max_tokens'] as int? ??
          openaiOptions['maxTokens'] as int?,
      temperature: request.confidenceThreshold != null
          ? 1.0 - request.confidenceThreshold!
          : (openaiOptions['temperature'] as double?),
      user: openaiOptions['user'] as String?,
    );
  }

  @override
  VideoAnalysisResponse mapVideoAnalysisResponse(dynamic response) {
    if (response is! OpenAIVideoAnalysisResponse) {
      throw ArgumentError(
        'Expected OpenAIVideoAnalysisResponse, got ${response.runtimeType}',
      );
    }

    // Extract analysis text from the first choice
    String analysisText = '';
    if (response.choices.isNotEmpty) {
      final firstChoice = response.choices.first;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      if (message != null) {
        final content = message['content'] as String?;
        if (content != null) {
          analysisText = content;
        }
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
    // In a real implementation, you might use structured output or prompt engineering
    // to get more structured data
    if (analysisText.isNotEmpty) {
      // Extract potential labels (simple heuristic - look for capitalized phrases)
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

    // Build metadata from OpenAI-specific fields
    final metadata = <String, dynamic>{
      'id': response.id,
      'created': response.created,
      'analysis_text': analysisText,
      if (response.usage != null)
        'usage': {
          'prompt_tokens': response.usage!.promptTokens,
          'completion_tokens': response.usage!.completionTokens,
          'total_tokens': response.usage!.totalTokens,
        },
    };

    return VideoAnalysisResponse(
      objects: objects,
      scenes: scenes,
      actions: actions,
      text: text,
      labels: labels,
      model: response.model,
      provider: 'openai',
      timestamp: DateTime.fromMillisecondsSinceEpoch(response.created * 1000),
      metadata: metadata,
    );
  }
}
