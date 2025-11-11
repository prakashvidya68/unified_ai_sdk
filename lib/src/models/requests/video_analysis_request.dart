/// Represents a request to analyze a video.
///
/// Video analysis requests analyze existing videos to extract information
/// such as objects, scenes, actions, text, or other insights. This model
/// standardizes video analysis requests across different AI providers.
///
/// **Example usage:**
/// ```dart
/// final request = VideoAnalysisRequest(
///   videoUrl: 'https://example.com/video.mp4',
///   features: ['objects', 'scenes', 'text'],
/// );
///
/// final response = await ai.analyzeVideo(request: request);
/// print('Detected objects: ${response.objects}');
/// ```
class VideoAnalysisRequest {
  /// URL of the video to analyze.
  ///
  /// This should be a publicly accessible URL to the video file.
  /// Some providers may also support base64-encoded video data.
  final String? videoUrl;

  /// Base64-encoded video data.
  ///
  /// Alternative to [videoUrl] for providing video data directly.
  /// At least one of [videoUrl] or [videoBase64] must be provided.
  final String? videoBase64;

  /// List of features to extract from the video.
  ///
  /// Common features:
  /// - "objects" - Detect objects in the video
  /// - "scenes" - Identify scenes and settings
  /// - "actions" - Detect actions and movements
  /// - "text" - Extract text from the video
  /// - "labels" - Generate descriptive labels
  /// - "moderation" - Content moderation checks
  ///
  /// If not specified, provider will use default features.
  final List<String>? features;

  /// Optional model identifier to use for video analysis.
  ///
  /// If not specified, the provider will use its default video analysis model.
  /// Examples: "video-intelligence", "rekognition-video"
  final String? model;

  /// Optional language for text extraction and labels.
  ///
  /// ISO-639-1 format (e.g., "en", "es", "fr")
  /// Defaults to provider-specific default if not specified.
  final String? language;

  /// Optional confidence threshold for detections.
  ///
  /// Values between 0.0 and 1.0. Only detections above this threshold
  /// will be included in the response. Defaults to provider-specific default.
  final double? confidenceThreshold;

  /// Optional provider-specific configuration options.
  ///
  /// Allows passing provider-specific parameters that aren't part of the
  /// standard API. Keys should be provider IDs (e.g., "google", "amazon").
  ///
  /// **Example:**
  /// ```dart
  /// VideoAnalysisRequest(
  ///   videoUrl: 'https://example.com/video.mp4',
  ///   providerOptions: {
  ///     'google': {'segment_config': {...}},
  ///     'amazon': {'min_confidence': 0.8},
  ///   },
  /// )
  /// ```
  final Map<String, Map<String, dynamic>>? providerOptions;

  /// Creates a new [VideoAnalysisRequest] instance.
  ///
  /// At least one of [videoUrl] or [videoBase64] must be provided.
  VideoAnalysisRequest({
    this.videoUrl,
    this.videoBase64,
    this.features,
    this.model,
    this.language,
    this.confidenceThreshold,
    this.providerOptions,
  }) : assert(
          videoUrl != null || videoBase64 != null,
          'Either videoUrl or videoBase64 must be provided',
        ),
        assert(
          videoUrl == null || videoUrl.isNotEmpty,
          'videoUrl must not be empty if provided',
        ),
        assert(
          videoBase64 == null || videoBase64.isNotEmpty,
          'videoBase64 must not be empty if provided',
        );

  /// Converts this [VideoAnalysisRequest] to a JSON map.
  ///
  /// The resulting map is compatible with most AI provider APIs.
  /// Only non-null optional fields are included in the output.
  Map<String, dynamic> toJson() {
    return {
      if (videoUrl != null) 'video_url': videoUrl,
      if (videoBase64 != null) 'video_base64': videoBase64,
      if (features != null) 'features': features,
      if (model != null) 'model': model,
      if (language != null) 'language': language,
      if (confidenceThreshold != null) 'confidence_threshold': confidenceThreshold,
      if (providerOptions != null) 'provider_options': providerOptions,
    };
  }

  /// Creates a [VideoAnalysisRequest] instance from a JSON map.
  ///
  /// Parses the JSON representation of a video analysis request into a
  /// [VideoAnalysisRequest] object.
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory VideoAnalysisRequest.fromJson(Map<String, dynamic> json) {
    final videoUrl = json['video_url'] as String? ?? json['videoUrl'] as String?;
    final videoBase64 = json['video_base64'] as String? ?? json['videoBase64'] as String?;

    if (videoUrl == null && videoBase64 == null) {
      throw const FormatException(
        'Either video_url or video_base64 must be provided',
      );
    }

    return VideoAnalysisRequest(
      videoUrl: videoUrl,
      videoBase64: videoBase64,
      features: json['features'] != null
          ? (json['features'] as List).map((e) => e.toString()).toList()
          : null,
      model: json['model'] as String?,
      language: json['language'] as String?,
      confidenceThreshold: (json['confidence_threshold'] as num?)?.toDouble() ??
          (json['confidenceThreshold'] as num?)?.toDouble(),
      providerOptions:
          json['provider_options'] as Map<String, Map<String, dynamic>>?,
    );
  }

  /// Creates a copy of this [VideoAnalysisRequest] with the given fields replaced.
  VideoAnalysisRequest copyWith({
    String? videoUrl,
    Object? videoBase64 = _undefined,
    List<String>? features,
    Object? model = _undefined,
    String? language,
    double? confidenceThreshold,
    Map<String, Map<String, dynamic>>? providerOptions,
  }) {
    return VideoAnalysisRequest(
      videoUrl: videoUrl ?? this.videoUrl,
      videoBase64: videoBase64 == _undefined ? this.videoBase64 : videoBase64 as String?,
      features: features ?? this.features,
      model: model == _undefined ? this.model : model as String?,
      language: language ?? this.language,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      providerOptions: providerOptions ?? this.providerOptions,
    );
  }

  static const _undefined = Object();

  @override
  String toString() {
    return 'VideoAnalysisRequest(${videoUrl != null ? "videoUrl: ..." : "videoBase64: ..."}${features != null ? ", features: $features" : ""}${model != null ? ", model: $model" : ""}${language != null ? ", language: $language" : ""}${confidenceThreshold != null ? ", confidenceThreshold: $confidenceThreshold" : ""}${providerOptions != null ? ", providerOptions: ..." : ""})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoAnalysisRequest &&
        other.videoUrl == videoUrl &&
        other.videoBase64 == videoBase64 &&
        _listEquals(other.features, features) &&
        other.model == model &&
        other.language == language &&
        other.confidenceThreshold == confidenceThreshold &&
        _mapEquals(other.providerOptions, providerOptions);
  }

  @override
  int get hashCode {
    int featuresHash = 0;
    if (features != null) {
      for (final feature in features!) {
        featuresHash = Object.hash(featuresHash, feature);
      }
    }
    int providerOptionsHash = 0;
    if (providerOptions != null) {
      final opts = providerOptions!;
      for (final key in opts.keys) {
        providerOptionsHash = Object.hash(providerOptionsHash, key, opts[key]);
      }
    }
    return Object.hash(
      videoUrl,
      videoBase64,
      featuresHash,
      model,
      language,
      confidenceThreshold,
      providerOptionsHash,
    );
  }

  /// Helper method to compare lists for equality.
  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
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

