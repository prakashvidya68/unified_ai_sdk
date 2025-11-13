import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/orchestrator/conversation_manager.dart';

void main() {
  group('ConversationManager', () {
    late ConversationManager manager;

    setUp(() {
      manager = ConversationManager();
    });

    group('create', () {
      test('should create conversation with auto-generated ID', () {
        final conversation = manager.create();

        expect(conversation, isNotNull);
        expect(conversation.id, isNotEmpty);
        expect(conversation.id, startsWith('conv_'));
        expect(conversation.messages, isEmpty);
        expect(conversation.metadata, isEmpty);
      });

      test('should create conversation with custom ID', () {
        final conversation = manager.create(id: 'my-conversation');

        expect(conversation.id, equals('my-conversation'));
        expect(conversation.messages, isEmpty);
        expect(manager.get('my-conversation'), equals(conversation));
      });

      test('should throw error when creating duplicate ID', () {
        manager.create(id: 'duplicate-id');

        expect(
          () => manager.create(id: 'duplicate-id'),
          throwsA(isA<ClientError>()),
        );
      });

      test('should create multiple conversations with different IDs', () {
        final conv1 = manager.create();
        final conv2 = manager.create();
        final conv3 = manager.create(id: 'custom-id');

        expect(conv1.id, isNot(equals(conv2.id)));
        expect(conv1.id, isNot(equals(conv3.id)));
        expect(conv2.id, isNot(equals(conv3.id)));
        expect(manager.count, equals(3));
      });
    });

    group('get', () {
      test('should return conversation when it exists', () {
        final created = manager.create(id: 'test-id');
        final retrieved = manager.get('test-id');

        expect(retrieved, isNotNull);
        expect(retrieved, equals(created));
      });

      test('should return null when conversation does not exist', () {
        final retrieved = manager.get('non-existent');

        expect(retrieved, isNull);
      });

      test('should return null for empty manager', () {
        expect(manager.get('any-id'), isNull);
      });
    });

    group('addMessage', () {
      test('should add message to existing conversation', () async {
        final conversation = manager.create(id: 'test-id');
        final message = const Message(
          role: Role.user,
          content: 'Hello!',
        );

        await manager.addMessage('test-id', message);

        expect(conversation.messages.length, equals(1));
        expect(conversation.messages.first, equals(message));
        expect(conversation.updatedAt, isNotNull);
      });

      test('should update updatedAt timestamp when adding message', () async {
        final conversation = manager.create(id: 'test-id');
        final originalUpdatedAt = conversation.updatedAt;

        // Wait a bit to ensure different timestamp
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await manager.addMessage(
          'test-id',
          const Message(role: Role.user, content: 'Test'),
        );

        expect(conversation.updatedAt, isNot(equals(originalUpdatedAt)));
      });

      test('should add multiple messages in order', () async {
        final conversation = manager.create(id: 'test-id');
        final message1 = const Message(role: Role.user, content: 'First');
        final message2 = const Message(role: Role.assistant, content: 'Second');
        final message3 = const Message(role: Role.user, content: 'Third');

        await manager.addMessage('test-id', message1);
        await manager.addMessage('test-id', message2);
        await manager.addMessage('test-id', message3);

        expect(conversation.messages.length, equals(3));
        expect(conversation.messages[0], equals(message1));
        expect(conversation.messages[1], equals(message2));
        expect(conversation.messages[2], equals(message3));
      });

      test('should throw error when conversation does not exist', () async {
        final message = const Message(role: Role.user, content: 'Test');

        expect(
          () => manager.addMessage('non-existent', message),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError with correct code', () async {
        final message = const Message(role: Role.user, content: 'Test');

        try {
          await manager.addMessage('non-existent', message);
          fail('Expected ClientError to be thrown');
        } on ClientError catch (e) {
          expect(e.code, equals('CONVERSATION_NOT_FOUND'));
          expect(e.message, contains('not found'));
        }
      });
    });

    group('getContext', () {
      test('should return all messages when maxTokens is null', () {
        final conversation = manager.create(id: 'test-id');
        conversation.messages.addAll([
          const Message(role: Role.user, content: 'First message'),
          const Message(role: Role.assistant, content: 'Second message'),
          const Message(role: Role.user, content: 'Third message'),
        ]);

        final context = manager.getContext('test-id');

        expect(context.length, equals(3));
        expect(context, equals(conversation.messages));
      });

      test('should return empty list when conversation does not exist', () {
        final context = manager.getContext('non-existent');

        expect(context, isEmpty);
      });

      test('should return empty list when conversation has no messages', () {
        manager.create(id: 'empty-id');
        final context = manager.getContext('empty-id');

        expect(context, isEmpty);
      });

      test('should limit messages by token count', () {
        final conversation = manager.create(id: 'test-id');
        // Add messages with varying lengths
        conversation.messages.addAll([
          const Message(role: Role.user, content: 'Short'),
          const Message(
            role: Role.assistant,
            content: 'This is a longer message that will take more tokens',
          ),
          const Message(role: Role.user, content: 'Another short one'),
        ]);

        // Request context with token limit
        final context = manager.getContext('test-id', maxTokens: 20);

        // Should return messages that fit within token limit
        // Starting from the most recent
        expect(context.length, lessThanOrEqualTo(3));
        expect(context.isNotEmpty, isTrue);
      });

      test('should prioritize recent messages when limiting', () {
        final conversation = manager.create(id: 'test-id');
        conversation.messages.addAll([
          const Message(role: Role.user, content: 'Old message 1'),
          const Message(role: Role.user, content: 'Old message 2'),
          const Message(role: Role.user, content: 'Recent message'),
        ]);

        final context = manager.getContext('test-id', maxTokens: 15);

        // Should include recent messages first
        expect(context.length, greaterThan(0));
        if (context.isNotEmpty) {
          // Most recent message should be included
          expect(context.last.content, contains('Recent'));
        }
      });

      test('should return all messages when token limit is very high', () {
        final conversation = manager.create(id: 'test-id');
        conversation.messages.addAll([
          const Message(role: Role.user, content: 'Message 1'),
          const Message(role: Role.user, content: 'Message 2'),
          const Message(role: Role.user, content: 'Message 3'),
        ]);

        final context = manager.getContext('test-id', maxTokens: 10000);

        expect(context.length, equals(3));
      });
    });

    group('delete', () {
      test('should delete existing conversation', () {
        manager.create(id: 'test-id');
        expect(manager.has('test-id'), isTrue);

        final deleted = manager.delete('test-id');

        expect(deleted, isTrue);
        expect(manager.has('test-id'), isFalse);
        expect(manager.get('test-id'), isNull);
      });

      test('should return false when deleting non-existent conversation', () {
        final deleted = manager.delete('non-existent');

        expect(deleted, isFalse);
      });

      test('should allow recreating conversation after deletion', () {
        manager.create(id: 'test-id');
        manager.delete('test-id');

        // Should be able to create again with same ID
        final newConversation = manager.create(id: 'test-id');
        expect(newConversation.id, equals('test-id'));
        expect(manager.has('test-id'), isTrue);
      });
    });

    group('listAll', () {
      test('should return empty list when no conversations exist', () {
        final all = manager.listAll();

        expect(all, isEmpty);
      });

      test('should return all conversations', () {
        final conv1 = manager.create();
        final conv2 = manager.create();
        final conv3 = manager.create();

        final all = manager.listAll();

        expect(all.length, equals(3));
        expect(all, contains(conv1));
        expect(all, contains(conv2));
        expect(all, contains(conv3));
      });

      test('should return updated list after deletion', () {
        final conv1 = manager.create();
        final conv2 = manager.create();
        manager.delete(conv1.id);

        final all = manager.listAll();

        expect(all.length, equals(1));
        expect(all, contains(conv2));
        expect(all, isNot(contains(conv1)));
      });
    });

    group('count', () {
      test('should return zero for empty manager', () {
        expect(manager.count, equals(0));
      });

      test('should return correct count after creating conversations', () {
        manager.create();
        manager.create();
        manager.create();

        expect(manager.count, equals(3));
      });

      test('should update count after deletion', () {
        final conv1 = manager.create();
        final conv2 = manager.create();
        expect(manager.count, equals(2));

        manager.delete(conv1.id);
        expect(manager.count, equals(1));

        manager.delete(conv2.id);
        expect(manager.count, equals(0));
      });
    });

    group('has', () {
      test('should return true for existing conversation', () {
        manager.create(id: 'test-id');

        expect(manager.has('test-id'), isTrue);
      });

      test('should return false for non-existent conversation', () {
        expect(manager.has('non-existent'), isFalse);
      });

      test('should return false after deletion', () {
        final conversation = manager.create(id: 'test-id');
        expect(manager.has('test-id'), isTrue);

        manager.delete(conversation.id);
        expect(manager.has('test-id'), isFalse);
      });
    });

    group('clear', () {
      test('should clear all conversations', () {
        manager.create();
        manager.create();
        manager.create();

        expect(manager.count, equals(3));

        manager.clear();

        expect(manager.count, equals(0));
        expect(manager.listAll(), isEmpty);
      });

      test('should allow creating conversations after clear', () {
        manager.create(id: 'test-id');
        manager.clear();

        final newConversation = manager.create(id: 'test-id');
        expect(newConversation.id, equals('test-id'));
        expect(manager.count, equals(1));
      });
    });

    group('integration', () {
      test('should handle full conversation lifecycle', () async {
        // Create conversation
        manager.create(id: 'lifecycle-test');

        // Add messages
        await manager.addMessage(
          'lifecycle-test',
          const Message(role: Role.user, content: 'Hello'),
        );
        await manager.addMessage(
          'lifecycle-test',
          const Message(role: Role.assistant, content: 'Hi there!'),
        );

        // Get context
        final context = manager.getContext('lifecycle-test');
        expect(context.length, equals(2));

        // Retrieve conversation
        final retrieved = manager.get('lifecycle-test');
        expect(retrieved, isNotNull);
        expect(retrieved!.messageCount, equals(2));

        // Delete
        final deleted = manager.delete('lifecycle-test');
        expect(deleted, isTrue);
        expect(manager.get('lifecycle-test'), isNull);
      });

      test('should handle multiple conversations independently', () async {
        final conv1 = manager.create(id: 'conv-1');
        final conv2 = manager.create(id: 'conv-2');

        await manager.addMessage(
          'conv-1',
          const Message(role: Role.user, content: 'Message 1'),
        );
        await manager.addMessage(
          'conv-2',
          const Message(role: Role.user, content: 'Message 2'),
        );

        expect(conv1.messages.length, equals(1));
        expect(conv2.messages.length, equals(1));
        expect(conv1.messages.first.content, equals('Message 1'));
        expect(conv2.messages.first.content, equals('Message 2'));
      });
    });
  });
}
