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

import 'dart:typed_data';

import '../../error/error_types.dart';

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
  ///
  /// Note: For o1 models, use [maxCompletionTokens] instead.
  final int? maxTokens;

  /// Maximum number of completion tokens to generate (for o1 models).
  ///
  /// This parameter is used instead of [maxTokens] for o1 series models.
  /// The total length of input tokens and generated tokens is limited by the
  /// model's context length.
  final int? maxCompletionTokens;

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

  /// Whether to return log probabilities of the output tokens.
  ///
  /// If set, the API will return the log probabilities of each output token.
  /// Not supported by o1 series or gpt-5 models.
  final bool? logprobs;

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
    this.maxCompletionTokens,
    this.topP,
    this.n,
    this.stop,
    this.presencePenalty,
    this.frequencyPenalty,
    this.logitBias,
    this.logprobs,
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
        assert(maxCompletionTokens == null || maxCompletionTokens > 0,
            'maxCompletionTokens must be positive'),
        assert(n == null || n > 0, 'n must be positive');

  /// Converts this request to a JSON map matching OpenAI's API format.
  ///
  /// Only non-null optional fields are included in the output.
  /// For o1 models, filters out unsupported parameters and uses
  /// max_completion_tokens instead of max_tokens.
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
    final hasRestrictedParams = _hasRestrictedParameters(model);

    final json = <String, dynamic>{
      'model': model,
      'messages': messages,
    };

    // For models with restricted parameters, apply parameter restrictions
    if (hasRestrictedParams) {
      // Temperature: Only support temperature = 1.0 (default)
      // If temperature is explicitly set to 1.0, we can include it.
      // Otherwise, we omit it to use the default.
      if (temperature != null && temperature == 1.0) {
        json['temperature'] = temperature;
      }
      // Max tokens: Use max_completion_tokens instead of max_tokens
      if (maxCompletionTokens != null) {
        json['max_completion_tokens'] = maxCompletionTokens;
      } else if (maxTokens != null) {
        // Fallback: use maxTokens as max_completion_tokens
        json['max_completion_tokens'] = maxTokens;
      }
      // Note: top_p, presence_penalty, frequency_penalty, and logprobs are
      // explicitly excluded for models with restricted parameters (handled below)
    } else {
      // Standard models: include all parameters
      if (temperature != null) json['temperature'] = temperature;
      if (maxTokens != null) json['max_tokens'] = maxTokens;
      if (topP != null) json['top_p'] = topP;
      if (presencePenalty != null) json['presence_penalty'] = presencePenalty;
      if (frequencyPenalty != null)
        json['frequency_penalty'] = frequencyPenalty;
    }

    // Common parameters for all models
    if (n != null) json['n'] = n;
    if (stop != null) json['stop'] = stop;
    if (logitBias != null) json['logit_bias'] = logitBias;
    // logprobs is not supported by models with restricted parameters
    if (logprobs != null && !hasRestrictedParams) {
      json['logprobs'] = logprobs;
    }
    if (user != null) json['user'] = user;
    if (stream != null) json['stream'] = stream;
    if (tools != null) json['tools'] = tools;
    if (toolChoice != null) json['tool_choice'] = toolChoice;
    if (functionCall != null) json['function_call'] = functionCall;
    if (functions != null) json['functions'] = functions;

    return json;
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

    // Handle max_tokens vs max_completion_tokens
    final hasRestrictedParams = _hasRestrictedParameters(model);
    final int? maxTokensValue;
    final int? maxCompletionTokensValue;

    if (hasRestrictedParams) {
      // For models with restricted parameters, prefer max_completion_tokens
      maxCompletionTokensValue =
          json['max_completion_tokens'] as int? ?? json['max_tokens'] as int?;
      maxTokensValue = null;
    } else {
      maxTokensValue = json['max_tokens'] as int?;
      maxCompletionTokensValue = null;
    }

    return OpenAIChatRequest(
      model: model,
      messages: List<Map<String, dynamic>>.from(messages),
      temperature: json['temperature'] as double?,
      maxTokens: maxTokensValue,
      maxCompletionTokens: maxCompletionTokensValue,
      topP: json['top_p'] as double?,
      n: json['n'] as int?,
      stop:
          json['stop'] != null ? List<String>.from(json['stop'] as List) : null,
      presencePenalty: json['presence_penalty'] as double?,
      frequencyPenalty: json['frequency_penalty'] as double?,
      logitBias: json['logit_bias'] != null
          ? Map<String, int>.from(json['logit_bias'] as Map)
          : null,
      logprobs: json['logprobs'] as bool?,
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
        other.maxCompletionTokens == maxCompletionTokens &&
        other.topP == topP &&
        other.n == n &&
        _listEqualsStrings(other.stop, stop) &&
        other.presencePenalty == presencePenalty &&
        other.frequencyPenalty == frequencyPenalty &&
        _mapEquals(other.logitBias, logitBias) &&
        other.logprobs == logprobs &&
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
      maxCompletionTokens,
      topP,
      n,
      Object.hashAll(stop ?? []),
      presencePenalty,
      frequencyPenalty,
      logitBias,
      logprobs,
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

/// Represents a request in OpenAI's Responses API format.
///
/// This model matches the structure expected by OpenAI's `/v1/responses` endpoint.
/// The Responses API is stateful and supports both simple input strings and
/// message arrays, with optional previous_response_id for conversation continuity.
///
/// **OpenAI API Reference:**
/// https://platform.openai.com/docs/api-reference/responses/create
///
/// **Example:**
/// ```dart
/// final request = OpenAIResponseRequest(
///   model: 'gpt-5',
///   input: 'Hello!',
///   instructions: 'You are a helpful assistant.',
/// );
/// ```
///
/// **Stateful conversation example:**
/// ```dart
/// final request = OpenAIResponseRequest(
///   model: 'gpt-5',
///   input: 'Continue the conversation',
///   previousResponseId: 'resp_abc123',
/// );
/// ```
class OpenAIResponseRequest {
  /// ID of the model to use.
  final String model;

  /// The input for the response.
  ///
  /// Can be a string (simple input) or a list of messages (for multi-turn conversations).
  /// If using messages, the format is the same as Chat Completions API.
  final dynamic input;

  /// Optional system-level instructions.
  ///
  /// Provides high-level guidance to the model. This is similar to system messages
  /// but is a separate field in the Responses API.
  final String? instructions;

  /// Optional ID of the previous response for stateful conversations.
  ///
  /// When provided, the API will use the conversation context from the previous
  /// response instead of requiring the full message history.
  final String? previousResponseId;

  /// Sampling temperature between 0 and 2.
  final double? temperature;

  /// Maximum number of completion tokens to generate.
  ///
  /// Note: Responses API uses max_completion_tokens, not max_tokens.
  final int? maxCompletionTokens;

  /// Alternative to temperature: nucleus sampling.
  final double? topP;

  /// Number of response choices to generate.
  final int? n;

  /// Up to 4 sequences where the API will stop generating further tokens.
  final List<String>? stop;

  /// Number between -2.0 and 2.0. Positive values penalize new tokens based
  /// on whether they appear in the text so far.
  final double? presencePenalty;

  /// Number between -2.0 and 2.0. Positive values penalize new tokens based
  /// on their existing frequency in the text so far.
  final double? frequencyPenalty;

  /// Modify the likelihood of specified tokens appearing in the completion.
  final Map<String, int>? logitBias;

  /// A unique identifier representing your end-user.
  final String? user;

  /// Whether to stream back partial progress.
  final bool? stream;

  /// A list of tools the model may call.
  final List<Map<String, dynamic>>? tools;

  /// Controls which (if any) function is called by the model.
  final dynamic toolChoice;

  /// Creates a new [OpenAIResponseRequest] instance.
  OpenAIResponseRequest({
    required this.model,
    required this.input,
    this.instructions,
    this.previousResponseId,
    this.temperature,
    this.maxCompletionTokens,
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
  })  : assert(model.isNotEmpty, 'model must not be empty'),
        assert(input != null, 'input must not be null');

  /// Converts this request to a JSON map matching OpenAI's Responses API format.
  Map<String, dynamic> toJson() {
    final hasRestrictedParams = _hasRestrictedParameters(model);

    final json = <String, dynamic>{
      'model': model,
      'input': input,
    };

    if (instructions != null) {
      json['instructions'] = instructions;
    }

    if (previousResponseId != null) {
      json['previous_response_id'] = previousResponseId;
    }

    // For models with restricted parameters, apply parameter restrictions
    if (hasRestrictedParams) {
      // Temperature: Only support temperature = 1.0 (default)
      if (temperature != null && temperature == 1.0) {
        json['temperature'] = temperature;
      }
      // Max tokens: Use max_completion_tokens
      if (maxCompletionTokens != null) {
        json['max_completion_tokens'] = maxCompletionTokens;
      }
      // Note: top_p, presence_penalty, frequency_penalty are excluded
    } else {
      // Standard models: include all parameters
      if (temperature != null) json['temperature'] = temperature;
      if (maxCompletionTokens != null) {
        json['max_completion_tokens'] = maxCompletionTokens;
      }
      if (topP != null) json['top_p'] = topP;
      if (presencePenalty != null) json['presence_penalty'] = presencePenalty;
      if (frequencyPenalty != null)
        json['frequency_penalty'] = frequencyPenalty;
    }

    // Common parameters for all models
    if (n != null) json['n'] = n;
    if (stop != null) json['stop'] = stop;
    if (logitBias != null) json['logit_bias'] = logitBias;
    if (user != null) json['user'] = user;
    if (stream != null) json['stream'] = stream;
    if (tools != null) json['tools'] = tools;
    if (toolChoice != null) json['tool_choice'] = toolChoice;

    return json;
  }

  /// Creates an [OpenAIResponseRequest] from a JSON map.
  factory OpenAIResponseRequest.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as String;
    if (model.isEmpty) {
      throw ClientError(
        message: 'Missing required field: model',
        code: 'INVALID_REQUEST',
      );
    }

    final input = json['input'];
    if (input == null) {
      throw ClientError(
        message: 'Missing required field: input',
        code: 'INVALID_REQUEST',
      );
    }

    return OpenAIResponseRequest(
      model: model,
      input: input,
      instructions: json['instructions'] as String?,
      previousResponseId: json['previous_response_id'] as String?,
      temperature: json['temperature'] as double?,
      maxCompletionTokens: json['max_completion_tokens'] as int?,
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
    );
  }

  @override
  String toString() {
    return 'OpenAIResponseRequest(model: $model, input: ${input is String ? input : "${(input as List).length} messages"})';
  }
}

