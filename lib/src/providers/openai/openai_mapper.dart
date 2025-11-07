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

import '../../error/error_types.dart';
import '../../models/common/message.dart';
import '../../models/common/usage.dart';
import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/embedding_response.dart';
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
}
