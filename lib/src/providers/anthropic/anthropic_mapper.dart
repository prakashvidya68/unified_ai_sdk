/// Mapper for converting between unified SDK models and Anthropic-specific models.
///
/// This class provides bidirectional conversion between the provider-agnostic
/// SDK models ([ChatRequest], [ChatResponse]) and Anthropic-specific models
/// ([AnthropicChatRequest], [AnthropicChatResponse]).
///
/// **Design Pattern:** Adapter/Mapper Pattern
///
/// This mapper allows the SDK to maintain a unified API while supporting
/// Anthropic-specific features and formats. Users interact with unified models,
/// but internally the SDK converts to/from Anthropic-specific formats.
///
/// **Key Differences from OpenAI:**
/// - System prompts are a separate field, not a message role
/// - Content can be an array of content blocks
/// - Uses `stop_sequences` instead of `stop`
/// - Requires `max_tokens` (not optional)
/// - Uses `top_k` parameter (not in OpenAI)
/// - No `n` parameter (can't generate multiple choices)
/// - Different usage format (input_tokens/output_tokens vs prompt_tokens/completion_tokens)
///
/// **Example usage:**
/// ```dart
/// // SDK → Anthropic
/// final chatRequest = ChatRequest(
///   messages: [
///     Message(role: Role.system, content: 'You are helpful.'),
///     Message(role: Role.user, content: 'Hello!'),
///   ],
///   maxTokens: 1024,
/// );
/// final mapper = AnthropicMapper.instance;
/// final anthropicRequest = mapper.mapChatRequest(chatRequest);
///
/// // Anthropic → SDK
/// final anthropicResponse = AnthropicChatResponse.fromJson(apiResponse);
/// final chatResponse = mapper.mapChatResponse(anthropicResponse);
/// ```
library;

import 'dart:typed_data';

import '../../error/error_types.dart';
import '../../models/common/message.dart';
import '../../models/common/usage.dart';
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
import '../../models/base_enums.dart';
import '../base/provider_mapper.dart';
import 'anthropic_models.dart';

/// Mapper for converting between unified SDK models and Anthropic-specific models.
///
/// Implements [ProviderMapper] to provide Anthropic-specific conversion logic.
/// This class uses a singleton pattern and provides instance methods for
/// converting between unified SDK models and Anthropic-specific formats.
///
/// **Usage:**
/// ```dart
/// final mapper = AnthropicMapper.instance;
/// final request = mapper.mapChatRequest(chatRequest);
/// final response = mapper.mapChatResponse(anthropicResponse);
/// ```
class AnthropicMapper implements ProviderMapper {
  /// Private constructor to enforce singleton pattern.
  /// Use [AnthropicMapper.instance] to access the mapper instance.
  AnthropicMapper._();

  /// Singleton instance for instance-based usage.
  ///
  /// Use this when you need to inject the mapper as a dependency or
  /// when working with the [ProviderMapper] interface.
  static final AnthropicMapper instance = AnthropicMapper._();

  // Instance methods implementing ProviderMapper interface

  @override
  AnthropicChatRequest mapChatRequest(ChatRequest request,
      {String? defaultModel}) {
    return _mapChatRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  ChatResponse mapChatResponse(dynamic response) {
    if (response is! AnthropicChatResponse) {
      throw ArgumentError(
          'Expected AnthropicChatResponse, got ${response.runtimeType}');
    }
    return _mapChatResponseImpl(response);
  }

  @override
  dynamic mapEmbeddingRequest(EmbeddingRequest request,
      {String? defaultModel}) {
    // Anthropic doesn't support embeddings in the Messages API
    throw CapabilityError(
      message: 'Anthropic Claude API does not support embeddings',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: 'anthropic',
    );
  }

  @override
  EmbeddingResponse mapEmbeddingResponse(dynamic response) {
    throw CapabilityError(
      message: 'Anthropic Claude API does not support embeddings',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: 'anthropic',
    );
  }

  @override
  dynamic mapImageRequest(ImageRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Anthropic Claude API does not support image generation',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: 'anthropic',
    );
  }

  @override
  ImageResponse mapImageResponse(dynamic response) {
    throw CapabilityError(
      message: 'Anthropic Claude API does not support image generation',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: 'anthropic',
    );
  }

  // Private implementation methods