/// Represents a response in OpenAI's Responses API format.
///
/// This model matches the structure returned by OpenAI's `/v1/responses` endpoint.
/// The Responses API is stateful and includes a response_id for linking to
/// subsequent requests.
///
/// **OpenAI API Reference:**
/// https://platform.openai.com/docs/api-reference/responses/object
class OpenAIResponseResponse {
  /// Unique identifier for this response.
  ///
  /// This ID can be used in subsequent requests via previous_response_id
  /// to maintain conversation state.
  final String responseId;

  /// The model used for the response.
  final String model;

  /// List of response choices.
  final List<OpenAIResponseChoice> choices;

  /// Usage statistics for the response request.
  final OpenAIUsage? usage;

  /// Unix timestamp (in seconds) of when the response was created.
  final int created;

  /// Creates a new [OpenAIResponseResponse] instance.
  OpenAIResponseResponse({
    required this.responseId,
    required this.model,
    required this.choices,
    this.usage,
    required this.created,
  });

  /// Creates an [OpenAIResponseResponse] from a JSON map.
  factory OpenAIResponseResponse.fromJson(Map<String, dynamic> json) {
    // Handle both 'id' (actual API) and 'response_id' (legacy) for compatibility
    final responseId = json['id'] as String? ?? json['response_id'] as String?;
    if (responseId == null) {
      throw FormatException(
        'Missing required field: id or response_id',
        json,
      );
    }

    final model = json['model'] as String?;
    if (model == null) {
      throw FormatException(
        'Missing required field: model',
        json,
      );
    }

    // Handle both 'output' (actual API) and 'choices' (legacy) for compatibility
    final outputOrChoices = json['output'] ?? json['choices'];
    if (outputOrChoices == null || outputOrChoices is! List) {
      throw FormatException(
        'Missing or invalid required field: output or choices',
        json,
      );
    }

    // Handle both 'created_at' (actual API) and 'created' (legacy) for compatibility
    final created = json['created_at'] ?? json['created'];
    if (created == null || created is! int) {
      throw FormatException(
        'Missing or invalid required field: created_at or created',
        json,
      );
    }

    return OpenAIResponseResponse(
      responseId: responseId,
      model: model,
      choices: outputOrChoices
          .asMap()
          .entries
          .map((entry) => OpenAIResponseChoice.fromJson(
                entry.value as Map<String, dynamic>,
                index: entry.key,
              ))
          .toList(),
      usage: json['usage'] != null
          ? OpenAIUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
      created: created,
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'response_id': responseId,
      'model': model,
      'choices': choices.map((c) => c.toJson()).toList(),
      if (usage != null) 'usage': usage!.toJson(),
      'created': created,
    };
  }

