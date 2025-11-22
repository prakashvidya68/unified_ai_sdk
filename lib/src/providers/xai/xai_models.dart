/// Provider-specific models for xAI (Grok) API format.
///
/// This file contains data models that match xAI's API request and response
/// formats. These models are used internally by [XAIProvider] to communicate
/// with the xAI API endpoints.
///
/// **Note:** These models are provider-specific and should not be used directly
/// by SDK users. Use the unified SDK models ([ChatRequest], [ChatResponse], etc.)
/// instead, which will be automatically converted to/from these xAI-specific
/// models by [XAIMapper].
library;

import '../../error/error_types.dart';

/// Represents a chat completion request in xAI's API format.
///
/// This model matches the structure expected by xAI's `/v1/chat/completions`
/// endpoint. xAI's API is similar to OpenAI's format.
///
/// **xAI API Reference:**
/// https://docs.x.ai/docs/api-reference/chat/completions
class XAIChatRequest {
  /// ID of the model to use.
  ///
  /// Examples: "grok-4-0709", "grok-4-fast-reasoning", "grok-3", "grok-3-mini", "grok-code-fast-1"
  final String model;

  /// List of messages comprising the conversation.
  ///
  /// Each message is a map with "role" and "content" keys.
  /// Roles can be: "system", "user", "assistant"
  final List<Map<String, dynamic>> messages;

  /// Sampling temperature between 0 and 2.
  ///
  /// Higher values make output more random, lower values more focused.
  /// Defaults to 1.0 if not specified.
  final double? temperature;

  /// Maximum number of tokens to generate.
  final int? maxTokens;

  /// Alternative to temperature: nucleus sampling.
  final double? topP;

  /// Number of chat completion choices to generate.
  final int? n;

  /// Up to 4 sequences where the API will stop generating further tokens.
  final List<String>? stop;

  /// A unique identifier representing your end-user.
  final String? user;

  /// Whether to stream back partial progress.
  final bool? stream;

  /// Creates a new [XAIChatRequest] instance.
  XAIChatRequest({
    required this.model,
    required this.messages,
    this.temperature,
    this.maxTokens,
    this.topP,
    this.n,
    this.stop,
    this.user,
    this.stream,
  })  : assert(model.isNotEmpty, 'model must not be empty'),
        assert(messages.isNotEmpty, 'messages must not be empty'),
        assert(
            temperature == null || (temperature >= 0.0 && temperature <= 2.0),
            'temperature must be between 0.0 and 2.0'),
        assert(
            maxTokens == null || maxTokens > 0, 'maxTokens must be positive'),
        assert(n == null || n > 0, 'n must be positive');

  /// Converts this request to a JSON map matching xAI's API format.
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'messages': messages,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (topP != null) 'top_p': topP,
      if (n != null) 'n': n,
      if (stop != null) 'stop': stop,
      if (user != null) 'user': user,
      if (stream != null) 'stream': stream,
    };
  }

  /// Creates an [XAIChatRequest] from a JSON map.
  factory XAIChatRequest.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as String?;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message: 'Missing required field: model',
        code: 'INVALID_REQUEST',
      );
    }

    final messages = json['messages'];
    if (messages == null || messages is! List || messages.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: messages',
        code: 'INVALID_REQUEST',
      );
    }

    return XAIChatRequest(
      model: model,
      messages: List<Map<String, dynamic>>.from(messages),
      temperature: json['temperature'] as double?,
      maxTokens: json['max_tokens'] as int?,
      topP: json['top_p'] as double?,
      n: json['n'] as int?,
      stop:
          json['stop'] != null ? List<String>.from(json['stop'] as List) : null,
      user: json['user'] as String?,
      stream: json['stream'] as bool?,
    );
  }

  @override
  String toString() {
    return 'XAIChatRequest(model: $model, messages: ${messages.length}, '
        'temperature: $temperature, maxTokens: $maxTokens)';
  }
}

/// Represents a chat completion response in xAI's API format.
class XAIChatResponse {
  /// Unique identifier for the chat completion.
  final String id;

  /// Object type, typically "chat.completion".
  final String object;

  /// Unix timestamp (in seconds) of when the chat completion was created.
  final int created;

  /// The model used for the chat completion.
  final String model;

  /// List of completion choices.
  final List<XAIChatChoice> choices;

