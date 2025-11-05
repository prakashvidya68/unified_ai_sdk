import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';

void main() {
  group('Message', () {
    group('Construction', () {
      test('should create message with required fields', () {
        final message = const Message(
          role: Role.user,
          content: 'Hello, world!',
        );

        expect(message.role, equals(Role.user));
        expect(message.content, equals('Hello, world!'));
        expect(message.name, isNull);
        expect(message.meta, isNull);
      });

      test('should create message with all fields', () {
        final message = const Message(
          role: Role.function,
          content: 'Function result',
          name: 'calculate_sum',
          meta: {'result': 42},
        );

        expect(message.role, equals(Role.function));
        expect(message.content, equals('Function result'));
        expect(message.name, equals('calculate_sum'));
        expect(message.meta, equals({'result': 42}));
      });

      test('should be immutable (const constructor)', () {
        const message1 = Message(
          role: Role.system,
          content: 'System message',
        );
        const message2 = Message(
          role: Role.system,
          content: 'System message',
        );

        expect(message1, equals(message2));
        expect(message1.hashCode, equals(message2.hashCode));
      });
    });

    group('toJson()', () {
      test('should serialize basic message to JSON', () {
        final message = const Message(
          role: Role.user,
          content: 'Hello!',
        );

        final json = message.toJson();

        expect(json, isA<Map<String, dynamic>>());
        expect(json['role'], equals('user'));
        expect(json['content'], equals('Hello!'));
        expect(json.containsKey('name'), isFalse);
        expect(json.containsKey('meta'), isFalse);
      });

      test('should serialize message with name to JSON', () {
        final message = const Message(
          role: Role.function,
          content: 'Result',
          name: 'my_function',
        );

        final json = message.toJson();

        expect(json['role'], equals('function'));
        expect(json['content'], equals('Result'));
        expect(json['name'], equals('my_function'));
        expect(json.containsKey('meta'), isFalse);
      });

      test('should serialize message with meta to JSON', () {
        final message = const Message(
          role: Role.assistant,
          content: 'Response',
          meta: {'timestamp': 1234567890, 'model': 'gpt-4'},
        );

        final json = message.toJson();

        expect(json['role'], equals('assistant'));
        expect(json['content'], equals('Response'));
        expect(json['meta'], isA<Map<String, dynamic>>());
        expect(json['meta']['timestamp'], equals(1234567890));
        expect(json['meta']['model'], equals('gpt-4'));
      });

      test('should serialize all Role types correctly', () {
        for (final role in Role.values) {
          final message = Message(role: role, content: 'Test');
          final json = message.toJson();

          expect(json['role'], equals(role.name));
          expect(json['content'], equals('Test'));
        }
      });

      test('should not include null optional fields in JSON', () {
        final message = const Message(
          role: Role.user,
          content: 'Test',
          name: null,
          meta: null,
        );

        final json = message.toJson();

        expect(json.containsKey('name'), isFalse);
        expect(json.containsKey('meta'), isFalse);
      });
    });

    group('fromJson()', () {
      test('should deserialize basic JSON to Message', () {
        final json = {
          'role': 'user',
          'content': 'Hello!',
        };

        final message = Message.fromJson(json);

        expect(message.role, equals(Role.user));
        expect(message.content, equals('Hello!'));
        expect(message.name, isNull);
        expect(message.meta, isNull);
      });

      test('should deserialize JSON with name to Message', () {
        final json = {
          'role': 'function',
          'content': 'Result',
          'name': 'my_function',
        };

        final message = Message.fromJson(json);

        expect(message.role, equals(Role.function));
        expect(message.content, equals('Result'));
        expect(message.name, equals('my_function'));
      });

      test('should deserialize JSON with meta to Message', () {
        final json = {
          'role': 'assistant',
          'content': 'Response',
          'meta': {'timestamp': 1234567890},
        };

        final message = Message.fromJson(json);

        expect(message.role, equals(Role.assistant));
        expect(message.content, equals('Response'));
        expect(message.meta, equals({'timestamp': 1234567890}));
      });

      test('should deserialize all Role types correctly', () {
        for (final role in Role.values) {
          final json = {
            'role': role.name,
            'content': 'Test',
          };

          final message = Message.fromJson(json);

          expect(message.role, equals(role));
          expect(message.content, equals('Test'));
        }
      });

      test('should throw FormatException for invalid role', () {
        final json = {
          'role': 'invalid_role',
          'content': 'Test',
        };

        expect(
          () => Message.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw TypeError for missing required fields', () {
        final json = {
          'role': 'user',
          // Missing 'content'
        };

        expect(
          () => Message.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('Round-trip serialization', () {
      test('toJson and fromJson should be inverse operations', () {
        final original = const Message(
          role: Role.user,
          content: 'Hello, world!',
          name: 'Alice',
          meta: {'timestamp': 1234567890},
        );

        final json = original.toJson();
        final restored = Message.fromJson(json);

        expect(restored.role, equals(original.role));
        expect(restored.content, equals(original.content));
        expect(restored.name, equals(original.name));
        expect(restored.meta, equals(original.meta));
        expect(restored, equals(original));
      });

      test('should handle round-trip with minimal fields', () {
        final original = const Message(
          role: Role.system,
          content: 'System prompt',
        );

        final json = original.toJson();
        final restored = Message.fromJson(json);

        expect(restored, equals(original));
      });

      test('should handle round-trip with all fields', () {
        final original = const Message(
          role: Role.function,
          content: 'Function result',
          name: 'calculate',
          meta: {'result': 42, 'execution_time': 0.5},
        );

        final json = original.toJson();
        final restored = Message.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('copyWith()', () {
      test('should create copy with modified role', () {
        final original = const Message(
          role: Role.user,
          content: 'Hello',
        );

        final copy = original.copyWith(role: Role.assistant);

        expect(copy.role, equals(Role.assistant));
        expect(copy.content, equals(original.content));
        expect(copy.name, equals(original.name));
        expect(copy.meta, equals(original.meta));
      });

      test('should create copy with modified content', () {
        final original = const Message(
          role: Role.user,
          content: 'Hello',
        );

        final copy = original.copyWith(content: 'Goodbye');

        expect(copy.role, equals(original.role));
        expect(copy.content, equals('Goodbye'));
      });

      test('should create copy with added name', () {
        final original = const Message(
          role: Role.user,
          content: 'Hello',
        );

        final copy = original.copyWith(name: 'Alice');

        expect(copy.name, equals('Alice'));
        expect(copy.role, equals(original.role));
        expect(copy.content, equals(original.content));
      });

      test('should create copy with modified meta', () {
        final original = const Message(
          role: Role.user,
          content: 'Hello',
          meta: {'old': 'value'},
        );

        final copy = original.copyWith(meta: {'new': 'value'});

        expect(copy.meta, equals({'new': 'value'}));
        expect(original.meta, equals({'old': 'value'})); // Original unchanged
      });
    });

    group('Equality and hashCode', () {
      test('should be equal when all fields match', () {
        final message1 = const Message(
          role: Role.user,
          content: 'Hello',
          name: 'Alice',
          meta: {'key': 'value'},
        );
        final message2 = const Message(
          role: Role.user,
          content: 'Hello',
          name: 'Alice',
          meta: {'key': 'value'},
        );

        expect(message1, equals(message2));
        expect(message1.hashCode, equals(message2.hashCode));
      });

      test('should not be equal when role differs', () {
        final message1 = const Message(role: Role.user, content: 'Hello');
        final message2 = const Message(role: Role.assistant, content: 'Hello');

        expect(message1, isNot(equals(message2)));
      });

      test('should not be equal when content differs', () {
        final message1 = const Message(role: Role.user, content: 'Hello');
        final message2 = const Message(role: Role.user, content: 'Goodbye');

        expect(message1, isNot(equals(message2)));
      });

      test('should handle null fields in equality', () {
        final message1 = const Message(role: Role.user, content: 'Hello');
        final message2 = const Message(
          role: Role.user,
          content: 'Hello',
          name: null,
          meta: null,
        );

        expect(message1, equals(message2));
      });
    });

    group('toString()', () {
      test('should return readable string representation', () {
        final message = const Message(
          role: Role.user,
          content: 'Hello, world!',
        );

        final str = message.toString();

        expect(str, contains('Message'));
        expect(str, contains('user'));
        expect(str, contains('Hello, world!'));
      });

      test('should truncate long content', () {
        final longContent = 'A' * 100;
        final message = Message(
          role: Role.user,
          content: longContent,
        );

        final str = message.toString();

        expect(str.length, lessThan(longContent.length + 50));
        expect(str, contains('...'));
      });

      test('should include name when present', () {
        final message = const Message(
          role: Role.function,
          content: 'Result',
          name: 'my_function',
        );

        final str = message.toString();

        expect(str, contains('my_function'));
      });
    });
  });
}
