/// Represents a single segment in a transcription response.
///
/// Some providers return transcriptions broken down into segments with
/// timing information. This model represents one such segment.
class TranscriptionSegment {
  /// The text content of this segment.
  final String text;

  /// The start time of this segment in seconds.
  ///
  /// Indicates when this segment begins in the original audio.
  final double start;

  /// The end time of this segment in seconds.
  ///
  /// Indicates when this segment ends in the original audio.
  final double end;

  /// Optional identifier for this segment.
  ///
  /// Some providers assign IDs to segments for reference.
  final int? id;

  /// Optional confidence score for this segment.
  ///
  /// Indicates the model's confidence in the transcription accuracy.
  /// Typically ranges from 0.0 to 1.0, where 1.0 is highest confidence.
  final double? confidence;

  /// Creates a new [TranscriptionSegment] instance.
  ///
  /// [text], [start], and [end] are required. [id] and [confidence] are optional.
  const TranscriptionSegment({
    required this.text,
    required this.start,
    required this.end,
    this.id,
    this.confidence,
  });

  /// Converts this [TranscriptionSegment] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'start': start,
      'end': end,
      if (id != null) 'id': id,
      if (confidence != null) 'confidence': confidence,
    };
  }

  /// Creates a [TranscriptionSegment] instance from a JSON map.
  factory TranscriptionSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptionSegment(
      text: json['text'] as String,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      id: json['id'] as int?,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  /// Creates a copy of this [TranscriptionSegment] with the given fields replaced.
  TranscriptionSegment copyWith({
    String? text,
    double? start,
    double? end,
    int? id,
    double? confidence,
  }) {
    return TranscriptionSegment(
      text: text ?? this.text,
      start: start ?? this.start,
      end: end ?? this.end,
      id: id ?? this.id,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() {
    return 'TranscriptionSegment(text: ${text.length > 30 ? "${text.substring(0, 30)}..." : text}, start: $start, end: $end${id != null ? ", id: $id" : ""}${confidence != null ? ", confidence: $confidence" : ""})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranscriptionSegment &&
        other.text == text &&
        (other.start - start).abs() < 0.001 &&
        (other.end - end).abs() < 0.001 &&
        other.id == id &&
        (other.confidence == null && confidence == null ||
            other.confidence != null &&
                confidence != null &&
                (other.confidence! - confidence!).abs() < 0.001);
  }

  @override
  int get hashCode {
    return Object.hash(text, start, end, id, confidence);
  }
}

/// Represents a complete speech-to-text (STT) transcription response from an AI provider.
///
/// This is the primary response type returned by [stt()] operations.
/// It contains the transcribed text, along with optional metadata like
/// language detection, duration, and segmented transcriptions.
///
/// **Example usage:**
/// ```dart
/// final response = await ai.stt(request: sttRequest);
/// print('Transcribed text: ${response.text}');
/// if (response.language != null) {
///   print('Detected language: ${response.language}');
/// }
/// ```
class TranscriptionResponse {
  /// The transcribed text from the audio.
  ///
  /// This is the main output - the full text transcription of the audio.
  /// Required and always present.
  final String text;

  /// Optional detected language code.
  ///
  /// Indicates the language that was detected in the audio (if auto-detection
  /// was used). Uses ISO 639-1 language codes (e.g., "en", "es", "fr").
  final String? language;

  /// Optional duration of the audio in seconds.
  ///
  /// Indicates the length of the original audio file that was transcribed.
  final double? duration;

  /// Optional list of transcription segments.
  ///
  /// Some providers return transcriptions broken down into segments with
  /// timing information. Each segment contains text, start time, end time,
  /// and optionally confidence scores.
  final List<TranscriptionSegment>? segments;

  /// The model identifier used for this transcription.
  ///
  /// Examples: "whisper-1", "google-speech-v2", "azure-speech"
  final String model;

  /// The provider that generated this response.
  ///
  /// Examples: "openai", "google", "azure"
  final String provider;

  /// Creates a new [TranscriptionResponse] instance.
  ///
  /// [text], [model], and [provider] are required.
  /// [language], [duration], and [segments] are optional.
  TranscriptionResponse({
    required this.text,
    this.language,
    this.duration,
    this.segments,
    required this.model,
    required this.provider,
  }) : assert(text.isNotEmpty, 'text must not be empty');

  /// Converts this [TranscriptionResponse] to a JSON map.
  ///
  /// The resulting map includes all response data in a provider-agnostic format.
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (language != null) 'language': language,
      if (duration != null) 'duration': duration,
      if (segments != null)
        'segments': segments!.map((s) => s.toJson()).toList(),
      'model': model,
      'provider': provider,
    };
  }

  /// Creates a [TranscriptionResponse] instance from a JSON map.
  ///
  /// Parses the JSON representation of a transcription response into a
  /// [TranscriptionResponse] object.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "text": "Hello, how are you?",
  ///   "language": "en",
  ///   "duration": 2.5,
  ///   "segments": [{
  ///     "text": "Hello, how are you?",
  ///     "start": 0.0,
  ///     "end": 2.5,
  ///     "confidence": 0.95
  ///   }],
  ///   "model": "whisper-1",
  ///   "provider": "openai"
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory TranscriptionResponse.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String?;
    if (text == null || text.isEmpty) {
      throw const FormatException('Missing or empty required field: text');
    }

    List<TranscriptionSegment>? segments;
    if (json['segments'] != null) {
      segments = (json['segments'] as List)
          .map((s) => TranscriptionSegment.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return TranscriptionResponse(
      text: text,
      language: json['language'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
      segments: segments,
      model: json['model'] as String,
      provider: json['provider'] as String,
    );
  }

  /// Creates a copy of this [TranscriptionResponse] with the given fields replaced.
  TranscriptionResponse copyWith({
    String? text,
    String? language,
    double? duration,
    List<TranscriptionSegment>? segments,
    String? model,
    String? provider,
  }) {
    return TranscriptionResponse(
      text: text ?? this.text,
      language: language ?? this.language,
      duration: duration ?? this.duration,
      segments: segments ?? this.segments,
      model: model ?? this.model,
      provider: provider ?? this.provider,
    );
  }

  @override
  String toString() {
    return 'TranscriptionResponse(text: ${text.length > 50 ? "${text.substring(0, 50)}..." : text}${language != null ? ", language: $language" : ""}${duration != null ? ", duration: $duration" : ""}${segments != null ? ", segments: ${segments!.length}" : ""}, model: $model, provider: $provider)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranscriptionResponse &&
        other.text == text &&
        other.language == language &&
        (other.duration == null && duration == null ||
            other.duration != null &&
                duration != null &&
                (other.duration! - duration!).abs() < 0.001) &&
        _listEquals(other.segments, segments) &&
        other.model == model &&
        other.provider == provider;
  }

  @override
  int get hashCode {
    int segmentsHash = 0;
    if (segments != null) {
      for (final segment in segments!) {
        segmentsHash = Object.hash(segmentsHash, segment);
      }
    }
    return Object.hash(
      text,
      language,
      duration,
      segmentsHash,
      model,
      provider,
    );
  }

  /// Helper method to compare lists for equality.
  bool _listEquals(
      List<TranscriptionSegment>? a, List<TranscriptionSegment>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
