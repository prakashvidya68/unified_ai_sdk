import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/responses/transcription_response.dart';

void main() {
  group('TranscriptionSegment', () {
    group('Construction', () {
      test('should create segment with required fields', () {
        const segment = TranscriptionSegment(
          text: 'Hello',
          start: 0.0,
          end: 1.0,
        );

        expect(segment.text, equals('Hello'));
        expect(segment.start, equals(0.0));
        expect(segment.end, equals(1.0));
        expect(segment.id, isNull);
        expect(segment.confidence, isNull);
      });

      test('should create segment with all fields', () {
        const segment = TranscriptionSegment(
          text: 'Hello, world!',
          start: 0.0,
          end: 2.5,
          id: 0,
          confidence: 0.95,
        );

        expect(segment.text, equals('Hello, world!'));
        expect(segment.start, equals(0.0));
        expect(segment.end, equals(2.5));
        expect(segment.id, equals(0));
        expect(segment.confidence, equals(0.95));
      });
    });

    group('toJson()', () {
      test('should serialize segment to JSON', () {
        const segment = TranscriptionSegment(
          text: 'Hello',
          start: 0.0,
          end: 1.0,
          id: 0,
          confidence: 0.95,
        );

        final json = segment.toJson();

        expect(json['text'], equals('Hello'));
        expect(json['start'], equals(0.0));
        expect(json['end'], equals(1.0));
        expect(json['id'], equals(0));
        expect(json['confidence'], equals(0.95));
      });

      test('should not include null optional fields', () {
        const segment = TranscriptionSegment(
          text: 'Hello',
          start: 0.0,
          end: 1.0,
        );

        final json = segment.toJson();

        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('confidence'), isFalse);
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with all fields', () {
        final json = {
          'text': 'Hello',
          'start': 0.0,
          'end': 1.0,
          'id': 0,
          'confidence': 0.95,
        };

        final segment = TranscriptionSegment.fromJson(json);

        expect(segment.text, equals('Hello'));
        expect(segment.start, equals(0.0));
        expect(segment.end, equals(1.0));
        expect(segment.id, equals(0));
        expect(segment.confidence, equals(0.95));
      });

      test('should handle integer start/end values', () {
        final json = {
          'text': 'Hello',
          'start': 0,
          'end': 1,
        };

        final segment = TranscriptionSegment.fromJson(json);

        expect(segment.start, equals(0.0));
        expect(segment.end, equals(1.0));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        const segment1 = TranscriptionSegment(
          text: 'Hello',
          start: 0.0,
          end: 1.0,
          id: 0,
          confidence: 0.95,
        );
        const segment2 = TranscriptionSegment(
          text: 'Hello',
          start: 0.0,
          end: 1.0,
          id: 0,
          confidence: 0.95,
        );

        expect(segment1, equals(segment2));
        expect(segment1.hashCode, equals(segment2.hashCode));
      });

      test('should handle floating point comparison', () {
        const segment1 = TranscriptionSegment(
          text: 'Hello',
          start: 0.0,
          end: 1.0,
        );
        const segment2 = TranscriptionSegment(
          text: 'Hello',
          start: 0.0001,
          end: 1.0001,
        );

        // Should be equal due to epsilon comparison
        expect(segment1, equals(segment2));
      });
    });
  });

  group('TranscriptionResponse', () {
    group('Construction', () {
      test('should create response with required fields', () {
        final response = TranscriptionResponse(
          text: 'Hello, world!',
          model: 'whisper-1',
          provider: 'openai',
        );

        expect(response.text, equals('Hello, world!'));
        expect(response.model, equals('whisper-1'));
        expect(response.provider, equals('openai'));
        expect(response.language, isNull);
        expect(response.duration, isNull);
        expect(response.segments, isNull);
      });

      test('should create response with all fields', () {
        final segments = [
          const TranscriptionSegment(
            text: 'Hello',
            start: 0.0,
            end: 1.0,
          ),
        ];
        final response = TranscriptionResponse(
          text: 'Hello, world!',
          language: 'en',
          duration: 2.5,
          segments: segments,
          model: 'whisper-1',
          provider: 'openai',
        );

        expect(response.text, equals('Hello, world!'));
        expect(response.language, equals('en'));
        expect(response.duration, equals(2.5));
        expect(response.segments, equals(segments));
      });

      test('should throw assertion error if text is empty', () {
        expect(
          () => TranscriptionResponse(
            text: '',
            model: 'whisper-1',
            provider: 'openai',
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('toJson()', () {
      test('should serialize response to JSON', () {
        final response = TranscriptionResponse(
          text: 'Hello, world!',
          language: 'en',
          duration: 2.5,
          model: 'whisper-1',
          provider: 'openai',
        );

        final json = response.toJson();

        expect(json['text'], equals('Hello, world!'));
        expect(json['language'], equals('en'));
        expect(json['duration'], equals(2.5));
        expect(json['model'], equals('whisper-1'));
        expect(json['provider'], equals('openai'));
      });

      test('should serialize segments if present', () {
        final segments = [
          const TranscriptionSegment(
            text: 'Hello',
            start: 0.0,
            end: 1.0,
          ),
        ];
        final response = TranscriptionResponse(
          text: 'Hello',
          segments: segments,
          model: 'whisper-1',
          provider: 'openai',
        );

        final json = response.toJson();

        expect(json['segments'], isA<List<dynamic>>());
        expect(json['segments'].length, equals(1));
      });

      test('should not include null optional fields', () {
        final response = TranscriptionResponse(
          text: 'Hello',
          model: 'whisper-1',
          provider: 'openai',
        );

        final json = response.toJson();

        expect(json.containsKey('language'), isFalse);
        expect(json.containsKey('duration'), isFalse);
        expect(json.containsKey('segments'), isFalse);
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with required fields', () {
        final json = {
          'text': 'Hello, world!',
          'model': 'whisper-1',
          'provider': 'openai',
        };

        final response = TranscriptionResponse.fromJson(json);

        expect(response.text, equals('Hello, world!'));
        expect(response.model, equals('whisper-1'));
        expect(response.provider, equals('openai'));
      });

      test('should deserialize JSON with all fields', () {
        final json = {
          'text': 'Hello, world!',
          'language': 'en',
          'duration': 2.5,
          'segments': [
            {
              'text': 'Hello',
              'start': 0.0,
              'end': 1.0,
            },
          ],
          'model': 'whisper-1',
          'provider': 'openai',
        };

        final response = TranscriptionResponse.fromJson(json);

        expect(response.text, equals('Hello, world!'));
        expect(response.language, equals('en'));
        expect(response.duration, equals(2.5));
        expect(response.segments?.length, equals(1));
        expect(response.segments?.first.text, equals('Hello'));
      });

      test('should throw FormatException if text is missing', () {
        final json = {
          'model': 'whisper-1',
          'provider': 'openai',
        };

        expect(
          () => TranscriptionResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if text is empty', () {
        final json = {
          'text': '',
          'model': 'whisper-1',
          'provider': 'openai',
        };

        expect(
          () => TranscriptionResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should handle integer duration', () {
        final json = {
          'text': 'Hello',
          'duration': 2,
          'model': 'whisper-1',
          'provider': 'openai',
        };

        final response = TranscriptionResponse.fromJson(json);

        expect(response.duration, equals(2.0));
      });
    });

    group('copyWith()', () {
      test('should create copy with updated text', () {
        final original = TranscriptionResponse(
          text: 'Original',
          model: 'whisper-1',
          provider: 'openai',
        );

        final copy = original.copyWith(text: 'Updated');

        expect(copy.text, equals('Updated'));
        expect(copy.model, equals('whisper-1'));
      });

      test('should create copy that is equal but not identical', () {
        final original = TranscriptionResponse(
          text: 'Test',
          model: 'whisper-1',
          provider: 'openai',
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy, isNot(same(original)));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final response1 = TranscriptionResponse(
          text: 'Hello',
          language: 'en',
          duration: 2.5,
          model: 'whisper-1',
          provider: 'openai',
        );
        final response2 = TranscriptionResponse(
          text: 'Hello',
          language: 'en',
          duration: 2.5,
          model: 'whisper-1',
          provider: 'openai',
        );

        expect(response1, equals(response2));
        expect(response1.hashCode, equals(response2.hashCode));
      });

      test('should not be equal with different text', () {
        final response1 = TranscriptionResponse(
          text: 'Hello',
          model: 'whisper-1',
          provider: 'openai',
        );
        final response2 = TranscriptionResponse(
          text: 'World',
          model: 'whisper-1',
          provider: 'openai',
        );

        expect(response1, isNot(equals(response2)));
      });

      test('should not be equal with different segments', () {
        final segments1 = [
          const TranscriptionSegment(text: 'Hello', start: 0.0, end: 1.0),
        ];
        final segments2 = [
          const TranscriptionSegment(text: 'World', start: 0.0, end: 1.0),
        ];
        final response1 = TranscriptionResponse(
          text: 'Hello',
          segments: segments1,
          model: 'whisper-1',
          provider: 'openai',
        );
        final response2 = TranscriptionResponse(
          text: 'Hello',
          segments: segments2,
          model: 'whisper-1',
          provider: 'openai',
        );

        expect(response1, isNot(equals(response2)));
      });
    });

    group('toString()', () {
      test('should return string representation', () {
        final response = TranscriptionResponse(
          text: 'Hello, how are you today?',
          language: 'en',
          duration: 2.5,
          model: 'whisper-1',
          provider: 'openai',
        );

        final str = response.toString();

        expect(str, contains('TranscriptionResponse'));
        expect(str, contains('Hello'));
        expect(str, contains('en'));
        expect(str, contains('2.5'));
        expect(str, contains('whisper-1'));
      });

      test('should truncate long text', () {
        final longText = 'A' * 100;
        final response = TranscriptionResponse(
          text: longText,
          model: 'whisper-1',
          provider: 'openai',
        );

        final str = response.toString();

        expect(str, contains('...'));
      });
    });

    group('Round-trip serialization', () {
      test('should serialize and deserialize correctly', () {
        final segments = [
          const TranscriptionSegment(
            text: 'Hello',
            start: 0.0,
            end: 1.0,
            id: 0,
            confidence: 0.95,
          ),
          const TranscriptionSegment(
            text: 'World',
            start: 1.0,
            end: 2.0,
            id: 1,
            confidence: 0.90,
          ),
        ];
        final original = TranscriptionResponse(
          text: 'Hello World',
          language: 'en',
          duration: 2.5,
          segments: segments,
          model: 'whisper-1',
          provider: 'openai',
        );

        final json = original.toJson();
        final restored = TranscriptionResponse.fromJson(json);

        expect(restored.text, equals(original.text));
        expect(restored.language, equals(original.language));
        expect(restored.duration, equals(original.duration));
        expect(restored.segments?.length, equals(original.segments?.length));
        expect(restored.model, equals(original.model));
        expect(restored.provider, equals(original.provider));
      });
    });
  });
}

