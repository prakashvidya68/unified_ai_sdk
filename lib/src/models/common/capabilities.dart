/// Represents the capabilities of an AI provider.
///
/// This class defines what operations and features a provider supports,
/// allowing the SDK to intelligently route requests and validate operations
/// before attempting them.
///
/// **Example usage:**
/// ```dart
/// final capabilities = ProviderCapabilities(
///   supportsChat: true,
///   supportsEmbedding: true,
///   supportsStreaming: true,
///   supportedModels: ['gpt-4', 'gpt-3.5-turbo'],
/// );
///
/// if (capabilities.supportsChat) {
///   // Perform chat operation
/// }
/// ```
class ProviderCapabilities {
  /// Whether the provider supports chat/text generation.
  ///
  /// Providers that support chat can generate text completions, engage in
  /// conversations, and provide AI-powered responses to user queries.
  final bool supportsChat;

  /// Whether the provider supports embedding generation.
  ///
  /// Providers that support embeddings can convert text into vector
  /// representations for semantic search, similarity matching, and other
  /// vector-based operations.
  final bool supportsEmbedding;

  /// Whether the provider supports image generation.
  ///
  /// Providers that support image generation can create images from text
  /// prompts using models like DALL-E, Stable Diffusion, etc.
  final bool supportsImageGeneration;

  /// Whether the provider supports text-to-speech (TTS).
  ///
  /// Providers that support TTS can convert text into audio/speech.
  final bool supportsTTS;

  /// Whether the provider supports speech-to-text (STT).
  ///
  /// Providers that support STT can transcribe audio into text.
  final bool supportsSTT;

  /// Whether the provider supports streaming responses.
  ///
  /// Providers that support streaming can return responses incrementally
  /// as they are generated, rather than waiting for the complete response.
  /// This is useful for chat completions where users see text appear in
  /// real-time.
  final bool supportsStreaming;

  /// List of model identifiers supported by this provider.
  ///
  /// Examples: ['gpt-4', 'gpt-3.5-turbo', 'text-embedding-ada-002']
  /// This list helps the SDK validate model selection and provides
  /// information about available models.
  final List<String> supportedModels;

  /// Creates a new [ProviderCapabilities] instance.
  ///
  /// All parameters are optional and default to `false` for boolean flags
  /// and an empty list for [supportedModels]. This allows creating minimal
  /// capability definitions that can be extended as needed.
  ///
  /// **Example:**
  /// ```dart
  /// // Minimal capabilities - only chat
  /// final basic = ProviderCapabilities(supportsChat: true);
  ///
  /// // Full-featured provider
  /// final advanced = ProviderCapabilities(
  ///   supportsChat: true,
  ///   supportsEmbedding: true,
  ///   supportsImageGeneration: true,
  ///   supportsTTS: true,
  ///   supportsSTT: true,
  ///   supportsStreaming: true,
  ///   supportedModels: ['model-1', 'model-2'],
  /// );
  /// ```
  const ProviderCapabilities({
    this.supportsChat = false,
    this.supportsEmbedding = false,
    this.supportsImageGeneration = false,
    this.supportsTTS = false,
    this.supportsSTT = false,
    this.supportsStreaming = false,
    this.supportedModels = const [],
  });

  /// Creates a [ProviderCapabilities] instance from a JSON map.
  ///
  /// Expects a map with optional keys matching the field names (snake_case
  /// or camelCase). Missing keys default to `false` for booleans and empty
  /// list for [supportedModels].
  ///
  /// **Example:**
  /// ```dart
  /// final json = {
  ///   'supports_chat': true,
  ///   'supports_streaming': true,
  ///   'supported_models': ['gpt-4', 'gpt-3.5'],
  /// };
  /// final capabilities = ProviderCapabilities.fromJson(json);
  /// ```
  factory ProviderCapabilities.fromJson(Map<String, dynamic> json) {
    return ProviderCapabilities(
      supportsChat: json['supportsChat'] as bool? ??
          json['supports_chat'] as bool? ??
          false,
      supportsEmbedding: json['supportsEmbedding'] as bool? ??
          json['supports_embedding'] as bool? ??
          false,
      supportsImageGeneration: json['supportsImageGeneration'] as bool? ??
          json['supports_image_generation'] as bool? ??
          false,
      supportsTTS: json['supportsTTS'] as bool? ??
          json['supports_tts'] as bool? ??
          false,
      supportsSTT: json['supportsSTT'] as bool? ??
          json['supports_stt'] as bool? ??
          false,
      supportsStreaming: json['supportsStreaming'] as bool? ??
          json['supports_streaming'] as bool? ??
          false,
      supportedModels:
          (json['supportedModels'] as List<dynamic>?)?.cast<String>() ??
              (json['supported_models'] as List<dynamic>?)?.cast<String>() ??
              const [],
    );
  }

