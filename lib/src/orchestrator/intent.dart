/// Represents the detected intent of a user request.
///
/// The intent determines what operation the user wants to perform:
/// - Chat/text generation
/// - Image generation
/// - Embedding generation
/// - Other operations (TTS, STT, etc.)
///
/// **Example usage:**
/// ```dart
/// final intent = Intent.chat(confidence: 0.95);
/// print('Intent: ${intent.type}, Confidence: ${intent.confidence}');
/// ```
class Intent {
  /// The type of intent detected.
  ///
  /// Common values: 'chat', 'image_generation', 'embedding', 'tts', 'stt'
  final String type;

  /// Confidence score for the detected intent (0.0 to 1.0).
  ///
  /// Higher values indicate higher confidence in the detection.
  /// Values below 0.5 may indicate ambiguous requests.
  final double confidence;

  /// The capability name that matches this intent.
  ///
  /// Used for provider capability matching:
  /// - 'chat' → 'chat'
  /// - 'image_generation' → 'image'
  /// - 'embedding' → 'embedding'
  /// - 'tts' → 'tts'
  /// - 'stt' → 'stt'
  final String capability;

  /// Optional metadata about the detected intent.
  ///
  /// Can contain additional information like detected keywords,
  /// suggested models, or provider hints.
  final Map<String, dynamic>? metadata;

  /// Creates a new [Intent] instance.
  ///
  /// [type] and [capability] are required. [confidence] defaults to 1.0.
  Intent({
    required this.type,
    required this.capability,
    this.confidence = 1.0,
    this.metadata,
  })  : assert(confidence >= 0.0 && confidence <= 1.0,
            'confidence must be between 0.0 and 1.0'),
        assert(type.isNotEmpty, 'type must not be empty'),
        assert(capability.isNotEmpty, 'capability must not be empty');

  /// Creates an intent for chat/text generation.
  ///
  /// This is the default intent for most conversational requests.
  factory Intent.chat({
    double confidence = 1.0,
    Map<String, dynamic>? metadata,
  }) {
    return Intent(
      type: 'chat',
      capability: 'chat',
      confidence: confidence,
      metadata: metadata,
    );
  }

  /// Creates an intent for image generation.
  ///
  /// Used when the user wants to generate images from text prompts.
  factory Intent.imageGeneration({
    double confidence = 1.0,
    Map<String, dynamic>? metadata,
  }) {
    return Intent(
      type: 'image_generation',
      capability: 'image',
      confidence: confidence,
      metadata: metadata,
    );
  }

  /// Creates an intent for embedding generation.
  ///
  /// Used when the user wants to generate embeddings from text.
  factory Intent.embedding({
    double confidence = 1.0,
    Map<String, dynamic>? metadata,
  }) {
    return Intent(
      type: 'embedding',
      capability: 'embedding',
      confidence: confidence,
      metadata: metadata,
    );
  }

  /// Creates an intent for text-to-speech.
  ///
  /// Used when the user wants to convert text to speech.
  factory Intent.tts({
    double confidence = 1.0,
    Map<String, dynamic>? metadata,
  }) {
    return Intent(
      type: 'tts',
      capability: 'tts',
      confidence: confidence,
      metadata: metadata,
    );
  }

  /// Creates an intent for speech-to-text.
  ///
  /// Used when the user wants to convert speech to text.
  factory Intent.stt({
    double confidence = 1.0,
    Map<String, dynamic>? metadata,
  }) {
    return Intent(
      type: 'stt',
      capability: 'stt',
      confidence: confidence,
      metadata: metadata,
    );
  }

  @override
  String toString() {
    return 'Intent(type: $type, capability: $capability, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Intent &&
        other.type == type &&
        other.capability == capability &&
        (other.confidence - confidence).abs() < 0.001 &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      capability,
      (confidence * 1000).round(),
      metadata,
    );
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