  @override
  String toString() {
    return 'OpenAIResponseResponse(responseId: $responseId, model: $model, choices: ${choices.length})';
  }
}

/// Represents a single response choice in OpenAI's Responses API format.
class OpenAIResponseChoice {
  /// The index of the choice in the list of choices.
  final int index;

  /// The message generated by the model.
  final Map<String, dynamic> message;

  /// The reason the model stopped generating tokens.
  final String? finishReason;

  /// Creates a new [OpenAIResponseChoice] instance.
  OpenAIResponseChoice({
    required this.index,
    required this.message,
    this.finishReason,
  });

  /// Creates an [OpenAIResponseChoice] from a JSON map.
  factory OpenAIResponseChoice.fromJson(
    Map<String, dynamic> json, {
    int? index,
  }) {
    // Handle Responses API output format (from 'output' array)
    if (json['type'] == 'message' || json.containsKey('content')) {
      // Extract text from content array
      final content = json['content'] as List?;
      String? text;
      if (content != null && content.isNotEmpty) {
        final firstContent = content[0] as Map<String, dynamic>?;
        if (firstContent != null && firstContent['type'] == 'output_text') {
          text = firstContent['text'] as String?;
        }
      }

      // Build message map in the expected format
      final message = <String, dynamic>{
        'role': json['role'] as String? ?? 'assistant',
        'content': text ?? '',
      };

      return OpenAIResponseChoice(
        index: index ?? json['index'] as int? ?? 0,
        message: message,
        finishReason: json['finish_reason'] as String?,
      );
    }

    // Handle legacy format (from 'choices' array with 'message' field)
    return OpenAIResponseChoice(
      index: index ?? json['index'] as int? ?? 0,
      message: Map<String, dynamic>.from(json['message'] as Map),
      finishReason: json['finish_reason'] as String?,
    );
  }

