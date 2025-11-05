import '../base_enums.dart';

/// Represents a message in a chat conversation.
///
/// Messages are the fundamental building blocks of conversations with AI models.
/// Each message has a [role] (system, user, assistant, or function) and [content]
/// (the actual text). Optional fields include [name] (for function calls) and
/// [meta] (for additional metadata).
///
/// **Example usage:**
/// ```dart
/// final userMessage = Message(
///   role: Role.user,
///   content: 'Hello, how are you?',
/// );
///
/// final systemMessage = Message(
///   role: Role.system,
///   content: 'You are a helpful assistant.',
/// );
/// ```
class Message {
  /// The role of the message sender.
  ///
  /// Determines how the message should be interpreted by the AI model:
  /// - [Role.system]: Instructions or context for the model
  /// - [Role.user]: Input from the end user
  /// - [Role.assistant]: Response from the AI model
  /// - [Role.function]: Function call results or definitions
  final Role role;

  /// The text content of the message.
  ///
  /// This is the actual message text that will be sent to or received from
  /// the AI provider.
  final String content;

  /// Optional name for the message sender.
  ///
  /// Used primarily for function calling scenarios where multiple functions
  /// or users need to be distinguished. Typically used with [Role.function].
  final String? name;

  /// Optional metadata associated with the message.
  ///
  /// Can contain provider-specific fields or custom metadata that doesn't
  /// fit into the standard message structure.
  final Map<String, dynamic>? meta;

  /// Creates a new [Message] instance.
  ///
  /// [role] and [content] are required. [name] and [meta] are optional.
  const Message({
    required this.role,
    required this.content,
    this.name,
    this.meta,
  });

  /// Converts this [Message] to a JSON map.
  ///
  /// The resulting map is compatible with most AI provider APIs.
  /// Only non-null optional fields are included in the output.
  ///
  /// **Example output:**
  /// ```json
  /// {
  ///   "role": "user",
  ///   "content": "Hello!",
  ///   "name": "Alice"
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
      if (name != null) 'name': name,
      if (meta != null) 'meta': meta,
    };
  }

  /// Creates a [Message] instance from a JSON map.
  ///
  /// Parses the JSON representation of a message into a [Message] object.
  /// Handles the role enum conversion and optional fields.
  ///
  /// **Example input:**
  /// ```json
  /// {
  ///   "role": "assistant",
  ///   "content": "Hello! How can I help you?"
  /// }
  /// ```
  ///
  /// Throws a [FormatException] if the JSON is invalid or missing required fields.
  factory Message.fromJson(Map<String, dynamic> json) {
    final roleString = json['role'] as String;
    final role = Role.values.firstWhere(
      (r) => r.name == roleString,
      orElse: () => throw FormatException(
        'Invalid role: $roleString. Expected one of: ${Role.values.map((r) => r.name).join(", ")}',
      ),
    );

    return Message(
      role: role,
      content: json['content'] as String,
      name: json['name'] as String?,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }

  /// Creates a copy of this [Message] with the given fields replaced.
  ///
  /// Returns a new [Message] instance with the same values as this one,
  /// except for the fields explicitly provided.
  Message copyWith({
    Role? role,
    String? content,
    String? name,
    Map<String, dynamic>? meta,
  }) {
    return Message(
      role: role ?? this.role,
      content: content ?? this.content,
      name: name ?? this.name,
      meta: meta ?? this.meta,
    );
  }

  @override
  String toString() {
    return 'Message(role: $role, content: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}${name != null ? ", name: $name" : ""}${meta != null ? ", meta: ..." : ""})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.role == role &&
        other.content == content &&
        other.name == name &&
        _mapEquals(other.meta, meta);
  }

  @override
  int get hashCode {
    return Object.hash(role, content, name, meta);
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
