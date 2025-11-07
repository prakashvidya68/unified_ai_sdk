/// Provider-specific models for OpenAI API format.
///
/// This file contains data models that match OpenAI's API request and response
/// formats. These models are used internally by [OpenAIProvider] to communicate
/// with the OpenAI API endpoints.
///
/// **Note:** These models are provider-specific and should not be used directly
/// by SDK users. Use the unified SDK models ([ChatRequest], [ChatResponse], etc.)
/// instead, which will be automatically converted to/from these OpenAI-specific
/// models by [OpenAIMapper].

import '../../error/error_types.dart';

/// Represents a chat completion request in OpenAI's API format.
///
/// This model matches the exact structure expected by OpenAI's `/v1/chat/completions`
/// endpoint. It includes all OpenAI-specific fields like `presence_penalty`,
/// `frequency_penalty`, `logit_bias`, etc.
///
/// **OpenAI API Reference:**
/// https://platform.openai.com/docs/api-reference/chat/create
///
/// **Example:**
/// ```dart
/// final request = OpenAIChatRequest(
///   model: 'gpt-4',
///   messages: [
///     {'role': 'user', 'content': 'Hello!'}
///   ],
///   temperature: 0.7,
///   maxTokens: 500,
/// );
/// ```
class OpenAIChatRequest {
  /// ID of the model to use.
  ///
  /// Examples: "gpt-4", "gpt-3.5-turbo", "gpt-4-turbo-preview"
  final String model;

  /// List of messages comprising the conversation.
  ///
  /// Each message is a map with "role" and "content" keys.
  /// Roles can be: "system", "user", "assistant", "tool", "function"
  final List<Map<String, dynamic>> messages;

  /// Sampling temperature between 0 and 2.
  ///
  /// Higher values make output more random, lower values more focused.
  /// Defaults to 1.0 if not specified.
  final double? temperature;

  /// Maximum number of tokens to generate.
  ///
  /// The total length of input tokens and generated tokens is limited by the
  /// model's context length.
  final int? maxTokens;

  /// Alternative to temperature: nucleus sampling.
  ///
  /// Consider tokens with top_p probability mass. 0.1 means only tokens
  /// comprising the top 10% probability mass are considered.
  final double? topP;

  /// Number of chat completion choices to generate.
  ///
  /// Defaults to 1. Note: Using n > 1 can reduce cacheability.
  final int? n;

  /// Up to 4 sequences where the API will stop generating further tokens.
  final List<String>? stop;

  /// Number between -2.0 and 2.0. Positive values penalize new tokens based
  /// on whether they appear in the text so far, increasing the model's likelihood
  /// to talk about new topics.
  final double? presencePenalty;

  /// Number between -2.0 and 2.0. Positive values penalize new tokens based
  /// on their existing frequency in the text so far, decreasing the model's
  /// likelihood to repeat the same line verbatim.
  final double? frequencyPenalty;

  /// Modify the likelihood of specified tokens appearing in the completion.
  ///
  /// Accepts a map that maps tokens (specified by their token ID in the tokenizer)
  /// to an associated bias value from -100 to 100.
  final Map<String, int>? logitBias;

  /// A unique identifier representing your end-user.
  ///
  /// Can help OpenAI monitor and detect abuse.
  final String? user;

  /// Whether to stream back partial progress.
  ///
  /// If set, tokens will be sent as data-only server-sent events as they become
  /// available, with the stream terminated by a `data: [DONE]` message.
  final bool? stream;

  /// A list of tools the model may call.
  ///
  /// Currently only functions are supported as a tool. Use this to provide a list
  /// of functions the model may generate JSON inputs for.
  final List<Map<String, dynamic>>? tools;

  /// Controls which (if any) function is called by the model.
  ///
  /// Can be "none", "auto", or a specific function definition.
  final dynamic toolChoice;

  /// The name of the model to use for function calling.
  ///
  /// Deprecated in favor of `tools` parameter.
  @Deprecated('Use tools parameter instead')
  final String? functionCall;

  /// Deprecated. Use `tools` instead.
  @Deprecated('Use tools parameter instead')
  final Map<String, dynamic>? functions;