  /// Converts this choice to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'message': message,
      if (finishReason != null) 'finish_reason': finishReason,
    };
  }

  @override
  String toString() {
    return 'OpenAIResponseChoice(index: $index, finishReason: $finishReason)';
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
    // Handle both Responses API format (input_tokens/output_tokens) and
    // Chat Completions format (prompt_tokens/completion_tokens)
    final promptTokens =
        json['input_tokens'] as int? ?? json['prompt_tokens'] as int? ?? 0;
    final completionTokens =
        json['output_tokens'] as int? ?? json['completion_tokens'] as int? ?? 0;
    final totalTokens = json['total_tokens'] as int? ?? 0;

    return OpenAIUsage(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
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

/// Represents an image generation request in OpenAI's API format.
///
/// This model matches the exact structure expected by OpenAI's `/v1/images/generations`
/// endpoint for DALL-E image generation.
///
/// **OpenAI API Reference:**
/// https://platform.openai.com/docs/api-reference/images/create
class OpenAIImageRequest {
  /// The text prompt describing the image to generate.
  ///
  /// Required. The prompt must be specific and descriptive for best results.
  /// DALL-E 3 has a maximum prompt length of 4000 characters.
  final String prompt;

  /// The model to use for image generation.
  ///
  /// Options: "dall-e-3" or "dall-e-2"
  /// Defaults to "dall-e-3" if not specified.
  final String? model;

  /// The number of images to generate.
  ///
  /// For DALL-E 3: Must be 1 (only one image can be generated at a time).
  /// For DALL-E 2: Can be 1-10.
  final int? n;

  /// The size of the generated images.
  ///
  /// For DALL-E 3: "1024x1024", "1024x1792", or "1792x1024"
  /// For DALL-E 2: "256x256", "512x512", or "1024x1024"
  /// Must be in format "WIDTHxHEIGHT" (e.g., "1024x1024").
  final String? size;

  /// The quality of the image that will be generated.
  ///
  /// Only supported for DALL-E 3.
  /// Options: "standard" or "hd"
  /// "hd" creates images with finer details and greater consistency.
  final String? quality;

  /// The style of the generated images.
  ///
  /// Only supported for DALL-E 3.
  /// Options: "vivid" or "natural"
  /// "vivid" creates hyper-real and dramatic images.
  /// "natural" creates more natural, less hyper-real images.
  final String? style;

  /// The format in which the generated images are returned.
  ///
  /// Options: "url" or "b64_json"
  /// Defaults to "url" if not specified.
  final String? responseFormat;

  /// A unique identifier representing your end-user.
  ///
  /// Can help OpenAI monitor and detect abuse.
  final String? user;

  /// Creates a new [OpenAIImageRequest] instance.
  ///
  /// [prompt] is required and must not be empty.
  OpenAIImageRequest({
    required this.prompt,
    this.model,
    this.n,
    this.size,
    this.quality,
    this.style,
    this.responseFormat,
    this.user,
  }) : assert(prompt.isNotEmpty, 'prompt must not be empty');

  /// Converts this request to a JSON map matching OpenAI's API format.
  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      if (model != null) 'model': model,
      if (n != null) 'n': n,
      if (size != null) 'size': size,
      if (quality != null) 'quality': quality,
      if (style != null) 'style': style,
      if (responseFormat != null) 'response_format': responseFormat,
      if (user != null) 'user': user,
    };
  }

  /// Creates an [OpenAIImageRequest] from a JSON map.
  factory OpenAIImageRequest.fromJson(Map<String, dynamic> json) {
    return OpenAIImageRequest(
      prompt: json['prompt'] as String,
      model: json['model'] as String?,
      n: json['n'] as int?,
      size: json['size'] as String?,
      quality: json['quality'] as String?,
      style: json['style'] as String?,
      responseFormat: json['response_format'] as String? ??
          json['responseFormat'] as String?,
      user: json['user'] as String?,
    );
  }

  @override
  String toString() {
    return 'OpenAIImageRequest(prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}, model: ${model ?? "dall-e-3"}, size: ${size ?? "1024x1024"})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OpenAIImageRequest &&
        other.prompt == prompt &&
        other.model == model &&
        other.n == n &&
        other.size == size &&
        other.quality == quality &&
        other.style == style &&
        other.responseFormat == responseFormat &&
        other.user == user;
  }

  @override
  int get hashCode {
    return Object.hash(
      prompt,
      model,
      n,
      size,
      quality,
      style,
      responseFormat,
      user,
    );
  }
}

