/// Provider-specific models for Cohere API format.
///
/// This file contains data models that match Cohere's API request and response
/// formats. These models are used internally by [CohereProvider] to communicate
/// with the Cohere API endpoints.
///
/// **Note:** These models are provider-specific and should not be used directly
/// by SDK users. Use the unified SDK models ([EmbeddingRequest], [EmbeddingResponse], etc.)
/// instead, which will be automatically converted to/from these Cohere-specific
/// models by [CohereMapper].
///
/// **Cohere API Reference:**
/// https://docs.cohere.com/reference/embed
library;

import '../../error/error_types.dart';

/// Represents an embedding request in Cohere API format.
///
/// This model matches the exact structure expected by Cohere's `/v2/embed` endpoint.
///
/// **Key differences from OpenAI:**
/// - Uses "texts" array (not "input")
/// - Supports "input_type" parameter (search_document, search_query, classification, etc.)
/// - Requires "embedding_types" array (float, int8, uint8, binary, ubinary) - mandatory in v2
/// - Supports "truncate" parameter (NONE, START, END)
///
/// **Cohere API Reference:**
/// https://docs.cohere.com/reference/embed
class CohereEmbeddingRequest {
  /// List of texts to generate embeddings for.
  ///
  /// Each string in the list will be converted into a vector representation.
  final List<String> texts;

  /// Model identifier to use for embedding generation.
  ///
  /// Examples: "embed-english-v3.0", "embed-multilingual-v3.0", "embed-english-light-v3.0"
  final String? model;

  /// Type of input for embedding generation.
  ///
  /// Determines how the embeddings are optimized:
  /// - "search_document": For documents to be searched
  /// - "search_query": For search queries
  /// - "classification": For classification tasks
  /// - "clustering": For clustering tasks
  ///
  /// **Note:** Required in v2 API. Must be provided for all requests.
  final String inputType;

  /// Types of embeddings to return.
  ///
  /// Can include: "float", "int8", "uint8", "binary", "ubinary"
  /// Required in v2 API.
  final List<String> embeddingTypes;

  /// Truncation strategy for long texts.
  ///
  /// - "NONE": No truncation (may fail if text is too long)
  /// - "START": Truncate from the start
  /// - "END": Truncate from the end (default)
  final String? truncate;

  /// Creates a new [CohereEmbeddingRequest] instance.
  ///
  /// [texts], [inputType], and [embeddingTypes] are required and must not be empty.
  CohereEmbeddingRequest({
    required this.texts,
    this.model,
    required this.inputType,
    required this.embeddingTypes,
    this.truncate,
  })  : assert(texts.isNotEmpty, 'texts must not be empty'),
        assert(inputType.isNotEmpty, 'inputType must not be empty'),
        assert(embeddingTypes.isNotEmpty, 'embeddingTypes must not be empty'),
        assert(
          truncate == null ||
              truncate == 'NONE' ||
              truncate == 'START' ||
              truncate == 'END',
          'truncate must be NONE, START, or END',
        );

  /// Converts this [CohereEmbeddingRequest] to a JSON map.
  ///
  /// Returns a map compatible with Cohere API format.
  Map<String, dynamic> toJson() {
    return {
      'texts': texts,
      if (model != null) 'model': model,
      'input_type': inputType,
      'embedding_types': embeddingTypes,
      if (truncate != null) 'truncate': truncate,
    };
  }

  /// Creates a [CohereEmbeddingRequest] from a JSON map.
  ///
  /// Parses the JSON representation into a [CohereEmbeddingRequest] object.
  factory CohereEmbeddingRequest.fromJson(Map<String, dynamic> json) {
    final texts = json['texts'] as List<dynamic>?;
    if (texts == null || texts.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: texts',
        code: 'INVALID_REQUEST',
      );
    }

