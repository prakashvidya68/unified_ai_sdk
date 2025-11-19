/// Provider-specific models for Google Gemini API format.
///
/// This file contains data models that match Google's Gemini API request and response
/// formats. These models are used internally by [GoogleProvider] to communicate
/// with the Google Gemini API endpoints.
///
/// **Note:** These models are provider-specific and should not be used directly
/// by SDK users. Use the unified SDK models ([ChatRequest], [ChatResponse], etc.)
/// instead, which will be automatically converted to/from these Google-specific
/// models by [GoogleMapper].
///
/// **Google Gemini API Reference:**
/// https://ai.google.dev/api/generateContent
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../error/error_types.dart';

/// Represents a content part in Google Gemini API format.
///
/// Gemini uses a "parts" array where each part can be:
/// - Text: `{"text": "Hello"}`
/// - Image: `{"inline_data": {"mime_type": "image/jpeg", "data": "base64..."}}`
/// - File data: `{"file_data": {...}}`
class GoogleContentPart {
  /// Text content of this part.
  ///
  /// Used for text-only content parts. Mutually exclusive with
  /// [inlineData] and [fileData].
  final String? text;

  /// Inline data (e.g., base64-encoded images) for this part.
  ///
  /// Used for multimodal content like images. Format:
  /// `{"mime_type": "image/jpeg", "data": "base64..."}`
  /// Mutually exclusive with [text] and [fileData].
  final Map<String, dynamic>? inlineData;

  /// File data reference for this part.
  ///
  /// Used for file-based content. Mutually exclusive with
  /// [text] and [inlineData].
  final Map<String, dynamic>? fileData;

  /// Creates a new [GoogleContentPart] instance.
  ///
  /// Exactly one of [text], [inlineData], or [fileData] must be provided.
  GoogleContentPart({
    this.text,
    this.inlineData,
    this.fileData,
  }) : assert(
          (text != null && inlineData == null && fileData == null) ||
              (text == null && inlineData != null && fileData == null) ||
              (text == null && inlineData == null && fileData != null),
          'Exactly one of text, inlineData, or fileData must be provided',
        );

  /// Creates a [GoogleContentPart] from a JSON map.
  ///
  /// Parses the JSON representation of a content part into a
  /// [GoogleContentPart] object.
  factory GoogleContentPart.fromJson(Map<String, dynamic> json) {
    return GoogleContentPart(
      text: json['text'] as String?,
      inlineData: json['inline_data'] as Map<String, dynamic>?,
      fileData: json['file_data'] as Map<String, dynamic>?,
    );
  }

