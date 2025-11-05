import 'dart:convert';
import 'dart:typed_data';

/// Represents a complete text-to-speech (TTS) response from an AI provider.
///
/// This is the primary response type returned by [tts()] operations.
/// It contains the generated audio data as bytes, along with metadata
/// about the format and model used.
///
/// **Example usage:**
/// ```dart
/// final response = await ai.tts(request: ttsRequest);
/// File('output.mp3').writeAsBytesSync(response.bytes);
/// print('Audio format: ${response.format}');
/// ```
class AudioResponse {
  /// The generated audio data as bytes.
  ///
  /// Contains the actual audio file data (e.g., MP3, WAV, OGG) that can be
  /// saved to a file or played directly. The format is indicated by [format].
  final Uint8List bytes;

  /// The audio format/codec of the generated audio.
  ///
  /// Common formats: "mp3", "wav", "ogg", "opus", "pcm", "flac"
  /// This indicates how the bytes should be interpreted and played.
  final String format;

  /// The model identifier used for this audio generation.
  ///
  /// Examples: "tts-1", "tts-1-hd", "google-tts", "azure-tts"
  final String model;

  /// The provider that generated this response.
  ///
  /// Examples: "openai", "google", "azure"
  final String provider;

  /// Creates a new [AudioResponse] instance.
  ///
  /// [bytes], [format], [model], and [provider] are all required.
  AudioResponse({
    required this.bytes,
    required this.format,
    required this.model,
    required this.provider,
  }) : assert(bytes.isNotEmpty, 'bytes must not be empty'),
       assert(format.isNotEmpty, 'format must not be empty');

  /// Converts this [AudioResponse] to a JSON map.
  ///
  /// Note: The [bytes] field is encoded as base64 in the JSON output
  /// since binary data cannot be directly represented in JSON.
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "bytes": "base64encodedaudiobytes...",
  ///   "format": "mp3",
  ///   "model": "tts-1",
  ///   "provider": "openai"
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'bytes': base64Encode(bytes),
      'format': format,
      'model': model,
      'provider': provider,
    };
  }

  /// Creates an [AudioResponse] instance from a JSON map.
  ///
  /// Parses the JSON representation of an audio response into an
  /// [AudioResponse] object. The [bytes] field is decoded from base64.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "bytes": "base64encodedaudiobytes...",
  ///   "format": "mp3",
  ///   "model": "tts-1",
  ///   "provider": "openai"
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory AudioResponse.fromJson(Map<String, dynamic> json) {
    final bytesBase64 = json['bytes'] as String?;
    if (bytesBase64 == null) {
      throw const FormatException('Missing required field: bytes');
    }

    Uint8List bytes;
    try {
      bytes = base64Decode(bytesBase64);
    } catch (e) {
      throw FormatException('Invalid base64 encoding for bytes field', e);
    }

    final format = json['format'] as String?;
    if (format == null || format.isEmpty) {
      throw const FormatException('Missing or empty required field: format');
    }

    return AudioResponse(
      bytes: bytes,
      format: format,
      model: json['model'] as String,
      provider: json['provider'] as String,
    );
  }

  /// Creates a copy of this [AudioResponse] with the given fields replaced.
  AudioResponse copyWith({
    Uint8List? bytes,
    String? format,
    String? model,
    String? provider,
  }) {
    return AudioResponse(
      bytes: bytes ?? this.bytes,
      format: format ?? this.format,
      model: model ?? this.model,
      provider: provider ?? this.provider,
    );
  }

  @override
  String toString() {
    return 'AudioResponse(bytes: ${bytes.length} bytes, format: $format, model: $model, provider: $provider)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioResponse &&
        _listEquals(other.bytes, bytes) &&
        other.format == format &&
        other.model == model &&
        other.provider == provider;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(bytes),
      format,
      model,
      provider,
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
}