    final embeddingTypes = json['embedding_types'] as List<dynamic>?;
    if (embeddingTypes == null || embeddingTypes.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: embedding_types',
        code: 'INVALID_REQUEST',
      );
    }

    final inputType = json['input_type'] as String?;
    if (inputType == null || inputType.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: input_type',
        code: 'INVALID_REQUEST',
      );
    }

    return CohereEmbeddingRequest(
      texts: texts.map((e) => e.toString()).toList(),
      model: json['model'] as String?,
      inputType: inputType,
      embeddingTypes: List<String>.from(embeddingTypes),
      truncate: json['truncate'] as String?,
    );
  }

  @override
  String toString() {
    return 'CohereEmbeddingRequest(texts: ${texts.length}, model: $model)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CohereEmbeddingRequest &&
        _listEquals(other.texts, texts) &&
        other.model == model &&
        other.inputType == inputType &&
        _listEqualsStrings(other.embeddingTypes, embeddingTypes) &&
        other.truncate == truncate;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(texts),
      model,
      inputType,
      Object.hashAll(embeddingTypes),
      truncate,
    );
  }

  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
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
}

/// Represents a single embedding in Cohere API response.
///
/// Cohere returns embeddings as a list of float arrays.
class CohereEmbedding {
  /// The embedding vector as a list of floating-point numbers.
  final List<double> embedding;

  /// The index of this embedding in the response list.
  ///
  /// Corresponds to the position of the input text in the original request.
  final int? index;

  /// Creates a new [CohereEmbedding] instance.
  ///
  /// [embedding] is required. [index] is optional.
  CohereEmbedding({
    required this.embedding,
    this.index,
  });

  /// Creates a [CohereEmbedding] from a JSON map.
  ///
  /// Parses the JSON representation of an embedding into a [CohereEmbedding] object.
  factory CohereEmbedding.fromJson(Map<String, dynamic> json) {
    final embedding = json['embedding'] as List<dynamic>?;
    if (embedding == null) {
      throw ClientError(
        message: 'Missing required field: embedding',
        code: 'INVALID_RESPONSE',
      );
    }

    return CohereEmbedding(
      embedding: embedding.map((e) => (e as num).toDouble()).toList(),
      index: json['index'] as int?,
    );
  }

  /// Converts this [CohereEmbedding] to a JSON map.
  ///
  /// Returns a map compatible with Cohere API format.
  Map<String, dynamic> toJson() {
    return {
      'embedding': embedding,
      if (index != null) 'index': index,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CohereEmbedding &&
        _listEquals(other.embedding, embedding) &&
        other.index == index;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(embedding), index);

  bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-10) return false;
    }
    return true;
  }
}

/// Represents usage statistics for a Cohere API request.
class CohereUsage {
  /// Number of tokens in the input.
  final int? tokens;

  /// Creates a new [CohereUsage] instance.
  ///
  /// [tokens] is optional.
  CohereUsage({
    this.tokens,
  });

  /// Creates a [CohereUsage] from a JSON map.
  ///
  /// Parses the JSON representation of usage statistics into a [CohereUsage] object.
  factory CohereUsage.fromJson(Map<String, dynamic> json) {
    return CohereUsage(
      tokens: json['tokens'] as int?,
    );
  }

  /// Converts this [CohereUsage] to a JSON map.
  ///
  /// Returns a map compatible with Cohere API format.
  Map<String, dynamic> toJson() {
    return {
      if (tokens != null) 'tokens': tokens,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CohereUsage && other.tokens == tokens;
  }

  @override
  int get hashCode => tokens.hashCode;
}

/// Represents an embedding response in Cohere API format.
///
/// This model matches the exact structure returned by Cohere's `/v2/embed` endpoint.
/// v2 API returns embeddings organized by type (e.g., {"float": [[...], [...]]}).
class CohereEmbeddingResponse {
  /// List of embedding vectors, one for each input text.
  ///
  /// The order matches the order of inputs in the original request.
  /// Extracted from the embeddings object (e.g., embeddings['float']).
  final List<List<double>> embeddings;

  /// The model identifier used for this embedding generation.
  final String? model;

  /// Usage statistics for this request.
  final CohereUsage? usage;

  /// Creates a new [CohereEmbeddingResponse] instance.
  ///
  /// [embeddings] is required and must not be empty.
  CohereEmbeddingResponse({
    required this.embeddings,
    this.model,
    this.usage,
  }) : assert(embeddings.isNotEmpty, 'embeddings must not be empty');