  /// Converts this [GoogleContentPart] to a JSON map.
  ///
  /// Returns a map compatible with Google Gemini API format.
  Map<String, dynamic> toJson() {
    return {
      if (text != null) 'text': text,
      if (inlineData != null) 'inline_data': inlineData,
      if (fileData != null) 'file_data': fileData,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoogleContentPart &&
        other.text == text &&
        _mapEquals(other.inlineData, inlineData) &&
        _mapEquals(other.fileData, fileData);
  }

  @override
  int get hashCode => Object.hash(text, inlineData, fileData);

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

/// Represents a message in Google Gemini API format.
///
/// Gemini messages contain a "parts" array with content parts.
/// The role can be "user" or "model" (assistant).
class GoogleMessage {
  /// The role of the message sender.
  ///
  /// Must be either "user" or "model" (assistant).
  final String role;

  /// List of content parts in this message.
  ///
  /// Each part can be text, image, or file data.
  /// Must not be empty.
  final List<GoogleContentPart> parts;

  /// Creates a new [GoogleMessage] instance.
  ///
  /// [role] must be "user" or "model", and [parts] must not be empty.
  GoogleMessage({
    required this.role,
    required this.parts,
  })  : assert(role == 'user' || role == 'model',
            'role must be "user" or "model"'),
        assert(parts.isNotEmpty, 'parts must not be empty');

  /// Creates a [GoogleMessage] from a JSON map.
  ///
  /// Parses the JSON representation of a message into a [GoogleMessage] object.
  factory GoogleMessage.fromJson(Map<String, dynamic> json) {
    final parts = json['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: parts',
        code: 'INVALID_REQUEST',
      );
    }

    return GoogleMessage(
      role: json['role'] as String,
      parts: parts
          .map((p) => GoogleContentPart.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts this [GoogleMessage] to a JSON map.
  ///
  /// Returns a map compatible with Google Gemini API format.
  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'parts': parts.map((p) => p.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoogleMessage &&
        other.role == role &&
        _listEquals(other.parts, parts);
  }

  @override
  int get hashCode => Object.hash(role, Object.hashAll(parts));

  bool _listEquals(List<GoogleContentPart>? a, List<GoogleContentPart>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Represents a chat completion request in Google Gemini API format.
///
/// This model matches the exact structure expected by Google's Gemini
/// `/v1/models/{model}:generateContent` endpoint.
///
/// **Key differences from OpenAI/Anthropic:**
/// - Uses "contents" array (not "messages")
/// - Each content has "parts" array (supports multimodal: text + images)
/// - System instructions are in "system_instruction" field
/// - Uses "maxOutputTokens" (not "max_tokens")
/// - Uses "candidateCount" (not "n")
///
/// **Google Gemini API Reference:**
/// https://ai.google.dev/api/generateContent
class GoogleChatRequest {
  /// List of messages in the conversation.
  ///
  /// Each message contains role and parts. Must not be empty.
  final List<GoogleMessage> contents;

  /// System instruction for the model.
  ///
  /// Provides context or instructions that apply to the entire conversation.
  final Map<String, dynamic>? systemInstruction;

  /// Model identifier to use for generation.
  ///
  /// Examples: "gemini-pro", "gemini-1.5-pro"
  final String? model;

  /// Sampling temperature between 0.0 and 2.0.
  ///
  /// Higher values make output more random, lower values more focused.
  final double? temperature;

  /// Top-p sampling parameter between 0.0 and 1.0.
  ///
  /// Nucleus sampling: consider tokens with top_p probability mass.
  final double? topP;

  /// Top-k sampling parameter.
  ///
  /// Consider only the top k most likely tokens.
  final int? topK;

  /// Maximum number of tokens to generate in the response.
  ///
  /// Limits the length of the generated text.
  final int? maxOutputTokens;

  /// Sequences where the API will stop generating.
  ///
  /// When one of these sequences is encountered, generation stops.
  final List<String>? stopSequences;

  /// Number of candidate responses to generate.
  ///
  /// Must be between 1 and 8.
  final int? candidateCount;

  /// Safety settings for content filtering.
  ///
  /// Controls what content the model can generate.
  final Map<String, dynamic>? safetySettings;

  /// Generation configuration options.
  ///
  /// Additional configuration for content generation.
  final Map<String, dynamic>? generationConfig;

  /// Creates a new [GoogleChatRequest] instance.
  ///
  /// [contents] is required and must not be empty.
  GoogleChatRequest({
    required this.contents,
    this.systemInstruction,
    this.model,
    this.temperature,
    this.topP,
    this.topK,
    this.maxOutputTokens,
    this.stopSequences,
    this.candidateCount,
    this.safetySettings,
    this.generationConfig,
  })  : assert(contents.isNotEmpty, 'contents must not be empty'),
        assert(
            temperature == null || (temperature >= 0.0 && temperature <= 2.0),
            'temperature must be between 0.0 and 2.0'),
        assert(topP == null || (topP >= 0.0 && topP <= 1.0),
            'topP must be between 0.0 and 1.0'),
        assert(maxOutputTokens == null || maxOutputTokens > 0,
            'maxOutputTokens must be positive'),
        assert(
            candidateCount == null ||
                (candidateCount >= 1 && candidateCount <= 8),
            'candidateCount must be between 1 and 8');

  /// Converts this [GoogleChatRequest] to a JSON map.
  ///
  /// Returns a map compatible with Google Gemini API format.
  /// Note: temperature, topP, topK, maxOutputTokens, and stopSequences should be
  /// inside generationConfig, not as top-level fields.
  Map<String, dynamic> toJson() {
    return {
      'contents': contents.map((c) => c.toJson()).toList(),
      if (systemInstruction != null) 'systemInstruction': systemInstruction,
      if (model != null) 'model': model,
      // temperature, topP, topK, maxOutputTokens, stopSequences are now in generationConfig
      // Only include them as top-level if generationConfig is null (for backward compatibility)
      if (generationConfig == null && temperature != null)
        'temperature': temperature,
      if (generationConfig == null && topP != null) 'topP': topP,
      if (generationConfig == null && topK != null) 'topK': topK,
      if (generationConfig == null && maxOutputTokens != null)
        'maxOutputTokens': maxOutputTokens,
      if (generationConfig == null && stopSequences != null)
        'stopSequences': stopSequences,
      if (candidateCount != null) 'candidateCount': candidateCount,
      if (safetySettings != null) 'safetySettings': safetySettings,
      if (generationConfig != null) 'generationConfig': generationConfig,
    };
  }

  /// Creates a [GoogleChatRequest] from a JSON map.
  ///
  /// Parses the JSON representation into a [GoogleChatRequest] object.
  factory GoogleChatRequest.fromJson(Map<String, dynamic> json) {
    final contents = json['contents'] as List<dynamic>?;
    if (contents == null || contents.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: contents',
        code: 'INVALID_REQUEST',
      );
    }

    return GoogleChatRequest(
      contents: contents
          .map((c) => GoogleMessage.fromJson(c as Map<String, dynamic>))
          .toList(),
      systemInstruction: json['system_instruction'] as Map<String, dynamic>?,
      model: json['model'] as String?,
      temperature: json['temperature'] as double?,
      topP: json['top_p'] as double?,
      topK: json['top_k'] as int?,
      maxOutputTokens: json['max_output_tokens'] as int?,
      stopSequences: json['stop_sequences'] != null
          ? List<String>.from(json['stop_sequences'] as List)
          : null,
      candidateCount: json['candidate_count'] as int?,
      safetySettings: json['safety_settings'] as Map<String, dynamic>?,
      generationConfig: json['generation_config'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'GoogleChatRequest(model: $model, contents: ${contents.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoogleChatRequest &&
        _listEquals(other.contents, contents) &&
        _mapEqualsDeep(other.systemInstruction, systemInstruction) &&
        other.model == model &&
        other.temperature == temperature &&
        other.topP == topP &&
        other.topK == topK &&
        other.maxOutputTokens == maxOutputTokens &&
        _listEqualsStrings(other.stopSequences, stopSequences) &&
        other.candidateCount == candidateCount &&
        _mapEqualsDeep(other.safetySettings, safetySettings) &&
        _mapEqualsDeep(other.generationConfig, generationConfig);
  }

  @override
  int get hashCode {
    int contentsHash = 0;
    for (final content in contents) {
      contentsHash = Object.hash(contentsHash, content);
    }
    return Object.hash(
      contentsHash,
      systemInstruction,
      model,
      temperature,
      topP,
      topK,
      maxOutputTokens,
      Object.hashAll(stopSequences ?? []),
      candidateCount,
      safetySettings,
      generationConfig,
    );
  }

  bool _listEquals(List<GoogleMessage>? a, List<GoogleMessage>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _listEqualsStrings(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEqualsDeep(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Represents a candidate in Google Gemini API response.
///
/// Each candidate contains the generated content and finish reason.
class GoogleCandidate {
  /// The generated content for this candidate.
  ///
  /// Contains a "parts" array with the generated text and other content.
  final Map<String, dynamic>? content;

  /// The reason why generation stopped.
  ///
  /// Common values: "STOP", "MAX_TOKENS", "SAFETY", "RECITATION"
  final String? finishReason;

  /// The index of this candidate in the candidates array.
  final int? index;

  /// Safety ratings for this candidate.
  ///
  /// Contains safety scores and categories for content filtering.
  final List<Map<String, dynamic>>? safetyRatings;

  /// Creates a new [GoogleCandidate] instance.
  GoogleCandidate({
    this.content,
    this.finishReason,
    this.index,
    this.safetyRatings,
  });

  /// Creates a [GoogleCandidate] from a JSON map.
  ///
  /// Parses the JSON representation of a candidate into a [GoogleCandidate] object.
  factory GoogleCandidate.fromJson(Map<String, dynamic> json) {
    return GoogleCandidate(
      content: json['content'] as Map<String, dynamic>?,
      finishReason: json['finish_reason'] as String?,
      index: json['index'] as int?,
      safetyRatings: json['safety_ratings'] != null
          ? List<Map<String, dynamic>>.from(json['safety_ratings'] as List)
          : null,
    );
  }

  /// Converts this [GoogleCandidate] to a JSON map.
  ///
  /// Returns a map compatible with Google Gemini API format.
  Map<String, dynamic> toJson() {
    return {
      if (content != null) 'content': content,
      if (finishReason != null) 'finish_reason': finishReason,
      if (index != null) 'index': index,
      if (safetyRatings != null) 'safety_ratings': safetyRatings,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoogleCandidate &&
        _mapEqualsDeep(other.content, content) &&
        other.finishReason == finishReason &&
        other.index == index &&
        _listEqualsMaps(other.safetyRatings, safetyRatings);
  }

  @override
  int get hashCode {
    return Object.hash(
      content,
      finishReason,
      index,
      Object.hashAll(safetyRatings ?? []),
    );
  }

  bool _mapEqualsDeep(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  bool _listEqualsMaps(
      List<Map<String, dynamic>>? a, List<Map<String, dynamic>>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_mapEqualsDeep(a[i], b[i])) return false;
    }
    return true;
  }
}

/// Represents usage statistics for a Google Gemini API request.
class GoogleUsage {
  /// Number of tokens in the prompt.
  final int? promptTokenCount;

  /// Number of tokens in the generated candidates.
  final int? candidatesTokenCount;

  /// Total number of tokens used (prompt + candidates).
  final int? totalTokenCount;

  /// Creates a new [GoogleUsage] instance.
  GoogleUsage({
    this.promptTokenCount,
    this.candidatesTokenCount,
    this.totalTokenCount,
  });

  /// Creates a [GoogleUsage] from a JSON map.
  ///
  /// Parses the JSON representation of usage statistics into a [GoogleUsage] object.
  factory GoogleUsage.fromJson(Map<String, dynamic> json) {
    return GoogleUsage(
      promptTokenCount: json['prompt_token_count'] as int?,
      candidatesTokenCount: json['candidates_token_count'] as int?,
      totalTokenCount: json['total_token_count'] as int?,
    );
  }

  /// Converts this [GoogleUsage] to a JSON map.
  ///
  /// Returns a map compatible with Google Gemini API format.
  Map<String, dynamic> toJson() {
    return {
      if (promptTokenCount != null) 'prompt_token_count': promptTokenCount,
      if (candidatesTokenCount != null)
        'candidates_token_count': candidatesTokenCount,
      if (totalTokenCount != null) 'total_token_count': totalTokenCount,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoogleUsage &&
        other.promptTokenCount == promptTokenCount &&
        other.candidatesTokenCount == candidatesTokenCount &&
        other.totalTokenCount == totalTokenCount;
  }

  @override
  int get hashCode =>
      Object.hash(promptTokenCount, candidatesTokenCount, totalTokenCount);
}

/// Represents a chat completion response in Google Gemini API format.
///
/// This model matches the exact structure returned by Google's Gemini
/// `/v1/models/{model}:generateContent` endpoint.
class GoogleChatResponse {
  /// List of generated candidate responses.
  ///
  /// Each candidate contains generated content and metadata.
  /// Must not be empty.
  final List<GoogleCandidate> candidates;

  /// Usage statistics for this request.
  ///
  /// Contains token counts for prompt and generated content.
  final GoogleUsage? usageMetadata;

  /// Model information.
  ///
  /// Contains details about the model used for generation.
  final Map<String, dynamic>? model;

  /// Feedback about the prompt.
  ///
  /// Contains information about prompt processing and any issues.
  final Map<String, dynamic>? promptFeedback;

  /// Creates a new [GoogleChatResponse] instance.
  ///
  /// [candidates] is required and must not be empty.
  GoogleChatResponse({
    required this.candidates,
    this.usageMetadata,
    this.model,
    this.promptFeedback,
  }) : assert(candidates.isNotEmpty, 'candidates must not be empty');

  /// Creates a [GoogleChatResponse] from a JSON map.
  ///
  /// Parses the JSON representation of a response into a [GoogleChatResponse] object.
  factory GoogleChatResponse.fromJson(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw ClientError(
        message: 'Missing or empty required field: candidates',
        code: 'INVALID_RESPONSE',
      );
    }

    return GoogleChatResponse(
      candidates: candidates
          .map((c) => GoogleCandidate.fromJson(c as Map<String, dynamic>))
          .toList(),
      usageMetadata: json['usage_metadata'] != null
          ? GoogleUsage.fromJson(json['usage_metadata'] as Map<String, dynamic>)
          : null,
      model: json['model'] as Map<String, dynamic>?,
      promptFeedback: json['prompt_feedback'] as Map<String, dynamic>?,
    );
  }

  /// Converts this [GoogleChatResponse] to a JSON map.
  ///
  /// Returns a map compatible with Google Gemini API format.
  Map<String, dynamic> toJson() {
    return {
      'candidates': candidates.map((c) => c.toJson()).toList(),
      if (usageMetadata != null) 'usage_metadata': usageMetadata!.toJson(),
      if (model != null) 'model': model,
      if (promptFeedback != null) 'prompt_feedback': promptFeedback,
    };
  }

  @override
  String toString() {
    return 'GoogleChatResponse(candidates: ${candidates.length}, usage: $usageMetadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoogleChatResponse &&
        _listEquals(other.candidates, candidates) &&
        other.usageMetadata == usageMetadata &&
        _mapEqualsDeep(other.model, model) &&
        _mapEqualsDeep(other.promptFeedback, promptFeedback);
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(candidates),
      usageMetadata,
      model,
      promptFeedback,
    );
  }

  bool _listEquals(List<GoogleCandidate>? a, List<GoogleCandidate>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEqualsDeep(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Represents an embedding request in Google Gemini API format.
///
/// Google provides embeddings via the embedContent endpoint.
/// Models: text-embedding-004, text-embedding-3, gemini-embedding-001
class GoogleEmbeddingRequest {
  /// The model to use for embeddings.
  final String? model;

  /// The content to embed.
  ///
  /// Can be a single string or a map with parts (for multimodal).
  final dynamic content;

  /// Task type for the embedding.
  ///
  /// Options: "RETRIEVAL_QUERY", "RETRIEVAL_DOCUMENT", "SEMANTIC_SIMILARITY", etc.
  final String? taskType;

  /// Title for the content (optional).
  final String? title;

  /// Creates a new [GoogleEmbeddingRequest] instance.
  GoogleEmbeddingRequest({
    this.model,
    required this.content,
    this.taskType,
    this.title,
  });

  /// Converts this request to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (model != null) 'model': model,
      'content': content is Map
          ? content
          : {
              'parts': [
                {'text': content}
              ]
            },
      if (taskType != null) 'taskType': taskType,
      if (title != null) 'title': title,
    };
  }

  /// Creates a [GoogleEmbeddingRequest] from a JSON map.
  factory GoogleEmbeddingRequest.fromJson(Map<String, dynamic> json) {
    return GoogleEmbeddingRequest(
      model: json['model'] as String?,
      content: json['content'],
      taskType: json['taskType'] as String?,
      title: json['title'] as String?,
    );
  }
}

/// Represents an embedding response in Google Gemini API format.
class GoogleEmbeddingResponse {
  /// The embedding values.
  final GoogleEmbedding embedding;

  /// Creates a new [GoogleEmbeddingResponse] instance.
  GoogleEmbeddingResponse({required this.embedding});

  /// Creates a [GoogleEmbeddingResponse] from a JSON map.
  factory GoogleEmbeddingResponse.fromJson(Map<String, dynamic> json) {
    return GoogleEmbeddingResponse(
      embedding: GoogleEmbedding.fromJson(
        json['embedding'] as Map<String, dynamic>,
      ),
    );
  }
}

/// Represents a single embedding in Google format.
class GoogleEmbedding {
  /// The embedding vector values.
  final List<double> values;

  /// Creates a new [GoogleEmbedding] instance.
  GoogleEmbedding({required this.values});

  /// Creates a [GoogleEmbedding] from a JSON map.
  factory GoogleEmbedding.fromJson(Map<String, dynamic> json) {
    final valuesList = json['values'] as List<dynamic>?;
    return GoogleEmbedding(
      values: valuesList != null
          ? valuesList.map((v) => (v as num).toDouble()).toList()
          : [],
    );
  }
}

/// Represents an image generation request in Google Imagen API format.
class GoogleImageRequest {
  /// The model to use for image generation.
  final String? model;

  /// The text prompt describing the image to generate.
  final String prompt;

  /// Number of images to generate.
  final int? numberOfImages;

  /// Aspect ratio for the generated images.
  final String? aspectRatio;

  /// Safety filter level.
  final String? safetyFilterLevel;

  /// Person generation setting.
  final String? personGeneration;

  /// Image size setting.
  ///
  /// Supported values: "1K" and "2K". Only supported for Standard and Ultra models.
  /// Default is "1K".
  final String? imageSize;

  /// Creates a new [GoogleImageRequest] instance.
  GoogleImageRequest({
    this.model,
    required this.prompt,
    this.numberOfImages,
    this.aspectRatio,
    this.safetyFilterLevel,
    this.personGeneration,
    this.imageSize,
  });

  /// Converts this request to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (model != null) 'model': model,
      'instances': [
        {
          'prompt': prompt,
        }
      ],
      'parameters': {
        if (numberOfImages != null) 'sampleCount': numberOfImages,
        if (aspectRatio != null) 'aspectRatio': aspectRatio,
        if (imageSize != null) 'imageSize': imageSize,
        if (safetyFilterLevel != null) 'safetyFilterLevel': safetyFilterLevel,
        if (personGeneration != null) 'personGeneration': personGeneration,
      },
    };
  }

  /// Creates a [GoogleImageRequest] from a JSON map.
  factory GoogleImageRequest.fromJson(Map<String, dynamic> json) {
    final instances = json['instances'] as List<dynamic>?;
    final prompt = instances != null && instances.isNotEmpty
        ? (instances[0] as Map<String, dynamic>)['prompt'] as String?
        : null;
    final parameters = json['parameters'] as Map<String, dynamic>?;
    return GoogleImageRequest(
      model: json['model'] as String?,
      prompt: prompt ?? '',
      numberOfImages: parameters?['sampleCount'] as int?,
      aspectRatio: parameters?['aspectRatio'] as String?,
      imageSize: parameters?['imageSize'] as String?,
      safetyFilterLevel: parameters?['safetyFilterLevel'] as String?,
      personGeneration: parameters?['personGeneration'] as String?,
    );
  }
}

/// Represents an image generation response in Google Imagen API format.
class GoogleImageResponse {
  /// List of generated images.
  final List<GoogleImageData> predictions;

  /// Creates a new [GoogleImageResponse] instance.
  GoogleImageResponse({required this.predictions});

  /// Creates a [GoogleImageResponse] from a JSON map.
  factory GoogleImageResponse.fromJson(Map<String, dynamic> json) {
    final predictions = json['predictions'] as List<dynamic>?;
    return GoogleImageResponse(
      predictions: predictions != null
          ? predictions
              .map((p) => GoogleImageData.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

/// Represents a single generated image in Google format.
class GoogleImageData {
  /// Base64-encoded image data.
  final String? bytesBase64Encoded;

  /// MIME type of the image.
  final String? mimeType;

  /// Creates a new [GoogleImageData] instance.
  GoogleImageData({
    this.bytesBase64Encoded,
    this.mimeType,
  });

  /// Creates a [GoogleImageData] from a JSON map.
  factory GoogleImageData.fromJson(Map<String, dynamic> json) {
    return GoogleImageData(
      bytesBase64Encoded: json['bytesBase64Encoded'] as String?,
      mimeType: json['mimeType'] as String?,
    );
  }
}

/// Represents a text-to-speech request in Google TTS API format.
class GoogleTtsRequest {
  /// The text to convert to speech.
  final String input;

  /// The voice configuration.
  final Map<String, dynamic> voice;

  /// The audio configuration.
  final Map<String, dynamic> audioConfig;

  /// Creates a new [GoogleTtsRequest] instance.
  GoogleTtsRequest({
    required this.input,
    required this.voice,
    required this.audioConfig,
  });

  /// Converts this request to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'input': {'text': input},
      'voice': voice,
      'audioConfig': audioConfig,
    };
  }

  /// Creates a [GoogleTtsRequest] from a JSON map.
  factory GoogleTtsRequest.fromJson(Map<String, dynamic> json) {
    final inputMap = json['input'] as Map<String, dynamic>?;
    return GoogleTtsRequest(
      input: inputMap?['text'] as String? ?? '',
      voice: json['voice'] as Map<String, dynamic>? ?? {},
      audioConfig: json['audioConfig'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Represents a speech-to-text request in Google STT API format.
class GoogleSttRequest {
  /// The audio data to transcribe.
  final Uint8List audio;

  /// The audio configuration.
  final Map<String, dynamic> config;

  /// Creates a new [GoogleSttRequest] instance.
  GoogleSttRequest({
    required this.audio,
    required this.config,
  });

  /// Converts this request to form fields for multipart request.
  Map<String, dynamic> toFormFields() {
    return {
      'config': jsonEncode(config),
    };
  }

  /// Creates a [GoogleSttRequest] from a JSON map.
  factory GoogleSttRequest.fromJson(Map<String, dynamic> json,
      {Uint8List? audio}) {
    return GoogleSttRequest(
      audio: audio ?? Uint8List(0),
      config: json['config'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Represents a video generation request in Google Veo API format.
class GoogleVideoRequest {
  /// The model to use for video generation.
  final String? model;

  /// The text prompt describing the video to generate.
  final String prompt;

  /// Optional duration in seconds.
  final int? duration;

  /// Optional aspect ratio.
  final String? aspectRatio;

  /// Optional frame rate.
  final int? frameRate;

  /// Optional quality setting.
  final String? quality;

  /// Optional seed for reproducibility.
  final int? seed;

  /// Creates a new [GoogleVideoRequest] instance.
  GoogleVideoRequest({
    this.model,
    required this.prompt,
    this.duration,
    this.aspectRatio,
    this.frameRate,
    this.quality,
    this.seed,
  });

  /// Converts this request to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (model != null) 'model': model,
      'prompt': prompt,
      if (duration != null) 'duration': duration,
      if (aspectRatio != null) 'aspectRatio': aspectRatio,
      if (frameRate != null) 'frameRate': frameRate,
      if (quality != null) 'quality': quality,
      if (seed != null) 'seed': seed,
    };
  }

  /// Creates a [GoogleVideoRequest] from a JSON map.
  factory GoogleVideoRequest.fromJson(Map<String, dynamic> json) {
    return GoogleVideoRequest(
      model: json['model'] as String?,
      prompt: json['prompt'] as String,
      duration: json['duration'] as int?,
      aspectRatio: json['aspectRatio'] as String?,
      frameRate: json['frameRate'] as int?,
      quality: json['quality'] as String?,
      seed: json['seed'] as int?,
    );
  }
}

/// Represents a video generation response in Google Veo API format.
class GoogleVideoResponse {
  /// List of generated videos.
  final List<GoogleVideoData> videos;

  /// The model used for generation.
  final String model;

  /// Creates a new [GoogleVideoResponse] instance.
  GoogleVideoResponse({
    required this.videos,
    required this.model,
  });

  /// Creates a [GoogleVideoResponse] from a JSON map.
  factory GoogleVideoResponse.fromJson(Map<String, dynamic> json) {
    final videos = json['videos'] as List<dynamic>?;
    return GoogleVideoResponse(
      videos: videos != null
          ? videos
              .map((v) => GoogleVideoData.fromJson(v as Map<String, dynamic>))
              .toList()
          : [],
      model: json['model'] as String? ?? 'veo-3.1',
    );
  }
}

/// Represents a single generated video in Google format.
class GoogleVideoData {
  /// URL of the generated video.
  final String? url;

  /// Base64-encoded video data.
  final String? base64;

  /// Optional width in pixels.
  final int? width;

  /// Optional height in pixels.
  final int? height;

  /// Optional duration in seconds.
  final int? duration;

  /// Optional frame rate.
  final int? frameRate;

  /// Creates a new [GoogleVideoData] instance.
  GoogleVideoData({
    this.url,
    this.base64,
    this.width,
    this.height,
    this.duration,
    this.frameRate,
  });

  /// Creates a [GoogleVideoData] from a JSON map.
  factory GoogleVideoData.fromJson(Map<String, dynamic> json) {
    return GoogleVideoData(
      url: json['url'] as String?,
      base64: json['base64'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: json['duration'] as int?,
      frameRate: json['frameRate'] as int?,
    );
  }
}

/// Represents a video analysis request in Google Gemini API format.
///
/// Uses Gemini's multimodal capabilities to analyze video content.
class GoogleVideoAnalysisRequest {
  /// The model to use for video analysis.
  final String? model;

  /// List of messages with video content.
  final List<GoogleMessage> contents;

  /// System instruction (optional).
  final Map<String, dynamic>? systemInstruction;

  /// Generation configuration.
  final Map<String, dynamic>? generationConfig;

  /// Creates a new [GoogleVideoAnalysisRequest] instance.
  GoogleVideoAnalysisRequest({
    this.model,
    required this.contents,
    this.systemInstruction,
    this.generationConfig,
  });

  /// Converts this request to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (model != null) 'model': model,
      'contents': contents.map((c) => c.toJson()).toList(),
      if (systemInstruction != null) 'systemInstruction': systemInstruction,
      if (generationConfig != null) 'generationConfig': generationConfig,
    };
  }

  /// Creates a [GoogleVideoAnalysisRequest] from a JSON map.
  factory GoogleVideoAnalysisRequest.fromJson(Map<String, dynamic> json) {
    final contents = json['contents'] as List<dynamic>?;
    return GoogleVideoAnalysisRequest(
      model: json['model'] as String?,
      contents: contents != null
          ? contents
              .map((c) => GoogleMessage.fromJson(c as Map<String, dynamic>))
              .toList()
          : [],
      systemInstruction: json['systemInstruction'] as Map<String, dynamic>?,
      generationConfig: json['generationConfig'] as Map<String, dynamic>?,
    );
  }
}

/// Represents a video analysis response in Google Gemini API format.
///
/// Similar to GoogleChatResponse but contains video analysis results.
class GoogleVideoAnalysisResponse {
  /// List of analysis candidates.
  final List<GoogleCandidate> candidates;

  /// Usage statistics.
  final GoogleUsage? usageMetadata;

  /// Model information.
  final Map<String, dynamic>? model;

  /// Creates a new [GoogleVideoAnalysisResponse] instance.
  GoogleVideoAnalysisResponse({
    required this.candidates,
    this.usageMetadata,
    this.model,
  });

  /// Creates a [GoogleVideoAnalysisResponse] from a JSON map.
  factory GoogleVideoAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List<dynamic>?;
    return GoogleVideoAnalysisResponse(
      candidates: candidates != null
          ? candidates
              .map((c) => GoogleCandidate.fromJson(c as Map<String, dynamic>))
              .toList()
          : [],
      usageMetadata: json['usageMetadata'] != null
          ? GoogleUsage.fromJson(json['usageMetadata'] as Map<String, dynamic>)
          : null,
      model: json['model'] as Map<String, dynamic>?,
    );
  }
}
