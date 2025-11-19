/// Mapper for converting between unified SDK models and Cohere-specific models.
///
/// This class provides bidirectional conversion between the provider-agnostic
/// SDK models ([EmbeddingRequest], [EmbeddingResponse]) and Cohere-specific
/// models ([CohereEmbeddingRequest], [CohereEmbeddingResponse]).
///
/// **Design Pattern:** Adapter/Mapper Pattern
///
/// This mapper allows the SDK to maintain a unified API while supporting
/// provider-specific features and formats. Users interact with unified models,
/// but internally the SDK converts to/from Cohere-specific formats.
///
/// **Key Features:**
/// - Handles Cohere's "texts" array format
/// - Supports input_type parameter (search_document, search_query, etc.)
/// - Maps Cohere's embedding format to SDK format
/// - Converts Cohere usage statistics to SDK format
///
/// **Example usage:**
/// ```dart
/// // SDK → Cohere
/// final embeddingRequest = EmbeddingRequest(
///   inputs: ['Hello, world!', 'How are you?'],
///   model: 'embed-english-v3.0',
/// );
/// final mapper = CohereMapper.instance;
/// final cohereRequest = mapper.mapEmbeddingRequest(embeddingRequest);
///
/// // Cohere → SDK
/// final cohereResponse = CohereEmbeddingResponse.fromJson(apiResponse);
/// final embeddingResponse = mapper.mapEmbeddingResponse(cohereResponse);
/// ```
library;

import 'dart:typed_data';

import '../../error/error_types.dart';
import '../../models/common/message.dart';
import '../../models/common/usage.dart';
import '../../models/requests/chat_request.dart';
import '../../models/base_enums.dart';
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
import '../base/provider_mapper.dart';
import 'cohere_models.dart';

/// Mapper for converting between unified SDK models and Cohere-specific models.
///
/// Implements [ProviderMapper] to provide Cohere-specific conversion logic.
/// This class uses a singleton pattern and provides instance methods for
/// converting between unified SDK models and Cohere-specific formats.
///
/// **Usage:**
/// ```dart
/// final mapper = CohereMapper.instance;
/// final request = mapper.mapEmbeddingRequest(embeddingRequest);
/// final response = mapper.mapEmbeddingResponse(cohereResponse);
/// ```
class CohereMapper implements ProviderMapper {
  /// Private constructor to enforce singleton pattern.
  /// Use [CohereMapper.instance] to access the mapper instance.
  CohereMapper._();

  /// Singleton instance for instance-based usage.
  ///
  /// Use this when you need to inject the mapper as a dependency or
  /// when working with the [ProviderMapper] interface.
  static final CohereMapper instance = CohereMapper._();

  // Instance methods implementing ProviderMapper interface

