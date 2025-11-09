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
  Map<String, dynamic> toJson() {
    return {
      'contents': contents.map((c) => c.toJson()).toList(),
      if (systemInstruction != null) 'system_instruction': systemInstruction,
      if (model != null) 'model': model,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (topK != null) 'top_k': topK,
      if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
      if (stopSequences != null) 'stop_sequences': stopSequences,
      if (candidateCount != null) 'candidate_count': candidateCount,
      if (safetySettings != null) 'safety_settings': safetySettings,
      if (generationConfig != null) 'generation_config': generationConfig,
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
