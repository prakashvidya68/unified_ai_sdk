/// Represents a request to convert text to speech (TTS).
///
/// Text-to-speech requests convert written text into spoken audio using
/// AI voice models. This model standardizes TTS requests across different
/// AI providers like OpenAI, Google, Azure, etc.
///
/// **Example usage:**
/// ```dart
/// final request = TtsRequest(
///   text: 'Hello, how are you today?',
///   model: 'tts-1',
///   voice: 'alloy',
///   speed: 1.0,
/// );
///
/// final response = await ai.tts(request: request);
/// // Use response.bytes to play audio or save to file
/// ```
class TtsRequest {
  /// The text to convert to speech.
  ///
  /// This is the main input that will be spoken by the TTS model.
  /// Should not be empty. Some providers have limits on text length.
  final String text;

  /// Optional model identifier to use for text-to-speech generation.
  ///
  /// If not specified, the provider will use its default TTS model.
  /// Examples: "tts-1", "tts-1-hd", "google-tts", "azure-tts"
  final String? model;

  /// Optional voice identifier to use for speech generation.
  ///
  /// Different providers offer different voices. Common values:
  /// - OpenAI: "alloy", "echo", "fable", "onyx", "nova", "shimmer"
  /// - Google: "en-US-Standard-A", "en-US-Wavenet-D"
  /// - Azure: "en-US-AriaNeural", "en-US-GuyNeural"
  final String? voice;

  /// Optional speed multiplier for speech playback.
  ///
  /// Controls the speed at which the text is spoken. Typically ranges
  /// from 0.25 (very slow) to 4.0 (very fast). Default is usually 1.0.
  /// Some providers may use different ranges or units.
  final double? speed;

  /// Optional provider-specific configuration options.
  ///
  /// Allows passing provider-specific parameters that aren't part of the
  /// standard API. Keys should be provider IDs (e.g., "openai", "google").
  ///
  /// **Example:**
  /// ```dart
  /// TtsRequest(
  ///   text: 'Hello',
  ///   providerOptions: {
  ///     'openai': {'response_format': 'mp3'},
  ///     'google': {'audio_encoding': 'MP3', 'pitch': 0.0},
  ///   },
  /// )
  /// ```
  final Map<String, Map<String, dynamic>>? providerOptions;

  /// Creates a new [TtsRequest] instance.
  ///
  /// [text] is required and must not be empty. All other fields are optional.
  TtsRequest({
    required this.text,
    this.model,
    this.voice,
    this.speed,
    this.providerOptions,
  }) : assert(text.isNotEmpty, 'text must not be empty');

  /// Converts this [TtsRequest] to a JSON map.
  ///
  /// The resulting map is compatible with most AI provider APIs.
  /// Only non-null optional fields are included in the output.
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "text": "Hello, world!",
  ///   "model": "tts-1",
  ///   "voice": "alloy",
  ///   "speed": 1.0
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (model != null) 'model': model,
      if (voice != null) 'voice': voice,
      if (speed != null) 'speed': speed,
      if (providerOptions != null) 'provider_options': providerOptions,
    };
  }

  /// Creates a [TtsRequest] instance from a JSON map.
  ///
  /// Parses the JSON representation of a TTS request into a [TtsRequest] object.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "text": "Hello, world!",
  ///   "model": "tts-1",
  ///   "voice": "alloy",
  ///   "speed": 1.0
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory TtsRequest.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String?;
    if (text == null || text.isEmpty) {
      throw const FormatException('Missing or empty required field: text');
    }

    return TtsRequest(
      text: text,
      model: json['model'] as String?,
      voice: json['voice'] as String?,
      speed: (json['speed'] as num?)?.toDouble(),
      providerOptions: json['provider_options'] as Map<String, Map<String, dynamic>>?,
    );
  }

  /// Creates a copy of this [TtsRequest] with the given fields replaced.
  ///
  /// Returns a new [TtsRequest] instance with the same values as this one,
  /// except for the fields explicitly provided.
  TtsRequest copyWith({
    String? text,
    Object? model = _undefined,
    String? voice,
    double? speed,
    Map<String, Map<String, dynamic>>? providerOptions,
  }) {
    return TtsRequest(
      text: text ?? this.text,
      model: model == _undefined ? this.model : model as String?,
      voice: voice ?? this.voice,
      speed: speed ?? this.speed,
      providerOptions: providerOptions ?? this.providerOptions,
    );
  }

  static const _undefined = Object();

  @override
  String toString() {
    return 'TtsRequest(text: ${text.length > 50 ? "${text.substring(0, 50)}..." : text}${model != null ? ", model: $model" : ""}${voice != null ? ", voice: $voice" : ""}${speed != null ? ", speed: $speed" : ""}${providerOptions != null ? ", providerOptions: ..." : ""})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TtsRequest &&
        other.text == text &&
        other.model == model &&
        other.voice == voice &&
        other.speed == speed &&
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
    return Object.hash(text, model, voice, speed, providerOptionsHash);
  }

  /// Helper method to compare maps for equality.
  bool _mapEquals(
      Map<String, Map<String, dynamic>>? a,
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

