import '../common/usage.dart';

/// Represents a single embedding vector with its associated metadata.
///
/// Each embedding in a response is paired with its dimension count and
/// optional index for correlation with input order.
class EmbeddingData {
  /// The embedding vector as a list of floating-point numbers.
  ///
  /// The length of this list equals the embedding dimension.
  final List<double> vector;

  /// The dimension of this embedding vector.
  ///
  /// Typically matches the length of [vector], but provided separately
  /// for convenience and validation.
  final int dimension;

  /// Optional index of this embedding in the response list.
  ///
  /// Corresponds to the position of the input text in the original request.
  /// Useful when processing multiple embeddings to maintain input-output correlation.
  final int? index;

  /// Creates a new [EmbeddingData] instance.
  ///
  /// [vector] and [dimension] are required. [index] is optional.
  const EmbeddingData({
    required this.vector,
    required this.dimension,
    this.index,
  }) : assert(vector.length == dimension, 'vector length must match dimension');

  /// Converts this [EmbeddingData] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'vector': vector,
      'dimension': dimension,
      if (index != null) 'index': index,
    };
  }

  /// Creates an [EmbeddingData] instance from a JSON map.
  factory EmbeddingData.fromJson(Map<String, dynamic> json) {
    return EmbeddingData(
      vector:
          (json['vector'] as List).map((e) => (e as num).toDouble()).toList(),
      dimension: json['dimension'] as int,
      index: json['index'] as int?,
    );
  }

  /// Creates a copy of this [EmbeddingData] with the given fields replaced.
  EmbeddingData copyWith({
    List<double>? vector,
    int? dimension,
    int? index,
  }) {
    return EmbeddingData(
      vector: vector ?? this.vector,
      dimension: dimension ?? this.dimension,
      index: index ?? this.index,
    );
  }

  @override
  String toString() {
    return 'EmbeddingData(dimension: $dimension${index != null ? ", index: $index" : ""})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmbeddingData &&
        _listEquals(other.vector, vector) &&
        other.dimension == dimension &&
        other.index == index;
  }

  @override
  int get hashCode {
    // Use a consistent hash for the vector list
    int vectorHash = 0;
    for (final v in vector) {
      vectorHash = Object.hash(vectorHash, v);
    }
    return Object.hash(vectorHash, dimension, index);
  }

  /// Helper method to compare lists for equality.
  bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-10) {
        return false; // Floating point comparison
      }
    }
    return true;
  }
}

/// Represents a complete embedding response from an AI provider.
///
/// This is the primary response type returned by [embed()] operations.
/// It contains the generated embedding vectors, their dimensions, and metadata
/// about the response.
///
/// **Example usage:**
/// ```dart
/// final response = await ai.embed(request: embeddingRequest);
/// final firstVector = response.embeddings.first.vector;
/// print('Dimension: ${response.embeddings.first.dimension}');
/// print('Used ${response.usage?.totalTokens} tokens');
/// ```
class EmbeddingResponse {
  /// List of embedding data objects, one for each input.
  ///
  /// Each [EmbeddingData] contains a vector and its dimension.
  /// The order matches the order of inputs in the original request.
  final List<EmbeddingData> embeddings;

  /// The model identifier used for this embedding generation.
  ///
  /// Examples: "text-embedding-3-small", "text-embedding-ada-002", "embed-english-v3.0"
  final String model;

  /// The provider that generated this response.
  ///
  /// Examples: "openai", "cohere", "google"
  final String provider;

  /// Token usage statistics for this embedding generation.
  ///
  /// Contains information about how many tokens were used in the request.
  /// May be null if the provider doesn't report usage information.
  final Usage? usage;

  /// Timestamp when this response was created.
  ///
  /// Defaults to the current time if not specified. Useful for tracking
  /// response times and ordering responses.
  final DateTime timestamp;

  /// Optional metadata associated with this response.
  ///
  /// Can contain provider-specific fields, request IDs, or custom metadata
  /// that doesn't fit into the standard response structure.
  final Map<String, dynamic>? metadata;

  /// Creates a new [EmbeddingResponse] instance.
  ///
  /// [embeddings], [model], and [provider] are required.
  /// [timestamp] defaults to the current time if not provided.
  /// [usage] and [metadata] are optional.
  EmbeddingResponse({
    required this.embeddings,
    required this.model,
    required this.provider,
    this.usage,
    DateTime? timestamp,
    this.metadata,
  })  : timestamp = timestamp ?? DateTime.now(),
        assert(embeddings.isNotEmpty, 'embeddings must not be empty');