  /// Usage statistics for the completion request.
  final XAIUsage usage;

  /// Creates a new [XAIChatResponse] instance.
  XAIChatResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
  });

  /// Creates an [XAIChatResponse] from a JSON map.
  factory XAIChatResponse.fromJson(Map<String, dynamic> json) {
    return XAIChatResponse(
      id: json['id'] as String,
      object: json['object'] as String,
      created: json['created'] as int,
      model: json['model'] as String,
      choices: (json['choices'] as List)
          .map((c) => XAIChatChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
      usage: XAIUsage.fromJson(json['usage'] as Map<String, dynamic>),
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': object,
      'created': created,
      'model': model,
      'choices': choices.map((c) => c.toJson()).toList(),
      'usage': usage.toJson(),
    };
  }

  @override
  String toString() {
    return 'XAIChatResponse(id: $id, model: $model, choices: ${choices.length})';
  }
}

/// Represents a single chat completion choice in xAI's format.
class XAIChatChoice {
  /// The index of the choice in the list of choices.
  final int index;

  /// The message generated by the model.
  final Map<String, dynamic> message;

  /// The reason the model stopped generating tokens.
  ///
  /// Possible values: "stop", "length", "content_filter"
  final String? finishReason;

  /// Creates a new [XAIChatChoice] instance.
  XAIChatChoice({
    required this.index,
    required this.message,
    this.finishReason,
  });

  /// Creates an [XAIChatChoice] from a JSON map.
  factory XAIChatChoice.fromJson(Map<String, dynamic> json) {
    return XAIChatChoice(
      index: json['index'] as int,
      message: Map<String, dynamic>.from(json['message'] as Map),
      finishReason: json['finish_reason'] as String?,
    );
  }

  /// Converts this choice to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'message': message,
      if (finishReason != null) 'finish_reason': finishReason,
    };
  }
}

/// Represents usage statistics in xAI's format.
class XAIUsage {
  /// Number of tokens in the prompt.
  final int promptTokens;

  /// Number of tokens in the completion.
  final int completionTokens;

  /// Total number of tokens used.
  final int totalTokens;

  /// Creates a new [XAIUsage] instance.
  XAIUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  /// Creates an [XAIUsage] from a JSON map.
  factory XAIUsage.fromJson(Map<String, dynamic> json) {
    return XAIUsage(
      promptTokens: json['prompt_tokens'] as int,
      completionTokens: json['completion_tokens'] as int,
      totalTokens: json['total_tokens'] as int,
    );
  }

  /// Converts this usage to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
    };
  }

  @override
  String toString() {
    return 'XAIUsage(prompt: $promptTokens, completion: $completionTokens, total: $totalTokens)';
  }
}

/// Represents an image generation request in xAI's API format.
///
/// xAI supports image generation through grok-2-image-1212 model.
class XAIImageRequest {
  /// The text prompt describing the image to generate.
  final String prompt;

  /// The model to use for image generation.
  ///
  /// Examples: "grok-2-image-1212"
  final String? model;

  /// The number of images to generate.
  final int? n;

  /// The size of the generated images.
  ///
  /// Format: "WIDTHxHEIGHT" (e.g., "1024x1024")
  ///
  /// Note: This field is stored but not sent to the xAI API as it does not
  /// support the size parameter. The field is kept for compatibility with
  /// the unified SDK interface.
  final String? size;

  /// The quality of the image that will be generated.
  ///
  /// Note: This field is stored but not sent to the xAI API as it does not
  /// support the quality parameter. The field is kept for compatibility with
  /// the unified SDK interface.
  final String? quality;

  /// The style of the generated images.
  ///
  /// Note: This field is stored but not sent to the xAI API as it does not
  /// support the style parameter. The field is kept for compatibility with
  /// the unified SDK interface.
  final String? style;

  /// The format in which the generated images are returned.
  ///
  /// Options: "url" or "b64_json"
  final String? responseFormat;

  /// Creates a new [XAIImageRequest] instance.
  XAIImageRequest({
    required this.prompt,
    this.model,
    this.n,
    this.size,
    this.quality,
    this.style,
    this.responseFormat,
  }) : assert(prompt.isNotEmpty, 'prompt must not be empty');

