/// Represents a single event in a streaming chat response.
///
/// [ChatStreamEvent] is used to represent incremental updates from AI providers
/// during streaming chat responses. Each event contains a text delta (the new
/// content since the last event), a completion flag, and optional metadata.
///
/// **Key Features:**
/// - **Delta content**: Incremental text chunks as they're generated
/// - **Done flag**: Indicates when the stream has completed
/// - **Metadata**: Optional provider-specific information (usage, finish reason, etc.)
///
/// **Streaming Flow:**
/// 1. Multiple events with `delta` text and `done: false` are emitted
/// 2. Final event with `delta: null` and `done: true` signals completion
///
/// **Example usage:**
/// ```dart
/// final stream = ai.chatStream(request: chatRequest);
///
/// await for (final event in stream) {
///   if (event.delta != null) {
///     // Append delta to accumulated text
///     accumulatedText += event.delta;
///     print(event.delta); // Print incrementally
///   }
///
///   if (event.done) {
///     // Stream completed
///     print('Final text: $accumulatedText');
///     if (event.metadata != null) {
///       print('Usage: ${event.metadata!['usage']}');
///     }
///   }
/// }
/// ```
///
/// **Provider Differences:**
/// Different providers may structure their streaming responses differently:
/// - **OpenAI**: Emits deltas with content chunks, final event may include usage
/// - **Anthropic**: Similar structure but may include different metadata
/// - **Google**: May include additional fields in metadata
///
/// The [metadata] field allows providers to include provider-specific information
/// like token usage, finish reasons, or other details that don't fit in the
/// standard delta/done structure.
class ChatStreamEvent {
  /// The incremental text content for this event.
  ///
  /// This is the new text generated since the last event. For most providers,
  /// this is typically a word, phrase, or sentence fragment. Multiple events
  /// are emitted during generation, each containing the next piece of text.
  ///
  /// **Null cases:**
  /// - `null` when `done` is `true` (final event)
  /// - `null` for events that don't contain content (e.g., metadata-only events)
  ///
  /// **Example:**
  /// ```dart
  /// // Event 1: delta = "Hello"
  /// // Event 2: delta = ", "
  /// // Event 3: delta = "world"
  /// // Event 4: delta = "!"
  /// // Event 5: delta = null, done = true
  /// ```
  final String? delta;

  /// Indicates whether the stream has completed.
  ///
  /// - `false`: More events are coming (stream is still active)
  /// - `true`: This is the final event (stream has ended)
  ///
  /// **Important:** Always check `done` to know when to stop listening to
  /// the stream. The final event typically has `delta: null` and `done: true`.
  ///
  /// **Example:**
  /// ```dart
  /// await for (final event in stream) {
  ///   if (event.done) {
  ///     print('Stream completed');
  ///     break; // Exit loop
  ///   }
  ///   // Process delta...
  /// }
  /// ```
  final bool done;

  /// Optional metadata for this event.
  ///
  /// Contains provider-specific information that may be included in streaming
  /// events. Common metadata fields:
  ///
  /// - **usage**: Token usage statistics (typically in final event)
  /// - **finish_reason**: Why generation stopped (e.g., "stop", "length")
  /// - **model**: The model used for generation
  /// - **provider-specific fields**: Additional fields from the provider
  ///
  /// **Note:** Metadata structure varies by provider. Check provider documentation
  /// for specific fields available.
  ///
  /// **Example:**
  /// ```dart
  /// if (event.metadata != null) {
  ///   final usage = event.metadata!['usage'];
  ///   if (usage != null) {
  ///     print('Tokens used: ${usage['total_tokens']}');
  ///   }
  /// }
  /// ```
  final Map<String, dynamic>? metadata;

  /// Creates a new [ChatStreamEvent] instance.
  ///
  /// **Parameters:**
  /// - [delta]: The incremental text content. Can be null for final events.
  /// - [done]: Whether the stream has completed. Required.
  /// - [metadata]: Optional metadata map. Can be null.
  ///
  /// **Example:**
  /// ```dart
  /// // Content event
  /// final contentEvent = ChatStreamEvent(
  ///   delta: 'Hello, ',
  ///   done: false,
  /// );
  ///
  /// // Final event with metadata
  /// final finalEvent = ChatStreamEvent(
  ///   delta: null,
  ///   done: true,
  ///   metadata: {
  ///     'usage': {'total_tokens': 150},
  ///     'finish_reason': 'stop',
  ///   },
  /// );
  /// ```
  const ChatStreamEvent({
    this.delta,
    required this.done,
    this.metadata,
  });

