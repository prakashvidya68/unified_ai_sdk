/// Provider-specific models for Anthropic Claude API format.
///
/// This file contains data models that match Anthropic's API request and response
/// formats. These models are used internally by [AnthropicProvider] to communicate
/// with the Anthropic Claude API endpoints.
///
/// **Note:** These models are provider-specific and should not be used directly
/// by SDK users. Use the unified SDK models ([ChatRequest], [ChatResponse], etc.)
/// instead, which will be automatically converted to/from these Anthropic-specific
/// models by [AnthropicMapper].
///
/// **Anthropic API Reference:**
/// https://docs.anthropic.com/claude/reference/messages-post
library;

import '../../error/error_types.dart';

/// Represents a message completion request in Anthropic's API format.
///
/// This model matches the exact structure expected by Anthropic's `/v1/messages`
/// endpoint. Key differences from OpenAI:
/// - Uses `system` field for system prompts (not a message role)
/// - Requires `max_tokens` (not optional)
/// - Uses `stop_sequences` instead of `stop`
/// - Supports `top_k` parameter
/// - Content can be an array of content blocks
///
/// **Anthropic API Reference:**
/// https://docs.anthropic.com/claude/reference/messages-post
///
/// **Example:**
/// ```dart
/// final request = AnthropicChatRequest(
///   model: 'claude-3-opus-20240229',
///   maxTokens: 1024,
///   messages: [
///     {'role': 'user', 'content': 'Hello!'}
///   ],
///   system: 'You are a helpful assistant.',
///   temperature: 0.7,
/// );
/// ```
class AnthropicChatRequest {
  /// ID of the model to use.
  ///
  /// Examples: "claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307"
  final String model;

  /// Maximum number of tokens to generate before stopping.
  ///
  /// Note that our models may stop before reaching this maximum. This parameter
  /// only specifies the absolute maximum number of tokens to generate.
  ///
  /// Required field in Anthropic API.
  final int maxTokens;

  /// List of messages comprising the conversation.
  ///
  /// Each message is a map with "role" and "content" keys.
  /// Roles can be: "user" or "assistant"
  /// Content can be a string or an array of content blocks.
  final List<Map<String, dynamic>> messages;

  /// System prompt for the model.
  ///
  /// System prompts are a way to provide context and instructions to Claude,
  /// such as specifying a particular goal or role. The system prompt is separate
  /// from the messages array and is not included in the conversation history.
  final String? system;

  /// Sampling temperature between 0 and 1.
  ///
  /// Higher values make output more random, lower values more focused.
  /// Defaults to 1.0 if not specified.
  final double? temperature;

  /// Alternative to temperature: nucleus sampling.
  ///
  /// Consider tokens with top_p probability mass. 0.1 means only tokens
  /// comprising the top 10% probability mass are considered.
  final double? topP;

  /// Only sample from the top K options for each subsequent token.
  ///
  /// Used to remove "long tail" low probability responses.
  /// Recommended for advanced use cases only.
  final int? topK;

  /// Sequences where the API will stop generating further tokens.
  ///
  /// The returned text will not contain the stop sequence.
  final List<String>? stopSequences;

  /// Whether to stream back partial progress.
  ///
  /// If set, tokens will be sent as data-only server-sent events as they become
  /// available, with the stream terminated by a `data: [DONE]` message.
  final bool? stream;

  /// Metadata for the request.
  ///
  /// An object describing metadata about the request.
  final Map<String, dynamic>? metadata;

  /// Definitions of tools that the model may use.
  ///
  /// If you include `tools` in your API request, Claude can use those tools
  /// when processing the request.
  final List<Map<String, dynamic>>? tools;

  /// How the model should use the provided tools.
  ///
  /// Can be "auto", "any", or a specific tool definition.
  final dynamic toolChoice;

  /// Creates a new [AnthropicChatRequest] instance.
  ///
  /// [model], [maxTokens], and [messages] are required. All other fields are optional.
  ///
  /// **Validation:**
  /// - [model] must not be empty
  /// - [maxTokens] must be positive
  /// - [messages] must not be empty
  /// - [temperature] must be between 0.0 and 1.0 if provided
  /// - [topP] must be between 0.0 and 1.0 if provided
  /// - [topK] must be positive if provided
  AnthropicChatRequest({
    required this.model,
    required this.maxTokens,
    required this.messages,
    this.system,
    this.temperature,
    this.topP,
    this.topK,
    this.stopSequences,
    this.stream,
    this.metadata,
    this.tools,
    this.toolChoice,
  })  : assert(model.isNotEmpty, 'model must not be empty'),
        assert(maxTokens > 0, 'maxTokens must be positive'),
        assert(messages.isNotEmpty, 'messages must not be empty'),
        assert(
            temperature == null || (temperature >= 0.0 && temperature <= 1.0),
            'temperature must be between 0.0 and 1.0'),
        assert(topP == null || (topP >= 0.0 && topP <= 1.0),
            'top_p must be between 0.0 and 1.0'),
        assert(topK == null || topK > 0, 'top_k must be positive');

