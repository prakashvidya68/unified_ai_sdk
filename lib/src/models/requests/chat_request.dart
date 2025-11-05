import '../common/message.dart';

/// Represents a request to generate a chat completion from an AI model.
///
/// Chat requests are the primary way to interact with conversational AI models.
/// They contain a conversation history (messages) and generation parameters
/// that control how the model responds.
///
/// **Example usage:**
/// ```dart
/// final request = ChatRequest(
///   messages: [
///     Message(role: Role.system, content: 'You are a helpful assistant.'),
///     Message(role: Role.user, content: 'Explain quantum computing'),
///   ],
///   model: 'gpt-4',
///   maxTokens: 500,
///   temperature: 0.7,
/// );
///
/// final response = await ai.chat(request: request);
/// print(response.choices.first.message.content);
/// ```
class ChatRequest {
  /// List of messages in the conversation.
  ///
  /// The conversation history that provides context for the AI model.
  /// Typically includes:
  /// - A system message (optional) to set behavior
  /// - One or more user messages
  /// - Assistant messages (if continuing a conversation)
  ///
  /// Must not be empty. The order matters - messages should be in
  /// chronological order.
  final List<Message> messages;

  /// Optional model identifier to use for the completion.
  ///
  /// If not specified, the provider will use its default chat model.
  /// Examples: "gpt-4", "gpt-3.5-turbo", "claude-3-opus", "gemini-pro"
  final String? model;

  /// Optional maximum number of tokens to generate in the response.
  ///
  /// Limits the length of the generated text. If not specified, the provider
  /// will use its default (typically 16-4096 tokens depending on the model).
  ///
  /// Note: This is a maximum limit. The model may stop earlier if it
  /// reaches a natural stopping point or encounters a stop sequence.
  final int? maxTokens;

  /// Provides fine-grained control over token selection during generation.
  ///
  /// Represents the percentage of tokens to consider, using nucleus sampling.
  /// This parameter works in conjunction with temperature to control randomness.
  ///
  /// Common values:
  /// - `0.9`: Consider tokens with top 90% probability mass
  /// - `0.95`: More diverse (default for many models)
  /// - `1.0`: Consider all tokens
  ///
  /// Higher values lead to more diverse outputs, while lower values make
  /// the model more focused and deterministic.
  final double? topP;

  /// Number of completion choices to generate.
  ///
  /// Specifies how many different responses to generate for the same prompt.
  /// Default is typically 1. Higher values (e.g., 3-5) can be useful for
  /// exploring different response styles, but increase API costs.
  ///
  /// Note: Higher values reduce cacheability (see [isCacheable]).
  final int? n;

  /// Optional list of stop sequences.
  ///
  /// When the model encounters any of these sequences, it will stop generating.
  /// Useful for controlling output format or preventing unwanted content.
  ///
  /// **Example:**
  /// ```dart
  /// ChatRequest(
  ///   messages: [...],
  ///   stop: ['\n\nHuman:', '\n\nAssistant:'],
  /// )
  /// ```
  final List<String>? stop;

  /// Optional user identifier for tracking and abuse prevention.
  ///
  /// Some providers use this to monitor API usage and prevent abuse.
  /// Can be a user ID, session ID, or any identifier that helps track
  /// requests from a specific user or application.
  final String? user;

  /// Optional provider-specific configuration options.
  ///
  /// Allows passing provider-specific parameters that aren't part of the
  /// standard API. Keys should be provider IDs (e.g., "openai", "anthropic").
  ///
  /// **Example:**
  /// ```dart
  /// ChatRequest(
  ///   messages: [...],
  ///   providerOptions: {
  ///     'openai': {
  ///       'presence_penalty': 0.6,
  ///       'frequency_penalty': 0.3,
  ///     },
  ///     'anthropic': {
  ///       'max_tokens': 4096,
  ///     },
  ///   },
  /// )
  /// ```
  final Map<String, Map<String, dynamic>>? providerOptions;

  /// Controls randomness in the model's output.
  ///
  /// Temperature determines how "creative" or "focused" the model's responses are:
  /// - **Lower values (0.0-0.3)**: More focused, deterministic, and consistent
  /// - **Medium values (0.4-0.7)**: Balanced creativity and coherence (default)
  /// - **Higher values (0.8-1.0)**: More creative, diverse, and unpredictable
  ///
  /// **Example:**
  /// - `temperature: 0.0` - Very focused, fact-based responses
  /// - `temperature: 0.7` - Balanced (good for most use cases)
  /// - `temperature: 1.0` - Very creative, can be inconsistent
  ///
  /// Note: Lower temperatures improve cacheability (see [isCacheable]).
  final double? temperature;

  /// Creates a new [ChatRequest] instance.
  ///
  /// [messages] is required and must not be empty. All other fields are optional.
  ///
  /// **Validation:**
  /// - [messages] must not be empty
  /// - [maxTokens] must be positive if provided
  /// - [temperature] should be between 0.0 and 2.0 (provider-dependent)
  /// - [n] must be positive if provided
  ///
  /// **Example:**
  /// ```dart
  /// final request = ChatRequest(
  ///   messages: [
  ///     Message(role: Role.user, content: 'Hello!'),
  ///   ],
  ///   maxTokens: 100,
  ///   temperature: 0.7,
  /// );
  /// ```
  ChatRequest({
    required this.messages,
    this.model,
    this.maxTokens,
    this.temperature,
    this.topP,
    this.n,
    this.stop,
    this.user,
    this.providerOptions,
  })  : assert(messages.isNotEmpty, 'messages must not be empty'),
        assert(
            maxTokens == null || maxTokens > 0, 'maxTokens must be positive'),
        assert(n == null || n > 0, 'n must be positive'),
        assert(
            temperature == null || (temperature >= 0.0 && temperature <= 2.0),
            'temperature must be between 0.0 and 2.0');