  AnthropicChatRequest _mapChatRequestImpl(
    ChatRequest request, {
    String? defaultModel,
  }) {
    // Separate system messages from regular messages
    String? systemPrompt;
    final messages = <Map<String, dynamic>>[];

    for (final msg in request.messages) {
      if (msg.role == Role.system) {
        // Accumulate system messages into system prompt
        if (systemPrompt == null) {
          systemPrompt = msg.content;
        } else {
          systemPrompt = '$systemPrompt\n\n${msg.content}';
        }
      } else {
        // Convert user/assistant messages to Anthropic format
        final messageMap = <String, dynamic>{
          'role': _mapRoleToAnthropic(msg.role),
          'content': msg.content, // Simple string content
        };
        if (msg.name != null) {
          messageMap['name'] = msg.name;
        }
        // Merge any metadata into the message
        if (msg.meta != null) {
          messageMap.addAll(msg.meta!);
        }
        messages.add(messageMap);
      }
    }

    // Ensure we have at least one message
    if (messages.isEmpty) {
      throw ClientError(
        message: 'At least one user or assistant message is required',
        code: 'INVALID_REQUEST',
      );
    }

    // Extract Anthropic-specific options from providerOptions
    final anthropicOptions =
        request.providerOptions?['anthropic'] ?? <String, dynamic>{};

    // Determine model - use request.model, then defaultModel, or throw error
    final model = request.model ?? defaultModel;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in ChatRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // max_tokens is required for Anthropic - use request.maxTokens or default
    final maxTokens = request.maxTokens ?? 1024;
    if (maxTokens <= 0) {
      throw ClientError(
        message: 'maxTokens must be positive',
        code: 'INVALID_REQUEST',
      );
    }

    // Convert stop sequences (Anthropic uses stop_sequences array)
    // ChatRequest.stop is List<String>?, so we can use it directly
    final stopSequences = request.stop;

    // Build Anthropic request
    return AnthropicChatRequest(
      model: model,
      maxTokens: maxTokens,
      messages: messages,
      system: systemPrompt,
      temperature: request.temperature,
      topP: request.topP,
      // Anthropic-specific fields from providerOptions
      topK:
          anthropicOptions['top_k'] as int? ?? anthropicOptions['topK'] as int?,
      stopSequences: stopSequences ??
          (anthropicOptions['stop_sequences'] != null
              ? List<String>.from(anthropicOptions['stop_sequences'] as List)
              : anthropicOptions['stopSequences'] != null
                  ? List<String>.from(anthropicOptions['stopSequences'] as List)
                  : null),
      stream: anthropicOptions['stream'] as bool?,
      metadata: anthropicOptions['metadata'] as Map<String, dynamic>?,
      tools: anthropicOptions['tools'] != null
          ? List<Map<String, dynamic>>.from(anthropicOptions['tools'] as List)
          : null,
      toolChoice:
          anthropicOptions['tool_choice'] ?? anthropicOptions['toolChoice'],
    );
  }

  ChatResponse _mapChatResponseImpl(AnthropicChatResponse response) {
    // Extract text content from content blocks
    // Anthropic returns content as an array of blocks, e.g.:
    // [{"type": "text", "text": "Hello!"}]
    String content = '';
    final contentBlocks = response.content;

    for (final block in contentBlocks) {
      final type = block['type'] as String?;
      if (type == 'text') {
        final text = block['text'] as String? ?? '';
        if (content.isEmpty) {
          content = text;
        } else {
          content = '$content\n$text';
        }
      }
      // Handle other block types (tool_use, etc.) if needed
    }

    // Anthropic doesn't support multiple choices (n parameter)
    // So we always create a single choice
    final message = Message(
      role: Role.assistant,
      content: content,
      meta: {
        'stop_reason': response.stopReason,
        if (response.stopSequence != null)
          'stop_sequence': response.stopSequence,
      },
    );

    final choice = ChatChoice(
      index: 0,
      message: message,
      finishReason: _mapStopReasonToFinishReason(response.stopReason),
    );

    // Convert Anthropic usage to SDK usage
    // Anthropic uses input_tokens/output_tokens, SDK uses prompt_tokens/completion_tokens
    final usage = Usage(
      promptTokens: response.usage.inputTokens,
      completionTokens: response.usage.outputTokens,
      totalTokens: response.usage.inputTokens + response.usage.outputTokens,
    );

    // Build metadata from Anthropic-specific fields
    final metadata = <String, dynamic>{
      'type': response.type,
      'role': response.role,
      if (response.stopReason != null) 'stop_reason': response.stopReason,
      if (response.stopSequence != null) 'stop_sequence': response.stopSequence,
    };

    return ChatResponse(
      id: response.id,
      choices: [choice],
      usage: usage,
      model: response.model,
      provider: 'anthropic',
      timestamp: DateTime.now(), // Anthropic doesn't provide timestamp
      metadata: metadata,
    );
  }

  /// Maps SDK Role enum to Anthropic role string.
  ///
  /// Anthropic supports: "user", "assistant"
  /// System messages are handled separately (not mapped here).
  String _mapRoleToAnthropic(Role role) {
    switch (role) {
      case Role.user:
        return 'user';
      case Role.assistant:
        return 'assistant';
      case Role.system:
        // System messages should be extracted before calling this
        throw ArgumentError(
            'System messages should be extracted to system field, not mapped to role');
      case Role.function:
        // Anthropic doesn't have a function role
        // Function results are typically sent as user messages
        return 'user';
    }
  }

  /// Maps Anthropic stop_reason to SDK finish_reason format.
  ///
  /// Converts Anthropic-specific stop reasons to a format compatible
  /// with the unified SDK finish_reason field.
  String? _mapStopReasonToFinishReason(String? stopReason) {
    if (stopReason == null) return null;

    switch (stopReason) {
      case 'end_turn':
        return 'stop';
      case 'max_tokens':
        return 'length';
      case 'stop_sequence':
        return 'stop';
      case 'tool_use':
        return 'function_call';
      default:
        return stopReason;
    }
  }

  @override
  dynamic mapTtsRequest(TtsRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Anthropic does not support text-to-speech',
      code: 'TTS_NOT_SUPPORTED',
      provider: 'anthropic',
    );
  }

  @override
  AudioResponse mapTtsResponse(
    dynamic response,
    Uint8List audioBytes,
    TtsRequest request,
  ) {
    throw CapabilityError(
      message: 'Anthropic does not support text-to-speech',
      code: 'TTS_NOT_SUPPORTED',
      provider: 'anthropic',
    );
  }

  @override
  dynamic mapSttRequest(SttRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Anthropic does not support speech-to-text',
      code: 'STT_NOT_SUPPORTED',
      provider: 'anthropic',
    );
  }

  @override
  TranscriptionResponse mapSttResponse(
    dynamic response,
    SttRequest request,
  ) {
    throw CapabilityError(
      message: 'Anthropic does not support speech-to-text',
      code: 'STT_NOT_SUPPORTED',
      provider: 'anthropic',
    );
  }
}
