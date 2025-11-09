import 'dart:math';
import '../error/error_types.dart';
import '../models/common/conversation.dart';
import '../models/common/message.dart';

/// Manages multiple conversation sessions with message history.
///
/// The [ConversationManager] provides a centralized way to create, retrieve,
/// and manage conversation sessions. It maintains an in-memory cache of
/// active conversations and provides methods to add messages and retrieve
/// conversation context.
///
/// **Key Features:**
/// - Create and manage multiple conversation sessions
/// - Add messages to conversations
/// - Retrieve conversation context with optional token limiting
/// - Delete conversations
/// - List all active conversations
///
/// **Example usage:**
/// ```dart
/// final manager = ConversationManager();
///
/// // Create a new conversation
/// final conversation = manager.create();
/// print('Created conversation: ${conversation.id}');
///
/// // Add messages
/// await manager.addMessage(conversation.id, Message(
///   role: Role.user,
///   content: 'Hello!',
/// ));
///
/// // Get conversation context
/// final context = manager.getContext(conversation.id, maxTokens: 100);
///
/// // Retrieve conversation
/// final retrieved = manager.get(conversation.id);
/// ```
///
/// **Thread Safety:**
/// This class is not thread-safe. If you need thread-safe access,
/// wrap it with synchronization primitives or use it within a single isolate.
class ConversationManager {
  /// In-memory storage for active conversations.
  ///
  /// Maps conversation IDs to [Conversation] instances.
  final Map<String, Conversation> _sessions = {};

  /// Creates a new [ConversationManager] instance.
  ///
  /// The manager starts with an empty session map.
  ConversationManager();

  /// Creates a new conversation session.
  ///
  /// **Parameters:**
  /// - [id]: Optional custom ID for the conversation. If not provided,
  ///   a unique ID will be generated automatically.
  ///
  /// **Returns:**
  /// A new [Conversation] instance with the specified or generated ID.
  ///
  /// **Example:**
  /// ```dart
  /// // Create with auto-generated ID
  /// final conv1 = manager.create();
  ///
  /// // Create with custom ID
  /// final conv2 = manager.create(id: 'my-conversation');
  /// ```
  Conversation create({String? id}) {
    final conversationId = id ?? _generateId();

    // Check if ID already exists
    if (_sessions.containsKey(conversationId)) {
      throw ClientError(
        message: 'Conversation with ID "$conversationId" already exists',
        code: 'DUPLICATE_CONVERSATION',
      );
    }

    final conversation = Conversation(
      id: conversationId,
      messages: [],
      metadata: {},
    );

    _sessions[conversationId] = conversation;
    return conversation;
  }

  /// Retrieves a conversation by its ID.
  ///
  /// **Parameters:**
  /// - [id]: The unique identifier of the conversation to retrieve.
  ///
  /// **Returns:**
  /// The [Conversation] instance if found, or `null` if not found.
  ///
  /// **Example:**
  /// ```dart
  /// final conversation = manager.get('conv-123');
  /// if (conversation != null) {
  ///   print('Found conversation with ${conversation.messageCount} messages');
  /// }
  /// ```
  Conversation? get(String id) {
    return _sessions[id];
  }

  /// Adds a message to an existing conversation.
  ///
  /// **Parameters:**
  /// - [id]: The unique identifier of the conversation.
  /// - [message]: The [Message] to add to the conversation.
  ///
  /// **Throws:**
  /// - [ClientError] if the conversation is not found.
  ///
  /// **Example:**
  /// ```dart
  /// await manager.addMessage('conv-123', Message(
  ///   role: Role.user,
  ///   content: 'Hello, how are you?',
  /// ));
  /// ```
  Future<void> addMessage(String id, Message message) async {
    final conversation = get(id);
    if (conversation == null) {
      throw ClientError(
        message: 'Conversation with ID "$id" not found',
        code: 'CONVERSATION_NOT_FOUND',
      );
    }

    conversation.messages.add(message);
    conversation.updatedAt = DateTime.now();
  }