  @override
  CohereChatRequest mapChatRequest(ChatRequest request,
      {String? defaultModel}) {
    // Determine model - default to command-r-plus if not specified
    final model = request.model ?? defaultModel ?? 'command-r-plus';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in ChatRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Extract Cohere-specific options
    final cohereOptions =
        request.providerOptions?['cohere'] ?? <String, dynamic>{};

    // Convert SDK messages to Cohere v2 format
    // v2 API uses "messages" array and supports system role directly
    final messages = <Map<String, dynamic>>[];

    for (final msg in request.messages) {
      // v2 supports system, user, assistant, and tool roles directly
      final messageMap = <String, dynamic>{
        'role': _mapRoleToCohere(msg.role),
        'content': msg.content,
      };
      if (msg.name != null) {
        messageMap['name'] = msg.name;
      }
      if (msg.meta != null) {
        // Include metadata if present (e.g., tool_call_id for tool messages)
        messageMap.addAll(msg.meta!);
      }
      messages.add(messageMap);
    }

    // Ensure we have at least one message
    if (messages.isEmpty) {
      throw ClientError(
        message: 'At least one message is required',
        code: 'INVALID_REQUEST',
      );
    }

    // Extract Cohere-specific v2 options
    final responseFormat = cohereOptions['response_format'] != null
        ? Map<String, dynamic>.from(cohereOptions['response_format'] as Map)
        : cohereOptions['responseFormat'] != null
            ? Map<String, dynamic>.from(cohereOptions['responseFormat'] as Map)
            : null;

    final thinking = cohereOptions['thinking'] != null
        ? Map<String, dynamic>.from(cohereOptions['thinking'] as Map)
        : null;

    // Build Cohere v2 request
    return CohereChatRequest(
      model: model,
      messages: messages,
      conversationId: cohereOptions['conversation_id'] as String? ??
          cohereOptions['conversationId'] as String?,
      documents: cohereOptions['documents'] != null
          ? List<Map<String, dynamic>>.from(
              (cohereOptions['documents'] as List)
                  .map((d) => d as Map<String, dynamic>),
            )
          : null,
      tools: cohereOptions['tools'] != null
          ? List<Map<String, dynamic>>.from(
              (cohereOptions['tools'] as List)
                  .map((t) => t as Map<String, dynamic>),
            )
          : null,
      toolChoice: cohereOptions['tool_choice'] ?? cohereOptions['toolChoice'],
      temperature: request.temperature,
      maxTokens: request.maxTokens,
      p: request.topP,
      k: cohereOptions['k'] as int? ?? cohereOptions['top_k'] as int?,
      stopSequences: request.stop,
      frequencyPenalty: cohereOptions['frequency_penalty'] as double? ??
          cohereOptions['frequencyPenalty'] as double?,
      presencePenalty: cohereOptions['presence_penalty'] as double? ??
          cohereOptions['presencePenalty'] as double?,
      stream: cohereOptions['stream'] as bool?,
      responseFormat: responseFormat,
      safetyMode: cohereOptions['safety_mode'] as String? ??
          cohereOptions['safetyMode'] as String?,
      strictTools: cohereOptions['strict_tools'] as bool? ??
          cohereOptions['strictTools'] as bool?,
      thinking: thinking,
      priority: cohereOptions['priority'] as int?,
      seed: cohereOptions['seed'] as int?,
      logprobs: cohereOptions['logprobs'] as bool?,
    );
  }

