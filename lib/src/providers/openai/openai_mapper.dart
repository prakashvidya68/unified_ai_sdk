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

import 'dart:convert';
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
    // For Responses API, we'll use a different method
    // This method is kept for backward compatibility but will be deprecated
    return _mapChatRequestImpl(request, defaultModel: defaultModel);
  }

  /// Maps a [ChatRequest] to OpenAI's Responses API format.
  ///
  /// The Responses API uses a different structure with `input` field and
  /// supports `previous_response_id` for stateful conversations.
  OpenAIResponseRequest mapResponseRequest(ChatRequest request,
      {String? defaultModel}) {
    return _mapResponseRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  ChatResponse mapChatResponse(dynamic response) {
    // Handle both Chat Completions and Responses API formats
    if (response is OpenAIResponseResponse) {
      return _mapResponseResponseImpl(response);
    }
    if (response is! OpenAIChatResponse) {
      throw ArgumentError(
          'Expected OpenAIChatResponse or OpenAIResponseResponse, got ${response.runtimeType}');
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

    // Check if this model has restricted parameters (gpt-5 series, or legacy o1 series)
    final hasRestrictedParams = _hasRestrictedParameters(model);

    // For models with restricted parameters, filter unsupported parameters
    double? temperature;
    int? maxTokens;
    int? maxCompletionTokens;
    double? topP;
    double? presencePenalty;
    double? frequencyPenalty;

    if (hasRestrictedParams) {
      // Models with restricted parameters (GPT-5 series, or legacy o1 series) only support
      // temperature = 1.0 (default). If temperature is set to something other than 1.0, we omit it.
      if (request.temperature != null && request.temperature == 1.0) {
        temperature = request.temperature;
      }
      // These models use max_completion_tokens instead of max_tokens
      if (request.maxTokens != null) {
        maxCompletionTokens = request.maxTokens;
      }
      // The following parameters are not supported by models with restricted parameters:
      // - top_p: Not supported
      // - presence_penalty: Not supported
      // - frequency_penalty: Not supported
      // - logprobs: Not supported (handled separately below)
      topP = null;
      presencePenalty = null;
      frequencyPenalty = null;
    } else {
      // Standard models: use all parameters as-is
      temperature = request.temperature;
      maxTokens = request.maxTokens;
      topP = request.topP;
      presencePenalty = openaiOptions['presence_penalty'] as double? ??
          openaiOptions['presencePenalty'] as double?;
      frequencyPenalty = openaiOptions['frequency_penalty'] as double? ??
          openaiOptions['frequencyPenalty'] as double?;
    }

    // Build OpenAI request
    return OpenAIChatRequest(
      model: model,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      maxCompletionTokens: maxCompletionTokens,
      topP: topP,
      n: request.n,
      stop: request.stop,
      presencePenalty: presencePenalty,
      frequencyPenalty: frequencyPenalty,
      user: request.user,
      // OpenAI-specific fields from providerOptions
      logitBias: openaiOptions['logit_bias'] != null
          ? Map<String, int>.from(openaiOptions['logit_bias'] as Map)
          : openaiOptions['logitBias'] != null
              ? Map<String, int>.from(openaiOptions['logitBias'] as Map)
              : null,
      // logprobs is not supported by models with restricted parameters
      logprobs:
          hasRestrictedParams ? null : (openaiOptions['logprobs'] as bool?),
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

  /// Checks if the model has restricted parameters.
  ///
  /// Models with restricted parameters have different requirements than standard GPT models:
  /// - Only support temperature = 1.0 (default)
  /// - Use max_completion_tokens instead of max_tokens
  /// - Do not support top_p, presence_penalty, frequency_penalty, or logprobs
  ///
  /// **Included models:**
  /// - GPT-5 series: gpt-5, gpt-5.1, gpt-5-pro, gpt-5-mini, gpt-5-nano, gpt-5-codex, gpt-5.1-codex, gpt-5-chat-latest
  ///
  /// **Note:** o1 series models (o1, o1-pro, o1-mini) are legacy/deprecated and have been
  /// succeeded by GPT-5 series. This function still supports them for backward compatibility
  /// if explicitly used, but they are not included in the fallback models list.
  bool _hasRestrictedParameters(String model) {
    final lowerModel = model.toLowerCase();

    // o1 series models (all variants) - legacy/deprecated, but still supported for backward compatibility
    if (lowerModel == 'o1' || lowerModel.startsWith('o1-')) {
      return true;
    }

    // GPT-5 series models (all variants including gpt-5.1, gpt-5-pro, etc.)
    // This pattern matches: gpt-5, gpt-5.1, gpt-5-pro, gpt-5-mini, gpt-5-nano,
    // gpt-5-codex, gpt-5.1-codex, gpt-5-chat-latest, etc.
    if (lowerModel.startsWith('gpt-5')) {
      return true;
    }

    return false;
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

  /// Maps a [ChatRequest] to OpenAI's Responses API request format.
  ///
  /// The Responses API supports:
  /// - Simple string input or message arrays
  /// - Instructions field for system-level guidance
  /// - previous_response_id for stateful conversations
  OpenAIResponseRequest _mapResponseRequestImpl(
    ChatRequest request, {
    String? defaultModel,
  }) {
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

    // Check if this model has restricted parameters
    final hasRestrictedParams = _hasRestrictedParameters(model);

    // Determine input format for Responses API
    // If there's a previous_response_id, we can use just the latest user message
    // Otherwise, we convert all messages to the format
    final previousResponseId = openaiOptions['previous_response_id'] as String?;

    dynamic input;
    String? instructions;

    if (previousResponseId != null && request.messages.length > 1) {
      // Stateful: use only the latest user message as input
      final lastMessage = request.messages.last;
      if (lastMessage.role == Role.user) {
        input = lastMessage.content;
      } else {
        // If last message is not user, use all messages
        input = request.messages.map((msg) {
          final messageMap = <String, dynamic>{
            'role': _mapRoleToOpenAI(msg.role),
            'content': msg.content,
          };
          if (msg.name != null) {
            messageMap['name'] = msg.name;
          }
          if (msg.meta != null) {
            messageMap.addAll(msg.meta!);
          }
          return messageMap;
        }).toList();
      }
    } else {
      // Non-stateful: convert all messages
      // Extract system message as instructions if present
      final systemMessages =
          request.messages.where((msg) => msg.role == Role.system).toList();
      final nonSystemMessages =
          request.messages.where((msg) => msg.role != Role.system).toList();

      if (systemMessages.isNotEmpty) {
        // Combine all system messages into instructions
        instructions = systemMessages.map((msg) => msg.content).join('\n');
      }

      if (nonSystemMessages.length == 1 &&
          nonSystemMessages.first.role == Role.user) {
        // Single user message: use as string input
        input = nonSystemMessages.first.content;
      } else {
        // Multiple messages: use as message array
        input = nonSystemMessages.map((msg) {
          final messageMap = <String, dynamic>{
            'role': _mapRoleToOpenAI(msg.role),
            'content': msg.content,
          };
          if (msg.name != null) {
            messageMap['name'] = msg.name;
          }
          if (msg.meta != null) {
            messageMap.addAll(msg.meta!);
          }
          return messageMap;
        }).toList();
      }
    }

    // Override instructions if provided in providerOptions
    instructions = openaiOptions['instructions'] as String? ?? instructions;

    // For models with restricted parameters, filter unsupported parameters
    double? temperature;
    int? maxCompletionTokens;
    double? topP;
    double? presencePenalty;
    double? frequencyPenalty;

    if (hasRestrictedParams) {
      // Models with restricted parameters only support temperature = 1.0 (default)
      if (request.temperature != null && request.temperature == 1.0) {
        temperature = request.temperature;
      }
      // These models use max_completion_tokens
      if (request.maxTokens != null) {
        maxCompletionTokens = request.maxTokens;
      }
      // top_p, presence_penalty, and frequency_penalty are not supported
      topP = null;
      presencePenalty = null;
      frequencyPenalty = null;
    } else {
      // Standard models: use all parameters as-is
      temperature = request.temperature;
      if (request.maxTokens != null) {
        maxCompletionTokens = request.maxTokens;
      }
      topP = request.topP;
      presencePenalty = openaiOptions['presence_penalty'] as double? ??
          openaiOptions['presencePenalty'] as double?;
      frequencyPenalty = openaiOptions['frequency_penalty'] as double? ??
          openaiOptions['frequencyPenalty'] as double?;
    }

    // Build Responses API request
    return OpenAIResponseRequest(
      model: model,
      input: input,
      instructions: instructions,
      previousResponseId: previousResponseId,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      topP: topP,
      n: request.n,
      stop: request.stop,
      presencePenalty: presencePenalty,
      frequencyPenalty: frequencyPenalty,
      logitBias: openaiOptions['logit_bias'] != null
          ? Map<String, int>.from(openaiOptions['logit_bias'] as Map)
          : openaiOptions['logitBias'] != null
              ? Map<String, int>.from(openaiOptions['logitBias'] as Map)
              : null,
      user: request.user,
      stream: openaiOptions['stream'] as bool?,
      tools: openaiOptions['tools'] != null
          ? List<Map<String, dynamic>>.from(openaiOptions['tools'] as List)
          : null,
      toolChoice: openaiOptions['tool_choice'] ?? openaiOptions['toolChoice'],
    );
  }

  /// Maps OpenAI's Responses API response to SDK [ChatResponse] format.
  ChatResponse _mapResponseResponseImpl(OpenAIResponseResponse response) {
    // Convert Responses API choices to SDK choices
    final choices = response.choices.map((choice) {
      // Convert Responses API message map to Message object
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

    // Convert usage statistics
    final usage = response.usage != null
        ? Usage(
            promptTokens: response.usage!.promptTokens,
            completionTokens: response.usage!.completionTokens,
            totalTokens: response.usage!.totalTokens,
          )
        : Usage(promptTokens: 0, completionTokens: 0, totalTokens: 0);

    // Convert timestamp from Unix seconds to DateTime
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(response.created * 1000);

    // Build metadata from Responses API-specific fields
    final metadata = <String, dynamic>{
      'response_id':
          response.responseId, // Important for stateful conversations
      'created': response.created,
    };

    return ChatResponse(
      id: response.responseId, // Use response_id as the ID
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
    // Determine model - default to gpt-image-1 if not specified
    final model = request.model ?? defaultModel ?? 'gpt-image-1';

    // Convert ImageSize enum to string format
    String? sizeString;
    if (request.size != null) {
      sizeString = request.size!.toString(); // Already in "WIDTHxHEIGHT" format
    }

    // Extract OpenAI-specific options
    final openaiOptions =
        request.providerOptions?['openai'] ?? <String, dynamic>{};

    // For GPT Image 1, n must be 1 (enforced by API, but we can validate)
    final int? n = request.n;
    if ((model == 'gpt-image-1' || model == 'gpt-image-1-mini') &&
        n != null &&
        n != 1) {
      throw ClientError(
        message: 'GPT Image 1 only supports generating 1 image at a time (n=1)',
        code: 'INVALID_N_VALUE',
      );
    }

    // GPT Image 1 models don't support response_format parameter
    // They always return base64-encoded images
    final isGptImage1 = model == 'gpt-image-1' || model == 'gpt-image-1-mini';
    final String? responseFormat;
    if (isGptImage1) {
      responseFormat = null; // Don't include response_format for GPT Image 1
    } else {
      responseFormat = openaiOptions['response_format'] as String? ??
          openaiOptions['responseFormat'] as String?;
    }

    return OpenAIImageRequest(
      prompt: request.prompt,
      model: model,
      n: n,
      size: sizeString,
      quality: request.quality ?? openaiOptions['quality'] as String?,
      style: request.style ?? openaiOptions['style'] as String?,
      responseFormat: responseFormat,
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
    // Determine model - default to gpt-4o-mini-tts if not specified
    final model = request.model ?? defaultModel ?? 'gpt-4o-mini-tts';

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
    final model = request.model ?? 'gpt-4o-mini-tts';

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
    // Determine model - default to gpt-4o-transcribe if not specified
    final model = request.model ?? defaultModel ?? 'gpt-4o-transcribe';

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
    final model = request.model ?? 'gpt-4o-transcribe';

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

  /// Maps a video job and content bytes to a VideoResponse.
  ///
  /// This method is used when the video is retrieved via the two-step process:
  /// 1. Create video job (returns OpenAIVideoJob)
  /// 2. Retrieve video content (returns bytes)
  ///
  /// The video content bytes are encoded as base64 and included in the response.
  VideoResponse mapVideoResponseFromContent(
    OpenAIVideoJob job,
    List<int> videoContentBytes,
    VideoRequest request,
  ) {
    // Parse size string (e.g., "1280x720") to width and height
    int? width;
    int? height;
    if (job.size != null) {
      final sizeParts = job.size!.split('x');
      if (sizeParts.length == 2) {
        width = int.tryParse(sizeParts[0]);
        height = int.tryParse(sizeParts[1]);
      }
    }

    // Encode video content as base64
    final base64Content = base64Encode(videoContentBytes);

    // Create a single video asset from the content
    final asset = VideoAsset(
      base64: base64Content,
      url: null, // Content is provided as base64, not URL
      width: width,
      height: height,
      duration: job.seconds,
      frameRate: null, // Not provided in job response
      revisedPrompt: null, // Not provided in job response
    );

    // Convert timestamp from Unix seconds to DateTime
    final timestamp = DateTime.fromMillisecondsSinceEpoch(job.createdAt * 1000);

    // Build metadata from job fields
    final metadata = <String, dynamic>{
      'id': job.id,
      'object': job.object,
      'created_at': job.createdAt,
      'status': job.status,
      if (job.progress != null) 'progress': job.progress,
      if (job.completedAt != null) 'completed_at': job.completedAt,
      if (job.expiresAt != null) 'expires_at': job.expiresAt,
      if (job.remixedFromVideoId != null)
        'remixed_from_video_id': job.remixedFromVideoId,
      if (job.error != null) 'error': job.error,
    };

    return VideoResponse(
      assets: [asset],
      model: job.model,
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