  /// Creates a new [OpenAIChatRequest] instance.
  ///
  /// [model] and [messages] are required. All other fields are optional.
  ///
  /// **Validation:**
  /// - [model] must not be empty
  /// - [messages] must not be empty
  /// - [temperature] must be between 0.0 and 2.0 if provided
  /// - [maxTokens] must be positive if provided
  /// - [n] must be positive if provided
  OpenAIChatRequest({
    required this.model,
    required this.messages,
    this.temperature,
    this.maxTokens,
    this.topP,
    this.n,
    this.stop,
    this.presencePenalty,
    this.frequencyPenalty,
    this.logitBias,
    this.user,
    this.stream,
    this.tools,
    this.toolChoice,
    @Deprecated('Use tools parameter instead') this.functionCall,
    @Deprecated('Use tools parameter instead') this.functions,
  })  : assert(model.isNotEmpty, 'model must not be empty'),
        assert(messages.isNotEmpty, 'messages must not be empty'),
        assert(
            temperature == null || (temperature >= 0.0 && temperature <= 2.0),
            'temperature must be between 0.0 and 2.0'),
        assert(
            maxTokens == null || maxTokens > 0, 'maxTokens must be positive'),
        assert(n == null || n > 0, 'n must be positive');

  /// Converts this request to a JSON map matching OpenAI's API format.
  ///
  /// Only non-null optional fields are included in the output.
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "model": "gpt-4",
  ///   "messages": [
  ///     {"role": "user", "content": "Hello!"}
  ///   ],
  ///   "temperature": 0.7,
  ///   "max_tokens": 500
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'messages': messages,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (topP != null) 'top_p': topP,
      if (n != null) 'n': n,
      if (stop != null) 'stop': stop,
      if (presencePenalty != null) 'presence_penalty': presencePenalty,
      if (frequencyPenalty != null) 'frequency_penalty': frequencyPenalty,
      if (logitBias != null) 'logit_bias': logitBias,
      if (user != null) 'user': user,
      if (stream != null) 'stream': stream,
      if (tools != null) 'tools': tools,
      if (toolChoice != null) 'tool_choice': toolChoice,
      if (functionCall != null) 'function_call': functionCall,
      if (functions != null) 'functions': functions,
    };
  }

  /// Creates an [OpenAIChatRequest] from a JSON map.
  ///
  /// Parses OpenAI API request format into an [OpenAIChatRequest] object.
  ///
  /// Throws [ClientError] if the JSON is invalid or missing required fields.
  factory OpenAIChatRequest.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as String?;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message: 'Missing required field: model',
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

    return OpenAIChatRequest(
      model: model,
      messages: List<Map<String, dynamic>>.from(messages),
      temperature: json['temperature'] as double?,
      maxTokens: json['max_tokens'] as int?,
      topP: json['top_p'] as double?,
      n: json['n'] as int?,
      stop:
          json['stop'] != null ? List<String>.from(json['stop'] as List) : null,
      presencePenalty: json['presence_penalty'] as double?,
      frequencyPenalty: json['frequency_penalty'] as double?,
      logitBias: json['logit_bias'] != null
          ? Map<String, int>.from(json['logit_bias'] as Map)
          : null,
      user: json['user'] as String?,
      stream: json['stream'] as bool?,
      tools: json['tools'] != null
          ? List<Map<String, dynamic>>.from(json['tools'] as List)
          : null,
      toolChoice: json['tool_choice'],
      functionCall: json['function_call'] as String?,
      functions: json['functions'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'OpenAIChatRequest(model: $model, messages: ${messages.length}, '
        'temperature: $temperature, maxTokens: $maxTokens)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OpenAIChatRequest &&
        other.model == model &&
        _listEquals(other.messages, messages) &&
        other.temperature == temperature &&
        other.maxTokens == maxTokens &&
        other.topP == topP &&
        other.n == n &&
        _listEqualsStrings(other.stop, stop) &&
        other.presencePenalty == presencePenalty &&
        other.frequencyPenalty == frequencyPenalty &&
        _mapEquals(other.logitBias, logitBias) &&
        other.user == user &&
        other.stream == stream &&
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
      messagesHash,
      temperature,
      maxTokens,
      topP,
      n,
      Object.hashAll(stop ?? []),
      presencePenalty,
      frequencyPenalty,
      logitBias,
      user,
      stream,
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

  bool _mapEquals(Map<String, int>? a, Map<String, int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Represents a chat completion response in OpenAI's API format.
///
/// This model matches the exact structure returned by OpenAI's `/v1/chat/completions`
/// endpoint.
///
/// **OpenAI API Reference:**
/// https://platform.openai.com/docs/api-reference/chat/object
class OpenAIChatResponse {
  /// Unique identifier for the chat completion.
  final String id;

  /// Object type, always "chat.completion".
  final String object;

  /// Unix timestamp (in seconds) of when the chat completion was created.
  final int created;

  /// The model used for the chat completion.
  final String model;

  /// List of completion choices.
  final List<OpenAIChatChoice> choices;

  /// Usage statistics for the completion request.
  final OpenAIUsage usage;

  /// System fingerprint for the completion.
  ///
  /// Can be used to determine which backend was used to process the request.
  final String? systemFingerprint;

  /// Creates a new [OpenAIChatResponse] instance.
  OpenAIChatResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
    this.systemFingerprint,
  });

  /// Creates an [OpenAIChatResponse] from a JSON map.
  ///
  /// Parses OpenAI API response format into an [OpenAIChatResponse] object.
  ///
  /// Throws [ClientError] if the JSON is invalid or missing required fields.
  factory OpenAIChatResponse.fromJson(Map<String, dynamic> json) {
    return OpenAIChatResponse(
      id: json['id'] as String,
      object: json['object'] as String,
      created: json['created'] as int,
      model: json['model'] as String,
      choices: (json['choices'] as List)
          .map((c) => OpenAIChatChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
      usage: OpenAIUsage.fromJson(json['usage'] as Map<String, dynamic>),
      systemFingerprint: json['system_fingerprint'] as String?,
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': object,
      'created': created,
      'model': model,
      'choices': choices.map((c) => c.toJson()).toList(),
      'usage': usage.toJson(),
      if (systemFingerprint != null) 'system_fingerprint': systemFingerprint,
    };
  }

  @override
  String toString() {
    return 'OpenAIChatResponse(id: $id, model: $model, choices: ${choices.length})';
  }
}

/// Represents a single chat completion choice in OpenAI's format.
class OpenAIChatChoice {
  /// The index of the choice in the list of choices.
  final int index;

  /// The message generated by the model.
  final Map<String, dynamic> message;

  /// The reason the model stopped generating tokens.
  ///
  /// Possible values: "stop", "length", "tool_calls", "content_filter", "function_call"
  final String? finishReason;

  /// Log probability information for the message.
  final Map<String, dynamic>? logprobs;

  /// Creates a new [OpenAIChatChoice] instance.
  OpenAIChatChoice({
    required this.index,
    required this.message,
    this.finishReason,
    this.logprobs,
  });

  /// Creates an [OpenAIChatChoice] from a JSON map.
  factory OpenAIChatChoice.fromJson(Map<String, dynamic> json) {
    return OpenAIChatChoice(
      index: json['index'] as int,
      message: Map<String, dynamic>.from(json['message'] as Map),
      finishReason: json['finish_reason'] as String?,
      logprobs: json['logprobs'] != null
          ? Map<String, dynamic>.from(json['logprobs'] as Map)
          : null,
    );
  }

  /// Converts this choice to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'message': message,
      if (finishReason != null) 'finish_reason': finishReason,
      if (logprobs != null) 'logprobs': logprobs,
    };
  }
}