  @override
  ChatResponse mapChatResponse(dynamic response) {
    if (response is! CohereChatResponse) {
      throw ArgumentError(
        'Expected CohereChatResponse, got ${response.runtimeType}',
      );
    }

    // Extract text from v2 message.content structure
    final text = response.getText();

    // Extract metadata from message object
    final messageMeta = <String, dynamic>{};
    if (response.message['tool_calls'] != null) {
      messageMeta['tool_calls'] = response.message['tool_calls'];
    }
    if (response.message['citations'] != null) {
      messageMeta['citations'] = response.message['citations'];
    }

    // Convert Cohere response to SDK format
    final message = Message(
      role: Role.assistant,
      content: text,
      meta: {
        ...messageMeta,
        if (response.finishReason != null)
          'finish_reason': response.finishReason,
      },
    );

    final choice = ChatChoice(
      index: 0,
      message: message,
      finishReason: _mapFinishReasonToSDK(response.finishReason),
    );

    // Convert Cohere usage to SDK usage
    // v2 API uses usage object with input_tokens and output_tokens
    Usage? usage;
    if (response.usage != null) {
      final usageMap = response.usage!;

      int inputTokens = 0;
      int outputTokens = 0;

      // Prefer direct fields when present
      final directInput = usageMap['input_tokens'];
      final directOutput = usageMap['output_tokens'];

      if (directInput is int) {
        inputTokens = directInput;
      } else if (directInput is num) {
        inputTokens = directInput.toInt();
      }

      if (directOutput is int) {
        outputTokens = directOutput;
      } else if (directOutput is num) {
        outputTokens = directOutput.toInt();
      }

      // Fallback: nested structure under `tokens`: { input_tokens, output_tokens }
      if ((inputTokens == 0 && outputTokens == 0)) {
        final tokensField = usageMap['tokens'];
        if (tokensField is Map) {
          final nestedInput = tokensField['input_tokens'];
          final nestedOutput = tokensField['output_tokens'];

          if (nestedInput is int) {
            inputTokens = nestedInput;
          } else if (nestedInput is num) {
            inputTokens = nestedInput.toInt();
          }

          if (nestedOutput is int) {
            outputTokens = nestedOutput;
          } else if (nestedOutput is num) {
            outputTokens = nestedOutput.toInt();
          }
        } else if (tokensField is num) {
          // Some responses may include a flat total token count
          inputTokens = tokensField.toInt();
          // completionTokens remains 0 in absence of breakdown
        }
      }

      usage = Usage(
        promptTokens: inputTokens,
        completionTokens: outputTokens,
        totalTokens: inputTokens + outputTokens,
      );
    }

    // Build metadata from Cohere-specific fields
    final metadata = <String, dynamic>{
      'id': response.id,
      if (response.finishReason != null) 'finish_reason': response.finishReason,
      if (response.usage != null) 'usage': response.usage,
      if (response.logprobs != null) 'logprobs': response.logprobs,
      ...messageMeta,
    };

    // Try to extract model from usage or use default
    final modelName = response.usage?['model'] as String? ?? 'command-r-plus';

    return ChatResponse(
      id: response.id,
      choices: [choice],
      usage: usage ??
          const Usage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
      model: modelName,
      provider: 'cohere',
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Maps SDK Role enum to Cohere role string.
  ///
  /// Cohere v2 supports: "user", "assistant", "system", "tool"
  String _mapRoleToCohere(Role role) {
    switch (role) {
      case Role.user:
        return 'user';
      case Role.assistant:
        return 'assistant';
      case Role.system:
        return 'system';
      case Role.function:
        // v2 API uses "tool" role for function/tool messages
        return 'tool';
    }
  }

  /// Maps Cohere finish_reason to SDK finish_reason format.
  ///
  /// v2 API uses: COMPLETE, MAX_TOKENS, STOP_SEQUENCE, TOOL_CALL, ERROR, TIMEOUT
  String? _mapFinishReasonToSDK(String? finishReason) {
    if (finishReason == null) return null;

    switch (finishReason.toUpperCase()) {
      case 'COMPLETE':
        return 'stop';
      case 'MAX_TOKENS':
        return 'length';
      case 'STOP_SEQUENCE':
        return 'stop';
      case 'TOOL_CALL':
        return 'function_call';
      case 'ERROR':
      case 'TIMEOUT':
        return finishReason.toLowerCase();
      default:
        // Handle legacy v1 values for backward compatibility
        switch (finishReason.toLowerCase()) {
          case 'complete':
          case 'stop':
            return 'stop';
          case 'max_tokens':
          case 'max_tokens_reached':
            return 'length';
          case 'tool_use':
          case 'tool_call':
            return 'function_call';
          default:
            return finishReason.toLowerCase();
        }
    }
  }

  @override
  CohereEmbeddingRequest mapEmbeddingRequest(EmbeddingRequest request,
      {String? defaultModel}) {
    return _mapEmbeddingRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  EmbeddingResponse mapEmbeddingResponse(dynamic response) {
    if (response is! CohereEmbeddingResponse) {
      throw ArgumentError(
          'Expected CohereEmbeddingResponse, got ${response.runtimeType}');
    }
    return _mapEmbeddingResponseImpl(response);
  }

  @override
  dynamic mapImageRequest(ImageRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Cohere provider does not support image generation.',
      code: 'UNSUPPORTED_OPERATION',
      provider: 'cohere',
    );
  }

  @override
  ImageResponse mapImageResponse(dynamic response) {
    throw CapabilityError(
      message: 'Cohere provider does not support image generation.',
      code: 'UNSUPPORTED_OPERATION',
      provider: 'cohere',
    );
  }

  // Private implementation methods

  CohereEmbeddingRequest _mapEmbeddingRequestImpl(
    EmbeddingRequest request, {
    String? defaultModel,
  }) {
    // Determine model - use request.model, then defaultModel, or throw error
    final model = request.model ?? defaultModel;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in EmbeddingRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Extract Cohere-specific options from providerOptions
    final cohereOptions =
        request.providerOptions?['cohere'] ?? <String, dynamic>{};

    // v2 API requires embedding_types - default to ['float'] if not specified
    final embeddingTypes = cohereOptions['embedding_types'] != null
        ? List<String>.from(cohereOptions['embedding_types'] as List)
        : cohereOptions['embeddingTypes'] != null
            ? List<String>.from(cohereOptions['embeddingTypes'] as List)
            : ['float']; // Default to float for v2

    // v2 API requires input_type - default to 'search_document' if not specified
    // Valid values: 'search_document', 'search_query', 'classification', 'clustering'
    final inputType = cohereOptions['input_type'] as String? ??
        cohereOptions['inputType'] as String? ??
        'search_document'; // Default to search_document for v2

    // Build Cohere v2 request
    return CohereEmbeddingRequest(
      texts: request.inputs,
      model: model,
      inputType: inputType,
      embeddingTypes: embeddingTypes,
      truncate: cohereOptions['truncate'] as String?,
    );
  }

  EmbeddingResponse _mapEmbeddingResponseImpl(
      CohereEmbeddingResponse response) {
    // Convert Cohere embeddings to SDK EmbeddingData
    final embeddings = response.embeddings.asMap().entries.map((entry) {
      final index = entry.key;
      final embedding = entry.value;

      return EmbeddingData(
        vector: embedding,
        dimension: embedding.length,
        index: index,
      );
    }).toList();

    // Convert Cohere usage to SDK usage
    // Cohere reports tokens in usage.meta.tokens
    final usage = response.usage != null && response.usage!.tokens != null
        ? Usage(
            promptTokens: response.usage!.tokens!,
            completionTokens: 0, // Embeddings don't have completion tokens
            totalTokens: response.usage!.tokens!,
          )
        : null;

    // Determine model name
    final modelName = response.model ?? 'unknown';

    return EmbeddingResponse(
      embeddings: embeddings,
      model: modelName,
      provider: 'cohere',
      usage: usage,
    );
  }

  @override
  dynamic mapTtsRequest(TtsRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Cohere does not support text-to-speech',
      code: 'TTS_NOT_SUPPORTED',
      provider: 'cohere',
    );
  }

  @override
  AudioResponse mapTtsResponse(
    dynamic response,
    Uint8List audioBytes,
    TtsRequest request,
  ) {
    throw CapabilityError(
      message: 'Cohere does not support text-to-speech',
      code: 'TTS_NOT_SUPPORTED',
      provider: 'cohere',
    );
  }

  @override
  dynamic mapSttRequest(SttRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Cohere does not support speech-to-text',
      code: 'STT_NOT_SUPPORTED',
      provider: 'cohere',
    );
  }

