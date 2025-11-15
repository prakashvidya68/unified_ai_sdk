import '../base_enums.dart';

/// Represents a request to generate images from a text prompt.
///
/// Image generation requests convert text descriptions into images using
/// AI models like DALL-E, Stable Diffusion, or Midjourney. This model
/// standardizes image generation requests across different AI providers.
///
/// **Example usage:**
/// ```dart
/// final request = ImageRequest(
///   prompt: 'A beautiful sunset over the ocean',
///   size: ImageSize.w1024h1024,
///   n: 2,
///   quality: 'hd',
/// );
///
/// final response = await ai.generateImage(request: request);
/// final firstImage = response.assets.first.url;
/// ```
class ImageRequest {
  /// The text prompt describing the image to generate.
  ///
  /// This is the main input that guides the image generation. Be specific
  /// and descriptive for best results. Some providers may return a
  /// revised prompt in the response.
  final String prompt;

  /// Optional model identifier to use for image generation.
  ///
  /// If not specified, the provider will use its default image generation model.
  /// Examples: "dall-e-3", "dall-e-2", "stable-diffusion-xl", "midjourney-v6"
  final String? model;

  /// Optional size/dimensions for the generated image.
  ///
  /// Specifies the output dimensions. Different providers support different
  /// sizes. Use [ImageSize] enum values for type-safe size specification.
  ///
  /// **Provider Support:**
  /// - Supported: OpenAI
  /// - Unsupported: xAI (parameter is ignored if provided)
  final ImageSize? size;

  /// Optional number of images to generate.
  ///
  /// The number of images to generate in a single request. Typically 1-10,
  /// depending on provider limits. Defaults to 1 if not specified.
  final int? n;

  /// Optional quality setting for the generated image.
  ///
  /// Quality settings vary by provider. Common values:
  /// - "standard" or "standard" - Normal quality (faster, cheaper)
  /// - "hd" or "high" - High quality (slower, more expensive)
  /// - "ultra" - Ultra high quality (slowest, most expensive)
  ///
  /// **Provider Support:**
  /// - Supported: OpenAI
  /// - Unsupported: xAI (parameter is ignored if provided)
  final String? quality;

  /// Optional style setting for the generated image.
  ///
  /// Style settings vary by provider. Common values:
  /// - "vivid" - More dramatic and saturated
  /// - "natural" - More natural and realistic
  /// - "artistic" - More artistic and stylized
  ///
  /// **Provider Support:**
  /// - Supported: OpenAI
  /// - Unsupported: xAI (parameter is ignored if provided)
  final String? style;

  /// Optional provider-specific configuration options.
  ///
  /// Allows passing provider-specific parameters that aren't part of the
  /// standard API. Keys should be provider IDs (e.g., "openai", "stability").
  ///
  /// **Example:**
  /// ```dart
  /// ImageRequest(
  ///   prompt: 'A cat',
  ///   providerOptions: {
  ///     'openai': {'response_format': 'url'},
  ///     'stability': {'seed': 42, 'steps': 50},
  ///   },
  /// )
  /// ```
  final Map<String, Map<String, dynamic>>? providerOptions;

  /// Creates a new [ImageRequest] instance.
  ///
  /// [prompt] is required and must not be empty. All other fields are optional.
  ImageRequest({
    required this.prompt,
    this.model,
    this.size,
    this.n,
    this.quality,
    this.style,
    this.providerOptions,
  }) : assert(prompt.isNotEmpty, 'prompt must not be empty');

  /// Converts this [ImageRequest] to a JSON map.
  ///
  /// The resulting map is compatible with most AI provider APIs.
  /// Only non-null optional fields are included in the output.
  /// The [size] is converted to its string representation (e.g., "1024x1024").
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "prompt": "A beautiful sunset",
  ///   "model": "dall-e-3",
  ///   "size": "1024x1024",
  ///   "n": 1,
  ///   "quality": "hd",
  ///   "style": "vivid"
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      if (model != null) 'model': model,
      if (size != null) 'size': size!.toString(),
      if (n != null) 'n': n,
      if (quality != null) 'quality': quality,
      if (style != null) 'style': style,
      if (providerOptions != null) 'provider_options': providerOptions,
    };
  }

  /// Creates an [ImageRequest] instance from a JSON map.
  ///
  /// Parses the JSON representation of an image request into an
  /// [ImageRequest] object. The [size] field is parsed from a string
  /// format (e.g., "1024x1024") back to an [ImageSize] enum.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "prompt": "A beautiful sunset",
  ///   "size": "1024x1024",
  ///   "n": 1
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory ImageRequest.fromJson(Map<String, dynamic> json) {
    final prompt = json['prompt'] as String?;
    if (prompt == null || prompt.isEmpty) {
      throw const FormatException('Missing or empty required field: prompt');
    }

    ImageSize? size;
    if (json['size'] != null) {
      final sizeString = json['size'] as String;
      try {
        size = ImageSize.values.firstWhere(
          (s) => s.toString() == sizeString,
          orElse: () => throw FormatException('Invalid size: $sizeString'),
        );
      } catch (e) {
        throw FormatException('Invalid size format: $sizeString', e);
      }
    }

    return ImageRequest(
      prompt: prompt,
      model: json['model'] as String?,
      size: size,
      n: json['n'] as int?,
      quality: json['quality'] as String?,
      style: json['style'] as String?,
      providerOptions:
          json['provider_options'] as Map<String, Map<String, dynamic>>?,
    );
  }

  /// Creates a copy of this [ImageRequest] with the given fields replaced.
  ///
  /// Returns a new [ImageRequest] instance with the same values as this one,
  /// except for the fields explicitly provided.
  ImageRequest copyWith({
    String? prompt,
    Object? model = _undefined,
    ImageSize? size,
    int? n,
    String? quality,
    String? style,
    Map<String, Map<String, dynamic>>? providerOptions,
  }) {
    return ImageRequest(
      prompt: prompt ?? this.prompt,
      model: model == _undefined ? this.model : model as String?,
      size: size ?? this.size,
      n: n ?? this.n,
      quality: quality ?? this.quality,
      style: style ?? this.style,
      providerOptions: providerOptions ?? this.providerOptions,
    );
  }

  static const _undefined = Object();

  @override
  String toString() {
    return 'ImageRequest(prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}${model != null ? ", model: $model" : ""}${size != null ? ", size: $size" : ""}${n != null ? ", n: $n" : ""}${quality != null ? ", quality: $quality" : ""}${style != null ? ", style: $style" : ""}${providerOptions != null ? ", providerOptions: ..." : ""})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageRequest &&
        other.prompt == prompt &&
        other.model == model &&
        other.size == size &&
        other.n == n &&
        other.quality == quality &&
        other.style == style &&
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
      size,
      n,
      quality,
      style,
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