/// Represents usage statistics in OpenAI's format.
class OpenAIUsage {
  /// Number of tokens in the prompt.
  final int promptTokens;

  /// Number of tokens in the completion.
  final int completionTokens;

  /// Total number of tokens used.
  final int totalTokens;

  /// Creates a new [OpenAIUsage] instance.
  OpenAIUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  /// Creates an [OpenAIUsage] from a JSON map.
  factory OpenAIUsage.fromJson(Map<String, dynamic> json) {
    return OpenAIUsage(
      promptTokens: json['prompt_tokens'] as int,
      completionTokens: json['completion_tokens'] as int,
      totalTokens: json['total_tokens'] as int,
    );
  }

  /// Converts this usage to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
    };
  }

  @override
  String toString() {
    return 'OpenAIUsage(prompt: $promptTokens, completion: $completionTokens, total: $totalTokens)';
  }
}

/// Represents an embedding request in OpenAI's API format.
///
/// This model matches the exact structure expected by OpenAI's `/v1/embeddings`
/// endpoint.
///
/// **OpenAI API Reference:**
/// https://platform.openai.com/docs/api-reference/embeddings/create
class OpenAIEmbeddingRequest {
  /// ID of the model to use.
  ///
  /// Examples: "text-embedding-3-small", "text-embedding-ada-002"
  final String model;