  @override
  TranscriptionResponse mapSttResponse(
    dynamic response,
    SttRequest request,
  ) {
    throw CapabilityError(
      message: 'Cohere does not support speech-to-text',
      code: 'STT_NOT_SUPPORTED',
      provider: 'cohere',
    );
  }

  @override
  dynamic mapVideoRequest(VideoRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Cohere does not support video generation',
      code: 'VIDEO_GENERATION_NOT_SUPPORTED',
      provider: 'cohere',
    );
  }

  @override
  VideoResponse mapVideoResponse(dynamic response) {
    throw CapabilityError(
      message: 'Cohere does not support video generation',
      code: 'VIDEO_GENERATION_NOT_SUPPORTED',
      provider: 'cohere',
    );
  }

  @override
  dynamic mapVideoAnalysisRequest(
    VideoAnalysisRequest request, {
    String? defaultModel,
  }) {
    throw CapabilityError(
      message: 'Cohere does not support video analysis',
      code: 'VIDEO_ANALYSIS_NOT_SUPPORTED',
      provider: 'cohere',
    );
  }

  @override
  VideoAnalysisResponse mapVideoAnalysisResponse(dynamic response) {
    throw CapabilityError(
      message: 'Cohere does not support video analysis',
      code: 'VIDEO_ANALYSIS_NOT_SUPPORTED',
      provider: 'cohere',
    );
  }
}