  /// Converts this [ChatStreamEvent] to a JSON map.
  ///
  /// Useful for serialization, logging, or sending to analytics services.
  ///
  /// **Returns:**
  /// A JSON-compatible map representation of this event.
  ///
  /// **Example:**
  /// ```dart
  /// final event = ChatStreamEvent(
  ///   delta: 'Hello',
  ///   done: false,
  ///   metadata: {'model': 'gpt-4'},
  /// );
  ///
  /// final json = event.toJson();
  /// // {
  /// //   'delta': 'Hello',
  /// //   'done': false,
  /// //   'metadata': {'model': 'gpt-4'}
  /// // }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      if (delta != null) 'delta': delta,
      'done': done,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Creates a [ChatStreamEvent] instance from a JSON map.
  ///
  /// Parses the JSON representation of a streaming event into a [ChatStreamEvent] object.
  ///
  /// **Parameters:**
  /// - [json]: A JSON map containing event data
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "delta": "Hello, ",
  ///   "done": false,
  ///   "metadata": {
  ///     "model": "gpt-4"
  ///   }
  /// }
  /// ```
  ///
  /// **Returns:**
  /// A [ChatStreamEvent] instance parsed from the JSON.
  factory ChatStreamEvent.fromJson(Map<String, dynamic> json) {
    return ChatStreamEvent(
      delta: json['delta'] as String?,
      done: json['done'] as bool,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Creates a copy of this [ChatStreamEvent] with the given fields replaced.
  ///
  /// Returns a new instance with updated fields. Fields not specified remain
  /// unchanged. Useful for creating variations of an event.
  ///
  /// **Note:** To set a nullable field to null, you must explicitly pass null.
  /// Passing no value for a parameter keeps the existing value.
  ///
  /// **Parameters:**
  /// - [delta]: New delta value. Pass null explicitly to set to null.
  /// - [done]: New done value, or null to keep existing
  /// - [metadata]: New metadata map. Pass null explicitly to set to null.
  ///
  /// **Example:**
  /// ```dart
  /// final event = ChatStreamEvent(delta: 'Hello', done: false);
  ///
  /// // Add metadata
  /// final withMetadata = event.copyWith(
  ///   metadata: {'model': 'gpt-4'},
  /// );
  ///
  /// // Mark as done and clear delta
  /// final finalEvent = event.copyWith(
  ///   delta: null,  // Explicitly set to null
  ///   done: true,
  /// );
  /// ```
  ChatStreamEvent copyWith({
    Object? delta = _sentinel,
    bool? done,
    Object? metadata = _sentinel,
  }) {
    return ChatStreamEvent(
      delta: delta == _sentinel ? this.delta : delta as String?,
      done: done ?? this.done,
      metadata: metadata == _sentinel
          ? this.metadata
          : metadata as Map<String, dynamic>?,
    );
  }

  /// Sentinel value to distinguish between "not provided" and "provided as null".
  static const _sentinel = Object();

  @override
  String toString() {
    final deltaStr = delta != null ? "'$delta'" : 'null';
    final metadataStr =
        metadata != null ? ', metadata: ${metadata.toString()}' : '';
    return 'ChatStreamEvent(delta: $deltaStr, done: $done$metadataStr)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatStreamEvent &&
        other.delta == delta &&
        other.done == done &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      delta,
      done,
      metadata != null ? _mapHashCode(metadata!) : null,
    );
  }

  /// Helper method to compare maps for equality.
  bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }

    return true;
  }

  /// Helper method to compute hash code for a map.
  int _mapHashCode(Map<String, dynamic> map) {
    int hash = 0;
    for (final entry in map.entries) {
      hash = Object.hash(hash, entry.key, entry.value);
    }
    return hash;
  }
}