  /// Creates a [CohereEmbeddingResponse] from a JSON map.
  ///
  /// Parses the JSON representation of a response into a [CohereEmbeddingResponse] object.
  /// Handles both v1 format (embeddings as array) and v2 format (embeddings as object by type).
  factory CohereEmbeddingResponse.fromJson(Map<String, dynamic> json) {
    final embeddingsData = json['embeddings'];
    List<List<double>> embeddings;

    if (embeddingsData is Map<String, dynamic>) {
      // v2 format: embeddings is an object with type keys (e.g., {"float": [[...], [...]]})
      // Extract the first available embedding type (usually "float")
      if (embeddingsData.isEmpty) {
        throw ClientError(
          message: 'Missing or empty required field: embeddings',
          code: 'INVALID_RESPONSE',
        );
      }

      // Get the first embedding type (typically "float")
      final firstType = embeddingsData.keys.first;
      final typeEmbeddings = embeddingsData[firstType] as List<dynamic>?;

      if (typeEmbeddings == null || typeEmbeddings.isEmpty) {
        throw ClientError(
          message: 'Missing or empty embeddings for type: $firstType',
          code: 'INVALID_RESPONSE',
        );
      }

      embeddings = typeEmbeddings
          .map((e) =>
              (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList();
    } else if (embeddingsData is List<dynamic>) {
      // v1 format: embeddings is a direct array
      if (embeddingsData.isEmpty) {
        throw ClientError(
          message: 'Missing or empty required field: embeddings',
          code: 'INVALID_RESPONSE',
        );
      }

      embeddings = embeddingsData
          .map((e) =>
              (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList();
    } else {
      throw ClientError(
        message: 'Invalid embeddings format: expected object or array',
        code: 'INVALID_RESPONSE',
      );
    }

    // Extract usage from meta object
    CohereUsage? usage;
    final meta = json['meta'] as Map<String, dynamic>?;
    if (meta != null) {
      // v2 uses meta.billed_units for usage
      final billedUnits = meta['billed_units'] as Map<String, dynamic>?;
      if (billedUnits != null && billedUnits['input_tokens'] != null) {
        usage = CohereUsage(
          tokens: billedUnits['input_tokens'] as int?,
        );
      } else if (meta['tokens'] != null) {
        // Fallback to v1 format
        usage = CohereUsage.fromJson(meta);
      }
    }

    return CohereEmbeddingResponse(
      embeddings: embeddings,
      model:
          json['id'] as String?, // Cohere v2 uses 'id' for response identifier
      usage: usage,
    );
  }

  /// Converts this [CohereEmbeddingResponse] to a JSON map.
  ///
  /// Returns a map compatible with Cohere API format.
  Map<String, dynamic> toJson() {
    return {
      'embeddings': embeddings,
      if (model != null) 'id': model,
      if (usage != null) 'meta': usage!.toJson(),
    };
  }

  @override
  String toString() {
    return 'CohereEmbeddingResponse(embeddings: ${embeddings.length}, model: $model)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CohereEmbeddingResponse &&
        _listEquals(other.embeddings, embeddings) &&
        other.model == model &&
        other.usage == usage;
  }

  @override
  int get hashCode {
    int embeddingsHash = 0;
    for (final embedding in embeddings) {
      embeddingsHash = Object.hash(embeddingsHash, Object.hashAll(embedding));
    }
    return Object.hash(embeddingsHash, model, usage);
  }

  bool _listEquals(List<List<double>>? a, List<List<double>>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (int j = 0; j < a[i].length; j++) {
        if ((a[i][j] - b[i][j]).abs() > 1e-10) return false;
      }
    }
    return true;
  }
}

/// Represents a chat completion request in Cohere API format.
///
/// This model matches the exact structure expected by Cohere's `/v2/chat` endpoint.
///
/// **Cohere API Reference:**
/// https://docs.cohere.com/reference/chat
class CohereChatRequest {
  /// The model to use for chat completion.
  ///
  /// Examples: "command-r-plus", "command-r", "command-a-03-2025"
  final String model;

  /// List of messages in the conversation.
  ///
  /// Each message has a role ("user", "assistant", "system", "tool") and content.
  /// v2 API uses "messages" array (not "message").
  final List<Map<String, dynamic>> messages;

  /// Optional conversation ID for maintaining context.
  final String? conversationId;

  /// Optional list of documents to ground the response.
  final List<Map<String, dynamic>>? documents;

  /// Optional list of tools/functions the model can use.
  final List<Map<String, dynamic>>? tools;

  /// Optional tool choice configuration.
  ///
  /// Used to control whether or not the model will be forced to use a tool.
  /// Values: "REQUIRED", "NONE", or null (model chooses).
  final dynamic toolChoice;

  /// Optional temperature for sampling.
  final double? temperature;

  /// Optional max tokens to generate.
  final int? maxTokens;

  /// Optional top-p for sampling.
  final double? p;

  /// Optional top-k for sampling.
  final int? k;

  /// Optional stop sequences.
  final List<String>? stopSequences;

  /// Optional frequency penalty.
  final double? frequencyPenalty;

  /// Optional presence penalty.
  final double? presencePenalty;

  /// Whether to stream the response.
  final bool? stream;

  /// Optional response format configuration.
  ///
  /// Can force JSON output: {"type": "json_object"} or provide JSON schema.
  final Map<String, dynamic>? responseFormat;

  /// Optional safety mode.
  ///
  /// Values: "CONTEXTUAL", "STRICT", "OFF"
  final String? safetyMode;

  /// Optional strict tools mode.
  ///
  /// When true, tool calls must follow tool definition strictly.
  final bool? strictTools;

  /// Optional thinking configuration.
  ///
  /// Configuration for reasoning features.
  final Map<String, dynamic>? thinking;

  /// Optional priority for request handling.
  ///
  /// Lower values mean earlier handling (0 is highest priority).
  final int? priority;

  /// Optional seed for deterministic generation.
  final int? seed;

  /// Optional logprobs flag.
  ///
  /// When true, log probabilities of generated tokens are included.
  final bool? logprobs;

  /// Creates a new [CohereChatRequest] instance.
  CohereChatRequest({
    required this.model,
    required this.messages,
    this.conversationId,
    this.documents,
    this.tools,
    this.toolChoice,
    this.temperature,
    this.maxTokens,
    this.p,
    this.k,
    this.stopSequences,
    this.frequencyPenalty,
    this.presencePenalty,
    this.stream,
    this.responseFormat,
    this.safetyMode,
    this.strictTools,
    this.thinking,
    this.priority,
    this.seed,
    this.logprobs,
  }) : assert(messages.isNotEmpty, 'messages must not be empty');

  /// Converts this request to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'messages': messages,
      if (conversationId != null) 'conversation_id': conversationId,
      if (documents != null && documents!.isNotEmpty) 'documents': documents,
      if (tools != null && tools!.isNotEmpty) 'tools': tools,
      if (toolChoice != null) 'tool_choice': toolChoice,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (p != null) 'p': p,
      if (k != null) 'k': k,
      if (stopSequences != null && stopSequences!.isNotEmpty)
        'stop_sequences': stopSequences,
      if (frequencyPenalty != null) 'frequency_penalty': frequencyPenalty,
      if (presencePenalty != null) 'presence_penalty': presencePenalty,
      if (stream == true) 'stream': stream,
      if (responseFormat != null) 'response_format': responseFormat,
      if (safetyMode != null) 'safety_mode': safetyMode,
      if (strictTools != null) 'strict_tools': strictTools,
      if (thinking != null) 'thinking': thinking,
      if (priority != null) 'priority': priority,
      if (seed != null) 'seed': seed,
      if (logprobs != null) 'logprobs': logprobs,
    };
  }

  /// Creates a [CohereChatRequest] from a JSON map.
  factory CohereChatRequest.fromJson(Map<String, dynamic> json) {
    final messages = json['messages'] as List<dynamic>?;
    if (messages == null || messages.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: messages',
        code: 'INVALID_REQUEST',
      );
    }

    final model = json['model'] as String?;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message: 'Missing required field: model',
        code: 'INVALID_REQUEST',
      );
    }

