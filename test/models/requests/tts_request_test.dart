import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/requests/tts_request.dart';

void main() {
  group('TtsRequest', () {
    group('Construction', () {
      test('should create request with required fields', () {
        final request = TtsRequest(
          text: 'Hello, world!',
        );

        expect(request.text, equals('Hello, world!'));
        expect(request.model, isNull);
        expect(request.voice, isNull);
        expect(request.speed, isNull);
        expect(request.providerOptions, isNull);
      });

      test('should create request with all fields', () {
        final request = TtsRequest(
          text: 'Hello, how are you?',
          model: 'tts-1',
          voice: 'alloy',
          speed: 1.0,
          providerOptions: {
            'openai': {'response_format': 'mp3'},
          },
        );

        expect(request.text, equals('Hello, how are you?'));
        expect(request.model, equals('tts-1'));
        expect(request.voice, equals('alloy'));
        expect(request.speed, equals(1.0));
        expect(request.providerOptions, equals({
          'openai': {'response_format': 'mp3'},
        }));
      });

      test('should throw assertion error if text is empty', () {
        expect(
          () => TtsRequest(text: ''),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('toJson()', () {
      test('should serialize request to JSON with only required fields', () {
        final request = TtsRequest(
          text: 'Hello, world!',
        );

        final json = request.toJson();

        expect(json, isA<Map<String, dynamic>>());
        expect(json['text'], equals('Hello, world!'));
        expect(json.containsKey('model'), isFalse);
        expect(json.containsKey('voice'), isFalse);
      });

      test('should serialize request with all fields', () {
        final request = TtsRequest(
          text: 'Hello',
          model: 'tts-1',
          voice: 'alloy',
          speed: 1.5,
          providerOptions: {
            'openai': {'response_format': 'mp3'},
          },
        );

        final json = request.toJson();

        expect(json['text'], equals('Hello'));
        expect(json['model'], equals('tts-1'));
        expect(json['voice'], equals('alloy'));
        expect(json['speed'], equals(1.5));
        expect(json['provider_options'], equals({
          'openai': {'response_format': 'mp3'},
        }));
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with only required fields', () {
        final json = {
          'text': 'Hello, world!',
        };

        final request = TtsRequest.fromJson(json);

        expect(request.text, equals('Hello, world!'));
        expect(request.model, isNull);
        expect(request.voice, isNull);
      });

      test('should deserialize JSON with all fields', () {
        final json = {
          'text': 'Hello',
          'model': 'tts-1',
          'voice': 'alloy',
          'speed': 1.5,
          'provider_options': {
            'openai': {'response_format': 'mp3'},
          },
        };

        final request = TtsRequest.fromJson(json);

        expect(request.text, equals('Hello'));
        expect(request.model, equals('tts-1'));
        expect(request.voice, equals('alloy'));
        expect(request.speed, equals(1.5));
      });

      test('should throw FormatException if text is missing', () {
        final json = <String, dynamic>{};

        expect(
          () => TtsRequest.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if text is empty', () {
        final json = {'text': ''};

        expect(
          () => TtsRequest.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should handle speed as integer', () {
        final json = {
          'text': 'Hello',
          'speed': 1,
        };

        final request = TtsRequest.fromJson(json);

        expect(request.speed, equals(1.0));
      });
    });

    group('copyWith()', () {
      test('should create copy with updated text', () {
        final original = TtsRequest(
          text: 'Original',
          model: 'tts-1',
        );

        final copy = original.copyWith(text: 'Updated');

        expect(copy.text, equals('Updated'));
        expect(copy.model, equals('tts-1'));
      });

      test('should create copy that is equal but not identical', () {
        final original = TtsRequest(
          text: 'Test',
          model: 'tts-1',
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy, isNot(same(original)));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final request1 = TtsRequest(
          text: 'Hello',
          model: 'tts-1',
          voice: 'alloy',
          speed: 1.0,
        );
        final request2 = TtsRequest(
          text: 'Hello',
          model: 'tts-1',
          voice: 'alloy',
          speed: 1.0,
        );

        expect(request1, equals(request2));
        expect(request1.hashCode, equals(request2.hashCode));
      });

      test('should not be equal with different text', () {
        final request1 = TtsRequest(text: 'Hello');
        final request2 = TtsRequest(text: 'World');

        expect(request1, isNot(equals(request2)));
      });

      test('should not be equal with different speed', () {
        final request1 = TtsRequest(text: 'Hello', speed: 1.0);
        final request2 = TtsRequest(text: 'Hello', speed: 1.5);

        expect(request1, isNot(equals(request2)));
      });
    });

    group('toString()', () {
      test('should return string representation', () {
        final request = TtsRequest(
          text: 'Hello, how are you today?',
          model: 'tts-1',
          voice: 'alloy',
        );

        final str = request.toString();

        expect(str, contains('TtsRequest'));
        expect(str, contains('Hello'));
        expect(str, contains('tts-1'));
        expect(str, contains('alloy'));
      });

      test('should truncate long text', () {
        final longText = 'A' * 100;
        final request = TtsRequest(text: longText);

        final str = request.toString();

        expect(str, contains('...'));
        expect(str.length, lessThan(longText.length + 50));
      });
    });

    group('Round-trip serialization', () {
      test('should serialize and deserialize correctly', () {
        final original = TtsRequest(
          text: 'Hello, world!',
          model: 'tts-1',
          voice: 'alloy',
          speed: 1.0,
          providerOptions: {
            'openai': {'response_format': 'mp3'},
          },
        );

        final json = original.toJson();
        final restored = TtsRequest.fromJson(json);

        expect(restored.text, equals(original.text));
        expect(restored.model, equals(original.model));
        expect(restored.voice, equals(original.voice));
        expect(restored.speed, equals(original.speed));
        expect(restored.providerOptions, equals(original.providerOptions));
      });
    });
  });
}

