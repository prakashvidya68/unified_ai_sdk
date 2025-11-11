/// Represents a single generated video asset.
///
/// Each video in a response contains either a URL (for hosted videos) or
/// base64-encoded data (for inline videos), along with optional metadata
/// like dimensions, duration, and revised prompts.
///
/// **Example usage:**
/// ```dart
/// final asset = response.assets.first;
/// if (asset.url != null) {
///   print('Video URL: ${asset.url}');
/// } else if (asset.base64 != null) {
///   // Decode and display base64 video
/// }
/// ```
class VideoAsset {
  /// Optional URL where the generated video is hosted.
  ///
  /// If provided, this is a direct link to the generated video file.
  /// URLs are typically temporary and may expire after a certain period.
  /// Use this when you want to display or download the video directly.
  final String? url;

  /// Optional base64-encoded video data.
  ///
  /// If provided, this contains the video data encoded as a base64 string.
  /// Use this when you need the video data inline. At least one of [url] or [base64]
  /// should be provided.
  final String? base64;

  /// Optional width of the generated video in pixels.
  ///
  /// May be provided by some providers to indicate the actual dimensions
  /// of the generated video.
  final int? width;

  /// Optional height of the generated video in pixels.
  ///
  /// May be provided by some providers to indicate the actual dimensions
  /// of the generated video.
  final int? height;

  /// Optional duration of the video in seconds.
  ///
  /// The actual duration of the generated video, which may differ from
  /// the requested duration.
  final int? duration;

  /// Optional frame rate of the video (fps).
  ///
  /// The actual frame rate of the generated video.
  final int? frameRate;

  /// Optional revised prompt used for video generation.
  ///
  /// Some providers automatically revise the user's prompt to improve
  /// video quality or add detail. This field contains the revised version
  /// if available.
  final String? revisedPrompt;

  /// Creates a new [VideoAsset] instance.
  ///
  /// At least one of [url] or [base64] should be provided, though this is
  /// not enforced to allow for flexibility with different providers.
  /// All other fields are optional.
  const VideoAsset({
    this.url,
    this.base64,
    this.width,
    this.height,
    this.duration,
    this.frameRate,
    this.revisedPrompt,
  });

  /// Converts this [VideoAsset] to a JSON map.
  ///
  /// Only non-null fields are included in the output.
  Map<String, dynamic> toJson() {
    return {
      if (url != null) 'url': url,
      if (base64 != null) 'base64': base64,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      if (frameRate != null) 'frame_rate': frameRate,
      if (revisedPrompt != null) 'revised_prompt': revisedPrompt,
    };
  }

  /// Creates a [VideoAsset] instance from a JSON map.
  ///
  /// Parses the JSON representation of a video asset into a [VideoAsset] object.
  factory VideoAsset.fromJson(Map<String, dynamic> json) {
    return VideoAsset(
      url: json['url'] as String?,
      base64: json['base64'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: json['duration'] as int?,
      frameRate: json['frame_rate'] as int? ?? json['frameRate'] as int?,
      revisedPrompt:
          json['revised_prompt'] as String? ?? json['revisedPrompt'] as String?,
    );
  }

  /// Creates a copy of this [VideoAsset] with the given fields replaced.
  VideoAsset copyWith({
    String? url,
    String? base64,
    int? width,
    int? height,
    int? duration,
    int? frameRate,
    String? revisedPrompt,
  }) {
    return VideoAsset(
      url: url ?? this.url,
      base64: base64 ?? this.base64,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      frameRate: frameRate ?? this.frameRate,
      revisedPrompt: revisedPrompt ?? this.revisedPrompt,
    );
  }

  @override
  String toString() {
    final parts = <String>[];
    if (url != null) parts.add('url: ...');
    if (base64 != null) parts.add('base64: ...');
    if (width != null && height != null) {
      parts.add('${width}x$height');
    }
    if (duration != null) parts.add('${duration}s');
    if (frameRate != null) parts.add('${frameRate}fps');
    if (revisedPrompt != null) parts.add('revisedPrompt: ...');
    return 'VideoAsset(${parts.join(", ")})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoAsset &&
        other.url == url &&
        other.base64 == base64 &&
        other.width == width &&
        other.height == height &&
        other.duration == duration &&
        other.frameRate == frameRate &&
        other.revisedPrompt == revisedPrompt;
  }

  @override
  int get hashCode {
    return Object.hash(
      url,
      base64,
      width,
      height,
      duration,
      frameRate,
      revisedPrompt,
    );
  }
}

/// Represents a complete video generation response from an AI provider.
///
/// This is the primary response type returned by [generateVideo()] operations.
/// It contains the generated video assets, model information, and metadata
/// about the response.
///
/// **Example usage:**
/// ```dart
/// final response = await ai.generateVideo(request: videoRequest);
/// for (final asset in response.assets) {
///   if (asset.url != null) {
///     print('Generated video: ${asset.url}');
///   }
/// }
/// ```
class VideoResponse {
  /// List of generated video assets.
  ///
  /// Contains one or more videos generated based on the request.
  final List<VideoAsset> assets;