    return CohereChatRequest(
      model: model,
      messages: List<Map<String, dynamic>>.from(
        messages.map((m) => m as Map<String, dynamic>),
      ),
      conversationId: json['conversation_id'] as String?,
      documents: json['documents'] != null
          ? List<Map<String, dynamic>>.from(
              (json['documents'] as List).map((d) => d as Map<String, dynamic>),
            )
          : null,
      tools: json['tools'] != null
          ? List<Map<String, dynamic>>.from(
              (json['tools'] as List).map((t) => t as Map<String, dynamic>),
            )
          : null,
      toolChoice: json['tool_choice'],
      temperature: json['temperature'] as double?,
      maxTokens: json['max_tokens'] as int?,
      p: json['p'] as double?,
      k: json['k'] as int?,
      stopSequences: json['stop_sequences'] != null
          ? List<String>.from(json['stop_sequences'] as List)
          : null,
      frequencyPenalty: json['frequency_penalty'] as double?,
      presencePenalty: json['presence_penalty'] as double?,
      stream: json['stream'] as bool?,
      responseFormat: json['response_format'] != null
          ? Map<String, dynamic>.from(json['response_format'] as Map)
          : null,
      safetyMode: json['safety_mode'] as String?,
      strictTools: json['strict_tools'] as bool?,
      thinking: json['thinking'] != null
          ? Map<String, dynamic>.from(json['thinking'] as Map)
          : null,
      priority: json['priority'] as int?,
      seed: json['seed'] as int?,
      logprobs: json['logprobs'] as bool?,
    );
  }
}

