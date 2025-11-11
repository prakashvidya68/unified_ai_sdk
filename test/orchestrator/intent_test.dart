import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/orchestrator/intent.dart';

void main() {
  group('Intent', () {
    group('Construction', () {
      test('should create intent with required fields', () {
        final intent = Intent(
          type: 'chat',
          capability: 'chat',
          confidence: 0.95,
        );

        expect(intent.type, equals('chat'));
        expect(intent.capability, equals('chat'));
        expect(intent.confidence, equals(0.95));
        expect(intent.metadata, isNull);
      });

      test('should create intent with metadata', () {
        final intent = Intent(
          type: 'chat',
          capability: 'chat',
          metadata: {'model': 'gpt-4'},
        );

        expect(intent.metadata, equals({'model': 'gpt-4'}));
      });

      test('should throw assertion error when confidence is out of range', () {
        expect(
          () => Intent(type: 'chat', capability: 'chat', confidence: 1.5),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => Intent(type: 'chat', capability: 'chat', confidence: -0.1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error when type is empty', () {
        expect(
          () => Intent(type: '', capability: 'chat'),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should throw assertion error when capability is empty', () {
        expect(
          () => Intent(type: 'chat', capability: ''),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('Factory constructors', () {
      test('Intent.chat() should create chat intent', () {
        final intent = Intent.chat();

        expect(intent.type, equals('chat'));
        expect(intent.capability, equals('chat'));
        expect(intent.confidence, equals(1.0));
      });

      test('Intent.chat() should accept custom confidence and metadata', () {
        final intent = Intent.chat(
          confidence: 0.8,
          metadata: {'model': 'gpt-4'},
        );

        expect(intent.confidence, equals(0.8));
        expect(intent.metadata, equals({'model': 'gpt-4'}));
      });

      test('Intent.imageGeneration() should create image generation intent',
          () {
        final intent = Intent.imageGeneration();

        expect(intent.type, equals('image_generation'));
        expect(intent.capability, equals('image'));
        expect(intent.confidence, equals(1.0));
      });

      test('Intent.embedding() should create embedding intent', () {
        final intent = Intent.embedding();

        expect(intent.type, equals('embedding'));
        expect(intent.capability, equals('embedding'));
        expect(intent.confidence, equals(1.0));
      });

      test('Intent.tts() should create TTS intent', () {
        final intent = Intent.tts();

        expect(intent.type, equals('tts'));
        expect(intent.capability, equals('tts'));
        expect(intent.confidence, equals(1.0));
      });

      test('Intent.stt() should create STT intent', () {
        final intent = Intent.stt();

        expect(intent.type, equals('stt'));
        expect(intent.capability, equals('stt'));
        expect(intent.confidence, equals(1.0));
      });
    });

    group('Equality and hashCode', () {
      test('should be equal when all fields match', () {
        final metadata = {'model': 'gpt-4'};
        final intent1 = Intent(
          type: 'chat',
          capability: 'chat',
          confidence: 0.95,
          metadata: metadata,
        );
        final intent2 = Intent(
          type: 'chat',
          capability: 'chat',
          confidence: 0.95,
          metadata: metadata, // Same map reference
        );

        expect(intent1, equals(intent2));
        // Equal objects must have equal hashCodes
        expect(intent1.hashCode, equals(intent2.hashCode));
      });

      test('should not be equal when type differs', () {
        final intent1 = Intent(type: 'chat', capability: 'chat');
        final intent2 = Intent(type: 'image', capability: 'image');

        expect(intent1, isNot(equals(intent2)));
      });

      test('should not be equal when capability differs', () {
        final intent1 = Intent(type: 'chat', capability: 'chat');
        final intent2 = Intent(type: 'chat', capability: 'embedding');

        expect(intent1, isNot(equals(intent2)));
      });

      test('should not be equal when confidence differs significantly', () {
        final intent1 = Intent(
          type: 'chat',
          capability: 'chat',
          confidence: 0.9,
        );
        final intent2 = Intent(
          type: 'chat',
          capability: 'chat',
          confidence: 0.5,
        );

        expect(intent1, isNot(equals(intent2)));
      });

      test(
          'should be equal when confidence differs slightly (within tolerance)',
          () {
        final intent1 = Intent(
          type: 'chat',
          capability: 'chat',
          confidence: 0.95,
        );
        final intent2 = Intent(
          type: 'chat',
          capability: 'chat',
          confidence: 0.9501, // Within 0.001 tolerance
        );

        expect(intent1, equals(intent2));
      });

      test('should handle null metadata in equality', () {
        final intent1 = Intent(type: 'chat', capability: 'chat');
        final intent2 = Intent(type: 'chat', capability: 'chat');

        expect(intent1, equals(intent2));
      });

      test('should handle different metadata in equality', () {
        final intent1 = Intent(
          type: 'chat',
          capability: 'chat',
          metadata: {'model': 'gpt-4'},
        );
        final intent2 = Intent(
          type: 'chat',
          capability: 'chat',
          metadata: {'model': 'gpt-3.5'},
        );

        expect(intent1, isNot(equals(intent2)));
      });
    });

    group('toString()', () {
      test('should return descriptive string representation', () {
        final intent = Intent(
          type: 'chat',
          capability: 'chat',
          confidence: 0.95,
        );

        final str = intent.toString();
        expect(str, contains('Intent'));
        expect(str, contains('type: chat'));
        expect(str, contains('capability: chat'));
        expect(str, contains('confidence: 0.95'));
      });
    });
  });
}
