/// Provider-specific models for Mistral AI API format.
///
/// This file contains data models that match Mistral AI's API request and response
/// formats. These models are used internally by [MistralProvider] to communicate
/// with the Mistral AI API endpoints.
///
/// **Note:** These models are provider-specific and should not be used directly
/// by SDK users. Use the unified SDK models ([ChatRequest], [ChatResponse], etc.)
/// instead, which will be automatically converted to/from these Mistral-specific
/// models by [MistralMapper].

import '../../error/error_types.dart';

/// Represents a chat completion request in Mistral AI's API format.
///
/// This model matches the structure expected by Mistral AI's `/v1/chat/completions`
/// endpoint. Mistral AI's API is similar to OpenAI's format.
///
/// **Mistral AI API Reference:**
/// https://docs.mistral.ai/api/
class MistralChatRequest {
  /// ID of the model to use.
  ///
  /// Examples: "mistral-large-latest", "mistral-medium-latest", "mistral-small-latest",
  /// "codestral-latest", "pixtral-latest"
  final String model;

  /// List of messages comprising the conversation.
  ///
  /// Each message is a map with "role" and "content" keys.
  /// Roles can be: "system", "user", "assistant"
  final List<Map<String, dynamic>> messages;

  /// Sampling temperature between 0 and 1.
  ///
  /// Higher values make output more random, lower values more focused.
  /// Defaults to 0.7 if not specified.
  final double? temperature;

  /// Maximum number of tokens to generate.
  final int? maxTokens;

  /// Alternative to temperature: nucleus sampling.
  final double? topP;

  /// Number of chat completion choices to generate.
  final int? n;

  /// Up to 4 sequences where the API will stop generating further tokens.
  final List<String>? stop;

  /// A unique identifier representing your end-user.
  final String? user;

  /// Whether to stream back partial progress.
  final bool? stream;

  /// Random seed for deterministic outputs.
  final int? randomSeed;

  /// Creates a new [MistralChatRequest] instance.
  MistralChatRequest({
    required this.model,
    required this.messages,
    this.temperature,
    this.maxTokens,
    this.topP,
    this.n,
    this.stop,
    this.user,
    this.stream,
    this.randomSeed,
  })  : assert(model.isNotEmpty, 'model must not be empty'),
        assert(messages.isNotEmpty, 'messages must not be empty'),
        assert(
            temperature == null || (temperature >= 0.0 && temperature <= 1.0),
            'temperature must be between 0.0 and 1.0'),
        assert(
            maxTokens == null || maxTokens > 0, 'maxTokens must be positive'),
        assert(n == null || n > 0, 'n must be positive');

  /// Converts this request to a JSON map matching Mistral AI's API format.
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'messages': messages,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (topP != null) 'top_p': topP,
      if (n != null) 'n': n,
      if (stop != null) 'stop': stop,
      if (user != null) 'user': user,
      if (stream != null) 'stream': stream,
      if (randomSeed != null) 'random_seed': randomSeed,
    };
  }

  /// Creates a [MistralChatRequest] from a JSON map.
  factory MistralChatRequest.fromJson(Map<String, dynamic> json) {
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

    return MistralChatRequest(
      model: model,
      messages: List<Map<String, dynamic>>.from(messages),
      temperature: json['temperature'] as double?,
      maxTokens: json['max_tokens'] as int?,
      topP: json['top_p'] as double?,
      n: json['n'] as int?,
      stop:
          json['stop'] != null ? List<String>.from(json['stop'] as List) : null,
      user: json['user'] as String?,
      stream: json['stream'] as bool?,
      randomSeed: json['random_seed'] as int?,
    );
  }

  @override
  String toString() {
    return 'MistralChatRequest(model: $model, messages: ${messages.length}, '
        'temperature: $temperature, maxTokens: $maxTokens)';
  }
}

/// Represents a chat completion response in Mistral AI's API format.
class MistralChatResponse {
  /// Unique identifier for the chat completion.
  final String id;

  /// Object type, typically "chat.completion".
  final String object;

  /// Unix timestamp (in seconds) of when the chat completion was created.
  final int created;

  /// The model used for the chat completion.
  final String model;

  /// List of completion choices.
  final List<MistralChatChoice> choices;

  /// Usage statistics for the completion request.
  final MistralUsage usage;

  /// Creates a new [MistralChatResponse] instance.
  MistralChatResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
  });

  /// Creates a [MistralChatResponse] from a JSON map.
  factory MistralChatResponse.fromJson(Map<String, dynamic> json) {
    return MistralChatResponse(
      id: json['id'] as String,
      object: json['object'] as String,
      created: json['created'] as int,
      model: json['model'] as String,
      choices: (json['choices'] as List)
          .map((c) => MistralChatChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
      usage: MistralUsage.fromJson(json['usage'] as Map<String, dynamic>),
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
    };
  }

  @override
  String toString() {
    return 'MistralChatResponse(id: $id, model: $model, choices: ${choices.length})';
  }
}

/// Represents a single chat completion choice in Mistral AI's format.
class MistralChatChoice {
  /// The index of the choice in the list of choices.
  final int index;

  /// The message generated by the model.
  final Map<String, dynamic> message;

  /// The reason the model stopped generating tokens.
  ///
  /// Possible values: "stop", "length", "content_filter"
  final String? finishReason;

  /// Creates a new [MistralChatChoice] instance.
  MistralChatChoice({
    required this.index,
    required this.message,
    this.finishReason,
  });

