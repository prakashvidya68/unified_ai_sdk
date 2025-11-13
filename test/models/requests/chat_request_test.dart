import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/models/requests/chat_request.dart';

void main() {
  group('ChatRequest', () {
    group('Construction', () {
      test('should create request with required messages', () {
        final request = ChatRequest(
          messages: [
            Message(role: Role.user, content: 'Hello!'),
          ],
        );

        expect(request.messages.length, equals(1));
        expect(request.messages.first.content, equals('Hello!'));
        expect(request.model, isNull);
        expect(request.maxTokens, isNull);
        expect(request.temperature, isNull);
      });

      test('should create request with all fields', () {
        final request = ChatRequest(
          messages: [
            Message(role: Role.system, content: 'You are helpful'),
            Message(role: Role.user, content: 'Hello!'),
          ],
          model: 'gpt-4',
          maxTokens: 500,
          temperature: 0.7,
          topP: 0.95,
          n: 1,
          stop: ['\n\n'],
          user: 'user-123',
          providerOptions: {
            'openai': {'presence_penalty': 0.6},
          },
        );

        expect(request.messages.length, equals(2));
        expect(request.model, equals('gpt-4'));
        expect(request.maxTokens, equals(500));
        expect(request.temperature, equals(0.7));
        expect(request.topP, equals(0.95));
        expect(request.n, equals(1));
        expect(request.stop, equals(['\n\n']));
        expect(request.user, equals('user-123'));
        expect(request.providerOptions, isNotNull);
      });

      test('should throw assertion error if messages is empty', () {
        expect(
          () => ChatRequest(messages: []),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error if maxTokens is negative', () {
        expect(
          () => ChatRequest(
            messages: [Message(role: Role.user, content: 'Hi')],
            maxTokens: -1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error if maxTokens is zero', () {
        expect(
          () => ChatRequest(
            messages: [Message(role: Role.user, content: 'Hi')],
            maxTokens: 0,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error if n is negative', () {
        expect(
          () => ChatRequest(
            messages: [Message(role: Role.user, content: 'Hi')],
            n: -1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error if n is zero', () {
        expect(
          () => ChatRequest(
            messages: [Message(role: Role.user, content: 'Hi')],
            n: 0,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error if temperature is negative', () {
        expect(
          () => ChatRequest(
            messages: [Message(role: Role.user, content: 'Hi')],
            temperature: -0.1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error if temperature exceeds 2.0', () {
        expect(
          () => ChatRequest(
            messages: [Message(role: Role.user, content: 'Hi')],
            temperature: 2.1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should accept temperature at boundaries', () {
        final request1 = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          temperature: 0.0,
        );
        final request2 = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          temperature: 2.0,
        );

        expect(request1.temperature, equals(0.0));
        expect(request2.temperature, equals(2.0));
      });
    });

    group('fromJson', () {
      test('should parse JSON with camelCase keys', () {
        final json = {
          'messages': [
            {'role': 'user', 'content': 'Hello!'}
          ],
          'model': 'gpt-4',
          'maxTokens': 500,
          'temperature': 0.7,
          'topP': 0.95,
          'n': 1,
          'stop': ['\n\n'],
          'user': 'user-123',
        };

        final request = ChatRequest.fromJson(json);

        expect(request.messages.length, equals(1));
        expect(request.model, equals('gpt-4'));
        expect(request.maxTokens, equals(500));
        expect(request.temperature, equals(0.7));
        expect(request.topP, equals(0.95));
        expect(request.n, equals(1));
        expect(request.stop, equals(['\n\n']));
        expect(request.user, equals('user-123'));
      });

      test('should parse JSON with snake_case keys', () {
        final json = {
          'messages': [
            {'role': 'user', 'content': 'Hello!'}
          ],
          'model': 'gpt-4',
          'max_tokens': 500,
          'temperature': 0.7,
          'top_p': 0.95,
        };

        final request = ChatRequest.fromJson(json);

        expect(request.maxTokens, equals(500));
        expect(request.topP, equals(0.95));
      });

      test('should prefer camelCase over snake_case', () {
        final json = {
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
          'maxTokens': 100,
          'max_tokens': 200,
        };

        final request = ChatRequest.fromJson(json);

        expect(request.maxTokens, equals(100));
      });

      test('should throw FormatException if messages is missing', () {
        final json = <String, dynamic>{};

        expect(
          () => ChatRequest.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if messages is empty', () {
        final json = {'messages': <dynamic>[]};

        expect(
          () => ChatRequest.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should handle missing optional fields', () {
        final json = {
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
        };

        final request = ChatRequest.fromJson(json);

        expect(request.model, isNull);
        expect(request.maxTokens, isNull);
        expect(request.temperature, isNull);
      });
    });

    group('toJson', () {
      test('should serialize to JSON with camelCase keys', () {
        final request = ChatRequest(
          messages: [
            Message(role: Role.user, content: 'Hello!'),
          ],
          model: 'gpt-4',
          maxTokens: 500,
          temperature: 0.7,
          topP: 0.95,
          n: 1,
          stop: ['\n\n'],
          user: 'user-123',
        );

        final json = request.toJson();

        expect(json['messages'], isA<List<dynamic>>());
        expect(json['model'], equals('gpt-4'));
        expect(json['max_tokens'], equals(500));
        expect(json['temperature'], equals(0.7));
        expect(json['top_p'], equals(0.95));
        expect(json['n'], equals(1));
        expect(json['stop'], equals(['\n\n']));
        expect(json['user'], equals('user-123'));
      });

      test('should not include null fields', () {
        final request = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
        );

        final json = request.toJson();

        expect(json.containsKey('model'), isFalse);
        expect(json.containsKey('max_tokens'), isFalse);
        expect(json.containsKey('temperature'), isFalse);
      });

      test('should serialize messages correctly', () {
        final request = ChatRequest(
          messages: [
            Message(role: Role.system, content: 'You are helpful'),
            Message(role: Role.user, content: 'Hello!'),
          ],
        );

        final json = request.toJson();

        expect(json['messages'], isA<List<dynamic>>());
        expect((json['messages'] as List).length, equals(2));
        expect((json['messages'] as List).first['role'], equals('system'));
      });

      test('should round-trip through JSON', () {
        final original = ChatRequest(
          messages: [
            Message(role: Role.user, content: 'Hello!'),
          ],
          model: 'gpt-4',
          maxTokens: 500,
          temperature: 0.7,
          topP: 0.95,
          n: 1,
          stop: ['\n\n'],
        );

        final json = original.toJson();
        final restored = ChatRequest.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          temperature: 0.7,
        );

        final updated = original.copyWith(temperature: 0.9);

        expect(updated.temperature, equals(0.9));
        expect(updated.messages, equals(original.messages));
      });

      test('should preserve unchanged fields', () {
        final original = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          model: 'gpt-4',
          maxTokens: 500,
        );

        final updated = original.copyWith(temperature: 0.7);

        expect(updated.model, equals('gpt-4'));
        expect(updated.maxTokens, equals(500));
        expect(updated.temperature, equals(0.7));
      });

      test('should allow setting model to null', () {
        final original = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          model: 'gpt-4',
        );

        final updated = original.copyWith(model: null);

        expect(updated.model, isNull);
      });

      test('should allow setting user to null', () {
        final original = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          user: 'user-123',
        );

        final updated = original.copyWith(user: null);

        expect(updated.user, isNull);
      });
    });

    group('isCacheable', () {
      test('should be cacheable with temperature 0 and n 1', () {
        final request = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          temperature: 0.0,
          n: 1,
        );

        expect(request.isCacheable, isTrue);
      });

      test('should be cacheable with temperature 0 and n null', () {
        final request = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          temperature: 0.0,
        );

        expect(request.isCacheable, isTrue);
      });

      test('should not be cacheable with temperature > 0', () {
        final request = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          temperature: 0.7,
          n: 1,
        );

        expect(request.isCacheable, isFalse);
      });

      test('should not be cacheable with n > 1', () {
        final request = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          temperature: 0.0,
          n: 2,
        );

        expect(request.isCacheable, isFalse);
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final request1 = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          model: 'gpt-4',
          maxTokens: 500,
        );
        final request2 = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          model: 'gpt-4',
          maxTokens: 500,
        );

        expect(request1, equals(request2));
        expect(request1.hashCode, equals(request2.hashCode));
      });

      test('should not be equal with different messages', () {
        final request1 = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
        );
        final request2 = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hello')],
        );

        expect(request1, isNot(equals(request2)));
      });

      test('should not be equal with different models', () {
        final request1 = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          model: 'gpt-4',
        );
        final request2 = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          model: 'gpt-3.5',
        );

        expect(request1, isNot(equals(request2)));
      });

      test('should handle null fields correctly', () {
        final request1 = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
        );
        final request2 = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hi')],
          model: null,
        );

        expect(request1, equals(request2));
      });
    });

    group('toString', () {
      test('should include key fields in string representation', () {
        final request = ChatRequest(
          messages: [
            Message(role: Role.user, content: 'Hello!'),
          ],
          model: 'gpt-4',
          maxTokens: 500,
          temperature: 0.7,
        );

        final str = request.toString();

        expect(str, contains('ChatRequest'));
        expect(str, contains('messages: 1'));
        expect(str, contains('model: gpt-4'));
        expect(str, contains('maxTokens: 500'));
        expect(str, contains('temperature: 0.7'));
      });
    });
  });
}
