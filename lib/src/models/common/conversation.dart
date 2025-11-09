import 'package:collection/collection.dart'; // For listEquals and mapEquals
import 'message.dart';

/// Represents a conversation session with a history of messages.
///
/// A [Conversation] is a container for managing multi-turn conversations
/// with AI providers. It maintains a chronological list of messages,
/// metadata, and timestamps for tracking conversation state.
///
/// **Key Features:**
/// - Unique identifier for each conversation
/// - Chronological message history
/// - Creation and update timestamps
/// - Extensible metadata for custom data
/// - JSON serialization/deserialization
///
/// **Example usage:**
/// ```dart
/// final conversation = Conversation(
///   id: 'conv-123',
///   messages: [
///     Message(role: Role.user, content: 'Hello!'),
///     Message(role: Role.assistant, content: 'Hi there!'),
///   ],
///   metadata: {'topic': 'greeting'},
/// );
///
/// // Add a message
/// conversation.messages.add(
///   Message(role: Role.user, content: 'How are you?'),
/// );
/// conversation.updatedAt = DateTime.now();
///
/// // Serialize to JSON
/// final json = conversation.toJson();
/// ```
///
/// **Thread Safety:**
/// This class is not thread-safe. If you need thread-safe access,
/// wrap it with synchronization primitives or use it within a single isolate.
class Conversation {
  /// Unique identifier for this conversation.
  ///
  /// This ID is used to retrieve and manage the conversation.
  /// It should be unique across all conversations.
  final String id;

  /// List of messages in chronological order.
  ///
  /// Messages are added in the order they occur in the conversation.
  /// The list can be modified directly, but you should update [updatedAt]
  /// when making changes.
  final List<Message> messages;

  /// Timestamp when the conversation was created.
  ///
  /// This is set when the conversation is first created and never changes.
  final DateTime createdAt;

  /// Timestamp when the conversation was last updated.
  ///
  /// This should be updated whenever messages are added or modified.
  /// It defaults to [createdAt] if not specified.
  DateTime updatedAt;

  /// Optional metadata associated with this conversation.
  ///
  /// Can be used to store custom data like:
  /// - Conversation topic or category
  /// - User preferences
  /// - Provider-specific settings
  /// - Custom tags or labels
  ///
  /// The map is unmodifiable after creation to ensure immutability
  /// of the conversation's metadata.
  final Map<String, dynamic> metadata;

  /// Creates a new [Conversation] instance.
  ///
  /// **Parameters:**
  /// - [id]: Unique identifier for the conversation (required)
  /// - [messages]: Initial list of messages (defaults to empty list)
  /// - [createdAt]: Creation timestamp (defaults to current time)
  /// - [updatedAt]: Last update timestamp (defaults to [createdAt])
  /// - [metadata]: Optional metadata map (defaults to empty map)
  ///
  /// **Example:**
  /// ```dart
  /// final conversation = Conversation(
  ///   id: 'conv-123',
  ///   messages: [
  ///     Message(role: Role.user, content: 'Hello'),
  ///   ],
  ///   metadata: {'topic': 'greeting'},
  /// );
  /// ```
  Conversation({
    required this.id,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now()),
        metadata = Map<String, dynamic>.unmodifiable(metadata ?? {});

  /// Creates a copy of this [Conversation] with the given fields replaced.
  ///
  /// **Parameters:**
  /// - [id]: New ID (if provided)
  /// - [messages]: New messages list (if provided)
  /// - [createdAt]: New creation timestamp (if provided)
  /// - [updatedAt]: New update timestamp (if provided)
  /// - [metadata]: New metadata map (if provided)
  ///
  /// **Returns:**
  /// A new [Conversation] instance with the specified fields updated.
  ///
  /// **Example:**
  /// ```dart
  /// final updated = conversation.copyWith(
  ///   updatedAt: DateTime.now(),
  ///   metadata: {'topic': 'updated'},
  /// );
  /// ```
  Conversation copyWith({
    String? id,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      id: id ?? this.id,
      messages: messages ?? List<Message>.from(this.messages),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
    );
  }

  /// Converts this [Conversation] to a JSON map.
  ///
  /// **Returns:**
  /// A map containing all conversation data in JSON-serializable format.
  ///
  /// **Example:**
  /// ```dart
  /// final json = conversation.toJson();
  /// // {
  /// //   'id': 'conv-123',
  /// //   'messages': [...],
  /// //   'created_at': '2024-01-01T00:00:00.000Z',
  /// //   'updated_at': '2024-01-01T00:00:00.000Z',
  /// //   'metadata': {...}
  /// // }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messages': messages.map((m) => m.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Creates a [Conversation] from a JSON map.
  ///
  /// **Parameters:**
  /// - [json]: A map containing conversation data in JSON format
  ///
  /// **Returns:**
  /// A new [Conversation] instance parsed from the JSON data.
  ///
  /// **Throws:**
  /// - [FormatException] if the JSON data is invalid or missing required fields
  ///
  /// **Example:**
  /// ```dart
  /// final conversation = Conversation.fromJson({
  ///   'id': 'conv-123',
  ///   'messages': [
  ///     {'role': 'user', 'content': 'Hello'},
  ///   ],
  ///   'created_at': '2024-01-01T00:00:00.000Z',
  ///   'updated_at': '2024-01-01T00:00:00.000Z',
  ///   'metadata': {},
  /// });
  /// ```
  factory Conversation.fromJson(Map<String, dynamic> json) {
    try {
      return Conversation(
        id: json['id'] as String,
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => Message.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      );
    } catch (e) {
      throw FormatException(
        'Failed to parse Conversation from JSON: $e',
        json,
      );
    }
  }

  /// Gets the number of messages in this conversation.
  int get messageCount => messages.length;

  /// Checks if this conversation is empty (has no messages).
  bool get isEmpty => messages.isEmpty;

  /// Checks if this conversation has messages.
  bool get isNotEmpty => messages.isNotEmpty;

  /// Gets the last message in the conversation, if any.
  Message? get lastMessage => messages.isEmpty ? null : messages.last;

  /// Gets the first message in the conversation, if any.
  Message? get firstMessage => messages.isEmpty ? null : messages.first;

  @override
  String toString() {
    return 'Conversation(id: $id, messages: ${messages.length}, '
        'createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is! Conversation) return false;

    // Compare messages using ListEquality (Message already implements equality)
    if (!const ListEquality<Message>().equals(other.messages, messages)) {
      return false;
    }

    // Compare metadata using MapEquality
    if (!const MapEquality<String, dynamic>().equals(
      other.metadata,
      metadata,
    )) {
      return false;
    }

    return other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      const ListEquality<Message>().hash(messages),
      createdAt,
      updatedAt,
      const MapEquality<String, dynamic>().hash(metadata),
    );
  }
}