  /// Converts this [ProviderCapabilities] instance to a JSON map.
  ///
  /// Returns a map with camelCase keys. All fields are included, even if
  /// they are false or empty, for consistency.
  ///
  /// **Example:**
  /// ```dart
  /// final capabilities = ProviderCapabilities(supportsChat: true);
  /// final json = capabilities.toJson();
  /// // {'supportsChat': true, 'supportsEmbedding': false, ...}
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'supportsChat': supportsChat,
      'supportsEmbedding': supportsEmbedding,
      'supportsImageGeneration': supportsImageGeneration,
      'supportsTTS': supportsTTS,
      'supportsSTT': supportsSTT,
      'supportsStreaming': supportsStreaming,
      'supportedModels': supportedModels,
    };
  }

  /// Creates a copy of this [ProviderCapabilities] with the given fields
  /// replaced with new values.
  ///
  /// Returns a new instance with updated fields. Fields not specified
  /// remain unchanged.
  ///
  /// **Example:**
  /// ```dart
  /// final original = ProviderCapabilities(supportsChat: true);
  /// final updated = original.copyWith(supportsStreaming: true);
  /// // updated.supportsChat is still true, supportsStreaming is now true
  /// ```
  ProviderCapabilities copyWith({
    bool? supportsChat,
    bool? supportsEmbedding,
    bool? supportsImageGeneration,
    bool? supportsTTS,
    bool? supportsSTT,
    bool? supportsStreaming,
    List<String>? supportedModels,
  }) {
    return ProviderCapabilities(
      supportsChat: supportsChat ?? this.supportsChat,
      supportsEmbedding: supportsEmbedding ?? this.supportsEmbedding,
      supportsImageGeneration:
          supportsImageGeneration ?? this.supportsImageGeneration,
      supportsTTS: supportsTTS ?? this.supportsTTS,
      supportsSTT: supportsSTT ?? this.supportsSTT,
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      supportedModels: supportedModels ?? this.supportedModels,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProviderCapabilities &&
        other.supportsChat == supportsChat &&
        other.supportsEmbedding == supportsEmbedding &&
        other.supportsImageGeneration == supportsImageGeneration &&
        other.supportsTTS == supportsTTS &&
        other.supportsSTT == supportsSTT &&
        other.supportsStreaming == supportsStreaming &&
        _listEquals(other.supportedModels, supportedModels);
  }

  @override
  int get hashCode {
    return Object.hash(
      supportsChat,
      supportsEmbedding,
      supportsImageGeneration,
      supportsTTS,
      supportsSTT,
      supportsStreaming,
      Object.hashAll(supportedModels),
    );
  }

  @override
  String toString() {
    final capabilities = <String>[];
    if (supportsChat) capabilities.add('Chat');
    if (supportsEmbedding) capabilities.add('Embedding');
    if (supportsImageGeneration) capabilities.add('Image');
    if (supportsTTS) capabilities.add('TTS');
    if (supportsSTT) capabilities.add('STT');
    if (supportsStreaming) capabilities.add('Streaming');

    final modelsInfo = supportedModels.isEmpty
        ? 'no models'
        : '${supportedModels.length} model(s)';

    return 'ProviderCapabilities('
        '${capabilities.isEmpty ? 'none' : capabilities.join(', ')}, '
        '$modelsInfo)';
  }

  /// Helper method to compare lists of strings for equality.
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
