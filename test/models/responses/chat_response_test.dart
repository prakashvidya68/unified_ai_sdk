import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/responses/chat_response.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/models/common/usage.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';

void main() {
  group('ChatChoice', () {
    group('Construction', () {
      test('should create choice with required fields', () {
        final choice = const ChatChoice(
          index: 0,
          message: Message(role: Role.assistant, content: 'Hello!'),
        );

        expect(choice.index, equals(0));
        expect(choice.message.content, equals('Hello!'));
        expect(choice.finishReason, isNull);
      });

      test('should create choice with all fields', () {
        final choice = const ChatChoice(
          index: 1,
          message: Message(role: Role.assistant, content: 'Response'),
          finishReason: 'stop',
        );

        expect(choice.index, equals(1));
        expect(choice.message.content, equals('Response'));
        expect(choice.finishReason, equals('stop'));
      });
    });

    group('toJson()', () {
      test('should serialize choice to JSON', () {
        final choice = const ChatChoice(
          index: 0,
          message: Message(role: Role.assistant, content: 'Hello!'),
          finishReason: 'stop',
        );

        final json = choice.toJson();

        expect(json['index'], equals(0));
        expect(json['message'], isA<Map<String, dynamic>>());
        expect(json['message']['role'], equals('assistant'));
        expect(json['message']['content'], equals('Hello!'));
        expect(json['finish_reason'], equals('stop'));
      });

      test('should not include finishReason if null', () {
        final choice = const ChatChoice(
          index: 0,
          message: Message(role: Role.assistant, content: 'Hello!'),
        );

        final json = choice.toJson();

        expect(json.containsKey('finish_reason'), isFalse);
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON to ChatChoice', () {
        final json = {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': 'Hello!',
          },
          'finish_reason': 'stop',
        };

        final choice = ChatChoice.fromJson(json);

        expect(choice.index, equals(0));
        expect(choice.message.role, equals(Role.assistant));
        expect(choice.message.content, equals('Hello!'));
        expect(choice.finishReason, equals('stop'));
      });

      test('should handle missing finishReason', () {
        final json = {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': 'Hello!',
          },
        };

        final choice = ChatChoice.fromJson(json);

        expect(choice.finishReason, isNull);
      });
    });
  });

  group('ChatResponse', () {
    group('Construction', () {
      test('should create response with required fields', () {
        final response = ChatResponse(
          id: 'chatcmpl-123',
          choices: [
            const ChatChoice(
              index: 0,
              message: Message(role: Role.assistant, content: 'Hello!'),
            ),
          ],
          usage: const Usage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
          model: 'gpt-4',
          provider: 'openai',
        );

        expect(response.id, equals('chatcmpl-123'));
        expect(response.choices.length, equals(1));
        expect(response.usage.totalTokens, equals(15));
        expect(response.model, equals('gpt-4'));
        expect(response.provider, equals('openai'));
        expect(response.timestamp, isA<DateTime>());
      });

      test('should default timestamp to current time', () {
        final before = DateTime.now();
        final response = ChatResponse(
          id: 'test',
          choices: const [],
          usage: const Usage(
            promptTokens: 0,
            completionTokens: 0,
            totalTokens: 0,
          ),
          model: 'test',
          provider: 'test',
        );
        final after = DateTime.now();

        expect(
            response.timestamp.isAfter(before) ||
                response.timestamp.isAtSameMomentAs(before),
            isTrue);
        expect(
            response.timestamp.isBefore(after) ||
                response.timestamp.isAtSameMomentAs(after),
            isTrue);
      });

      test('should accept custom timestamp', () {
        final customTime = DateTime(2024, 1, 1, 12, 0, 0);
        final response = ChatResponse(
          id: 'test',
          choices: const [],
          usage: const Usage(
            promptTokens: 0,
            completionTokens: 0,
            totalTokens: 0,
          ),
          model: 'test',
          provider: 'test',
          timestamp: customTime,
        );

        expect(response.timestamp, equals(customTime));
      });

      test('should support multiple choices', () {
        final response = ChatResponse(
          id: 'test',
          choices: [
            const ChatChoice(
              index: 0,
              message: Message(role: Role.assistant, content: 'First'),
            ),
            const ChatChoice(
              index: 1,
              message: Message(role: Role.assistant, content: 'Second'),
            ),
          ],
          usage: const Usage(
            promptTokens: 10,
            completionTokens: 20,
            totalTokens: 30,
          ),
          model: 'gpt-4',
          provider: 'openai',
        );

        expect(response.choices.length, equals(2));
        expect(response.choices[0].message.content, equals('First'));
        expect(response.choices[1].message.content, equals('Second'));
      });
    });

    group('toJson()', () {
      test('should serialize response to JSON', () {
        final response = ChatResponse(
          id: 'chatcmpl-123',
          choices: [
            const ChatChoice(
              index: 0,
              message: Message(role: Role.assistant, content: 'Hello!'),
              finishReason: 'stop',
            ),
          ],
          usage: const Usage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
          model: 'gpt-4',
          provider: 'openai',
        );

        final json = response.toJson();

        expect(json['id'], equals('chatcmpl-123'));
        expect(json['choices'], isA<List<dynamic>>());
        expect(json['choices'].length, equals(1));
        expect(json['usage'], isA<Map<String, dynamic>>());
        expect(json['usage']['total_tokens'], equals(15));
        expect(json['model'], equals('gpt-4'));
        expect(json['provider'], equals('openai'));
        expect(json['timestamp'], isA<String>());
      });

      test('should serialize timestamp as ISO8601 string', () {
        final customTime = DateTime(2024, 1, 1, 12, 0, 0);
        final response = ChatResponse(
          id: 'test',
          choices: const [],
          usage: const Usage(
            promptTokens: 0,
            completionTokens: 0,
            totalTokens: 0,
          ),
          model: 'test',
          provider: 'test',
          timestamp: customTime,
        );

        final json = response.toJson();

        expect(json['timestamp'], equals(customTime.toIso8601String()));
      });

      test('should include metadata if present', () {
        final response = ChatResponse(
          id: 'test',
          choices: const [],
          usage: const Usage(
            promptTokens: 0,
            completionTokens: 0,
            totalTokens: 0,
          ),
          model: 'test',
          provider: 'test',
          metadata: {'request_id': 'req-123'},
        );

        final json = response.toJson();

        expect(json['metadata'], equals({'request_id': 'req-123'}));
      });

      test('should not include metadata if null', () {
        final response = ChatResponse(
          id: 'test',
          choices: const [],
          usage: const Usage(
            promptTokens: 0,
            completionTokens: 0,
            totalTokens: 0,
          ),
          model: 'test',
          provider: 'test',
        );

        final json = response.toJson();

        expect(json.containsKey('metadata'), isFalse);
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON to ChatResponse', () {
        final json = {
          'id': 'chatcmpl-123',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': 'Hello!',
              },
              'finish_reason': 'stop',
            },
          ],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 5,
            'total_tokens': 15,
          },
          'model': 'gpt-4',
          'provider': 'openai',
          'timestamp': '2024-01-01T12:00:00.000Z',
        };

        final response = ChatResponse.fromJson(json);

        expect(response.id, equals('chatcmpl-123'));
        expect(response.choices.length, equals(1));
        expect(response.choices.first.message.content, equals('Hello!'));
        expect(response.usage.totalTokens, equals(15));
        expect(response.model, equals('gpt-4'));
        expect(response.provider, equals('openai'));
        expect(response.timestamp,
            equals(DateTime.parse('2024-01-01T12:00:00.000Z')));
      });

      test('should handle missing timestamp', () {
        final json = {
          'id': 'test',
          'choices': <Map<String, dynamic>>[],
          'usage': {
            'prompt_tokens': 0,
            'completion_tokens': 0,
            'total_tokens': 0,
          },
          'model': 'test',
          'provider': 'test',
        };

        final response = ChatResponse.fromJson(json);

        expect(response.timestamp, isA<DateTime>());
      });

      test('should handle metadata', () {
        final json = {
          'id': 'test',
          'choices': <Map<String, dynamic>>[],
          'usage': {
            'prompt_tokens': 0,
            'completion_tokens': 0,
            'total_tokens': 0,
          },
          'model': 'test',
          'provider': 'test',
          'metadata': {'custom': 'value'},
        };

        final response = ChatResponse.fromJson(json);

        expect(response.metadata, equals({'custom': 'value'}));
      });
    });

    group('Round-trip serialization', () {
      test('toJson and fromJson should be inverse operations', () {
        final original = ChatResponse(
          id: 'chatcmpl-123',
          choices: [
            const ChatChoice(
              index: 0,
              message: Message(role: Role.assistant, content: 'Hello!'),
              finishReason: 'stop',
            ),
          ],
          usage: const Usage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
          model: 'gpt-4',
          provider: 'openai',
          timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        );

        final json = original.toJson();
        final restored = ChatResponse.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.choices.length, equals(original.choices.length));
        expect(restored.choices.first.message.content,
            equals(original.choices.first.message.content));
        expect(restored.usage, equals(original.usage));
        expect(restored.model, equals(original.model));
        expect(restored.provider, equals(original.provider));
        expect(restored.timestamp, equals(original.timestamp));
      });
    });

    group('Full request/response cycle', () {
      test('should handle complete chat conversation flow', () {
        // Simulate a complete request/response cycle
        // Note: In real usage, requestMessages would be sent to the provider
        // Here we simulate the response that would come back

        // Simulate provider response
        final response = ChatResponse(
          id: 'chatcmpl-abc123',
          choices: [
            const ChatChoice(
              index: 0,
              message: Message(
                role: Role.assistant,
                content: 'Hello! How can I help you today?',
              ),
              finishReason: 'stop',
            ),
          ],
          usage: const Usage(
            promptTokens: 5,
            completionTokens: 10,
            totalTokens: 15,
          ),
          model: 'gpt-4',
          provider: 'openai',
        );

        // Verify response structure
        expect(response.choices.isNotEmpty, isTrue);
        expect(response.choices.first.message.role, equals(Role.assistant));
        expect(response.usage.totalTokens, greaterThan(0));

        // Extract assistant message for next turn
        final assistantMessage = response.choices.first.message;
        expect(assistantMessage.content, contains('Hello!'));
      });

      test('should handle multiple completion choices', () {
        final response = ChatResponse(
          id: 'chatcmpl-123',
          choices: [
            const ChatChoice(
              index: 0,
              message: Message(role: Role.assistant, content: 'First option'),
              finishReason: 'stop',
            ),
            const ChatChoice(
              index: 1,
              message: Message(role: Role.assistant, content: 'Second option'),
              finishReason: 'stop',
            ),
          ],
          usage: const Usage(
            promptTokens: 10,
            completionTokens: 20,
            totalTokens: 30,
          ),
          model: 'gpt-4',
          provider: 'openai',
        );

        expect(response.choices.length, equals(2));
        expect(response.choices[0].index, equals(0));
        expect(response.choices[1].index, equals(1));
      });

      test('should track token usage correctly', () {
        final response = ChatResponse(
          id: 'test',
          choices: const [],
          usage: const Usage(
            promptTokens: 100,
            completionTokens: 200,
            totalTokens: 300,
          ),
          model: 'gpt-4',
          provider: 'openai',
        );

        expect(response.usage.promptTokens, equals(100));
        expect(response.usage.completionTokens, equals(200));
        expect(response.usage.totalTokens, equals(300));
      });
    });

    group('copyWith()', () {
      test('should create copy with modified fields', () {
        final original = ChatResponse(
          id: 'test',
          choices: const [],
          usage: const Usage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
          model: 'gpt-4',
          provider: 'openai',
        );

        final copy = original.copyWith(id: 'new-id');

        expect(copy.id, equals('new-id'));
        expect(copy.model, equals(original.model));
        expect(copy.provider, equals(original.provider));
      });
    });

    group('Equality', () {
      test('should be equal when all fields match', () {
        final timestamp = DateTime(2024, 1, 1);
        final response1 = ChatResponse(
          id: 'test',
          choices: const [],
          usage: const Usage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
          model: 'gpt-4',
          provider: 'openai',
          timestamp: timestamp,
        );
        final response2 = ChatResponse(
          id: 'test',
          choices: const [],
          usage: const Usage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
          model: 'gpt-4',
          provider: 'openai',
          timestamp: timestamp,
        );

        expect(response1, equals(response2));
      });
    });
  });
}