/// Represents a chat completion response in Cohere API format.
///
/// This model matches the exact structure returned by Cohere's `/v2/chat` endpoint.
class CohereChatResponse {
  /// Unique identifier for the generated reply.
  final String id;

  /// The message object containing the response.
  ///
  /// v2 API uses a message object with content array instead of text string.
  final Map<String, dynamic> message;

  /// The finish reason for the generation.
  ///
  /// Values: "COMPLETE", "MAX_TOKENS", "STOP_SEQUENCE", "TOOL_CALL", "ERROR", "TIMEOUT"
  final String? finishReason;

  /// Optional usage statistics.
  final Map<String, dynamic>? usage;

  /// Optional log probabilities.
  final List<Map<String, dynamic>>? logprobs;

  /// Creates a new [CohereChatResponse] instance.
  CohereChatResponse({
    required this.id,
    required this.message,
    this.finishReason,
    this.usage,
    this.logprobs,
  });

  /// Creates a [CohereChatResponse] from a JSON map.
  factory CohereChatResponse.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) {
      throw ClientError(
        message: 'Missing required field: id',
        code: 'INVALID_RESPONSE',
      );
    }

    final message = json['message'] as Map<String, dynamic>?;
    if (message == null) {
      throw ClientError(
        message: 'Missing required field: message',
        code: 'INVALID_RESPONSE',
      );
    }

    return CohereChatResponse(
      id: id,
      message: message,
      finishReason: json['finish_reason'] as String?,
      usage: json['usage'] != null && json['usage'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['usage'] as Map)
          : null,
      logprobs: json['logprobs'] != null
          ? List<Map<String, dynamic>>.from(
              (json['logprobs'] as List).map((l) => l as Map<String, dynamic>),
            )
          : null,
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      if (finishReason != null) 'finish_reason': finishReason,
      if (usage != null) 'usage': usage,
      if (logprobs != null) 'logprobs': logprobs,
    };
  }

  /// Helper method to extract text content from message.
  ///
  /// v2 API uses message.content which can be a string or array of content blocks.
  String getText() {
    final content = message['content'];
    if (content is String) {
      return content;
    } else if (content is List) {
      // Content is an array of content blocks
      final textParts = <String>[];
      for (final block in content) {
        if (block is Map<String, dynamic>) {
          if (block['type'] == 'text' && block['text'] is String) {
            textParts.add(block['text'] as String);
          }
        } else if (block is String) {
          textParts.add(block);
        }
      }
      return textParts.join('');
    }
    return '';
  }
}

