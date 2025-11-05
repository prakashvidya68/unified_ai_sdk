/// Represents a request to generate embeddings from text inputs.
///
/// Embeddings are vector representations of text that capture semantic meaning.
/// This model standardizes embedding requests across different AI providers.
///
/// **Example usage:**
/// ```dart
/// final request = EmbeddingRequest(
///   inputs: ['Hello, world!', 'How are you?'],
///   model: 'text-embedding-3-small',
/// );
///
/// final response = await ai.embed(request: request);
/// final vectors = response.vectors;
/// ```
class EmbeddingRequest {
  /// List of text inputs to generate embeddings for.
  ///
  /// Each string in the list will be converted into a vector representation.
  /// Multiple inputs can be embedded in a single request for efficiency.
  final List<String> inputs;

  /// Optional model identifier to use for embedding generation.
  ///
  /// If not specified, the provider will use its default embedding model.
  /// Examples: "text-embedding-3-small", "text-embedding-ada-002", "embed-english-v3.0"
  final String? model;

  /// Optional provider-specific configuration options.
  ///
  /// Allows passing provider-specific parameters that aren't part of the
  /// standard API. Keys should be provider IDs (e.g., "openai", "cohere").
  ///
  /// **Example:**
  /// ```dart
  /// EmbeddingRequest(
  ///   inputs: ['Hello'],
  ///   providerOptions: {
  ///     'openai': {'encoding_format': 'float'},
  ///     'cohere': {'input_type': 'search_document'},
  ///   },
  /// )
  /// ```
  final Map<String, Map<String, dynamic>>? providerOptions;

  /// Creates a new [EmbeddingRequest] instance.
  ///
  /// [inputs] is required and must not be empty. [model] and [providerOptions]
  /// are optional.
  EmbeddingRequest({
    required this.inputs,
    this.model,
    this.providerOptions,
  }) : assert(inputs.isNotEmpty, 'inputs must not be empty');

  /// Converts this [EmbeddingRequest] to a JSON map.
  ///
  /// The resulting map is compatible with most AI provider APIs.
  /// Only non-null optional fields are included in the output.
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "inputs": ["Hello, world!", "How are you?"],
  ///   "model": "text-embedding-3-small",
  ///   "provider_options": {
  ///     "openai": {"encoding_format": "float"}
  ///   }
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'inputs': inputs,
      if (model != null) 'model': model,
      if (providerOptions != null) 'provider_options': providerOptions,
    };
  }

  /// Creates an [EmbeddingRequest] instance from a JSON map.
  ///
  /// Parses the JSON representation of an embedding request into an
  /// [EmbeddingRequest] object.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "inputs": ["Hello, world!"],
  ///   "model": "text-embedding-3-small"
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory EmbeddingRequest.fromJson(Map<String, dynamic> json) {
    final inputs = json['inputs'];
    if (inputs == null) {
      throw const FormatException('Missing required field: inputs');
    }
    if (inputs is! List) {
      throw const FormatException('Field "inputs" must be a List');
    }
    if (inputs.isEmpty) {
      throw const FormatException('Field "inputs" must not be empty');
    }

    return EmbeddingRequest(
      inputs: inputs.map((e) => e.toString()).toList(),
      model: json['model'] as String?,
      providerOptions:
          json['provider_options'] as Map<String, Map<String, dynamic>>?,
    );
  }

  /// Creates a copy of this [EmbeddingRequest] with the given fields replaced.
  ///
  /// Returns a new [EmbeddingRequest] instance with the same values as this one,
  /// except for the fields explicitly provided.
  ///
  /// To explicitly set a field to null, use [Object] as a wrapper:
  /// ```dart
  /// request.copyWith(model: null) // Sets model to null
  /// ```
  EmbeddingRequest copyWith({
    List<String>? inputs,
    Object? model = _undefined,
    Map<String, Map<String, dynamic>>? providerOptions,
  }) {
    return EmbeddingRequest(
      inputs: inputs ?? this.inputs,
      model: model == _undefined ? this.model : model as String?,
      providerOptions: providerOptions ?? this.providerOptions,
    );
  }

  static const _undefined = Object();

  @override
  String toString() {
    return 'EmbeddingRequest(inputs: ${inputs.length} item(s)${model != null ? ", model: $model" : ""}${providerOptions != null ? ", providerOptions: ..." : ""})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmbeddingRequest &&
        _listEquals(other.inputs, inputs) &&
        other.model == model &&
        _mapEquals(other.providerOptions, providerOptions);
  }

  @override
  int get hashCode {
    int providerOptionsHash = 0;
    if (providerOptions != null) {
      final opts = providerOptions!;
      for (final key in opts.keys) {
        providerOptionsHash = Object.hash(providerOptionsHash, key, opts[key]);
      }
    }
    return Object.hash(
      Object.hashAll(inputs),
      model,
      providerOptionsHash,
    );
  }

  /// Helper method to compare lists for equality.
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Helper method to compare maps for equality.
  bool _mapEquals(Map<String, Map<String, dynamic>>? a,
      Map<String, Map<String, dynamic>>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
