import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/models/requests/chat_request.dart';
import 'package:unified_ai_sdk/src/models/requests/embedding_request.dart';
import 'package:unified_ai_sdk/src/models/requests/image_request.dart';
import 'package:unified_ai_sdk/src/orchestrator/intent.dart';
import 'package:unified_ai_sdk/src/orchestrator/intent_detector.dart';

void main() {
  group('IntentDetector', () {
    late IntentDetector detector;

    setUp(() {
      detector = IntentDetector();
    });

    group('Explicit Request Types', () {
      test('should detect image generation intent from ImageRequest', () {
        final request = ImageRequest(prompt: 'A beautiful sunset');
        final intent = detector.detect(request);

        expect(intent.type, equals('image_generation'));
        expect(intent.capability, equals('image'));
        expect(intent.confidence, equals(1.0));
        expect(intent.metadata?['detection_method'],
            equals('explicit_request_type'));
      });

      test('should detect embedding intent from EmbeddingRequest', () {
        final request = EmbeddingRequest(inputs: ['Hello, world!']);
        final intent = detector.detect(request);

        expect(intent.type, equals('embedding'));
        expect(intent.capability, equals('embedding'));
        expect(intent.confidence, equals(1.0));
        expect(intent.metadata?['detection_method'],
            equals('explicit_request_type'));
        expect(intent.metadata?['input_count'], equals(1));
      });
    });

    group('Chat Request - Image Generation Detection', () {
      test('should detect image generation from "draw" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Draw a picture of a cat'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('image_generation'));
        expect(intent.capability, equals('image'));
        expect(intent.confidence, greaterThan(0.5));
        expect(
            intent.metadata?['detection_method'], equals('keyword_matching'));
        expect(intent.metadata?['matched_keywords'], isNotEmpty);
      });

      test('should detect image generation from "generate image" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(
                role: Role.user, content: 'Generate an image of a sunset'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('image_generation'));
        expect(intent.confidence, greaterThan(0.5));
      });

      test('should detect image generation from "create art" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Create art of a mountain'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('image_generation'));
      });

      test('should detect image generation from "logo" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(
                role: Role.user, content: 'Design a logo for my company'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('image_generation'));
      });

      test('should detect image generation from multiple keywords', () {
        final request = ChatRequest(
          messages: [
            const Message(
                role: Role.user,
                content: 'Draw and create an image of a beautiful landscape'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('image_generation'));
        expect(intent.confidence, greaterThan(0.6));
      });
    });

    group('Chat Request - Embedding Detection', () {
      test('should detect embedding intent from "embed" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(
                role: Role.user, content: 'Get embedding for this text'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('embedding'));
        expect(intent.capability, equals('embedding'));
        expect(intent.confidence, greaterThan(0.5));
      });

      test('should detect embedding intent from "vector" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Convert this to a vector'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('embedding'));
      });

      test('should detect embedding intent from "semantic search" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(
                role: Role.user,
                content: 'Find similar items using semantic search'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('embedding'));
      });
    });

    group('Chat Request - TTS Detection', () {
      test('should detect TTS intent from "speak" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Speak this text'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('tts'));
        expect(intent.capability, equals('tts'));
        expect(intent.confidence, greaterThan(0.5));
      });

      test('should detect TTS intent from "read aloud" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Read this aloud'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('tts'));
      });
    });

    group('Chat Request - STT Detection', () {
      test('should detect STT intent from "transcribe" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Transcribe this audio'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('stt'));
        expect(intent.capability, equals('stt'));
        expect(intent.confidence, greaterThan(0.5));
      });

      test('should detect STT intent from "speech to text" keyword', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Convert speech to text'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('stt'));
      });
    });

    group('Chat Request - Default Chat Intent', () {
      test('should default to chat intent when no keywords match', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello, how are you?'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('chat'));
        expect(intent.capability, equals('chat'));
        expect(intent.confidence, equals(0.8));
        expect(intent.metadata?['detection_method'], equals('default'));
      });

      test('should default to chat for general questions', () {
        final request = ChatRequest(
          messages: [
            const Message(
                role: Role.user, content: 'What is the capital of France?'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('chat'));
      });

      test('should default to chat for empty user messages', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.system, content: 'You are helpful.'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('chat'));
        expect(intent.confidence, equals(0.5));
      });
    });

    group('Chat Request - Multiple Messages', () {
      test('should analyze all user messages for intent', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.system, content: 'You are helpful.'),
            const Message(role: Role.user, content: 'Hello'),
            const Message(role: Role.user, content: 'Draw a cat'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('image_generation'));
      });

      test('should prioritize intent from later messages', () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello'),
            const Message(role: Role.user, content: 'Generate an image'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.type, equals('image_generation'));
      });
    });

    group('Confidence Scoring', () {
      test('should return higher confidence for explicit request types', () {
        final imageRequest = ImageRequest(prompt: 'A cat');
        final imageIntent = detector.detect(imageRequest);

        final chatRequest = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Draw a cat'),
          ],
        );
        final chatIntent = detector.detect(chatRequest);

        expect(imageIntent.confidence, equals(1.0));
        expect(chatIntent.confidence, greaterThan(0.5));
        expect(chatIntent.confidence, lessThan(1.0));
      });

      test('should return confidence between 0.5 and 1.0 for detected intents',
          () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Draw a picture'),
          ],
        );
        final intent = detector.detect(request);

        expect(intent.confidence, greaterThanOrEqualTo(0.5));
        expect(intent.confidence, lessThanOrEqualTo(1.0));
      });
    });

    group('Error Handling', () {
      test('should throw ArgumentError for unsupported request type', () {
        expect(
          () => detector.detect('invalid request'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError with helpful message', () {
        expect(
          () => detector.detect(123),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unsupported request type'),
            ),
          ),
        );
      });
    });

    group('Metadata', () {
      test('should include detection method in metadata', () {
        final imageRequest = ImageRequest(prompt: 'A cat');
        final intent = detector.detect(imageRequest);

        expect(intent.metadata?['detection_method'],
            equals('explicit_request_type'));
      });

      test('should include matched keywords in metadata for keyword detection',
          () {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Draw a picture'),
          ],
        );
        final intent = detector.detect(request);

        expect(
            intent.metadata?['detection_method'], equals('keyword_matching'));
        expect(intent.metadata?['matched_keywords'], isA<List<String>>());
        expect(intent.metadata?['matched_keywords'], isNotEmpty);
      });
    });
  });

  group('Intent', () {
    test('should create chat intent with factory', () {
      final intent = Intent.chat(confidence: 0.9);
      expect(intent.type, equals('chat'));
      expect(intent.capability, equals('chat'));
      expect(intent.confidence, equals(0.9));
    });

    test('should create image generation intent with factory', () {
      final intent = Intent.imageGeneration(confidence: 0.95);
      expect(intent.type, equals('image_generation'));
      expect(intent.capability, equals('image'));
      expect(intent.confidence, equals(0.95));
    });

    test('should create embedding intent with factory', () {
      final intent = Intent.embedding(confidence: 0.85);
      expect(intent.type, equals('embedding'));
      expect(intent.capability, equals('embedding'));
      expect(intent.confidence, equals(0.85));
    });

    test('should validate confidence range', () {
      expect(
        () => Intent.chat(confidence: -0.1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => Intent.chat(confidence: 1.1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should support metadata', () {
      final intent = Intent.chat(
        confidence: 0.9,
        metadata: {'key': 'value'},
      );
      expect(intent.metadata?['key'], equals('value'));
    });

    test('should implement equality correctly', () {
      final intent1 = Intent.chat(confidence: 0.9);
      final intent2 = Intent.chat(confidence: 0.9);
      final intent3 = Intent.chat(confidence: 0.8);

      expect(intent1, equals(intent2));
      expect(intent1, isNot(equals(intent3)));
    });
  });
}