/// Represents a tokenize request in Cohere API format.
///
/// This model matches the exact structure expected by Cohere's `/v1/tokenize` endpoint.
///
/// **Cohere API Reference:**
/// https://docs.cohere.com/reference/tokenize
class CohereTokenizeRequest {
  /// The text to tokenize.
  final String text;

  /// Optional model identifier.
  ///
  /// If not specified, uses the default tokenizer.
  final String? model;

  /// Creates a new [CohereTokenizeRequest] instance.
  CohereTokenizeRequest({
    required this.text,
    this.model,
  }) : assert(text.isNotEmpty, 'text must not be empty');

  /// Converts this request to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (model != null) 'model': model,
    };
  }

  /// Creates a [CohereTokenizeRequest] from a JSON map.
  factory CohereTokenizeRequest.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String?;
    if (text == null || text.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: text',
        code: 'INVALID_REQUEST',
      );
    }

    return CohereTokenizeRequest(
      text: text,
      model: json['model'] as String?,
    );
  }
}

/// Represents a tokenize response in Cohere API format.
///
/// This model matches the exact structure returned by Cohere's `/v1/tokenize` endpoint.
class CohereTokenizeResponse {
  /// List of token IDs.
  final List<int> tokens;

  /// Optional list of token strings.
  ///
  /// Contains the string representation of each token.
  final List<String>? tokenStrings;

  /// Creates a new [CohereTokenizeResponse] instance.
  CohereTokenizeResponse({
    required this.tokens,
    this.tokenStrings,
  });

  /// Creates a [CohereTokenizeResponse] from a JSON map.
  factory CohereTokenizeResponse.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'] as List<dynamic>?;
    if (tokens == null) {
      throw ClientError(
        message: 'Missing required field: tokens',
        code: 'INVALID_RESPONSE',
      );
    }

    return CohereTokenizeResponse(
      tokens: tokens.map((t) => (t as num).toInt()).toList(),
      tokenStrings: json['token_strings'] != null
          ? List<String>.from(json['token_strings'] as List)
          : null,
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'tokens': tokens,
      if (tokenStrings != null) 'token_strings': tokenStrings,
    };
  }
}

/// Represents a detokenize request in Cohere API format.
///
/// This model matches the exact structure expected by Cohere's `/v1/detokenize` endpoint.
///
/// **Cohere API Reference:**
/// https://docs.cohere.com/reference/detokenize
class CohereDetokenizeRequest {
  /// List of token IDs to detokenize.
  final List<int> tokens;

  /// Optional model identifier.
  ///
  /// If not specified, uses the default tokenizer.
  final String? model;

  /// Creates a new [CohereDetokenizeRequest] instance.
  CohereDetokenizeRequest({
    required this.tokens,
    this.model,
  }) : assert(tokens.isNotEmpty, 'tokens must not be empty');

  /// Converts this request to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'tokens': tokens,
      if (model != null) 'model': model,
    };
  }

  /// Creates a [CohereDetokenizeRequest] from a JSON map.
  factory CohereDetokenizeRequest.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'] as List<dynamic>?;
    if (tokens == null || tokens.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: tokens',
        code: 'INVALID_REQUEST',
      );
    }

    return CohereDetokenizeRequest(
      tokens: tokens.map((t) => (t as num).toInt()).toList(),
      model: json['model'] as String?,
    );
  }
}

/// Represents a detokenize response in Cohere API format.
///
/// This model matches the exact structure returned by Cohere's `/v1/detokenize` endpoint.
class CohereDetokenizeResponse {
  /// The detokenized text.
  final String text;

  /// Creates a new [CohereDetokenizeResponse] instance.
  CohereDetokenizeResponse({
    required this.text,
  });

  /// Creates a [CohereDetokenizeResponse] from a JSON map.
  factory CohereDetokenizeResponse.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String?;
    if (text == null) {
      throw ClientError(
        message: 'Missing required field: text',
        code: 'INVALID_RESPONSE',
      );
    }

    return CohereDetokenizeResponse(
      text: text,
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'text': text,
    };
  }
}
