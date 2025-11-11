/// Represents a request to generate videos from a text prompt.
///
/// Video generation requests convert text descriptions into videos using
/// AI models like Sora, Veo, or Grok Imagine. This model standardizes
/// video generation requests across different AI providers.
///
/// **Example usage:**
/// ```dart
/// final request = VideoRequest(
///   prompt: 'A beautiful sunset over the ocean with waves crashing',
///   duration: 10, // seconds
///   aspectRatio: '16:9',
/// );
///
/// final response = await ai.generateVideo(request: request);
/// final videoUrl = response.assets.first.url;
/// ```
class VideoRequest {
  /// The text prompt describing the video to generate.
  ///
  /// This is the main input that guides the video generation. Be specific
  /// and descriptive for best results. Some providers may return a
  /// revised prompt in the response.
  final String prompt;

  /// Optional model identifier to use for video generation.
  ///
  /// If not specified, the provider will use its default video generation model.
  /// Examples: "sora-2", "veo-3.1-generate", "grok-imagine-v0.9"
  final String? model;

  /// Optional duration of the video in seconds.
  ///
  /// Specifies how long the generated video should be. Typical ranges:
  /// - 5-10 seconds for most providers
  /// - Up to 60 seconds for some providers
  /// Defaults to provider-specific default if not specified.
  final int? duration;

  /// Optional aspect ratio for the generated video.
  ///
  /// Common values: "16:9", "9:16", "1:1", "4:3", "21:9"
  /// Defaults to provider-specific default if not specified.
  final String? aspectRatio;

  /// Optional frame rate for the generated video.
  ///
  /// Specifies frames per second (fps). Common values: 24, 30, 60
  /// Defaults to provider-specific default if not specified.
  final int? frameRate;

  /// Optional quality setting for the generated video.
  ///
  /// Quality settings vary by provider. Common values:
  /// - "standard" - Normal quality (faster, cheaper)
  /// - "hd" or "high" - High quality (slower, more expensive)
  /// - "4k" - Ultra high quality (slowest, most expensive)
  final String? quality;

  /// Optional seed for reproducible video generation.
  ///
  /// Using the same seed with the same prompt will generate the same video.
  /// Useful for testing and consistency.
  final int? seed;

  /// Optional provider-specific configuration options.
  ///
  /// Allows passing provider-specific parameters that aren't part of the
  /// standard API. Keys should be provider IDs (e.g., "openai", "google").
  ///
  /// **Example:**
  /// ```dart
  /// VideoRequest(
  ///   prompt: 'A cat playing',
  ///   providerOptions: {
  ///     'openai': {'response_format': 'url'},
  ///     'google': {'motion_bucket_id': 127},
  ///   },
  /// )
  /// ```
  final Map<String, Map<String, dynamic>>? providerOptions;

  /// Creates a new [VideoRequest] instance.
  ///
  /// [prompt] is required and must not be empty. All other fields are optional.
  VideoRequest({
    required this.prompt,
    this.model,
    this.duration,
    this.aspectRatio,
    this.frameRate,
    this.quality,
    this.seed,
    this.providerOptions,
  }) : assert(prompt.isNotEmpty, 'prompt must not be empty');

  /// Converts this [VideoRequest] to a JSON map.
  ///
  /// The resulting map is compatible with most AI provider APIs.
  /// Only non-null optional fields are included in the output.
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "prompt": "A beautiful sunset",
  ///   "model": "sora-2",
  ///   "duration": 10,
  ///   "aspect_ratio": "16:9",
  ///   "frame_rate": 30,
  ///   "quality": "hd"
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      if (model != null) 'model': model,
      if (duration != null) 'duration': duration,
      if (aspectRatio != null) 'aspect_ratio': aspectRatio,
      if (frameRate != null) 'frame_rate': frameRate,
      if (quality != null) 'quality': quality,
      if (seed != null) 'seed': seed,
      if (providerOptions != null) 'provider_options': providerOptions,
    };
  }

  /// Creates a [VideoRequest] instance from a JSON map.
  ///
  /// Parses the JSON representation of a video request into a [VideoRequest] object.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "prompt": "A beautiful sunset",
  ///   "duration": 10,
  ///   "aspect_ratio": "16:9"
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory VideoRequest.fromJson(Map<String, dynamic> json) {
    final prompt = json['prompt'] as String?;
    if (prompt == null || prompt.isEmpty) {
      throw const FormatException('Missing or empty required field: prompt');
    }

    return VideoRequest(
      prompt: prompt,
      model: json['model'] as String?,
      duration: json['duration'] as int?,
      aspectRatio: json['aspect_ratio'] as String? ?? json['aspectRatio'] as String?,
      frameRate: json['frame_rate'] as int? ?? json['frameRate'] as int?,
      quality: json['quality'] as String?,
      seed: json['seed'] as int?,
      providerOptions:
          json['provider_options'] as Map<String, Map<String, dynamic>>?,
    );
  }

  /// Creates a copy of this [VideoRequest] with the given fields replaced.
  ///
  /// Returns a new [VideoRequest] instance with the same values as this one,
  /// except for the fields explicitly provided.
  VideoRequest copyWith({
    String? prompt,
    Object? model = _undefined,
    int? duration,
    String? aspectRatio,
    int? frameRate,
    String? quality,
    int? seed,
    Map<String, Map<String, dynamic>>? providerOptions,
  }) {
    return VideoRequest(
      prompt: prompt ?? this.prompt,
      model: model == _undefined ? this.model : model as String?,
      duration: duration ?? this.duration,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      frameRate: frameRate ?? this.frameRate,
      quality: quality ?? this.quality,
      seed: seed ?? this.seed,
      providerOptions: providerOptions ?? this.providerOptions,
    );
  }

  static const _undefined = Object();

  @override
  String toString() {
    return 'VideoRequest(prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}${model != null ? ", model: $model" : ""}${duration != null ? ", duration: $duration" : ""}${aspectRatio != null ? ", aspectRatio: $aspectRatio" : ""}${frameRate != null ? ", frameRate: $frameRate" : ""}${quality != null ? ", quality: $quality" : ""}${seed != null ? ", seed: $seed" : ""}${providerOptions != null ? ", providerOptions: ..." : ""})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoRequest &&
        other.prompt == prompt &&
        other.model == model &&
        other.duration == duration &&
        other.aspectRatio == aspectRatio &&
        other.frameRate == frameRate &&
        other.quality == quality &&
        other.seed == seed &&
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
      prompt,
      model,
      duration,
      aspectRatio,
      frameRate,
      quality,
      seed,
      providerOptionsHash,
    );
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

