/// Represents token usage statistics from an AI provider response.
///
/// Token usage information is returned by most AI providers to help track
/// API costs and understand resource consumption. This model standardizes
/// token usage data across different providers.
///
/// **Example usage:**
/// ```dart
/// final usage = Usage(
///   promptTokens: 50,
///   completionTokens: 100,
///   totalTokens: 150,
/// );
///
/// print('Used ${usage.totalTokens} tokens');
/// print('Cost: \$${usage.totalTokens * 0.001}');
/// ```
class Usage {
  /// Number of tokens used in the prompt/input.
  ///
  /// This includes all tokens from the conversation history and the current
  /// user message that were sent to the model.
  final int promptTokens;

  /// Number of tokens generated in the completion/output.
  ///
  /// This represents the tokens in the model's response. Note that this
  /// may be less than the actual response length if the model was stopped
  /// early or hit other limits.
  final int completionTokens;

  /// Total number of tokens used (prompt + completion).
  ///
  /// This is typically the sum of [promptTokens] and [completionTokens],
  /// but some providers may report slightly different values due to
  /// overhead or different counting methods.
  final int totalTokens;

  /// Creates a new [Usage] instance.
  ///
  /// All fields are required. Typically, [totalTokens] should equal
  /// [promptTokens] + [completionTokens], but this is not enforced to
  /// accommodate provider-specific variations.
  const Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  /// Converts this [Usage] to a JSON map.
  ///
  /// The resulting map uses snake_case keys as expected by most AI provider APIs.
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "prompt_tokens": 50,
  ///   "completion_tokens": 100,
  ///   "total_tokens": 150
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
    };
  }

  /// Creates a [Usage] instance from a JSON map.
  ///
  /// Parses the JSON representation of usage statistics into a [Usage] object.
  /// Handles both snake_case (from APIs) and camelCase (from SDK) formats.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "prompt_tokens": 50,
  ///   "completion_tokens": 100,
  ///   "total_tokens": 150
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory Usage.fromJson(Map<String, dynamic> json) {
    // Support both snake_case (from APIs) and camelCase (from SDK)
    final promptTokens =
        json['prompt_tokens'] as int? ?? json['promptTokens'] as int?;
    final completionTokens =
        json['completion_tokens'] as int? ?? json['completionTokens'] as int?;
    final totalTokens =
        json['total_tokens'] as int? ?? json['totalTokens'] as int?;

    if (promptTokens == null) {
      throw const FormatException(
          'Missing required field: prompt_tokens or promptTokens');
    }
    if (completionTokens == null) {
      throw const FormatException(
          'Missing required field: completion_tokens or completionTokens');
    }
    if (totalTokens == null) {
      throw const FormatException(
          'Missing required field: total_tokens or totalTokens');
    }

    return Usage(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
    );
  }

  /// Creates a copy of this [Usage] with the given fields replaced.
  ///
  /// Returns a new [Usage] instance with the same values as this one,
  /// except for the fields explicitly provided.
  Usage copyWith({
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
  }) {
    return Usage(
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      totalTokens: totalTokens ?? this.totalTokens,
    );
  }

  /// Calculates the sum of two [Usage] objects.
  ///
  /// Useful for aggregating token usage across multiple API calls.
  ///
  /// **Example:**
  /// ```dart
  /// final usage1 = Usage(promptTokens: 10, completionTokens: 20, totalTokens: 30);
  /// final usage2 = Usage(promptTokens: 15, completionTokens: 25, totalTokens: 40);
  /// final combined = usage1 + usage2;
  /// // Usage(promptTokens: 25, completionTokens: 45, totalTokens: 70)
  /// ```
  Usage operator +(Usage other) {
    return Usage(
      promptTokens: promptTokens + other.promptTokens,
      completionTokens: completionTokens + other.completionTokens,
      totalTokens: totalTokens + other.totalTokens,
    );
  }

  @override
  String toString() {
    return 'Usage(promptTokens: $promptTokens, completionTokens: $completionTokens, totalTokens: $totalTokens)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Usage &&
        other.promptTokens == promptTokens &&
        other.completionTokens == completionTokens &&
        other.totalTokens == totalTokens;
  }

  @override
  int get hashCode {
    return Object.hash(promptTokens, completionTokens, totalTokens);
  }
}
