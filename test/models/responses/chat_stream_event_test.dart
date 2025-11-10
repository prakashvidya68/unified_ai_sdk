import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/responses/chat_stream_event.dart';

void main() {
  group('ChatStreamEvent', () {
    group('Construction', () {
      test('should create event with required done field', () {
        const event = ChatStreamEvent(done: false);

        expect(event.delta, isNull);
        expect(event.done, isFalse);
        expect(event.metadata, isNull);
      });

      test('should create event with delta content', () {
        const event = ChatStreamEvent(
          delta: 'Hello, ',
          done: false,
        );

        expect(event.delta, equals('Hello, '));
        expect(event.done, isFalse);
        expect(event.metadata, isNull);
      });

      test('should create event with all fields', () {
        const event = ChatStreamEvent(
          delta: 'world!',
          done: false,
          metadata: {'model': 'gpt-4'},
        );

        expect(event.delta, equals('world!'));
        expect(event.done, isFalse);
        expect(event.metadata, equals({'model': 'gpt-4'}));
      });

      test('should create final event with done true', () {
        const event = ChatStreamEvent(
          delta: null,
          done: true,
          metadata: {
            'usage': {'total_tokens': 150},
            'finish_reason': 'stop',
          },
        );

        expect(event.delta, isNull);
        expect(event.done, isTrue);
        expect(event.metadata, isNotNull);
        expect(event.metadata!['usage'], equals({'total_tokens': 150}));
      });
    });

    group('toJson()', () {
      test('should serialize event with delta to JSON', () {
        const event = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );

        final json = event.toJson();

        expect(json['delta'], equals('Hello'));
        expect(json['done'], isFalse);
        expect(json.containsKey('metadata'), isFalse);
      });

      test('should serialize event without delta to JSON', () {
        const event = ChatStreamEvent(done: true);

        final json = event.toJson();

        expect(json.containsKey('delta'), isFalse);
        expect(json['done'], isTrue);
        expect(json.containsKey('metadata'), isFalse);
      });

      test('should serialize event with metadata to JSON', () {
        const event = ChatStreamEvent(
          delta: 'test',
          done: false,
          metadata: {
            'model': 'gpt-4',
            'usage': {'total_tokens': 100},
          },
        );

        final json = event.toJson();

        expect(json['delta'], equals('test'));
        expect(json['done'], isFalse);
        expect(json['metadata'], isA<Map<String, dynamic>>());
        expect(json['metadata']['model'], equals('gpt-4'));
        expect(json['metadata']['usage'], equals({'total_tokens': 100}));
      });

      test('should not include null delta in JSON', () {
        const event = ChatStreamEvent(done: false);

        final json = event.toJson();

        expect(json.containsKey('delta'), isFalse);
        expect(json['done'], isFalse);
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON to ChatStreamEvent', () {
        final json = {
          'delta': 'Hello',
          'done': false,
        };

        final event = ChatStreamEvent.fromJson(json);

        expect(event.delta, equals('Hello'));
        expect(event.done, isFalse);
        expect(event.metadata, isNull);
      });

      test('should deserialize JSON without delta', () {
        final json = {
          'done': true,
        };

        final event = ChatStreamEvent.fromJson(json);

        expect(event.delta, isNull);
        expect(event.done, isTrue);
        expect(event.metadata, isNull);
      });

      test('should deserialize JSON with metadata', () {
        final json = {
          'delta': 'test',
          'done': false,
          'metadata': {
            'model': 'gpt-4',
            'usage': {'total_tokens': 100},
          },
        };

        final event = ChatStreamEvent.fromJson(json);

        expect(event.delta, equals('test'));
        expect(event.done, isFalse);
        expect(event.metadata, isNotNull);
        expect(event.metadata!['model'], equals('gpt-4'));
        expect(event.metadata!['usage'], equals({'total_tokens': 100}));
      });

      test('should handle null delta in JSON', () {
        final json = {
          'delta': null,
          'done': true,
        };

        final event = ChatStreamEvent.fromJson(json);

        expect(event.delta, isNull);
        expect(event.done, isTrue);
      });
    });

    group('copyWith()', () {
      test('should create copy with updated delta', () {
        const original = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );

        final updated = original.copyWith(delta: 'World');

        expect(updated.delta, equals('World'));
        expect(updated.done, isFalse);
        expect(updated.metadata, isNull);
      });

      test('should create copy with updated done flag', () {
        const original = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );

        final updated = original.copyWith(done: true);

        expect(updated.delta, equals('Hello'));
        expect(updated.done, isTrue);
        expect(updated.metadata, isNull);
      });

      test('should create copy with added metadata', () {
        const original = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );

        final updated = original.copyWith(
          metadata: {'model': 'gpt-4'},
        );

        expect(updated.delta, equals('Hello'));
        expect(updated.done, isFalse);
        expect(updated.metadata, equals({'model': 'gpt-4'}));
      });

      test('should create copy with updated metadata', () {
        const original = ChatStreamEvent(
          delta: 'Hello',
          done: false,
          metadata: {'model': 'gpt-3'},
        );

        final updated = original.copyWith(
          metadata: {'model': 'gpt-4'},
        );

        expect(updated.delta, equals('Hello'));
        expect(updated.done, isFalse);
        expect(updated.metadata, equals({'model': 'gpt-4'}));
      });

      test('should create copy with multiple fields updated', () {
        const original = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );

        final updated = original.copyWith(
          delta: 'World',
          done: true,
          metadata: {
            'usage': {'total_tokens': 100}
          },
        );

        expect(updated.delta, equals('World'));
        expect(updated.done, isTrue);
        expect(
            updated.metadata,
            equals({
              'usage': {'total_tokens': 100}
            }));
      });

      test('should create copy with null delta', () {
        const original = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );

        final updated = original.copyWith(delta: null);

        expect(updated.delta, isNull);
        expect(updated.done, isFalse);
      });
    });

    group('toString()', () {
      test('should format event with delta', () {
        const event = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );

        final str = event.toString();

        expect(str, contains("delta: 'Hello'"));
        expect(str, contains('done: false'));
        expect(str, isNot(contains('metadata')));
      });

      test('should format event without delta', () {
        const event = ChatStreamEvent(done: true);

        final str = event.toString();

        expect(str, contains('delta: null'));
        expect(str, contains('done: true'));
      });

      test('should format event with metadata', () {
        const event = ChatStreamEvent(
          delta: 'test',
          done: false,
          metadata: {'model': 'gpt-4'},
        );

        final str = event.toString();

        expect(str, contains("delta: 'test'"));
        expect(str, contains('done: false'));
        expect(str, contains('metadata'));
      });
    });

    group('Equality', () {
      test('should be equal when all fields match', () {
        const event1 = ChatStreamEvent(
          delta: 'Hello',
          done: false,
          metadata: {'model': 'gpt-4'},
        );
        const event2 = ChatStreamEvent(
          delta: 'Hello',
          done: false,
          metadata: {'model': 'gpt-4'},
        );

        expect(event1, equals(event2));
        expect(event1.hashCode, equals(event2.hashCode));
      });

      test('should not be equal when delta differs', () {
        const event1 = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );
        const event2 = ChatStreamEvent(
          delta: 'World',
          done: false,
        );

        expect(event1, isNot(equals(event2)));
      });

      test('should not be equal when done differs', () {
        const event1 = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );
        const event2 = ChatStreamEvent(
          delta: 'Hello',
          done: true,
        );

        expect(event1, isNot(equals(event2)));
      });

      test('should not be equal when metadata differs', () {
        const event1 = ChatStreamEvent(
          delta: 'Hello',
          done: false,
          metadata: {'model': 'gpt-3'},
        );
        const event2 = ChatStreamEvent(
          delta: 'Hello',
          done: false,
          metadata: {'model': 'gpt-4'},
        );

        expect(event1, isNot(equals(event2)));
      });

      test('should be equal when both have null delta', () {
        const event1 = ChatStreamEvent(done: true);
        const event2 = ChatStreamEvent(done: true);

        expect(event1, equals(event2));
      });

      test('should be equal when both have null metadata', () {
        const event1 = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );
        const event2 = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );

        expect(event1, equals(event2));
      });

      test('should handle identical instances', () {
        const event = ChatStreamEvent(
          delta: 'Hello',
          done: false,
        );

        expect(event, equals(event));
      });
    });

    group('Streaming scenarios', () {
      test('should represent typical streaming flow', () {
        // Simulate a typical streaming response
        final events = [
          const ChatStreamEvent(delta: 'Hello', done: false),
          const ChatStreamEvent(delta: ', ', done: false),
          const ChatStreamEvent(delta: 'world', done: false),
          const ChatStreamEvent(delta: '!', done: false),
          const ChatStreamEvent(
            delta: null,
            done: true,
            metadata: {
              'usage': {'total_tokens': 10},
              'finish_reason': 'stop',
            },
          ),
        ];

        expect(events.length, equals(5));
        expect(events[0].delta, equals('Hello'));
        expect(events[0].done, isFalse);
        expect(events[4].delta, isNull);
        expect(events[4].done, isTrue);
        expect(events[4].metadata, isNotNull);
      });

      test('should accumulate deltas correctly', () {
        final events = [
          const ChatStreamEvent(delta: 'The', done: false),
          const ChatStreamEvent(delta: ' quick', done: false),
          const ChatStreamEvent(delta: ' brown', done: false),
          const ChatStreamEvent(delta: ' fox', done: false),
        ];

        String accumulated = '';
        for (final event in events) {
          if (event.delta != null) {
            accumulated += event.delta!;
          }
        }

        expect(accumulated, equals('The quick brown fox'));
      });
    });
  });
}