  /// Convenience getter for accessing embedding vectors directly.
  ///
  /// Returns a list of vectors (List<double>) extracted from [embeddings].
  /// This is provided for backward compatibility and convenience.
  List<List<double>> get vectors {
    return embeddings.map((e) => e.vector).toList();
  }

  /// Convenience getter for accessing embedding dimensions directly.
  ///
  /// Returns a list of dimensions (int) extracted from [embeddings].
  /// This is provided for backward compatibility and convenience.
  List<int> get dimensions {
    return embeddings.map((e) => e.dimension).toList();
  }

  /// Converts this [EmbeddingResponse] to a JSON map.
  ///
  /// The resulting map includes all response data in a provider-agnostic format.
  Map<String, dynamic> toJson() {
    return {
      'embeddings': embeddings.map((e) => e.toJson()).toList(),
      'model': model,
      'provider': provider,
      if (usage != null) 'usage': usage!.toJson(),
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Creates an [EmbeddingResponse] instance from a JSON map.
  ///
  /// Parses the JSON representation of an embedding response into an
  /// [EmbeddingResponse] object.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "embeddings": [{
  ///     "vector": [0.1, 0.2, 0.3],
  ///     "dimension": 3,
  ///     "index": 0
  ///   }],
  ///   "model": "text-embedding-3-small",
  ///   "provider": "openai",
  ///   "usage": {
  ///     "prompt_tokens": 5,
  ///     "completion_tokens": 0,
  ///     "total_tokens": 5
  ///   }
  /// }
  /// ```
  ///
  /// Also supports legacy format with separate `vectors` and `dimensions` arrays:
  /// ```json
  /// {
  ///   "vectors": [[0.1, 0.2, 0.3]],
  ///   "dimensions": [3],
  ///   "model": "text-embedding-3-small",
  ///   "provider": "openai"
  /// }
  /// ```
  factory EmbeddingResponse.fromJson(Map<String, dynamic> json) {
    List<EmbeddingData> embeddings;

    // Support both new format (embeddings array) and legacy format (vectors/dimensions)
    if (json.containsKey('embeddings')) {
      embeddings = (json['embeddings'] as List)
          .map((e) => EmbeddingData.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json.containsKey('vectors') && json.containsKey('dimensions')) {
      // Legacy format support
      final vectors = json['vectors'] as List;
      final dimensions = json['dimensions'] as List;
      if (vectors.length != dimensions.length) {
        throw const FormatException(
            'vectors and dimensions arrays must have the same length');
      }
      embeddings = List.generate(vectors.length, (index) {
        return EmbeddingData(
          vector: (vectors[index] as List)
              .map((e) => (e as num).toDouble())
              .toList(),
          dimension: dimensions[index] as int,
          index: index,
        );
      });
    } else {
      throw const FormatException(
          'Missing required field: embeddings or vectors/dimensions');
    }

    return EmbeddingResponse(
      embeddings: embeddings,
      model: json['model'] as String,
      provider: json['provider'] as String,
      usage: json['usage'] != null
          ? Usage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Creates a copy of this [EmbeddingResponse] with the given fields replaced.
  EmbeddingResponse copyWith({
    List<EmbeddingData>? embeddings,
    String? model,
    String? provider,
    Usage? usage,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return EmbeddingResponse(
      embeddings: embeddings ?? this.embeddings,
      model: model ?? this.model,
      provider: provider ?? this.provider,
      usage: usage ?? this.usage,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'EmbeddingResponse(embeddings: ${embeddings.length}, model: $model, provider: $provider${usage != null ? ", usage: $usage" : ""})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmbeddingResponse &&
        _listEquals(other.embeddings, embeddings) &&
        other.model == model &&
        other.provider == provider &&
        other.usage == usage &&
        other.timestamp.millisecondsSinceEpoch ==
            timestamp.millisecondsSinceEpoch &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    int embeddingsHash = 0;
    for (final embedding in embeddings) {
      embeddingsHash = Object.hash(embeddingsHash, embedding);
    }
    return Object.hash(
      embeddingsHash,
      model,
      provider,
      usage,
      timestamp.millisecondsSinceEpoch,
      metadata,
    );
  }

  /// Helper method to compare lists for equality.
  bool _listEquals(List<EmbeddingData> a, List<EmbeddingData> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Helper method to compare maps for equality.
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
