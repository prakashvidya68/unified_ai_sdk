import 'dart:typed_data';

/// Represents a request to convert speech to text (STT/transcription).
///
/// Speech-to-text requests convert audio recordings into written text using
/// AI transcription models. This model standardizes STT requests across different
/// AI providers like OpenAI Whisper, Google Speech-to-Text, Azure Speech, etc.
///
/// **Example usage:**
/// ```dart
/// final audioBytes = File('recording.mp3').readAsBytesSync();
/// final request = SttRequest(
///   audio: Uint8List.fromList(audioBytes),
///   model: 'whisper-1',
///   language: 'en',
///   prompt: 'Technical terms: API, SDK, HTTP',
/// );
///
/// final response = await ai.stt(request: request);
/// print(response.text);
/// ```
class SttRequest {
  /// The audio data to transcribe.
  ///
  /// Audio should be in a format supported by the provider (typically
  /// MP3, WAV, FLAC, M4A, or WebM). The format is usually auto-detected
  /// from the data or specified via providerOptions.
  final Uint8List audio;

  /// Optional model identifier to use for speech-to-text transcription.
  ///
  /// If not specified, the provider will use its default STT model.
  /// Examples: "whisper-1", "google-speech-v2", "azure-speech"
  final String? model;

  /// Optional language code for the audio content.
  ///
  /// Specifies the language of the audio to improve accuracy. Use ISO 639-1
  /// language codes (e.g., "en", "es", "fr", "de", "ja", "zh").
  /// If not specified, the provider will attempt to auto-detect the language.
  final String? language;

  /// Optional prompt to guide the transcription.
  ///
  /// Helps the model with proper capitalization, punctuation, and handling
  /// of specific terminology, names, or technical terms that might appear
  /// in the audio. Useful for domain-specific content.
  final String? prompt;

  /// Optional provider-specific configuration options.
  ///
  /// Allows passing provider-specific parameters that aren't part of the
  /// standard API. Keys should be provider IDs (e.g., "openai", "google").
  ///
  /// **Example:**
  /// ```dart
  /// SttRequest(
  ///   audio: audioBytes,
  ///   providerOptions: {
  ///     'openai': {'response_format': 'verbose_json', 'temperature': 0.0},
  ///     'google': {'encoding': 'LINEAR16', 'sample_rate_hertz': 16000},
  ///   },
  /// )
  /// ```
  final Map<String, Map<String, dynamic>>? providerOptions;

  /// Creates a new [SttRequest] instance.
  ///
  /// [audio] is required and must not be empty. All other fields are optional.
  SttRequest({
    required this.audio,
    this.model,
    this.language,
    this.prompt,
    this.providerOptions,
  }) : assert(audio.isNotEmpty, 'audio must not be empty');

  /// Converts this [SttRequest] to a JSON map.
  ///
  /// Note: The [audio] field is not included in the JSON output as it should
  /// be sent as binary data in the HTTP request body (multipart/form-data).
  /// Only metadata fields are included in the JSON.
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "model": "whisper-1",
  ///   "language": "en",
  ///   "prompt": "Technical terms: API, SDK"
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      if (model != null) 'model': model,
      if (language != null) 'language': language,
      if (prompt != null) 'prompt': prompt,
      if (providerOptions != null) 'provider_options': providerOptions,
    };
  }

  /// Creates an [SttRequest] instance from a JSON map.
  ///
  /// Note: The [audio] field must be provided separately as it cannot be
  /// serialized in JSON. This method is primarily useful for metadata only.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "model": "whisper-1",
  ///   "language": "en",
  ///   "prompt": "Technical terms"
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid.
  factory SttRequest.fromJson(Map<String, dynamic> json, {Uint8List? audio}) {
    return SttRequest(
      audio: audio ?? Uint8List(0),
      model: json['model'] as String?,
      language: json['language'] as String?,
      prompt: json['prompt'] as String?,
      providerOptions: json['provider_options'] as Map<String, Map<String, dynamic>>?,
    );
  }

  /// Creates a copy of this [SttRequest] with the given fields replaced.
  ///
  /// Returns a new [SttRequest] instance with the same values as this one,
  /// except for the fields explicitly provided.
  SttRequest copyWith({
    Uint8List? audio,
    Object? model = _undefined,
    String? language,
    String? prompt,
    Map<String, Map<String, dynamic>>? providerOptions,
  }) {
    return SttRequest(
      audio: audio ?? this.audio,
      model: model == _undefined ? this.model : model as String?,
      language: language ?? this.language,
      prompt: prompt ?? this.prompt,
      providerOptions: providerOptions ?? this.providerOptions,
    );
  }

  static const _undefined = Object();

  @override
  String toString() {
    final promptStr = prompt != null
        ? (prompt!.length > 30 ? '${prompt!.substring(0, 30)}...' : prompt!)
        : '';
    return 'SttRequest(audio: ${audio.length} bytes${model != null ? ", model: $model" : ""}${language != null ? ", language: $language" : ""}${prompt != null ? ", prompt: $promptStr" : ""}${providerOptions != null ? ", providerOptions: ..." : ""})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SttRequest &&
        _listEquals(other.audio, audio) &&
        other.model == model &&
        other.language == language &&
        other.prompt == prompt &&
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
      Object.hashAll(audio),
      model,
      language,
      prompt,
      providerOptionsHash,
    );
  }

  /// Helper method to compare Uint8List for equality.
  bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

