import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';
import 'package:unified_ai_sdk/src/models/common/conversation.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';

void main() {
  group('Conversation', () {
    test('should create conversation with required fields', () {
      final conversation = Conversation(
        id: 'conv-123',
        messages: [],
        metadata: {},
      );

      expect(conversation.id, equals('conv-123'));
      expect(conversation.messages, isEmpty);
      expect(conversation.metadata, isEmpty);
      expect(conversation.createdAt, isNotNull);
      expect(conversation.updatedAt, isNotNull);
    });

    test('should create conversation with default values', () {
      final conversation = Conversation(id: 'conv-123');

      expect(conversation.id, equals('conv-123'));
      expect(conversation.messages, isEmpty);
      expect(conversation.metadata, isEmpty);
      expect(conversation.createdAt, isNotNull);
      expect(conversation.updatedAt, equals(conversation.createdAt));
    });

    test('should create conversation with messages', () {
      final messages = [
        const Message(role: Role.user, content: 'Hello'),
        const Message(role: Role.assistant, content: 'Hi there!'),
      ];

      final conversation = Conversation(
        id: 'conv-123',
        messages: messages,
      );

      expect(conversation.messages.length, equals(2));
      expect(conversation.messages, equals(messages));
    });

    test('should create conversation with metadata', () {
      final metadata = {
        'topic': 'greeting',
        'user_id': 'user-123',
      };

      final conversation = Conversation(
        id: 'conv-123',
        metadata: metadata,
      );

      expect(conversation.metadata, equals(metadata));
      expect(conversation.metadata['topic'], equals('greeting'));
      expect(conversation.metadata['user_id'], equals('user-123'));
      // Note: metadata is unmodifiable, so it's a different instance but equal content
    });

    test('should create conversation with custom timestamps', () {
      final createdAt = DateTime(2024, 1, 1);
      final updatedAt = DateTime(2024, 1, 2);

      final conversation = Conversation(
        id: 'conv-123',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(conversation.createdAt, equals(createdAt));
      expect(conversation.updatedAt, equals(updatedAt));
    });

    test('should update updatedAt timestamp', () {
      final conversation = Conversation(id: 'conv-123');
      final originalUpdatedAt = conversation.updatedAt;

      // Wait a bit to ensure different timestamp
      Future.delayed(const Duration(milliseconds: 10), () {
        conversation.updatedAt = DateTime.now();
        expect(conversation.updatedAt, isNot(equals(originalUpdatedAt)));
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = Conversation(
          id: 'conv-123',
          messages: [const Message(role: Role.user, content: 'Hello')],
          metadata: {'topic': 'greeting'},
        );

        final updated = original.copyWith(
          id: 'conv-456',
          metadata: {'topic': 'farewell'},
        );

        expect(updated.id, equals('conv-456'));
        expect(updated.messages, equals(original.messages));
        expect(updated.metadata['topic'], equals('farewell'));
        expect(updated.createdAt, equals(original.createdAt));
      });

      test('should create copy with new messages', () {
        final original = Conversation(
          id: 'conv-123',
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        final newMessages = [
          const Message(role: Role.user, content: 'Hello'),
          const Message(role: Role.assistant, content: 'Hi!'),
        ];

        final updated = original.copyWith(messages: newMessages);

        expect(updated.messages.length, equals(2));
        expect(updated.messages, equals(newMessages));
        expect(original.messages.length, equals(1)); // Original unchanged
      });
    });

    group('toJson', () {
      test('should serialize conversation to JSON', () {
        final conversation = Conversation(
          id: 'conv-123',
          messages: [
            const Message(role: Role.user, content: 'Hello'),
            const Message(role: Role.assistant, content: 'Hi!'),
          ],
          metadata: {'topic': 'greeting'},
        );

        final json = conversation.toJson();

        expect(json['id'], equals('conv-123'));
        expect(json['messages'], isA<List<dynamic>>());
        expect(json['messages'].length, equals(2));
        expect(json['created_at'], isA<String>());
        expect(json['updated_at'], isA<String>());
        expect(json['metadata'], equals({'topic': 'greeting'}));
      });

      test('should serialize empty conversation to JSON', () {
        final conversation = Conversation(id: 'conv-123');
        final json = conversation.toJson();

        expect(json['id'], equals('conv-123'));
        expect(json['messages'], isEmpty);
        expect(json['metadata'], isEmpty);
      });
    });

    group('fromJson', () {
      test('should deserialize conversation from JSON', () {
        final json = {
          'id': 'conv-123',
          'messages': [
            {'role': 'user', 'content': 'Hello'},
            {'role': 'assistant', 'content': 'Hi!'},
          ],
          'created_at': '2024-01-01T00:00:00.000Z',
          'updated_at': '2024-01-02T00:00:00.000Z',
          'metadata': {'topic': 'greeting'},
        };

        final conversation = Conversation.fromJson(json);

        expect(conversation.id, equals('conv-123'));
        expect(conversation.messages.length, equals(2));
        expect(conversation.messages[0].content, equals('Hello'));
        expect(conversation.messages[1].content, equals('Hi!'));
        expect(conversation.metadata['topic'], equals('greeting'));
      });

      test('should handle missing optional fields in JSON', () {
        final json = <String, dynamic>{
          'id': 'conv-123',
          'messages': <Map<String, dynamic>>[],
          'created_at': '2024-01-01T00:00:00.000Z',
          'updated_at': '2024-01-01T00:00:00.000Z',
        };

        final conversation = Conversation.fromJson(json);

        expect(conversation.id, equals('conv-123'));
        expect(conversation.messages, isEmpty);
        expect(conversation.metadata, isEmpty);
      });

      test('should throw FormatException for invalid JSON', () {
        final invalidJson = {
          'id': 'conv-123',
          // Missing required fields
        };

        expect(
          () => Conversation.fromJson(invalidJson),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException for invalid timestamp', () {
        final invalidJson = <String, dynamic>{
          'id': 'conv-123',
          'messages': <Map<String, dynamic>>[],
          'created_at': 'invalid-date',
          'updated_at': '2024-01-01T00:00:00.000Z',
        };

        expect(
          () => Conversation.fromJson(invalidJson),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('JSON round-trip', () {
      test('should serialize and deserialize correctly', () {
        final original = Conversation(
          id: 'conv-123',
          messages: [
            const Message(role: Role.user, content: 'Hello'),
            const Message(role: Role.assistant, content: 'Hi!'),
          ],
          metadata: {'topic': 'greeting'},
        );

        final json = original.toJson();
        final restored = Conversation.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.messages.length, equals(original.messages.length));
        expect(
            restored.messages[0].content, equals(original.messages[0].content));
        expect(
            restored.messages[1].content, equals(original.messages[1].content));
        expect(restored.metadata, equals(original.metadata));
      });
    });

    group('convenience getters', () {
      test('should return correct message count', () {
        final conversation = Conversation(
          id: 'conv-123',
          messages: [
            const Message(role: Role.user, content: 'Hello'),
            const Message(role: Role.assistant, content: 'Hi!'),
          ],
        );

        expect(conversation.messageCount, equals(2));
      });

      test('should return true for isEmpty when no messages', () {
        final conversation = Conversation(id: 'conv-123');
        expect(conversation.isEmpty, isTrue);
        expect(conversation.isNotEmpty, isFalse);
      });

      test('should return false for isEmpty when messages exist', () {
        final conversation = Conversation(
          id: 'conv-123',
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        expect(conversation.isEmpty, isFalse);
        expect(conversation.isNotEmpty, isTrue);
      });

      test('should return last message', () {
        final messages = [
          const Message(role: Role.user, content: 'First'),
          const Message(role: Role.assistant, content: 'Last'),
        ];

        final conversation = Conversation(
          id: 'conv-123',
          messages: messages,
        );

        expect(conversation.lastMessage, equals(messages.last));
        expect(conversation.lastMessage?.content, equals('Last'));
      });

      test('should return null for lastMessage when empty', () {
        final conversation = Conversation(id: 'conv-123');
        expect(conversation.lastMessage, isNull);
      });

      test('should return first message', () {
        final messages = [
          const Message(role: Role.user, content: 'First'),
          const Message(role: Role.assistant, content: 'Last'),
        ];

        final conversation = Conversation(
          id: 'conv-123',
          messages: messages,
        );

        expect(conversation.firstMessage, equals(messages.first));
        expect(conversation.firstMessage?.content, equals('First'));
      });

      test('should return null for firstMessage when empty', () {
        final conversation = Conversation(id: 'conv-123');
        expect(conversation.firstMessage, isNull);
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        final createdAt = DateTime(2024, 1, 1);
        final updatedAt = DateTime(2024, 1, 2);

        final conversation1 = Conversation(
          id: 'conv-123',
          messages: [const Message(role: Role.user, content: 'Hello')],
          metadata: {'topic': 'greeting'},
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        final conversation2 = Conversation(
          id: 'conv-123',
          messages: [const Message(role: Role.user, content: 'Hello')],
          metadata: {'topic': 'greeting'},
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        expect(conversation1, equals(conversation2));
        expect(conversation1.hashCode, equals(conversation2.hashCode));
      });

      test('should not be equal when IDs differ', () {
        final conversation1 = Conversation(
          id: 'conv-123',
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        final conversation2 = Conversation(
          id: 'conv-456',
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        expect(conversation1, isNot(equals(conversation2)));
      });

      test('should not be equal when messages differ', () {
        final conversation1 = Conversation(
          id: 'conv-123',
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        final conversation2 = Conversation(
          id: 'conv-123',
          messages: [const Message(role: Role.user, content: 'Hi')],
        );

        expect(conversation1, isNot(equals(conversation2)));
      });

      test('should not be equal when metadata differs', () {
        final conversation1 = Conversation(
          id: 'conv-123',
          metadata: {'topic': 'greeting'},
        );

        final conversation2 = Conversation(
          id: 'conv-123',
          metadata: {'topic': 'farewell'},
        );

        expect(conversation1, isNot(equals(conversation2)));
      });
    });

    group('toString', () {
      test('should return descriptive string representation', () {
        final conversation = Conversation(
          id: 'conv-123',
          messages: [
            const Message(role: Role.user, content: 'Hello'),
            const Message(role: Role.assistant, content: 'Hi!'),
          ],
        );

        final str = conversation.toString();

        expect(str, contains('conv-123'));
        expect(str, contains('messages: 2'));
        expect(str, contains('createdAt'));
        expect(str, contains('updatedAt'));
      });
    });

    group('metadata immutability', () {
      test('should have unmodifiable metadata', () {
        final conversation = Conversation(
          id: 'conv-123',
          metadata: {'topic': 'greeting'},
        );

        expect(
          () => conversation.metadata['new'] = 'value',
          throwsA(isA<UnsupportedError>()),
        );
      });
    });
  });
}