  /// Creates a [MistralChatChoice] from a JSON map.
  factory MistralChatChoice.fromJson(Map<String, dynamic> json) {
    return MistralChatChoice(
      index: json['index'] as int,
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
}

/// Represents usage statistics in Mistral AI's format.
class MistralUsage {
  /// Number of tokens in the prompt.
  final int promptTokens;

  /// Number of tokens in the completion.
  final int completionTokens;

  /// Total number of tokens used.
  final int totalTokens;

  /// Creates a new [MistralUsage] instance.
  MistralUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  /// Creates a [MistralUsage] from a JSON map.
  factory MistralUsage.fromJson(Map<String, dynamic> json) {
    return MistralUsage(
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
    return 'MistralUsage(prompt: $promptTokens, completion: $completionTokens, total: $totalTokens)';
  }
}

/// Represents an embedding request in Mistral AI's API format.
///
/// This model matches the structure expected by Mistral AI's `/v1/embeddings`
/// endpoint.
class MistralEmbeddingRequest {
  /// ID of the model to use.
  ///
  /// Examples: "mistral-embed"
  final String model;

  /// Input text(s) to generate embeddings for.
  ///
  /// Can be a string or array of strings.
  final dynamic input;

  /// The format to return the embeddings in.
  ///
  /// Can be "float" or "base64". Defaults to "float".
  final String? encodingFormat;

  /// Creates a new [MistralEmbeddingRequest] instance.
  MistralEmbeddingRequest({
    required this.model,
    required this.input,
    this.encodingFormat,
  })  : assert(model.isNotEmpty, 'model must not be empty'),
        assert(input != null, 'input must not be null');

  /// Converts this request to a JSON map matching Mistral AI's API format.
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'input': input,
      if (encodingFormat != null) 'encoding_format': encodingFormat,
    };
  }

  /// Creates a [MistralEmbeddingRequest] from a JSON map.
  factory MistralEmbeddingRequest.fromJson(Map<String, dynamic> json) {
    return MistralEmbeddingRequest(
      model: json['model'] as String,
      input: json['input'],
      encodingFormat: json['encoding_format'] as String?,
    );
  }

  @override
  String toString() {
    return 'MistralEmbeddingRequest(model: $model, input: ${input is List ? "${(input as List).length} items" : "string"})';
  }
}

/// Represents an embedding response in Mistral AI's API format.
class MistralEmbeddingResponse {
  /// List of embedding objects.
  final List<MistralEmbedding> data;

  /// The model used to generate the embeddings.
  final String model;

  /// Usage statistics for the embedding request.
  final MistralUsage usage;

  /// Creates a new [MistralEmbeddingResponse] instance.
  MistralEmbeddingResponse({
    required this.data,
    required this.model,
    required this.usage,
  });

  /// Creates a [MistralEmbeddingResponse] from a JSON map.
  factory MistralEmbeddingResponse.fromJson(Map<String, dynamic> json) {
    return MistralEmbeddingResponse(
      data: (json['data'] as List)
          .map((e) => MistralEmbedding.fromJson(e as Map<String, dynamic>))
          .toList(),
      model: json['model'] as String,
      usage: MistralUsage.fromJson(json['usage'] as Map<String, dynamic>),
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
    return 'MistralEmbeddingResponse(model: $model, embeddings: ${data.length})';
  }
}

/// Represents a single embedding object in Mistral AI's format.
class MistralEmbedding {
  /// The index of the embedding in the list.
  final int index;

  /// The embedding vector.
  ///
  /// Can be a List<double> for float format, or String for base64 format.
  final dynamic embedding;

  /// The object type, typically "embedding".
  final String object;

  /// Creates a new [MistralEmbedding] instance.
  MistralEmbedding({
    required this.index,
    required this.embedding,
    required this.object,
  });

  /// Creates a [MistralEmbedding] from a JSON map.
  factory MistralEmbedding.fromJson(Map<String, dynamic> json) {
    return MistralEmbedding(
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

/// Represents a speech-to-text (transcription) request in Mistral AI's API format.
///
/// This model matches the structure expected by Mistral AI's Voxtral endpoint.
class MistralSttRequest {
  /// ID of the model to use.
  ///
  /// Examples: "voxtral-mini-transcribe"
  final String? model;

  /// Audio data to transcribe.
  ///
  /// Can be base64-encoded audio or a file path.
  final dynamic audio;

  /// Language of the audio (optional).
  final String? language;

  /// Creates a new [MistralSttRequest] instance.
  MistralSttRequest({
    this.model,
    required this.audio,
    this.language,
  }) : assert(audio != null, 'audio must not be null');

  /// Converts this request to a JSON map matching Mistral AI's API format.
  Map<String, dynamic> toJson() {
    return {
      if (model != null) 'model': model,
      'audio': audio,
      if (language != null) 'language': language,
    };
  }

  /// Creates a [MistralSttRequest] from a JSON map.
  factory MistralSttRequest.fromJson(Map<String, dynamic> json) {
    return MistralSttRequest(
      model: json['model'] as String?,
      audio: json['audio'],
      language: json['language'] as String?,
    );
  }

  @override
  String toString() {
    return 'MistralSttRequest(model: $model, language: $language)';
  }
}

/// Represents a speech-to-text response in Mistral AI's API format.
class MistralSttResponse {
  /// The transcribed text.
  final String text;

  /// The language detected (if applicable).
  final String? language;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Creates a new [MistralSttResponse] instance.
  MistralSttResponse({
    required this.text,
    this.language,
    this.metadata,
  });

  /// Creates a [MistralSttResponse] from a JSON map.
  factory MistralSttResponse.fromJson(Map<String, dynamic> json) {
    return MistralSttResponse(
      text: json['text'] as String,
      language: json['language'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (language != null) 'language': language,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'MistralSttResponse(text: ${text.length > 50 ? "${text.substring(0, 50)}..." : text})';
  }
}
