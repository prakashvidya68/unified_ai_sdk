import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/responses/audio_response.dart';

void main() {
  group('AudioResponse', () {
    final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

    group('Construction', () {
      test('should create response with required fields', () {
        final response = AudioResponse(
          bytes: sampleBytes,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );

        expect(response.bytes, equals(sampleBytes));
        expect(response.format, equals('mp3'));
        expect(response.model, equals('tts-1'));
        expect(response.provider, equals('openai'));
      });

      test('should throw assertion error if bytes is empty', () {
        expect(
          () => AudioResponse(
            bytes: Uint8List(0),
            format: 'mp3',
            model: 'tts-1',
            provider: 'openai',
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error if format is empty', () {
        expect(
          () => AudioResponse(
            bytes: sampleBytes,
            format: '',
            model: 'tts-1',
            provider: 'openai',
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('toJson()', () {
      test('should serialize response to JSON with base64 encoded bytes', () {
        final response = AudioResponse(
          bytes: sampleBytes,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );

        final json = response.toJson();

        expect(json['format'], equals('mp3'));
        expect(json['model'], equals('tts-1'));
        expect(json['provider'], equals('openai'));
        expect(json['bytes'], isA<String>());
        expect(json['bytes'], equals(base64Encode(sampleBytes)));
      });

      test('should encode bytes as base64', () {
        final response = AudioResponse(
          bytes: Uint8List.fromList([72, 101, 108, 108, 111]), // "Hello" in ASCII
          format: 'wav',
          model: 'tts-1',
          provider: 'openai',
        );

        final json = response.toJson();

        expect(json['bytes'], equals(base64Encode(Uint8List.fromList([72, 101, 108, 108, 111]))));
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with base64 encoded bytes', () {
        final json = {
          'bytes': base64Encode(sampleBytes),
          'format': 'mp3',
          'model': 'tts-1',
          'provider': 'openai',
        };

        final response = AudioResponse.fromJson(json);

        expect(response.bytes, equals(sampleBytes));
        expect(response.format, equals('mp3'));
        expect(response.model, equals('tts-1'));
        expect(response.provider, equals('openai'));
      });

      test('should throw FormatException if bytes is missing', () {
        final json = {
          'format': 'mp3',
          'model': 'tts-1',
          'provider': 'openai',
        };

        expect(
          () => AudioResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if format is missing', () {
        final json = {
          'bytes': base64Encode(sampleBytes),
          'model': 'tts-1',
          'provider': 'openai',
        };

        expect(
          () => AudioResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if base64 is invalid', () {
        final json = {
          'bytes': 'invalid base64!!!',
          'format': 'mp3',
          'model': 'tts-1',
          'provider': 'openai',
        };

        expect(
          () => AudioResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('copyWith()', () {
      test('should create copy with updated bytes', () {
        final newBytes = Uint8List.fromList([6, 7, 8]);
        final original = AudioResponse(
          bytes: sampleBytes,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );

        final copy = original.copyWith(bytes: newBytes);

        expect(copy.bytes, equals(newBytes));
        expect(copy.format, equals('mp3'));
      });

      test('should create copy that is equal but not identical', () {
        final original = AudioResponse(
          bytes: sampleBytes,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy, isNot(same(original)));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final response1 = AudioResponse(
          bytes: sampleBytes,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );
        final response2 = AudioResponse(
          bytes: sampleBytes,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );

        expect(response1, equals(response2));
        expect(response1.hashCode, equals(response2.hashCode));
      });

      test('should not be equal with different bytes', () {
        final bytes1 = Uint8List.fromList([1, 2, 3]);
        final bytes2 = Uint8List.fromList([4, 5, 6]);
        final response1 = AudioResponse(
          bytes: bytes1,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );
        final response2 = AudioResponse(
          bytes: bytes2,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );

        expect(response1, isNot(equals(response2)));
      });

      test('should not be equal with different formats', () {
        final response1 = AudioResponse(
          bytes: sampleBytes,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );
        final response2 = AudioResponse(
          bytes: sampleBytes,
          format: 'wav',
          model: 'tts-1',
          provider: 'openai',
        );

        expect(response1, isNot(equals(response2)));
      });
    });

    group('toString()', () {
      test('should return string representation', () {
        final response = AudioResponse(
          bytes: sampleBytes,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );

        final str = response.toString();

        expect(str, contains('AudioResponse'));
        expect(str, contains('5 bytes'));
        expect(str, contains('mp3'));
        expect(str, contains('tts-1'));
        expect(str, contains('openai'));
      });
    });

    group('Round-trip serialization', () {
      test('should serialize and deserialize correctly', () {
        final original = AudioResponse(
          bytes: sampleBytes,
          format: 'mp3',
          model: 'tts-1',
          provider: 'openai',
        );

        final json = original.toJson();
        final restored = AudioResponse.fromJson(json);

        expect(restored.bytes, equals(original.bytes));
        expect(restored.format, equals(original.format));
        expect(restored.model, equals(original.model));
        expect(restored.provider, equals(original.provider));
      });
    });
  });
}

