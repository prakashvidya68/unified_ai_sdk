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

  /// Whether the provider supports video generation.
  ///
  /// Providers that support video generation can create videos from text
  /// prompts using models like Sora, Veo, or Grok Imagine.
  final bool supportsVideoGeneration;

  /// Whether the provider supports video analysis.
  ///
  /// Providers that support video analysis can analyze existing videos to
  /// extract information such as objects, scenes, actions, text, or other insights.
  final bool supportsVideoAnalysis;

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
  ///
  /// **Note:** If [dynamicModels] is true, this getter returns dynamically
  /// fetched models if available and cache is valid, otherwise returns
  /// [fallbackModels].
  List<String> get supportedModels {
    if (dynamicModels && _cachedModels != null && _isCacheValid()) {
      return _cachedModels!;
    }
    return fallbackModels;
  }

  /// Static fallback models (used when dynamic fetch fails or not implemented).
  ///
  /// These models are used as a backup when:
  /// - Dynamic model fetching is not supported
  /// - Dynamic fetch fails
  /// - Cache is expired and refresh fails
  ///
  /// This ensures the SDK always has a list of models available, even if
  /// the provider's API is unreachable.
  final List<String> fallbackModels;

  /// Whether models are dynamically fetched from the provider's API.
  ///
  /// When true, the provider implements [ModelFetcher] and models are
  /// fetched from the API. When false, only [fallbackModels] are used.
  final bool dynamicModels;

  /// Cached dynamically fetched models.
  List<String>? _cachedModels;

  /// Timestamp when models were last fetched.
  DateTime? _cacheTimestamp;

  /// Cache TTL for dynamically fetched models (24 hours).
  static const Duration _cacheTTL = Duration(hours: 24);

  /// Creates a new [ProviderCapabilities] instance.
  ///
  /// All parameters are optional and default to `false` for boolean flags
  /// and an empty list for [fallbackModels]. This allows creating minimal
  /// capability definitions that can be extended as needed.
  ///
  /// **Example:**
  /// ```dart
  /// // Minimal capabilities - only chat with static models
  /// final basic = ProviderCapabilities(
  ///   supportsChat: true,
  ///   fallbackModels: ['gpt-4'],
  /// );
  ///
  /// // Full-featured provider with dynamic model discovery
  /// final advanced = ProviderCapabilities(
  ///   supportsChat: true,
  ///   supportsEmbedding: true,
  ///   supportsImageGeneration: true,
  ///   supportsTTS: true,
  ///   supportsSTT: true,
  ///   supportsStreaming: true,
  ///   fallbackModels: ['gpt-4', 'gpt-3.5-turbo'],
  ///   dynamicModels: true, // Enable dynamic fetching
  /// );
  /// ```
  ProviderCapabilities({
    this.supportsChat = false,
    this.supportsEmbedding = false,
    this.supportsImageGeneration = false,
    this.supportsTTS = false,
    this.supportsSTT = false,
    this.supportsVideoGeneration = false,
    this.supportsVideoAnalysis = false,
    this.supportsStreaming = false,
    List<String>? fallbackModels,
    this.dynamicModels = false,
  }) : fallbackModels = fallbackModels ?? const [];

  /// Updates the cached models from dynamic fetch.
  ///
  /// This method should be called after successfully fetching models from
  /// the provider's API. The models will be cached for [cacheTTL] duration.
  ///
  /// **Parameters:**
  /// - [models]: List of model IDs fetched from the provider's API
  ///
  /// **Example:**
  /// ```dart
  /// final models = await provider.fetchAvailableModels();
  /// capabilities.updateModels(models);
  /// ```
  void updateModels(List<String> models) {
    _cachedModels = List<String>.unmodifiable(models);
    _cacheTimestamp = DateTime.now();
  }

  /// Clears the cached models, forcing a refresh on next access.
  ///
  /// Useful for forcing a refresh of models or when cache becomes invalid.
  void clearCache() {
    _cachedModels = null;
    _cacheTimestamp = null;
  }

  /// Checks if the cache is still valid.
  ///
  /// Returns true if cached models exist and haven't expired.
  bool _isCacheValid() {
    if (_cacheTimestamp == null || _cachedModels == null) {
      return false;
    }
    return DateTime.now().difference(_cacheTimestamp!) < _cacheTTL;
  }

  /// Gets the cache TTL for dynamically fetched models.
  static Duration get cacheTTL => _cacheTTL;

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
      supportsVideoGeneration: json['supportsVideoGeneration'] as bool? ??
          json['supports_video_generation'] as bool? ??
          false,
      supportsVideoAnalysis: json['supportsVideoAnalysis'] as bool? ??
          json['supports_video_analysis'] as bool? ??
          false,
      supportsStreaming: json['supportsStreaming'] as bool? ??
          json['supports_streaming'] as bool? ??
          false,
      fallbackModels:
          (json['fallbackModels'] as List<dynamic>?)?.cast<String>() ??
              (json['fallback_models'] as List<dynamic>?)?.cast<String>() ??
              (json['supportedModels'] as List<dynamic>?)?.cast<String>() ??
              (json['supported_models'] as List<dynamic>?)?.cast<String>() ??
              const [],
      dynamicModels: json['dynamicModels'] as bool? ??
          json['dynamic_models'] as bool? ??
          false,
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
      'supportsVideoGeneration': supportsVideoGeneration,
      'supportsVideoAnalysis': supportsVideoAnalysis,
      'supportsStreaming': supportsStreaming,
      'supportedModels':
          supportedModels, // Current models (dynamic or fallback)
      'fallbackModels': fallbackModels,
      'dynamicModels': dynamicModels,
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
    bool? supportsVideoGeneration,
    bool? supportsVideoAnalysis,
    bool? supportsStreaming,
    List<String>? fallbackModels,
    bool? dynamicModels,
  }) {
    return ProviderCapabilities(
      supportsChat: supportsChat ?? this.supportsChat,
      supportsEmbedding: supportsEmbedding ?? this.supportsEmbedding,
      supportsImageGeneration:
          supportsImageGeneration ?? this.supportsImageGeneration,
      supportsTTS: supportsTTS ?? this.supportsTTS,
      supportsSTT: supportsSTT ?? this.supportsSTT,
      supportsVideoGeneration:
          supportsVideoGeneration ?? this.supportsVideoGeneration,
      supportsVideoAnalysis:
          supportsVideoAnalysis ?? this.supportsVideoAnalysis,
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      fallbackModels: fallbackModels ?? this.fallbackModels,
      dynamicModels: dynamicModels ?? this.dynamicModels,
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
        other.supportsVideoGeneration == supportsVideoGeneration &&
        other.supportsVideoAnalysis == supportsVideoAnalysis &&
        other.supportsStreaming == supportsStreaming &&
        _listEquals(other.supportedModels, supportedModels) &&
        _listEquals(other.fallbackModels, fallbackModels) &&
        other.dynamicModels == dynamicModels;
  }

  @override
  int get hashCode {
    return Object.hash(
      supportsChat,
      supportsEmbedding,
      supportsImageGeneration,
      supportsTTS,
      supportsSTT,
      supportsVideoGeneration,
      supportsVideoAnalysis,
      supportsStreaming,
      Object.hashAll(supportedModels),
      Object.hashAll(fallbackModels),
      dynamicModels,
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
    if (supportsVideoGeneration) capabilities.add('Video Gen');
    if (supportsVideoAnalysis) capabilities.add('Video Analysis');
    if (supportsStreaming) capabilities.add('Streaming');

    final modelsInfo = supportedModels.isEmpty
        ? 'no models'
        : '${supportedModels.length} model(s)';
    final dynamicInfo = dynamicModels ? ' [dynamic]' : '';

    return 'ProviderCapabilities('
        '${capabilities.isEmpty ? 'none' : capabilities.join(', ')}, '
        '$modelsInfo$dynamicInfo)';
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
