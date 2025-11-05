/// Represents a single generated image asset.
///
/// Each image in a response contains either a URL (for hosted images) or
/// base64-encoded data (for inline images), along with optional metadata
/// like dimensions and revised prompts.
///
/// **Example usage:**
/// ```dart
/// final asset = response.assets.first;
/// if (asset.url != null) {
///   print('Image URL: ${asset.url}');
/// } else if (asset.base64 != null) {
///   // Decode and display base64 image
/// }
/// ```
class ImageAsset {
  /// Optional URL where the generated image is hosted.
  ///
  /// If provided, this is a direct link to the generated image file.
  /// URLs are typically temporary and may expire after a certain period.
  /// Use this when you want to display or download the image directly.
  final String? url;

  /// Optional base64-encoded image data.
  ///
  /// If provided, this contains the image data encoded as a base64 string.
  /// Use this when you need the image data inline (e.g., for embedding
  /// in HTML or storing in a database). At least one of [url] or [base64]
  /// should be provided.
  final String? base64;

  /// Optional width of the generated image in pixels.
  ///
  /// May be provided by some providers to indicate the actual dimensions
  /// of the generated image, which may differ from the requested size.
  final int? width;

  /// Optional height of the generated image in pixels.
  ///
  /// May be provided by some providers to indicate the actual dimensions
  /// of the generated image, which may differ from the requested size.
  final int? height;

  /// Optional revised prompt used for image generation.
  ///
  /// Some providers (like DALL-E 3) automatically revise the user's prompt
  /// to improve image quality or add detail. This field contains the revised
  /// version if available.
  final String? revisedPrompt;

  /// Creates a new [ImageAsset] instance.
  ///
  /// At least one of [url] or [base64] should be provided, though this is
  /// not enforced to allow for flexibility with different providers.
  /// All other fields are optional.
  const ImageAsset({
    this.url,
    this.base64,
    this.width,
    this.height,
    this.revisedPrompt,
  });

  /// Converts this [ImageAsset] to a JSON map.
  ///
  /// Only non-null fields are included in the output.
  Map<String, dynamic> toJson() {
    return {
      if (url != null) 'url': url,
      if (base64 != null) 'base64': base64,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (revisedPrompt != null) 'revised_prompt': revisedPrompt,
    };
  }

  /// Creates an [ImageAsset] instance from a JSON map.
  ///
  /// Parses the JSON representation of an image asset into an [ImageAsset] object.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "url": "https://example.com/image.png",
  ///   "width": 1024,
  ///   "height": 1024,
  ///   "revised_prompt": "A beautiful sunset over the ocean with vibrant colors"
  /// }
  /// ```
  factory ImageAsset.fromJson(Map<String, dynamic> json) {
    return ImageAsset(
      url: json['url'] as String?,
      base64: json['base64'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      revisedPrompt:
          json['revised_prompt'] as String? ?? json['revisedPrompt'] as String?,
    );
  }

  /// Creates a copy of this [ImageAsset] with the given fields replaced.
  ImageAsset copyWith({
    String? url,
    String? base64,
    int? width,
    int? height,
    String? revisedPrompt,
  }) {
    return ImageAsset(
      url: url ?? this.url,
      base64: base64 ?? this.base64,
      width: width ?? this.width,
      height: height ?? this.height,
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
    if (revisedPrompt != null) parts.add('revisedPrompt: ...');
    return 'ImageAsset(${parts.join(", ")})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageAsset &&
        other.url == url &&
        other.base64 == base64 &&
        other.width == width &&
        other.height == height &&
        other.revisedPrompt == revisedPrompt;
  }

  @override
  int get hashCode {
    return Object.hash(url, base64, width, height, revisedPrompt);
  }
}

/// Represents a complete image generation response from an AI provider.
///
/// This is the primary response type returned by [generateImage()] operations.
/// It contains the generated image assets, model information, and metadata
/// about the response.
///
/// **Example usage:**
/// ```dart
/// final response = await ai.generateImage(request: imageRequest);
/// for (final asset in response.assets) {
///   if (asset.url != null) {
///     print('Generated image: ${asset.url}');
///   }
/// }
/// ```
class ImageResponse {
  /// List of generated image assets.
  ///
  /// Contains one or more images generated based on the request. Typically
  /// contains [n] images from the request (or 1 if not specified).
  final List<ImageAsset> assets;

  /// The model identifier used for this image generation.
  ///
  /// Examples: "dall-e-3", "dall-e-2", "stable-diffusion-xl"
  final String model;

  /// The provider that generated this response.
  ///
  /// Examples: "openai", "stability", "midjourney"
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

  /// Creates a new [ImageResponse] instance.
  ///
  /// [assets], [model], and [provider] are required.
  /// [timestamp] defaults to the current time if not provided.
  /// [metadata] is optional.
  ImageResponse({
    required this.assets,
    required this.model,
    required this.provider,
    DateTime? timestamp,
    this.metadata,
  })  : timestamp = timestamp ?? DateTime.now(),
        assert(assets.isNotEmpty, 'assets must not be empty');

  /// Converts this [ImageResponse] to a JSON map.
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

  /// Creates an [ImageResponse] instance from a JSON map.
  ///
  /// Parses the JSON representation of an image response into an
  /// [ImageResponse] object.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "assets": [{
  ///     "url": "https://example.com/image.png",
  ///     "width": 1024,
  ///     "height": 1024
  ///   }],
  ///   "model": "dall-e-3",
  ///   "provider": "openai"
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory ImageResponse.fromJson(Map<String, dynamic> json) {
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

    return ImageResponse(
      assets: assets
          .map((a) => ImageAsset.fromJson(a as Map<String, dynamic>))
          .toList(),
      model: json['model'] as String,
      provider: json['provider'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Creates a copy of this [ImageResponse] with the given fields replaced.
  ImageResponse copyWith({
    List<ImageAsset>? assets,
    String? model,
    String? provider,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ImageResponse(
      assets: assets ?? this.assets,
      model: model ?? this.model,
      provider: provider ?? this.provider,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ImageResponse(assets: ${assets.length}, model: $model, provider: $provider)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageResponse &&
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
  bool _listEquals(List<ImageAsset> a, List<ImageAsset> b) {
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