  /// Input text(s) to generate embeddings for.
  ///
  /// Can be a string or array of strings. For array inputs, embeddings are
  /// generated for each string in the array.
  final dynamic input;

  /// The format to return the embeddings in.
  ///
  /// Can be "float" or "base64". Defaults to "float".
  final String? encodingFormat;

  /// Number of dimensions the resulting output should have.
  ///
  /// Only supported for "text-embedding-3" models.
  final int? dimensions;

  /// A unique identifier representing your end-user.
  ///
  /// Can help OpenAI monitor and detect abuse.
  final String? user;

  /// Creates a new [OpenAIEmbeddingRequest] instance.
  ///
  /// [model] and [input] are required.
  OpenAIEmbeddingRequest({
    required this.model,
    required this.input,
    this.encodingFormat,
    this.dimensions,
    this.user,
  })  : assert(model.isNotEmpty, 'model must not be empty'),
        assert(input != null, 'input must not be null');

  /// Converts this request to a JSON map matching OpenAI's API format.
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'input': input,
      if (encodingFormat != null) 'encoding_format': encodingFormat,
      if (dimensions != null) 'dimensions': dimensions,
      if (user != null) 'user': user,
    };
  }

  /// Creates an [OpenAIEmbeddingRequest] from a JSON map.
  factory OpenAIEmbeddingRequest.fromJson(Map<String, dynamic> json) {
    return OpenAIEmbeddingRequest(
      model: json['model'] as String,
      input: json['input'],
      encodingFormat: json['encoding_format'] as String?,
      dimensions: json['dimensions'] as int?,
      user: json['user'] as String?,
    );
  }

  @override
  String toString() {
    return 'OpenAIEmbeddingRequest(model: $model, input: ${input is List ? "${(input as List).length} items" : "string"})';
  }
}

/// Represents an embedding response in OpenAI's API format.
///
/// This model matches the exact structure returned by OpenAI's `/v1/embeddings`
/// endpoint.
class OpenAIEmbeddingResponse {
  /// List of embedding objects.
  final List<OpenAIEmbedding> data;

  /// The model used to generate the embeddings.
  final String model;

  /// Usage statistics for the embedding request.
  final OpenAIUsage usage;

  /// Creates a new [OpenAIEmbeddingResponse] instance.
  OpenAIEmbeddingResponse({
    required this.data,
    required this.model,
    required this.usage,
  });

  /// Creates an [OpenAIEmbeddingResponse] from a JSON map.
  factory OpenAIEmbeddingResponse.fromJson(Map<String, dynamic> json) {
    return OpenAIEmbeddingResponse(
      data: (json['data'] as List)
          .map((e) => OpenAIEmbedding.fromJson(e as Map<String, dynamic>))
          .toList(),
      model: json['model'] as String,
      usage: OpenAIUsage.fromJson(json['usage'] as Map<String, dynamic>),
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'data': data.map((e) => e.toJson()).toList(),
      'model': model,
      'usage': usage.toJson(),
    };
  }

  @override
  String toString() {
    return 'OpenAIEmbeddingResponse(model: $model, embeddings: ${data.length})';
  }
}

/// Represents a single embedding object in OpenAI's format.
class OpenAIEmbedding {
  /// The index of the embedding in the list.
  final int index;

  /// The embedding vector.
  ///
  /// Can be a List<double> for float format, or String for base64 format.
  final dynamic embedding;

  /// The object type, always "embedding".
  final String object;

  /// Creates a new [OpenAIEmbedding] instance.
  OpenAIEmbedding({
    required this.index,
    required this.embedding,
    required this.object,
  });

  /// Creates an [OpenAIEmbedding] from a JSON map.
  factory OpenAIEmbedding.fromJson(Map<String, dynamic> json) {
    return OpenAIEmbedding(
      index: json['index'] as int,
      embedding: json['embedding'],
      object: json['object'] as String,
    );
  }

  /// Converts this embedding to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'embedding': embedding,
      'object': object,
    };
  }
}
