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
/// This model matches the exact structure expected by Cohere's `/v1/embed` endpoint.
///
/// **Key differences from OpenAI:**
/// - Uses "texts" array (not "input")
/// - Supports "input_type" parameter (search_document, search_query, classification, etc.)
/// - Supports "embedding_types" array (float, int8, uint8, binary, ubinary)
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
  final String? inputType;

  /// Types of embeddings to return.
  ///
  /// Can include: "float", "int8", "uint8", "binary", "ubinary"
  /// Defaults to ["float"] if not specified.
  final List<String>? embeddingTypes;

  /// Truncation strategy for long texts.
  ///
  /// - "NONE": No truncation (may fail if text is too long)
  /// - "START": Truncate from the start
  /// - "END": Truncate from the end (default)
  final String? truncate;

  /// Creates a new [CohereEmbeddingRequest] instance.
  ///
  /// [texts] is required and must not be empty.
  CohereEmbeddingRequest({
    required this.texts,
    this.model,
    this.inputType,
    this.embeddingTypes,
    this.truncate,
  })  : assert(texts.isNotEmpty, 'texts must not be empty'),
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
      if (inputType != null) 'input_type': inputType,
      if (embeddingTypes != null) 'embedding_types': embeddingTypes,
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

    return CohereEmbeddingRequest(
      texts: texts.map((e) => e.toString()).toList(),
      model: json['model'] as String?,
      inputType: json['input_type'] as String?,
      embeddingTypes: json['embedding_types'] != null
          ? List<String>.from(json['embedding_types'] as List)
          : null,
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
      Object.hashAll(embeddingTypes ?? []),
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
/// This model matches the exact structure returned by Cohere's `/v1/embed` endpoint.
class CohereEmbeddingResponse {
  /// List of embedding vectors, one for each input text.
  ///
  /// The order matches the order of inputs in the original request.
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
  factory CohereEmbeddingResponse.fromJson(Map<String, dynamic> json) {
    final embeddings = json['embeddings'] as List<dynamic>?;
    if (embeddings == null || embeddings.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: embeddings',
        code: 'INVALID_RESPONSE',
      );
    }

    return CohereEmbeddingResponse(
      embeddings: embeddings
          .map((e) =>
              (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList(),
      model: json['id'] as String?, // Cohere uses 'id' for model identifier
      usage: json['meta'] != null && json['meta'] is Map<String, dynamic>
          ? CohereUsage.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
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