/// Represents an image generation response in OpenAI's API format.
///
/// This model matches the exact structure returned by OpenAI's `/v1/images/generations`
/// endpoint.
class OpenAIImageResponse {
  /// Timestamp when the images were created.
  ///
  /// Unix timestamp in seconds.
  final int created;

  /// List of generated image data.
  final List<OpenAIImageData> data;

  /// Creates a new [OpenAIImageResponse] instance.
  OpenAIImageResponse({
    required this.created,
    required this.data,
  });

  /// Creates an [OpenAIImageResponse] from a JSON map.
  factory OpenAIImageResponse.fromJson(Map<String, dynamic> json) {
    return OpenAIImageResponse(
      created: json['created'] as int,
      data: (json['data'] as List)
          .map((e) => OpenAIImageData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'created': created,
      'data': data.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'OpenAIImageResponse(created: $created, images: ${data.length})';
  }
}

/// Represents a single generated image in OpenAI's format.
class OpenAIImageData {
  /// URL of the generated image.
  ///
  /// Present when response_format is "url" (default).
  /// The URL is temporary and expires after a certain period.
  final String? url;

  /// Base64-encoded image data.
  ///
  /// Present when response_format is "b64_json".
  final String? b64Json;

  /// The revised prompt used for image generation (DALL-E 3 only).
  ///
  /// DALL-E 3 automatically revises the user's prompt to improve image quality.
  /// This field contains the revised version if available.
  final String? revisedPrompt;

  /// Creates a new [OpenAIImageData] instance.
  OpenAIImageData({
    this.url,
    this.b64Json,
    this.revisedPrompt,
  });

  /// Creates an [OpenAIImageData] from a JSON map.
  factory OpenAIImageData.fromJson(Map<String, dynamic> json) {
    return OpenAIImageData(
      url: json['url'] as String?,
      b64Json: json['b64_json'] as String? ?? json['b64Json'] as String?,
      revisedPrompt:
          json['revised_prompt'] as String? ?? json['revisedPrompt'] as String?,
    );
  }

  /// Converts this image data to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (url != null) 'url': url,
      if (b64Json != null) 'b64_json': b64Json,
      if (revisedPrompt != null) 'revised_prompt': revisedPrompt,
    };
  }

  @override
  String toString() {
    return 'OpenAIImageData(url: ${url != null ? "..." : null}, b64Json: ${b64Json != null ? "..." : null}, revisedPrompt: ${revisedPrompt != null ? "..." : null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OpenAIImageData &&
        other.url == url &&
        other.b64Json == b64Json &&
        other.revisedPrompt == revisedPrompt;
  }

  @override
  int get hashCode {
    return Object.hash(url, b64Json, revisedPrompt);
  }
}

/// Represents a text-to-speech request in OpenAI's API format.
///
/// This model matches the structure expected by OpenAI's `/v1/audio/speech`
/// endpoint.
class OpenAITtsRequest {
  /// ID of the model to use.
  ///
  /// Examples: "tts-1", "tts-1-hd"
  final String model;

  /// The text to convert to speech.
  final String input;

  /// The voice to use for generation.
  ///
  /// Options: "alloy", "echo", "fable", "onyx", "nova", "shimmer"
  final String voice;

  /// The format to return the audio in.
  ///
  /// Options: "mp3", "opus", "aac", "flac"
  /// Defaults to "mp3" if not specified.
  final String? responseFormat;