  /// Converts this [ChatRequest] to a JSON map.
  ///
  /// The resulting map is compatible with most AI provider APIs.
  /// Only non-null optional fields are included in the output.
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "messages": [
  ///     {"role": "user", "content": "Hello!"}
  ///   ],
  ///   "model": "gpt-4",
  ///   "max_tokens": 500,
  ///   "temperature": 0.7,
  ///   "top_p": 0.95,
  ///   "n": 1,
  ///   "stop": ["\n\n"],
  ///   "user": "user-123"
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'messages': messages.map((m) => m.toJson()).toList(),
      if (model != null) 'model': model,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (n != null) 'n': n,
      if (stop != null) 'stop': stop,
      if (user != null) 'user': user,
      if (providerOptions != null) 'provider_options': providerOptions,
    };
  }

  /// Creates a [ChatRequest] instance from a JSON map.
  ///
  /// Parses the JSON representation of a chat request into a [ChatRequest] object.
  /// Handles both camelCase and snake_case field names for compatibility.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "messages": [
  ///     {"role": "user", "content": "Hello!"}
  ///   ],
  ///   "model": "gpt-4",
  ///   "max_tokens": 500,
  ///   "temperature": 0.7
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory ChatRequest.fromJson(Map<String, dynamic> json) {
    final messagesJson = json['messages'] as List<dynamic>?;
    if (messagesJson == null || messagesJson.isEmpty) {
      throw FormatException('messages field is required and must not be empty');
    }

    return ChatRequest(
      messages: messagesJson
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList(),
      model: json['model'] as String?,
      maxTokens: json['maxTokens'] as int? ?? json['max_tokens'] as int?,
      temperature: json['temperature'] as double?,
      topP: json['topP'] as double? ?? json['top_p'] as double?,
      n: json['n'] as int?,
      stop:
          json['stop'] != null ? List<String>.from(json['stop'] as List) : null,
      user: json['user'] as String?,
      providerOptions:
          json['providerOptions'] as Map<String, Map<String, dynamic>>? ??
              json['provider_options'] as Map<String, Map<String, dynamic>>?,
    );
  }

  /// Creates a copy of this [ChatRequest] with the given fields replaced.
  ///
  /// Returns a new instance with updated fields. Fields not specified
  /// remain unchanged.
  ///
  /// **Example:**
  /// ```dart
  /// final original = ChatRequest(
  ///   messages: [Message(role: Role.user, content: 'Hello')],
  ///   temperature: 0.7,
  /// );
  ///
  /// final updated = original.copyWith(temperature: 0.9);
  /// // updated.temperature is 0.9, messages unchanged
  /// ```
  ChatRequest copyWith({
    List<Message>? messages,
    Object? model = _undefined,
    int? maxTokens,
    double? temperature,
    double? topP,
    int? n,
    List<String>? stop,
    Object? user = _undefined,
    Map<String, Map<String, dynamic>>? providerOptions,
  }) {
    return ChatRequest(
      messages: messages ?? this.messages,
      model: model == _undefined ? this.model : model as String?,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      n: n ?? this.n,
      stop: stop ?? this.stop,
      user: user == _undefined ? this.user : user as String?,
      providerOptions: providerOptions ?? this.providerOptions,
    );
  }

  /// Whether this request is cacheable.
  ///
  /// A request is cacheable if:
  /// - [temperature] is 0 (deterministic)
  /// - [n] is 1 (single response)
  ///
  /// Cached requests can be reused without making new API calls, reducing
  /// costs and improving response times for identical inputs.
  ///
  /// **Example:**
  /// ```dart
  /// final request = ChatRequest(
  ///   messages: [...],
  ///   temperature: 0.0, // Deterministic
  ///   n: 1, // Single response
  /// );
  ///
  /// if (request.isCacheable) {
  ///   // Can be cached
  /// }
  /// ```
  bool get isCacheable => temperature == 0 && (n == null || n == 1);

  @override
  String toString() {
    final parts = <String>[
      'messages: ${messages.length}',
      if (model != null) 'model: $model',
      if (maxTokens != null) 'maxTokens: $maxTokens',
      if (temperature != null) 'temperature: $temperature',
    ];
    return 'ChatRequest(${parts.join(', ')})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatRequest &&
        _listEquals(other.messages, messages) &&
        other.model == model &&
        other.maxTokens == maxTokens &&
        other.temperature == temperature &&
        other.topP == topP &&
        other.n == n &&
        _listEquals(other.stop, stop) &&
        other.user == user &&
        _mapEquals(other.providerOptions, providerOptions);
  }

  @override
  int get hashCode {
    int stopHash = 0;
    if (stop != null) {
      for (final item in stop!) {
        stopHash = Object.hash(stopHash, item);
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
      Object.hashAll(messages),
      model,
      maxTokens,
      temperature,
      topP,
      n,
      stopHash,
      user,
      providerOptionsHash,
    );
  }

  /// Helper method to compare lists for equality.
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Helper method to compare maps for equality.
  bool _mapEquals(
    Map<String, Map<String, dynamic>>? a,
    Map<String, Map<String, dynamic>>? b,
  ) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      // Deep comparison of nested maps
      final aValue = a[key]!;
      final bValue = b[key]!;
      if (aValue.length != bValue.length) return false;
      for (final nestedKey in aValue.keys) {
        if (aValue[nestedKey] != bValue[nestedKey]) return false;
      }
    }
    return true;
  }

  /// Private constant for copyWith null handling.
  static const _undefined = Object();
}