  /// The model identifier used for this video generation.
  ///
  /// Examples: "sora-2", "veo-3.1-generate", "grok-imagine-v0.9"
  final String model;

  /// The provider that generated this response.
  ///
  /// Examples: "openai", "google", "xai"
  final String provider;

  /// Timestamp when this response was created.
  ///
  /// Defaults to the current time if not specified. Useful for tracking
  /// response times and ordering responses.
  final DateTime timestamp;

  /// Optional metadata associated with this response.
  ///
  /// Can contain provider-specific fields, request IDs, or custom metadata
  /// that doesn't fit into the standard response structure.
  final Map<String, dynamic>? metadata;

  /// Creates a new [VideoResponse] instance.
  ///
  /// [assets], [model], and [provider] are required.
  /// [timestamp] defaults to the current time if not provided.
  /// [metadata] is optional.
  VideoResponse({
    required this.assets,
    required this.model,
    required this.provider,
    DateTime? timestamp,
    this.metadata,
  })  : timestamp = timestamp ?? DateTime.now(),
        assert(assets.isNotEmpty, 'assets must not be empty');

  /// Converts this [VideoResponse] to a JSON map.
  ///
  /// The resulting map includes all response data in a provider-agnostic format.
  Map<String, dynamic> toJson() {
    return {
      'assets': assets.map((a) => a.toJson()).toList(),
      'model': model,
      'provider': provider,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Creates a [VideoResponse] instance from a JSON map.
  ///
  /// Parses the JSON representation of a video response into a
  /// [VideoResponse] object.
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory VideoResponse.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'];
    if (assets == null) {
      throw const FormatException('Missing required field: assets');
    }
    if (assets is! List) {
      throw const FormatException('Field "assets" must be a List');
    }
    if (assets.isEmpty) {
      throw const FormatException('Field "assets" must not be empty');
    }

    return VideoResponse(
      assets: assets
          .map((a) => VideoAsset.fromJson(a as Map<String, dynamic>))
          .toList(),
      model: json['model'] as String,
      provider: json['provider'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Creates a copy of this [VideoResponse] with the given fields replaced.
  VideoResponse copyWith({
    List<VideoAsset>? assets,
    String? model,
    String? provider,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return VideoResponse(
      assets: assets ?? this.assets,
      model: model ?? this.model,
      provider: provider ?? this.provider,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'VideoResponse(assets: ${assets.length}, model: $model, provider: $provider)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoResponse &&
        _listEquals(other.assets, assets) &&
        other.model == model &&
        other.provider == provider &&
        other.timestamp.millisecondsSinceEpoch ==
            timestamp.millisecondsSinceEpoch &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    int assetsHash = 0;
    for (final asset in assets) {
      assetsHash = Object.hash(assetsHash, asset);
    }
    return Object.hash(
      assetsHash,
      model,
      provider,
      timestamp.millisecondsSinceEpoch,
      metadata,
    );
  }

  /// Helper method to compare lists for equality.
  bool _listEquals(List<VideoAsset> a, List<VideoAsset> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Helper method to compare maps for equality.
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

