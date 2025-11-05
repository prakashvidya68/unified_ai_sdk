import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/models/common/capabilities.dart';
import 'package:unified_ai_sdk/src/orchestrator/provider_registry.dart';
import 'package:unified_ai_sdk/src/providers/base/ai_provider.dart';

// Import MockProvider from ai_provider_test.dart
import '../providers/base/ai_provider_test.dart';

void main() {
  group('ProviderRegistry', () {
    late ProviderRegistry registry;

    setUp(() {
      registry = ProviderRegistry();
    });

    group('register', () {
      test('should register a provider successfully', () {
        final provider = MockProvider(
          id: 'test-provider',
          name: 'Test Provider',
          capabilities: const ProviderCapabilities(supportsChat: true),
        );

        expect(() => registry.register(provider), returnsNormally);
        expect(registry.has('test-provider'), isTrue);
        expect(registry.count, equals(1));
      });

      test('should throw ClientError when registering duplicate provider', () {
        final provider1 = MockProvider(
          id: 'duplicate-id',
          name: 'Provider 1',
          capabilities: const ProviderCapabilities(),
        );
        final provider2 = MockProvider(
          id: 'duplicate-id',
          name: 'Provider 2',
          capabilities: const ProviderCapabilities(),
        );

        registry.register(provider1);

        expect(
          () => registry.register(provider2),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'DUPLICATE_PROVIDER',
          )),
        );
      });

      test('should throw ClientError when provider ID is empty', () {
        final provider = MockProvider(
          id: '',
          name: 'Empty ID Provider',
          capabilities: const ProviderCapabilities(),
        );

        expect(
          () => registry.register(provider),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_PROVIDER_ID',
          )),
        );
      });

      test('should register multiple providers with different IDs', () {
        final provider1 = MockProvider(
          id: 'provider-1',
          name: 'Provider 1',
          capabilities: const ProviderCapabilities(),
        );
        final provider2 = MockProvider(
          id: 'provider-2',
          name: 'Provider 2',
          capabilities: const ProviderCapabilities(),
        );
        final provider3 = MockProvider(
          id: 'provider-3',
          name: 'Provider 3',
          capabilities: const ProviderCapabilities(),
        );

        registry.register(provider1);
        registry.register(provider2);
        registry.register(provider3);

        expect(registry.count, equals(3));
        expect(registry.has('provider-1'), isTrue);
        expect(registry.has('provider-2'), isTrue);
        expect(registry.has('provider-3'), isTrue);
      });
    });

    group('get', () {
      test('should return provider when found', () {
        final provider = MockProvider(
          id: 'test-provider',
          name: 'Test Provider',
          capabilities: const ProviderCapabilities(),
        );

        registry.register(provider);
        final retrieved = registry.get('test-provider');

        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals('test-provider'));
        expect(retrieved.name, equals('Test Provider'));
      });

      test('should return null when provider not found', () {
        final retrieved = registry.get('non-existent');
        expect(retrieved, isNull);
      });

      test('should return null for empty string ID', () {
        final retrieved = registry.get('');
        expect(retrieved, isNull);
      });

      test('should be case-sensitive', () {
        final provider = MockProvider(
          id: 'TestProvider',
          name: 'Test Provider',
          capabilities: const ProviderCapabilities(),
        );

        registry.register(provider);

        expect(registry.get('TestProvider'), isNotNull);
        expect(registry.get('testprovider'), isNull);
        expect(registry.get('test-provider'), isNull);
      });
    });

    group('getByCapability', () {
      test('should return providers that support chat', () {
        final chatProvider1 = MockProvider(
          id: 'chat-1',
          name: 'Chat Provider 1',
          capabilities: const ProviderCapabilities(supportsChat: true),
        );
        final chatProvider2 = MockProvider(
          id: 'chat-2',
          name: 'Chat Provider 2',
          capabilities: const ProviderCapabilities(supportsChat: true),
        );
        final nonChatProvider = MockProvider(
          id: 'non-chat',
          name: 'Non-Chat Provider',
          capabilities: const ProviderCapabilities(supportsChat: false),
        );

        registry.register(chatProvider1);
        registry.register(chatProvider2);
        registry.register(nonChatProvider);

        final chatProviders = registry.getByCapability('chat');

        expect(chatProviders.length, equals(2));
        expect(
            chatProviders.map((p) => p.id), containsAll(['chat-1', 'chat-2']));
        expect(chatProviders.map((p) => p.id), isNot(contains('non-chat')));
      });

      test('should return providers that support embedding', () {
        final embeddingProvider = MockProvider(
          id: 'embed-provider',
          name: 'Embedding Provider',
          capabilities: const ProviderCapabilities(supportsEmbedding: true),
        );
        final nonEmbeddingProvider = MockProvider(
          id: 'non-embed',
          name: 'Non-Embedding Provider',
          capabilities: const ProviderCapabilities(supportsEmbedding: false),
        );

        registry.register(embeddingProvider);
        registry.register(nonEmbeddingProvider);

        final embeddingProviders = registry.getByCapability('embedding');
        expect(embeddingProviders.length, equals(1));
        expect(embeddingProviders.first.id, equals('embed-provider'));

        // Test alias 'embed'
        final embedProviders = registry.getByCapability('embed');
        expect(embedProviders.length, equals(1));
        expect(embedProviders.first.id, equals('embed-provider'));
      });

      test('should return providers that support image generation', () {
        final imageProvider = MockProvider(
          id: 'image-provider',
          name: 'Image Provider',
          capabilities: const ProviderCapabilities(
            supportsImageGeneration: true,
          ),
        );
        final nonImageProvider = MockProvider(
          id: 'non-image',
          name: 'Non-Image Provider',
          capabilities: const ProviderCapabilities(
            supportsImageGeneration: false,
          ),
        );

        registry.register(imageProvider);
        registry.register(nonImageProvider);

        final imageProviders = registry.getByCapability('image');
        expect(imageProviders.length, equals(1));
        expect(imageProviders.first.id, equals('image-provider'));

        // Test alias 'imageGeneration'
        final imageGenProviders = registry.getByCapability('imageGeneration');
        expect(imageGenProviders.length, equals(1));
      });

      test('should return providers that support TTS', () {
        final ttsProvider = MockProvider(
          id: 'tts-provider',
          name: 'TTS Provider',
          capabilities: const ProviderCapabilities(supportsTTS: true),
        );
        registry.register(ttsProvider);

        final ttsProviders = registry.getByCapability('tts');
        expect(ttsProviders.length, equals(1));
        expect(ttsProviders.first.id, equals('tts-provider'));
      });

      test('should return providers that support STT', () {
        final sttProvider = MockProvider(
          id: 'stt-provider',
          name: 'STT Provider',
          capabilities: const ProviderCapabilities(supportsSTT: true),
        );
        registry.register(sttProvider);

        final sttProviders = registry.getByCapability('stt');
        expect(sttProviders.length, equals(1));
        expect(sttProviders.first.id, equals('stt-provider'));
      });

      test('should return providers that support streaming', () {
        final streamingProvider = MockProvider(
          id: 'streaming-provider',
          name: 'Streaming Provider',
          capabilities: const ProviderCapabilities(supportsStreaming: true),
        );
        final nonStreamingProvider = MockProvider(
          id: 'non-streaming',
          name: 'Non-Streaming Provider',
          capabilities: const ProviderCapabilities(supportsStreaming: false),
        );

        registry.register(streamingProvider);
        registry.register(nonStreamingProvider);

        final streamingProviders = registry.getByCapability('streaming');
        expect(streamingProviders.length, equals(1));
        expect(streamingProviders.first.id, equals('streaming-provider'));
      });

      test('should return empty list for unknown capability', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: const ProviderCapabilities(),
        );
        registry.register(provider);

        final providers = registry.getByCapability('unknown-capability');
        expect(providers, isEmpty);
      });

      test('should be case-insensitive for capability names', () {
        final chatProvider = MockProvider(
          id: 'chat-provider',
          name: 'Chat Provider',
          capabilities: const ProviderCapabilities(supportsChat: true),
        );
        registry.register(chatProvider);

        expect(registry.getByCapability('CHAT').length, equals(1));
        expect(registry.getByCapability('Chat').length, equals(1));
        expect(registry.getByCapability('chat').length, equals(1));
      });

      test('should handle providers with multiple capabilities', () {
        final multiCapProvider = MockProvider(
          id: 'multi-cap',
          name: 'Multi-Cap Provider',
          capabilities: const ProviderCapabilities(
            supportsChat: true,
            supportsEmbedding: true,
            supportsStreaming: true,
          ),
        );
        registry.register(multiCapProvider);

        expect(registry.getByCapability('chat').length, equals(1));
        expect(registry.getByCapability('embedding').length, equals(1));
        expect(registry.getByCapability('streaming').length, equals(1));
      });

      test('should return empty list when no providers registered', () {
        final providers = registry.getByCapability('chat');
        expect(providers, isEmpty);
      });
    });

    group('getAllIds', () {
      test('should return empty list when no providers registered', () {
        expect(registry.getAllIds(), isEmpty);
      });

      test('should return all provider IDs', () {
        registry.register(MockProvider(
          id: 'provider-1',
          name: 'Provider 1',
          capabilities: const ProviderCapabilities(),
        ));
        registry.register(MockProvider(
          id: 'provider-2',
          name: 'Provider 2',
          capabilities: const ProviderCapabilities(),
        ));
        registry.register(MockProvider(
          id: 'provider-3',
          name: 'Provider 3',
          capabilities: const ProviderCapabilities(),
        ));

        final ids = registry.getAllIds();
        expect(ids.length, equals(3));
        expect(ids, containsAll(['provider-1', 'provider-2', 'provider-3']));
      });
    });

    group('getAll', () {
      test('should return empty list when no providers registered', () {
        expect(registry.getAll(), isEmpty);
      });

      test('should return all providers', () {
        final provider1 = MockProvider(
          id: 'provider-1',
          name: 'Provider 1',
          capabilities: const ProviderCapabilities(),
        );
        final provider2 = MockProvider(
          id: 'provider-2',
          name: 'Provider 2',
          capabilities: const ProviderCapabilities(),
        );

        registry.register(provider1);
        registry.register(provider2);

        final providers = registry.getAll();
        expect(providers.length, equals(2));
        expect(providers.map((p) => p.id),
            containsAll(['provider-1', 'provider-2']));
      });
    });

    group('has', () {
      test('should return true when provider exists', () {
        registry.register(MockProvider(
          id: 'test-provider',
          name: 'Test',
          capabilities: const ProviderCapabilities(),
        ));

        expect(registry.has('test-provider'), isTrue);
      });

      test('should return false when provider does not exist', () {
        expect(registry.has('non-existent'), isFalse);
      });

      test('should return false for empty string', () {
        expect(registry.has(''), isFalse);
      });
    });

    group('count', () {
      test('should return 0 when empty', () {
        expect(registry.count, equals(0));
      });

      test('should return correct count after registering providers', () {
        expect(registry.count, equals(0));

        registry.register(MockProvider(
          id: 'provider-1',
          name: 'Provider 1',
          capabilities: const ProviderCapabilities(),
        ));
        expect(registry.count, equals(1));

        registry.register(MockProvider(
          id: 'provider-2',
          name: 'Provider 2',
          capabilities: const ProviderCapabilities(),
        ));
        expect(registry.count, equals(2));
      });
    });

    group('unregister', () {
      test('should remove provider and return true', () async {
        final provider = MockProvider(
          id: 'test-provider',
          name: 'Test',
          capabilities: const ProviderCapabilities(),
        );
        registry.register(provider);

        final removed = await registry.unregister('test-provider');
        expect(removed, isTrue);
        expect(registry.has('test-provider'), isFalse);
        expect(registry.count, equals(0));
      });

      test('should dispose provider when dispose is true', () async {
        final provider = MockProvider(
          id: 'test-provider',
          name: 'Test',
          capabilities: const ProviderCapabilities(),
        );
        registry.register(provider);
        await provider.init(ProviderConfig());

        expect(provider.isDisposed, isFalse);

        await registry.unregister('test-provider', dispose: true);
        expect(provider.isDisposed, isTrue);
      });

      test('should not dispose provider when dispose is false', () async {
        final provider = MockProvider(
          id: 'test-provider',
          name: 'Test',
          capabilities: const ProviderCapabilities(),
        );
        registry.register(provider);

        await registry.unregister('test-provider', dispose: false);
        expect(provider.isDisposed, isFalse);
      });

      test('should return false when provider not found', () async {
        final removed = await registry.unregister('non-existent');
        expect(removed, isFalse);
      });
    });

    group('clear', () {
      test('should remove all providers', () async {
        registry.register(MockProvider(
          id: 'provider-1',
          name: 'Provider 1',
          capabilities: const ProviderCapabilities(),
        ));
        registry.register(MockProvider(
          id: 'provider-2',
          name: 'Provider 2',
          capabilities: const ProviderCapabilities(),
        ));

        expect(registry.count, equals(2));

        await registry.clear();
        expect(registry.count, equals(0));
        expect(registry.getAllIds(), isEmpty);
      });

      test('should dispose providers when dispose is true', () async {
        final provider1 = MockProvider(
          id: 'provider-1',
          name: 'Provider 1',
          capabilities: const ProviderCapabilities(),
        );
        final provider2 = MockProvider(
          id: 'provider-2',
          name: 'Provider 2',
          capabilities: const ProviderCapabilities(),
        );

        registry.register(provider1);
        registry.register(provider2);
        await provider1.init(ProviderConfig());
        await provider2.init(ProviderConfig());

        await registry.clear(dispose: true);

        expect(provider1.isDisposed, isTrue);
        expect(provider2.isDisposed, isTrue);
      });

      test('should not dispose providers when dispose is false', () async {
        final provider = MockProvider(
          id: 'provider-1',
          name: 'Provider 1',
          capabilities: const ProviderCapabilities(),
        );
        registry.register(provider);

        await registry.clear(dispose: false);
        expect(provider.isDisposed, isFalse);
      });

      test('should work when registry is already empty', () async {
        await registry.clear();
        expect(registry.count, equals(0));
      });
    });

    group('toString', () {
      test('should return formatted string representation', () {
        registry.register(MockProvider(
          id: 'provider-1',
          name: 'Provider 1',
          capabilities: const ProviderCapabilities(),
        ));
        registry.register(MockProvider(
          id: 'provider-2',
          name: 'Provider 2',
          capabilities: const ProviderCapabilities(),
        ));

        final str = registry.toString();
        expect(str, contains('ProviderRegistry'));
        expect(str, contains('2 providers'));
        expect(str, contains('provider-1'));
        expect(str, contains('provider-2'));
      });

      test('should handle empty registry', () {
        final str = registry.toString();
        expect(str, contains('ProviderRegistry'));
        expect(str, contains('0 providers'));
      });
    });
  });
}