  /// Converts this request to a JSON map matching xAI's API format.
  ///
  /// Note: xAI API only supports: prompt, model, n, and response_format.
  /// Parameters like size, quality, and style are not supported and are excluded
  /// from the JSON output even if set in the model.
  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      if (model != null) 'model': model,
      if (n != null) 'n': n,
      // Note: 'size', 'quality', and 'style' are not supported by xAI API
      if (responseFormat != null) 'response_format': responseFormat,
    };
  }

  /// Creates an [XAIImageRequest] from a JSON map.
  factory XAIImageRequest.fromJson(Map<String, dynamic> json) {
    return XAIImageRequest(
      prompt: json['prompt'] as String,
      model: json['model'] as String?,
      n: json['n'] as int?,
      size: json['size'] as String?,
      quality: json['quality'] as String?,
      style: json['style'] as String?,
      // xAI REST API uses 'response_format', but Python SDK uses 'image_format' as alias
      responseFormat: json['response_format'] as String? ??
          json['responseFormat'] as String? ??
          json['image_format'] as String? ??
          json['imageFormat'] as String?,
    );
  }

  @override
  String toString() {
    return 'XAIImageRequest(prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}, model: ${model ?? "grok-2-image-1212"}, size: ${size ?? "1024x1024"})';
  }
}

/// Represents an image generation response in xAI's API format.
class XAIImageResponse {
  /// Timestamp when the images were created.
  ///
  /// Unix timestamp in seconds.
  final int created;

  /// List of generated image data.
  final List<XAIImageData> data;

  /// Creates a new [XAIImageResponse] instance.
  XAIImageResponse({
    required this.created,
    required this.data,
  });

  /// Creates an [XAIImageResponse] from a JSON map.
  ///
  /// xAI API returns responses in the format:
  /// ```json
  /// {
  ///   "created": 1234567890,
  ///   "data": [
  ///     {
  ///       "url": "https://...",
  ///       "revised_prompt": "..."
  ///     }
  ///   ]
  /// }
  /// ```
  factory XAIImageResponse.fromJson(Map<String, dynamic> json) {
    // Handle case where 'created' might be missing (use current timestamp as fallback)
    final created = json['created'] as int? ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Handle 'data' array - xAI returns images in a 'data' array
    final dataList = json['data'] as List<dynamic>?;
    if (dataList == null || dataList.isEmpty) {
      // If no 'data' array, check if response is a single image object
      // (some APIs might return a single object instead of an array)
      if (json.containsKey('url') || json.containsKey('b64_json')) {
        return XAIImageResponse(
          created: created,
          data: [XAIImageData.fromJson(json)],
        );
      }
      throw ClientError(
        message: 'Missing required field: data',
        code: 'INVALID_RESPONSE',
      );
    }

    return XAIImageResponse(
      created: created,
      data: dataList
          .map((e) => XAIImageData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'created': created,
      'data': data.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'XAIImageResponse(created: $created, images: ${data.length})';
  }
}

/// Represents a single generated image in xAI's format.
class XAIImageData {
  /// URL of the generated image.
  ///
  /// Present when response_format is "url" (default).
  final String? url;

  /// Base64-encoded image data.
  ///
  /// Present when response_format is "b64_json".
  final String? b64Json;

  /// The revised prompt used for image generation (if available).
  final String? revisedPrompt;

  /// Creates a new [XAIImageData] instance.
  XAIImageData({
    this.url,
    this.b64Json,
    this.revisedPrompt,
  });

  /// Creates an [XAIImageData] from a JSON map.
  factory XAIImageData.fromJson(Map<String, dynamic> json) {
    return XAIImageData(
      url: json['url'] as String?,
      b64Json: json['b64_json'] as String? ?? json['b64Json'] as String?,
      revisedPrompt:
          json['revised_prompt'] as String? ?? json['revisedPrompt'] as String?,
    );
  }

  /// Converts this image data to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (url != null) 'url': url,
      if (b64Json != null) 'b64_json': b64Json,
      if (revisedPrompt != null) 'revised_prompt': revisedPrompt,
    };
  }

  @override
  String toString() {
    return 'XAIImageData(url: ${url != null ? "..." : null}, b64Json: ${b64Json != null ? "..." : null}, revisedPrompt: ${revisedPrompt != null ? "..." : null})';
  }
}