  /// Converts this [AnthropicChatRequest] to a JSON map.
  ///
  /// The resulting map matches Anthropic's API request format exactly.
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'max_tokens': maxTokens,
      'messages': messages,
      if (system != null) 'system': system,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (topK != null) 'top_k': topK,
      if (stopSequences != null && stopSequences!.isNotEmpty)
        'stop_sequences': stopSequences,
      if (stream == true) 'stream': stream,
      if (metadata != null) 'metadata': metadata,
      if (tools != null && tools!.isNotEmpty) 'tools': tools,
      if (toolChoice != null) 'tool_choice': toolChoice,
    };
  }

  /// Creates an [AnthropicChatRequest] from a JSON map.
  ///
  /// Parses Anthropic API request format into an [AnthropicChatRequest] object.
  ///
  /// Throws [ClientError] if the JSON is invalid or missing required fields.
  factory AnthropicChatRequest.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as String?;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message: 'Missing required field: model',
        code: 'INVALID_REQUEST',
      );
    }

    final maxTokens = json['max_tokens'] as int?;
    if (maxTokens == null || maxTokens <= 0) {
      throw ClientError(
        message: 'Missing or invalid required field: max_tokens',
        code: 'INVALID_REQUEST',
      );
    }

    final messages = json['messages'];
    if (messages == null || messages is! List || messages.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: messages',
        code: 'INVALID_REQUEST',
      );
    }

    return AnthropicChatRequest(
      model: model,
      maxTokens: maxTokens,
      messages: List<Map<String, dynamic>>.from(messages),
      system: json['system'] as String?,
      temperature: json['temperature'] as double?,
      topP: json['top_p'] as double?,
      topK: json['top_k'] as int?,
      stopSequences: json['stop_sequences'] != null
          ? List<String>.from(json['stop_sequences'] as List)
          : null,
      stream: json['stream'] as bool?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      tools: json['tools'] != null
          ? List<Map<String, dynamic>>.from(json['tools'] as List)
          : null,
      toolChoice: json['tool_choice'],
    );
  }

  @override
  String toString() {
    return 'AnthropicChatRequest(model: $model, messages: ${messages.length}, '
        'maxTokens: $maxTokens, temperature: $temperature)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnthropicChatRequest &&
        other.model == model &&
        other.maxTokens == maxTokens &&
        _listEquals(other.messages, messages) &&
        other.system == system &&
        other.temperature == temperature &&
        other.topP == topP &&
        other.topK == topK &&
        _listEqualsStrings(other.stopSequences, stopSequences) &&
        other.stream == stream &&
        _mapEquals(other.metadata, metadata) &&
        _listEqualsMaps(other.tools, tools) &&
        other.toolChoice == toolChoice;
  }

  @override
  int get hashCode {
    int messagesHash = 0;
    for (final msg in messages) {
      messagesHash = Object.hash(
          messagesHash, Object.hashAll(msg.keys), Object.hashAll(msg.values));
    }

    int toolsHash = 0;
    if (tools != null) {
      for (final tool in tools!) {
        toolsHash = Object.hash(
            toolsHash, Object.hashAll(tool.keys), Object.hashAll(tool.values));
      }
    }

    return Object.hash(
      model,
      maxTokens,
      messagesHash,
      system,
      temperature,
      topP,
      topK,
      Object.hashAll(stopSequences ?? []),
      stream,
      metadata,
      toolsHash,
      toolChoice,
    );
  }

  bool _listEquals(
      List<Map<String, dynamic>>? a, List<Map<String, dynamic>>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_mapEqualsDeep(a[i], b[i])) return false;
    }
    return true;
  }

  bool _listEqualsStrings(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _listEqualsMaps(
      List<Map<String, dynamic>>? a, List<Map<String, dynamic>>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_mapEqualsDeep(a[i], b[i])) return false;
    }
    return true;
  }

  bool _mapEqualsDeep(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Represents a message completion response in Anthropic's API format.
///
/// This model matches the exact structure returned by Anthropic's `/v1/messages`
/// endpoint.
///
/// **Anthropic API Reference:**
/// https://docs.anthropic.com/claude/reference/messages-object
class AnthropicChatResponse {
  /// Unique identifier for the message.
  final String id;

  /// Object type, always "message".
  final String type;

  /// The role of the assistant's message.
  ///
  /// Always "assistant" for responses.
  final String role;

  /// The content of the message.
  ///
  /// Content is an array of content blocks. Each block can be:
  /// - Text block: {"type": "text", "text": "..."}
  /// - Tool use block: {"type": "tool_use", ...}
  final List<Map<String, dynamic>> content;

  /// The model used for the completion.
  final String model;

  /// The reason the model stopped generating tokens.
  ///
  /// Possible values:
  /// - "end_turn": The model reached a natural stopping point
  /// - "max_tokens": The model reached the max_tokens limit
  /// - "stop_sequence": The model encountered a stop sequence
  /// - "tool_use": The model is making a tool/function call
  final String? stopReason;

  /// The stop sequence that caused the model to stop, if any.
  final String? stopSequence;

  /// Usage statistics for the completion request.
  final AnthropicUsage usage;

  /// Creates a new [AnthropicChatResponse] instance.
  AnthropicChatResponse({
    required this.id,
    required this.type,
    required this.role,
    required this.content,
    required this.model,
    this.stopReason,
    this.stopSequence,
    required this.usage,
  });

  /// Creates an [AnthropicChatResponse] from a JSON map.
  ///
  /// Parses Anthropic API response format into an [AnthropicChatResponse] object.
  ///
  /// Throws [ClientError] if the JSON is invalid or missing required fields.
  factory AnthropicChatResponse.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw ClientError(
        message: 'Missing required field: id',
        code: 'INVALID_RESPONSE',
      );
    }

    final type = json['type'] as String?;
    if (type == null || type.isEmpty) {
      throw ClientError(
        message: 'Missing required field: type',
        code: 'INVALID_RESPONSE',
      );
    }

    final role = json['role'] as String?;
    if (role == null || role.isEmpty) {
      throw ClientError(
        message: 'Missing required field: role',
        code: 'INVALID_RESPONSE',
      );
    }

    final content = json['content'];
    if (content == null || content is! List) {
      throw ClientError(
        message: 'Missing or invalid required field: content',
        code: 'INVALID_RESPONSE',
      );
    }

    final model = json['model'] as String?;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message: 'Missing required field: model',
        code: 'INVALID_RESPONSE',
      );
    }

    final usage = json['usage'];
    if (usage == null || usage is! Map) {
      throw ClientError(
        message: 'Missing or invalid required field: usage',
        code: 'INVALID_RESPONSE',
      );
    }

    return AnthropicChatResponse(
      id: id,
      type: type,
      role: role,
      content: List<Map<String, dynamic>>.from(content),
      model: model,
      stopReason: json['stop_reason'] as String?,
      stopSequence: json['stop_sequence'] as String?,
      usage: AnthropicUsage.fromJson(usage as Map<String, dynamic>),
    );
  }

  /// Converts this [AnthropicChatResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'role': role,
      'content': content,
      'model': model,
      if (stopReason != null) 'stop_reason': stopReason,
      if (stopSequence != null) 'stop_sequence': stopSequence,
      'usage': usage.toJson(),
    };
  }

  @override
  String toString() {
    return 'AnthropicChatResponse(id: $id, model: $model, '
        'contentBlocks: ${content.length}, stopReason: $stopReason)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnthropicChatResponse &&
        other.id == id &&
        other.type == type &&
        other.role == role &&
        _listEquals(other.content, content) &&
        other.model == model &&
        other.stopReason == stopReason &&
        other.stopSequence == stopSequence &&
        other.usage == usage;
  }

  @override
  int get hashCode {
    int contentHash = 0;
    for (final block in content) {
      contentHash = Object.hash(contentHash, Object.hashAll(block.keys),
          Object.hashAll(block.values));
    }

    return Object.hash(
      id,
      type,
      role,
      contentHash,
      model,
      stopReason,
      stopSequence,
      usage,
    );
  }

  bool _listEquals(
      List<Map<String, dynamic>>? a, List<Map<String, dynamic>>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_mapEqualsDeep(a[i], b[i])) return false;
    }
    return true;
  }

  bool _mapEqualsDeep(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Represents usage statistics in Anthropic's API format.
///
/// Anthropic tracks input tokens and output tokens separately.
class AnthropicUsage {
  /// Number of input tokens used.
  final int inputTokens;

  /// Number of output tokens used.
  final int outputTokens;

  /// Creates a new [AnthropicUsage] instance.
  AnthropicUsage({
    required this.inputTokens,
    required this.outputTokens,
  });

  /// Creates an [AnthropicUsage] from a JSON map.
  factory AnthropicUsage.fromJson(Map<String, dynamic> json) {
    return AnthropicUsage(
      inputTokens: json['input_tokens'] as int? ?? 0,
      outputTokens: json['output_tokens'] as int? ?? 0,
    );
  }

  /// Converts this [AnthropicUsage] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
    };
  }

  @override
  String toString() {
    return 'AnthropicUsage(inputTokens: $inputTokens, outputTokens: $outputTokens)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnthropicUsage &&
        other.inputTokens == inputTokens &&
        other.outputTokens == outputTokens;
  }

  @override
  int get hashCode => Object.hash(inputTokens, outputTokens);
}
