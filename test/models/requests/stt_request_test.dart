import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/requests/stt_request.dart';

void main() {
  group('SttRequest', () {
    final sampleAudio = Uint8List.fromList([1, 2, 3, 4, 5]);

    group('Construction', () {
      test('should create request with required fields', () {
        final request = SttRequest(
          audio: sampleAudio,
        );

        expect(request.audio, equals(sampleAudio));
        expect(request.model, isNull);
        expect(request.language, isNull);
        expect(request.prompt, isNull);
        expect(request.providerOptions, isNull);
      });

      test('should create request with all fields', () {
        final request = SttRequest(
          audio: sampleAudio,
          model: 'whisper-1',
          language: 'en',
          prompt: 'Technical terms: API, SDK',
          providerOptions: {
            'openai': {'response_format': 'verbose_json'},
          },
        );

        expect(request.audio, equals(sampleAudio));
        expect(request.model, equals('whisper-1'));
        expect(request.language, equals('en'));
        expect(request.prompt, equals('Technical terms: API, SDK'));
        expect(request.providerOptions, equals({
          'openai': {'response_format': 'verbose_json'},
        }));
      });

      test('should throw assertion error if audio is empty', () {
        expect(
          () => SttRequest(audio: Uint8List(0)),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('toJson()', () {
      test('should serialize request to JSON (without audio)', () {
        final request = SttRequest(
          audio: sampleAudio,
        );

        final json = request.toJson();

        expect(json, isA<Map<String, dynamic>>());
        expect(json.containsKey('audio'), isFalse);
        expect(json.containsKey('model'), isFalse);
      });

      test('should serialize request with metadata fields', () {
        final request = SttRequest(
          audio: sampleAudio,
          model: 'whisper-1',
          language: 'en',
          prompt: 'Technical terms',
          providerOptions: {
            'openai': {'response_format': 'verbose_json'},
          },
        );

        final json = request.toJson();

        expect(json['model'], equals('whisper-1'));
        expect(json['language'], equals('en'));
        expect(json['prompt'], equals('Technical terms'));
        expect(json['provider_options'], equals({
          'openai': {'response_format': 'verbose_json'},
        }));
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with audio provided separately', () {
        final json = {
          'model': 'whisper-1',
          'language': 'en',
        };

        final request = SttRequest.fromJson(json, audio: sampleAudio);

        expect(request.audio, equals(sampleAudio));
        expect(request.model, equals('whisper-1'));
        expect(request.language, equals('en'));
      });

      test('should deserialize JSON with all fields', () {
        final json = {
          'model': 'whisper-1',
          'language': 'en',
          'prompt': 'Technical terms',
          'provider_options': {
            'openai': {'response_format': 'verbose_json'},
          },
        };

        final request = SttRequest.fromJson(json, audio: sampleAudio);

        expect(request.model, equals('whisper-1'));
        expect(request.language, equals('en'));
        expect(request.prompt, equals('Technical terms'));
      });

      test('should require audio to be provided separately', () {
        final json = {'model': 'whisper-1'};

        // fromJson requires audio to be provided explicitly
        final request = SttRequest.fromJson(json, audio: sampleAudio);

        expect(request.audio, equals(sampleAudio));
        expect(request.model, equals('whisper-1'));
      });
    });

    group('copyWith()', () {
      test('should create copy with updated audio', () {
        final newAudio = Uint8List.fromList([6, 7, 8]);
        final original = SttRequest(
          audio: sampleAudio,
          model: 'whisper-1',
        );

        final copy = original.copyWith(audio: newAudio);

        expect(copy.audio, equals(newAudio));
        expect(copy.model, equals('whisper-1'));
      });

      test('should create copy that is equal but not identical', () {
        final original = SttRequest(
          audio: sampleAudio,
          model: 'whisper-1',
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy, isNot(same(original)));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final request1 = SttRequest(
          audio: sampleAudio,
          model: 'whisper-1',
          language: 'en',
        );
        final request2 = SttRequest(
          audio: sampleAudio,
          model: 'whisper-1',
          language: 'en',
        );

        expect(request1, equals(request2));
        expect(request1.hashCode, equals(request2.hashCode));
      });

      test('should not be equal with different audio', () {
        final audio1 = Uint8List.fromList([1, 2, 3]);
        final audio2 = Uint8List.fromList([4, 5, 6]);
        final request1 = SttRequest(audio: audio1);
        final request2 = SttRequest(audio: audio2);

        expect(request1, isNot(equals(request2)));
      });

      test('should not be equal with different models', () {
        final request1 = SttRequest(
          audio: sampleAudio,
          model: 'whisper-1',
        );
        final request2 = SttRequest(
          audio: sampleAudio,
          model: 'whisper-2',
        );

        expect(request1, isNot(equals(request2)));
      });
    });

    group('toString()', () {
      test('should return string representation', () {
        final request = SttRequest(
          audio: sampleAudio,
          model: 'whisper-1',
          language: 'en',
        );

        final str = request.toString();

        expect(str, contains('SttRequest'));
        expect(str, contains('5 bytes'));
        expect(str, contains('whisper-1'));
        expect(str, contains('en'));
      });

      test('should truncate long prompts', () {
        final longPrompt = 'A' * 100;
        final request = SttRequest(
          audio: sampleAudio,
          prompt: longPrompt,
        );

        final str = request.toString();

        expect(str, contains('...'));
      });
    });
  });
}

