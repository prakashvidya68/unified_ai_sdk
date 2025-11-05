import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/common/capabilities.dart';

void main() {
  group('ProviderCapabilities', () {
    group('Construction', () {
      test('should create with default values', () {
        const capabilities = ProviderCapabilities();

        expect(capabilities.supportsChat, isFalse);
        expect(capabilities.supportsEmbedding, isFalse);
        expect(capabilities.supportsImageGeneration, isFalse);
        expect(capabilities.supportsTTS, isFalse);
        expect(capabilities.supportsSTT, isFalse);
        expect(capabilities.supportsStreaming, isFalse);
        expect(capabilities.supportedModels, isEmpty);
      });

      test('should create with all capabilities enabled', () {
        const capabilities = ProviderCapabilities(
          supportsChat: true,
          supportsEmbedding: true,
          supportsImageGeneration: true,
          supportsTTS: true,
          supportsSTT: true,
          supportsStreaming: true,
          supportedModels: ['gpt-4', 'gpt-3.5-turbo'],
        );

        expect(capabilities.supportsChat, isTrue);
        expect(capabilities.supportsEmbedding, isTrue);
        expect(capabilities.supportsImageGeneration, isTrue);
        expect(capabilities.supportsTTS, isTrue);
        expect(capabilities.supportsSTT, isTrue);
        expect(capabilities.supportsStreaming, isTrue);
        expect(capabilities.supportedModels, equals(['gpt-4', 'gpt-3.5-turbo']));
      });

      test('should create with partial capabilities', () {
        const capabilities = ProviderCapabilities(
          supportsChat: true,
          supportsStreaming: true,
        );

        expect(capabilities.supportsChat, isTrue);
        expect(capabilities.supportsStreaming, isTrue);
        expect(capabilities.supportsEmbedding, isFalse);
        expect(capabilities.supportedModels, isEmpty);
      });
    });

    group('fromJson', () {
      test('should parse JSON with camelCase keys', () {
        final json = {
          'supportsChat': true,
          'supportsEmbedding': true,
          'supportsImageGeneration': false,
          'supportsTTS': true,
          'supportsSTT': false,
          'supportsStreaming': true,
          'supportedModels': ['model-1', 'model-2'],
        };

        final capabilities = ProviderCapabilities.fromJson(json);

        expect(capabilities.supportsChat, isTrue);
        expect(capabilities.supportsEmbedding, isTrue);
        expect(capabilities.supportsImageGeneration, isFalse);
        expect(capabilities.supportsTTS, isTrue);
        expect(capabilities.supportsSTT, isFalse);
        expect(capabilities.supportsStreaming, isTrue);
        expect(capabilities.supportedModels, equals(['model-1', 'model-2']));
      });

      test('should parse JSON with snake_case keys', () {
        final json = {
          'supports_chat': true,
          'supports_embedding': false,
          'supports_image_generation': true,
          'supports_tts': false,
          'supports_stt': true,
          'supports_streaming': false,
          'supported_models': ['gpt-4'],
        };

        final capabilities = ProviderCapabilities.fromJson(json);

        expect(capabilities.supportsChat, isTrue);
        expect(capabilities.supportsEmbedding, isFalse);
        expect(capabilities.supportsImageGeneration, isTrue);
        expect(capabilities.supportsTTS, isFalse);
        expect(capabilities.supportsSTT, isTrue);
        expect(capabilities.supportsStreaming, isFalse);
        expect(capabilities.supportedModels, equals(['gpt-4']));
      });

      test('should handle missing keys with defaults', () {
        final json = <String, dynamic>{};

        final capabilities = ProviderCapabilities.fromJson(json);

        expect(capabilities.supportsChat, isFalse);
        expect(capabilities.supportsEmbedding, isFalse);
        expect(capabilities.supportedModels, isEmpty);
      });

      test('should prefer camelCase over snake_case', () {
        final json = {
          'supportsChat': true,
          'supports_chat': false,
        };

        final capabilities = ProviderCapabilities.fromJson(json);

        expect(capabilities.supportsChat, isTrue);
      });

      test('should handle empty supportedModels list', () {
        final json = {
          'supportedModels': <String>[],
        };

        final capabilities = ProviderCapabilities.fromJson(json);

        expect(capabilities.supportedModels, isEmpty);
      });
    });

    group('toJson', () {
      test('should serialize to JSON with camelCase keys', () {
        const capabilities = ProviderCapabilities(
          supportsChat: true,
          supportsEmbedding: false,
          supportsImageGeneration: true,
          supportsTTS: false,
          supportsSTT: true,
          supportsStreaming: false,
          supportedModels: ['model-1', 'model-2'],
        );

        final json = capabilities.toJson();

        expect(json['supportsChat'], isTrue);
        expect(json['supportsEmbedding'], isFalse);
        expect(json['supportsImageGeneration'], isTrue);
        expect(json['supportsTTS'], isFalse);
        expect(json['supportsSTT'], isTrue);
        expect(json['supportsStreaming'], isFalse);
        expect(json['supportedModels'], equals(['model-1', 'model-2']));
      });

      test('should include all fields even when false', () {
        const capabilities = ProviderCapabilities();

        final json = capabilities.toJson();

        expect(json.containsKey('supportsChat'), isTrue);
        expect(json.containsKey('supportsEmbedding'), isTrue);
        expect(json.containsKey('supportsImageGeneration'), isTrue);
        expect(json.containsKey('supportsTTS'), isTrue);
        expect(json.containsKey('supportsSTT'), isTrue);
        expect(json.containsKey('supportsStreaming'), isTrue);
        expect(json.containsKey('supportedModels'), isTrue);
      });

      test('should round-trip through JSON', () {
        const original = ProviderCapabilities(
          supportsChat: true,
          supportsEmbedding: true,
          supportsStreaming: true,
          supportedModels: ['gpt-4', 'gpt-3.5'],
        );

        final json = original.toJson();
        final restored = ProviderCapabilities.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        const original = ProviderCapabilities(
          supportsChat: true,
          supportsEmbedding: false,
        );

        final updated = original.copyWith(supportsEmbedding: true);

        expect(updated.supportsChat, isTrue);
        expect(updated.supportsEmbedding, isTrue);
      });

      test('should preserve unchanged fields', () {
        const original = ProviderCapabilities(
          supportsChat: true,
          supportsStreaming: true,
          supportedModels: ['model-1'],
        );

        final updated = original.copyWith(supportsEmbedding: true);

        expect(updated.supportsChat, isTrue);
        expect(updated.supportsStreaming, isTrue);
        expect(updated.supportedModels, equals(['model-1']));
        expect(updated.supportsEmbedding, isTrue);
      });

      test('should update supportedModels', () {
        const original = ProviderCapabilities(
          supportedModels: ['model-1'],
        );

        final updated = original.copyWith(
          supportedModels: ['model-1', 'model-2'],
        );

        expect(updated.supportedModels, equals(['model-1', 'model-2']));
      });

      test('should allow updating multiple fields', () {
        const original = ProviderCapabilities();

        final updated = original.copyWith(
          supportsChat: true,
          supportsStreaming: true,
          supportedModels: ['gpt-4'],
        );

        expect(updated.supportsChat, isTrue);
        expect(updated.supportsStreaming, isTrue);
        expect(updated.supportedModels, equals(['gpt-4']));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        const capabilities1 = ProviderCapabilities(
          supportsChat: true,
          supportsStreaming: true,
          supportedModels: ['gpt-4'],
        );
        const capabilities2 = ProviderCapabilities(
          supportsChat: true,
          supportsStreaming: true,
          supportedModels: ['gpt-4'],
        );

        expect(capabilities1, equals(capabilities2));
        expect(capabilities1.hashCode, equals(capabilities2.hashCode));
      });

      test('should not be equal with different boolean values', () {
        const capabilities1 = ProviderCapabilities(supportsChat: true);
        const capabilities2 = ProviderCapabilities(supportsChat: false);

        expect(capabilities1, isNot(equals(capabilities2)));
      });

      test('should not be equal with different supportedModels', () {
        const capabilities1 = ProviderCapabilities(
          supportedModels: ['model-1'],
        );
        const capabilities2 = ProviderCapabilities(
          supportedModels: ['model-2'],
        );

        expect(capabilities1, isNot(equals(capabilities2)));
      });

      test('should not be equal with different order of models', () {
        const capabilities1 = ProviderCapabilities(
          supportedModels: ['model-1', 'model-2'],
        );
        const capabilities2 = ProviderCapabilities(
          supportedModels: ['model-2', 'model-1'],
        );

        expect(capabilities1, isNot(equals(capabilities2)));
      });

      test('should be equal with empty models lists', () {
        const capabilities1 = ProviderCapabilities();
        const capabilities2 = ProviderCapabilities();

        expect(capabilities1, equals(capabilities2));
      });
    });

    group('toString', () {
      test('should format with no capabilities', () {
        const capabilities = ProviderCapabilities();

        final str = capabilities.toString();

        expect(str, contains('none'));
        expect(str, contains('no models'));
      });

      test('should format with single capability', () {
        const capabilities = ProviderCapabilities(supportsChat: true);

        final str = capabilities.toString();

        expect(str, contains('Chat'));
        expect(str, contains('no models'));
      });

      test('should format with multiple capabilities', () {
        const capabilities = ProviderCapabilities(
          supportsChat: true,
          supportsEmbedding: true,
          supportsStreaming: true,
        );

        final str = capabilities.toString();

        expect(str, contains('Chat'));
        expect(str, contains('Embedding'));
        expect(str, contains('Streaming'));
      });

      test('should format with supported models', () {
        const capabilities = ProviderCapabilities(
          supportsChat: true,
          supportedModels: ['gpt-4', 'gpt-3.5'],
        );

        final str = capabilities.toString();

        expect(str, contains('Chat'));
        expect(str, contains('2 model(s)'));
      });

      test('should format all capabilities', () {
        const capabilities = ProviderCapabilities(
          supportsChat: true,
          supportsEmbedding: true,
          supportsImageGeneration: true,
          supportsTTS: true,
          supportsSTT: true,
          supportsStreaming: true,
        );

        final str = capabilities.toString();

        expect(str, contains('Chat'));
        expect(str, contains('Embedding'));
        expect(str, contains('Image'));
        expect(str, contains('TTS'));
        expect(str, contains('STT'));
        expect(str, contains('Streaming'));
      });
    });

    group('Edge cases', () {
      test('should handle large list of supported models', () {
        final models = List.generate(100, (i) => 'model-$i');
        final capabilities = ProviderCapabilities(supportedModels: models);

        expect(capabilities.supportedModels.length, equals(100));
        expect(capabilities.supportedModels.first, equals('model-0'));
        expect(capabilities.supportedModels.last, equals('model-99'));
      });

      test('should handle empty string in supportedModels', () {
        const capabilities = ProviderCapabilities(
          supportedModels: ['', 'model-1'],
        );

        expect(capabilities.supportedModels, equals(['', 'model-1']));
      });

      test('should handle duplicate models in list', () {
        const capabilities = ProviderCapabilities(
          supportedModels: ['model-1', 'model-1'],
        );

        expect(capabilities.supportedModels, equals(['model-1', 'model-1']));
      });
    });
  });
}