  /// The speed of the generated audio.
  ///
  /// Range: 0.25 to 4.0. Defaults to 1.0.
  final double? speed;

  /// Creates a new [OpenAITtsRequest] instance.
  OpenAITtsRequest({
    required this.model,
    required this.input,
    required this.voice,
    this.responseFormat,
    this.speed,
  })  : assert(model.isNotEmpty, 'model must not be empty'),
        assert(input.isNotEmpty, 'input must not be empty'),
        assert(voice.isNotEmpty, 'voice must not be empty'),
        assert(speed == null || (speed >= 0.25 && speed <= 4.0),
            'speed must be between 0.25 and 4.0');

  /// Converts this request to a JSON map matching OpenAI's API format.
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'input': input,
      'voice': voice,
      if (responseFormat != null) 'response_format': responseFormat,
      if (speed != null) 'speed': speed,
    };
  }

  /// Creates an [OpenAITtsRequest] from a JSON map.
  factory OpenAITtsRequest.fromJson(Map<String, dynamic> json) {
    return OpenAITtsRequest(
      model: json['model'] as String,
      input: json['input'] as String,
      voice: json['voice'] as String,
      responseFormat: json['response_format'] as String?,
      speed: (json['speed'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() {
    return 'OpenAITtsRequest(model: $model, voice: $voice, input: ${input.length > 50 ? "${input.substring(0, 50)}..." : input})';
  }
}

/// Represents a speech-to-text (transcription) request in OpenAI's API format.
///
/// This model matches the structure expected by OpenAI's `/v1/audio/transcriptions`
/// endpoint. Note: The actual request uses multipart/form-data, not JSON.
class OpenAISttRequest {
  /// ID of the model to use.
  ///
  /// Examples: "whisper-1"
  final String model;

  /// The audio file to transcribe.
  ///
  /// This will be sent as a file in multipart/form-data.
  final Uint8List audio;

  /// The language of the input audio.
  ///
  /// ISO-639-1 format (e.g., "en", "es", "fr")
  final String? language;

  /// An optional text to guide the model's style or continue a previous audio segment.
  final String? prompt;

  /// The format of the transcript output.
  ///
  /// Options: "json", "text", "srt", "verbose_json", "vtt"
  /// Defaults to "json" if not specified.
  final String? responseFormat;

  /// The sampling temperature.
  ///
  /// Range: 0.0 to 1.0. Defaults to 0.0.
  final double? temperature;

  /// Creates a new [OpenAISttRequest] instance.
  OpenAISttRequest({
    required this.model,
    required this.audio,
    this.language,
    this.prompt,
    this.responseFormat,
    this.temperature,
  })  : assert(model.isNotEmpty, 'model must not be empty'),
        assert(audio.isNotEmpty, 'audio must not be empty'),
        assert(
            temperature == null || (temperature >= 0.0 && temperature <= 1.0),
            'temperature must be between 0.0 and 1.0');

  /// Converts this request to a map for multipart form data.
  ///
  /// Note: This doesn't include the audio file itself, which must be added
  /// separately when building the multipart request.
  Map<String, dynamic> toFormFields() {
    return {
      'model': model,
      if (language != null) 'language': language,
      if (prompt != null) 'prompt': prompt,
      if (responseFormat != null) 'response_format': responseFormat,
      if (temperature != null) 'temperature': temperature.toString(),
    };
  }

  /// Creates an [OpenAISttRequest] from a JSON map.
  ///
  /// Note: The audio field must be provided separately as it's binary data.
  factory OpenAISttRequest.fromJson(Map<String, dynamic> json,
      {Uint8List? audio}) {
    return OpenAISttRequest(
      model: json['model'] as String,
      audio: audio ?? Uint8List(0),
      language: json['language'] as String?,
      prompt: json['prompt'] as String?,
      responseFormat: json['response_format'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() {
    return 'OpenAISttRequest(model: $model, audio: ${audio.length} bytes${language != null ? ", language: $language" : ""})';
  }
}

/// Represents a video generation request in OpenAI's API format.
///
/// This model matches the structure expected by OpenAI's `/v1/videos/generations`
/// endpoint for Sora video generation.
///
/// **OpenAI API Reference:**
/// https://platform.openai.com/docs/api-reference/videos/create
class OpenAIVideoRequest {
  /// The text prompt describing the video to generate.
  ///
  /// Required. The prompt must be specific and descriptive for best results.
  final String prompt;

  /// The model to use for video generation.
  ///
  /// Examples: "sora-2", "sora-1.5", "sora-1.0", "sora-1.0-turbo"
  /// Defaults to "sora-2" if not specified.
  final String? model;

  /// The duration of the video in seconds.
  ///
  /// Typical range: 5-60 seconds. Defaults to provider-specific default.
  final int? duration;

  /// The aspect ratio for the generated video.
  ///
  /// Common values: "16:9", "9:16", "1:1", "4:3", "21:9"
  /// Defaults to provider-specific default if not specified.
  final String? aspectRatio;

  /// The frame rate for the generated video (fps).
  ///
  /// Common values: 24, 30, 60
  /// Defaults to provider-specific default if not specified.
  final int? frameRate;

  /// The quality setting for the generated video.
  ///
  /// Options: "standard", "hd", "4k"
  /// Defaults to "standard" if not specified.
  final String? quality;

  /// Optional seed for reproducible video generation.
  final int? seed;

  /// A unique identifier representing your end-user.
  ///
  /// Can help OpenAI monitor and detect abuse.
  final String? user;

  /// Creates a new [OpenAIVideoRequest] instance.
  ///
  /// [prompt] is required and must not be empty.
  OpenAIVideoRequest({
    required this.prompt,
    this.model,
    this.duration,
    this.aspectRatio,
    this.frameRate,
    this.quality,
    this.seed,
    this.user,
  }) : assert(prompt.isNotEmpty, 'prompt must not be empty');

  /// Converts this request to a JSON map matching OpenAI's API format.
  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      if (model != null) 'model': model,
      if (duration != null) 'duration': duration,
      if (aspectRatio != null) 'aspect_ratio': aspectRatio,
      if (frameRate != null) 'frame_rate': frameRate,
      if (quality != null) 'quality': quality,
      if (seed != null) 'seed': seed,
      if (user != null) 'user': user,
    };
  }

  /// Creates an [OpenAIVideoRequest] from a JSON map.
  factory OpenAIVideoRequest.fromJson(Map<String, dynamic> json) {
    return OpenAIVideoRequest(
      prompt: json['prompt'] as String,
      model: json['model'] as String?,
      duration: json['duration'] as int?,
      aspectRatio:
          json['aspect_ratio'] as String? ?? json['aspectRatio'] as String?,
      frameRate: json['frame_rate'] as int? ?? json['frameRate'] as int?,
      quality: json['quality'] as String?,
      seed: json['seed'] as int?,
      user: json['user'] as String?,
    );
  }

  @override
  String toString() {
    return 'OpenAIVideoRequest(prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}, model: ${model ?? "sora-2"})';
  }
}

/// Represents a video generation response in OpenAI's API format.
///
/// This model matches the structure returned by OpenAI's `/v1/videos/generations`
/// endpoint.
class OpenAIVideoResponse {
  /// Unique identifier for the video generation.
  final String id;

  /// The model used for video generation.
  final String model;

  /// List of generated video data.
  final List<OpenAIVideoData> data;

  /// Timestamp when the video was created.
  ///
  /// Unix timestamp in seconds.
  final int created;

  /// Creates a new [OpenAIVideoResponse] instance.
  OpenAIVideoResponse({
    required this.id,
    required this.model,
    required this.data,
    required this.created,
  });

  /// Creates an [OpenAIVideoResponse] from a JSON map.
  factory OpenAIVideoResponse.fromJson(Map<String, dynamic> json) {
    return OpenAIVideoResponse(
      id: json['id'] as String,
      model: json['model'] as String,
      data: (json['data'] as List)
          .map((e) => OpenAIVideoData.fromJson(e as Map<String, dynamic>))
          .toList(),
      created: json['created'] as int,
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'model': model,
      'data': data.map((e) => e.toJson()).toList(),
      'created': created,
    };
  }

  @override
  String toString() {
    return 'OpenAIVideoResponse(id: $id, model: $model, videos: ${data.length})';
  }
}

/// Represents a single generated video in OpenAI's format.
class OpenAIVideoData {
  /// URL of the generated video.
  ///
  /// The URL is temporary and expires after a certain period.
  final String? url;

  /// Base64-encoded video data.
  ///
  /// Present when response_format is "b64_json".
  final String? base64;

  /// Optional width of the generated video in pixels.
  final int? width;

  /// Optional height of the generated video in pixels.
  final int? height;

  /// Optional duration of the video in seconds.
  final int? duration;

  /// Optional frame rate of the video (fps).
  final int? frameRate;

  /// Optional revised prompt used for video generation.
  final String? revisedPrompt;

  /// Creates a new [OpenAIVideoData] instance.
  OpenAIVideoData({
    this.url,
    this.base64,
    this.width,
    this.height,
    this.duration,
    this.frameRate,
    this.revisedPrompt,
  });

  /// Creates an [OpenAIVideoData] from a JSON map.
  factory OpenAIVideoData.fromJson(Map<String, dynamic> json) {
    return OpenAIVideoData(
      url: json['url'] as String?,
      base64: json['base64'] as String? ?? json['b64_json'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: json['duration'] as int?,
      frameRate: json['frame_rate'] as int? ?? json['frameRate'] as int?,
      revisedPrompt:
          json['revised_prompt'] as String? ?? json['revisedPrompt'] as String?,
    );
  }

  /// Converts this video data to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (url != null) 'url': url,
      if (base64 != null) 'base64': base64,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      if (frameRate != null) 'frame_rate': frameRate,
      if (revisedPrompt != null) 'revised_prompt': revisedPrompt,
    };
  }

  @override
  String toString() {
    return 'OpenAIVideoData(url: ${url != null ? "..." : null}, base64: ${base64 != null ? "..." : null})';
  }
}

/// Represents a video analysis request in OpenAI's API format.
///
/// This model matches the structure expected by OpenAI's `/v1/chat/completions`
/// endpoint when using GPT-5 or GPT-4o Vision for video analysis. Video analysis is
/// performed by sending video frames or video URLs to the vision model.
class OpenAIVideoAnalysisRequest {
  /// The model to use for video analysis.
  ///
  /// Examples: "gpt-5", "gpt-4o", "gpt-4o-mini"
  /// Defaults to "gpt-4o" if not specified.
  /// Note: GPT-5 and GPT-4o support video analysis via vision capabilities.
  final String? model;

  /// List of messages comprising the conversation.
  ///
  /// Messages can include video content via content blocks with type "image_url"
  /// or "video_url".
  final List<Map<String, dynamic>> messages;

  /// Optional maximum number of tokens to generate.
  final int? maxTokens;

  /// Optional temperature for generation.
  final double? temperature;

  /// A unique identifier representing your end-user.
  final String? user;

  /// Creates a new [OpenAIVideoAnalysisRequest] instance.
  ///
  /// [messages] is required and must not be empty.
  OpenAIVideoAnalysisRequest({
    this.model,
    required this.messages,
    this.maxTokens,
    this.temperature,
    this.user,
  }) : assert(messages.isNotEmpty, 'messages must not be empty');

  /// Converts this request to a JSON map matching OpenAI's API format.
  Map<String, dynamic> toJson() {
    return {
      if (model != null) 'model': model,
      'messages': messages,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (temperature != null) 'temperature': temperature,
      if (user != null) 'user': user,
    };
  }

  /// Creates an [OpenAIVideoAnalysisRequest] from a JSON map.
  factory OpenAIVideoAnalysisRequest.fromJson(Map<String, dynamic> json) {
    return OpenAIVideoAnalysisRequest(
      model: json['model'] as String?,
      messages: List<Map<String, dynamic>>.from(json['messages'] as List),
      maxTokens: json['max_tokens'] as int?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      user: json['user'] as String?,
    );
  }

  @override
  String toString() {
    return 'OpenAIVideoAnalysisRequest(model: ${model ?? "gpt-4o"}, messages: ${messages.length})';
  }
}

/// Represents a video analysis response in OpenAI's API format.
///
/// This model matches the structure returned by OpenAI's `/v1/chat/completions`
/// endpoint when analyzing videos. The response is similar to a chat completion
/// but contains analysis of the video content.
class OpenAIVideoAnalysisResponse {
  /// Unique identifier for the analysis.
  final String id;

  /// The model used for analysis.
  final String model;

  /// List of analysis choices.
  final List<Map<String, dynamic>> choices;

  /// Usage statistics for the analysis request.
  final OpenAIUsage? usage;

  /// Timestamp when the analysis was created.
  ///
  /// Unix timestamp in seconds.
  final int created;

  /// Creates a new [OpenAIVideoAnalysisResponse] instance.
  OpenAIVideoAnalysisResponse({
    required this.id,
    required this.model,
    required this.choices,
    this.usage,
    required this.created,
  });

  /// Creates an [OpenAIVideoAnalysisResponse] from a JSON map.
  factory OpenAIVideoAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return OpenAIVideoAnalysisResponse(
      id: json['id'] as String,
      model: json['model'] as String,
      choices: List<Map<String, dynamic>>.from(json['choices'] as List),
      usage: json['usage'] != null
          ? OpenAIUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
      created: json['created'] as int,
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'model': model,
      'choices': choices,
      if (usage != null) 'usage': usage!.toJson(),
      'created': created,
    };
  }

  @override
  String toString() {
    return 'OpenAIVideoAnalysisResponse(id: $id, model: $model, choices: ${choices.length})';
  }
}