  /// Retrieves the conversation context (messages) with optional token limiting.
  ///
  /// **Parameters:**
  /// - [id]: The unique identifier of the conversation.
  /// - [maxTokens]: Optional maximum number of tokens to include in the context.
  ///   If provided, the method will return the most recent messages that fit
  ///   within the token limit. If `null`, all messages are returned.
  ///
  /// **Returns:**
  /// A list of [Message] objects representing the conversation context.
  /// Returns an empty list if the conversation is not found.
  ///
  /// **Note:**
  /// Token counting is approximate and based on a simple heuristic
  /// (roughly 4 characters per token). For accurate token counting,
  /// consider using a proper tokenizer.
  ///
  /// **Example:**
  /// ```dart
  /// // Get all messages
  /// final allMessages = manager.getContext('conv-123');
  ///
  /// // Get messages within token limit
  /// final limitedMessages = manager.getContext('conv-123', maxTokens: 1000);
  /// ```
  List<Message> getContext(String id, {int? maxTokens}) {
    final conversation = get(id);
    if (conversation == null) {
      return [];
    }

    // If no token limit, return all messages
    if (maxTokens == null) {
      return List<Message>.from(conversation.messages);
    }

    // Apply context windowing
    return _applyContextWindow(conversation.messages, maxTokens);
  }

  /// Deletes a conversation from the manager.
  ///
  /// **Parameters:**
  /// - [id]: The unique identifier of the conversation to delete.
  ///
  /// **Returns:**
  /// `true` if the conversation was found and deleted, `false` otherwise.
  ///
  /// **Example:**
  /// ```dart
  /// final deleted = manager.delete('conv-123');
  /// if (deleted) {
  ///   print('Conversation deleted');
  /// }
  /// ```
  bool delete(String id) {
    final removed = _sessions.remove(id);
    return removed != null;
  }

  /// Lists all active conversations.
  ///
  /// **Returns:**
  /// A list of all [Conversation] instances currently managed.
  ///
  /// **Example:**
  /// ```dart
  /// final allConversations = manager.listAll();
  /// print('Active conversations: ${allConversations.length}');
  /// ```
  List<Conversation> listAll() {
    return List<Conversation>.from(_sessions.values);
  }

  /// Gets the number of active conversations.
  ///
  /// **Returns:**
  /// The count of active conversations.
  int get count => _sessions.length;

  /// Checks if a conversation exists.
  ///
  /// **Parameters:**
  /// - [id]: The unique identifier of the conversation to check.
  ///
  /// **Returns:**
  /// `true` if the conversation exists, `false` otherwise.
  bool has(String id) {
    return _sessions.containsKey(id);
  }

  /// Clears all conversations from the manager.
  ///
  /// **Warning:**
  /// This operation cannot be undone. All conversation data will be lost.
  ///
  /// **Example:**
  /// ```dart
  /// manager.clear();
  /// print('All conversations cleared');
  /// ```
  void clear() {
    _sessions.clear();
  }

  /// Generates a unique conversation ID.
  ///
  /// The ID format is: `conv_<timestamp>_<random>`
  ///
  /// **Returns:**
  /// A unique string identifier.
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'conv_${timestamp}_$random';
  }

  /// Applies context windowing to limit messages by token count.
  ///
  /// This method returns the most recent messages that fit within the
  /// specified token limit, prioritizing newer messages.
  ///
  /// **Parameters:**
  /// - [messages]: The list of messages to filter.
  /// - [maxTokens]: The maximum number of tokens allowed.
  ///
  /// **Returns:**
  /// A list of messages that fit within the token limit, in chronological order.
  ///
  /// **Note:**
  /// Token counting uses a simple heuristic: approximately 4 characters per token.
  /// This is an approximation and may not match exact tokenizer counts.
  List<Message> _applyContextWindow(List<Message> messages, int maxTokens) {
    if (messages.isEmpty) {
      return [];
    }

    // Simple token estimation: ~4 characters per token
    // This is a rough approximation
    int estimateTokens(String text) {
      // Rough estimate: 4 chars per token, with minimum of 1 token
      return (text.length / 4).ceil().clamp(1, text.length);
    }

    // Calculate tokens for each message
    final messageTokens = messages.map((msg) {
      // Estimate tokens for content
      int tokens = estimateTokens(msg.content);

      // Add overhead for role, name, and metadata
      if (msg.name != null) {
        tokens += estimateTokens(msg.name!);
      }
      if (msg.meta != null) {
        // Rough estimate for metadata (JSON overhead)
        tokens += 10;
      }

      return tokens;
    }).toList();

    // Start from the end and work backwards to include most recent messages
    final result = <Message>[];
    int totalTokens = 0;

    for (int i = messages.length - 1; i >= 0; i--) {
      final messageTokenCount = messageTokens[i];

      // If adding this message would exceed the limit, stop
      if (totalTokens + messageTokenCount > maxTokens) {
        break;
      }

      // Add message to the beginning of result (to maintain chronological order)
      result.insert(0, messages[i]);
      totalTokens += messageTokenCount;
    }

    return result;
  }
}
