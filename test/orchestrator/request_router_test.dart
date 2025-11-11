import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';
import 'package:unified_ai_sdk/src/models/common/capabilities.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/models/requests/chat_request.dart';
import 'package:unified_ai_sdk/src/models/requests/embedding_request.dart';
import 'package:unified_ai_sdk/src/models/requests/image_request.dart';
import 'package:unified_ai_sdk/src/models/requests/stt_request.dart';
import 'package:unified_ai_sdk/src/models/requests/tts_request.dart';
import 'package:unified_ai_sdk/src/models/responses/audio_response.dart';
import 'package:unified_ai_sdk/src/models/responses/chat_response.dart';
import 'package:unified_ai_sdk/src/models/responses/chat_stream_event.dart';
import 'package:unified_ai_sdk/src/models/responses/embedding_response.dart';
import 'package:unified_ai_sdk/src/models/responses/image_response.dart';
import 'package:unified_ai_sdk/src/models/responses/transcription_response.dart';
import 'package:unified_ai_sdk/src/orchestrator/intent_detector.dart';
import 'package:unified_ai_sdk/src/orchestrator/provider_registry.dart';
import 'package:unified_ai_sdk/src/orchestrator/request_router.dart';
import 'package:unified_ai_sdk/src/providers/base/ai_provider.dart';

/// Mock provider for testing RequestRouter
class MockRouterProvider extends AiProvider {
  final String _id;
  final String _name;
  final ProviderCapabilities _capabilities;

  MockRouterProvider({
    required String id,
    required String name,
    required ProviderCapabilities capabilities,
  })  : _id = id,
        _name = name,
        _capabilities = capabilities;

  @override
  String get id => _id;

  @override
  String get name => _name;

  @override
  ProviderCapabilities get capabilities => _capabilities;

  @override
  Future<void> init(ProviderConfig config) async {
    // Mock implementation
  }

  @override
  Future<void> dispose() async {
    // Mock implementation
  }

  // Other methods not needed for router tests
  @override
  Future<ChatResponse> chat(ChatRequest request) async =>
      throw UnimplementedError();

  @override
  Stream<ChatStreamEvent> chatStream(ChatRequest request) async* {
    // Mock implementation - empty stream
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async =>
      throw UnimplementedError();

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async =>
      throw UnimplementedError();

  @override
  Future<AudioResponse> tts(TtsRequest request) async =>
      throw UnimplementedError();

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async =>
      throw UnimplementedError();

  @override
  Future<bool> healthCheck() async => true;
}

void main() {
  group('RequestRouter', () {
    late ProviderRegistry registry;
    late IntentDetector detector;
    late RequestRouter router;

    late MockRouterProvider chatProvider;
    late MockRouterProvider embeddingProvider;
    late MockRouterProvider imageProvider;
    late MockRouterProvider multiCapabilityProvider;

    setUp(() {
      registry = ProviderRegistry();
      detector = IntentDetector();
      router = RequestRouter(
        registry: registry,
        intentDetector: detector,
      );

      // Create mock providers with different capabilities
      chatProvider = MockRouterProvider(
        id: 'chat-provider',
        name: 'Chat Provider',
        capabilities: ProviderCapabilities(
          supportsChat: true,
          supportsEmbedding: false,
          supportsImageGeneration: false,
        ),
      );

      embeddingProvider = MockRouterProvider(
        id: 'embedding-provider',
        name: 'Embedding Provider',
        capabilities: ProviderCapabilities(
          supportsChat: false,
          supportsEmbedding: true,
          supportsImageGeneration: false,
        ),
      );

      imageProvider = MockRouterProvider(
        id: 'image-provider',
        name: 'Image Provider',
        capabilities: ProviderCapabilities(
          supportsChat: false,
          supportsEmbedding: false,
          supportsImageGeneration: true,
        ),
      );

      multiCapabilityProvider = MockRouterProvider(
        id: 'multi-provider',
        name: 'Multi Capability Provider',
        capabilities: ProviderCapabilities(
          supportsChat: true,
          supportsEmbedding: true,
          supportsImageGeneration: true,
        ),
      );
    });

    group('Explicit Provider Routing', () {
      test('should route to explicitly specified provider', () async {
        registry.register(chatProvider);
        registry.register(embeddingProvider);

        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        final provider = await router.route('chat-provider', request);

        expect(provider.id, equals('chat-provider'));
        expect(provider, equals(chatProvider));
      });

      test('should route to different provider when specified', () async {
        registry.register(chatProvider);
        registry.register(embeddingProvider);

        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        final provider = await router.route('embedding-provider', request);

        expect(provider.id, equals('embedding-provider'));
        expect(provider, equals(embeddingProvider));
      });

      test('should throw ClientError when explicit provider not found',
          () async {
        registry.register(chatProvider);

        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        expect(
          () => router.route('nonexistent-provider', request),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            equals('PROVIDER_NOT_FOUND'),
          )),
        );
      });

      test('should include available providers in error message', () async {
        registry.register(chatProvider);
        registry.register(embeddingProvider);

        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        try {
          await router.route('nonexistent', request);
          fail('Expected ClientError');
        } on ClientError catch (e) {
          expect(e.message, contains('Available providers'));
          expect(e.message, contains('chat-provider'));
          expect(e.message, contains('embedding-provider'));
        }
      });
    });

    group('Intent-Based Routing', () {
      test('should route chat request to chat provider', () async {
        registry.register(chatProvider);
        registry.register(embeddingProvider);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello, how are you?'),
          ],
        );

        final provider = await router.route(null, request);

        expect(provider.id, equals('chat-provider'));
        expect(provider.capabilities.supportsChat, isTrue);
      });

      test('should route image request to image provider', () async {
        registry.register(chatProvider);
        registry.register(imageProvider);

        final request = ImageRequest(prompt: 'A beautiful sunset');

        final provider = await router.route(null, request);

        expect(provider.id, equals('image-provider'));
        expect(provider.capabilities.supportsImageGeneration, isTrue);
      });

      test('should route embedding request to embedding provider', () async {
        registry.register(chatProvider);
        registry.register(embeddingProvider);

        final request = EmbeddingRequest(inputs: ['Hello, world!']);

        final provider = await router.route(null, request);

        expect(provider.id, equals('embedding-provider'));
        expect(provider.capabilities.supportsEmbedding, isTrue);
      });

      test('should route chat request with image intent to image provider',
          () async {
        registry.register(chatProvider);
        registry.register(imageProvider);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Draw a picture of a cat'),
          ],
        );

        final provider = await router.route(null, request);

        expect(provider.id, equals('image-provider'));
        expect(provider.capabilities.supportsImageGeneration, isTrue);
      });

      test(
          'should route chat request with embedding intent to embedding provider',
          () async {
        registry.register(chatProvider);
        registry.register(embeddingProvider);

        final request = ChatRequest(
          messages: [
            const Message(
                role: Role.user, content: 'Get embedding for this text'),
          ],
        );

        final provider = await router.route(null, request);

        expect(provider.id, equals('embedding-provider'));
        expect(provider.capabilities.supportsEmbedding, isTrue);
      });

      test(
          'should return first provider when multiple providers support capability',
          () async {
        registry.register(chatProvider);
        registry.register(multiCapabilityProvider);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello'),
          ],
        );

        final provider = await router.route(null, request);

        // Should return the first provider that supports chat
        expect(provider.capabilities.supportsChat, isTrue);
        expect(provider.id, equals('chat-provider'));
      });

      test('should throw CapabilityError when no providers support capability',
          () async {
        registry.register(embeddingProvider); // Only embedding, no chat

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello'),
          ],
        );

        expect(
          () => router.route(null, request),
          throwsA(isA<CapabilityError>().having(
            (e) => e.code,
            'code',
            equals('NO_PROVIDER_WITH_CAPABILITY'),
          )),
        );
      });

      test('should include detected intent in error message', () async {
        registry.register(embeddingProvider);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello'),
          ],
        );

        try {
          await router.route(null, request);
          fail('Expected CapabilityError');
        } on CapabilityError catch (e) {
          expect(e.message, contains('chat'));
          expect(e.message, contains('Detected intent'));
        }
      });

      test('should include registered providers in error message', () async {
        registry.register(embeddingProvider);
        registry.register(imageProvider);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello'),
          ],
        );

        try {
          await router.route(null, request);
          fail('Expected CapabilityError');
        } on CapabilityError catch (e) {
          expect(e.message, contains('Registered providers'));
          expect(e.message, contains('embedding-provider'));
          expect(e.message, contains('image-provider'));
        }
      });
    });

    group('Router Properties', () {
      test('should expose registry via providerRegistry getter', () {
        expect(router.providerRegistry, equals(registry));
      });

      test('should expose detector via detector getter', () {
        expect(router.detector, equals(detector));
      });
    });

    group('Edge Cases', () {
      test('should handle empty registry gracefully', () async {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello'),
          ],
        );

        expect(
          () => router.route(null, request),
          throwsA(isA<CapabilityError>()),
        );
      });

      test('should handle explicit provider with empty registry', () async {
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello'),
          ],
        );

        expect(
          () => router.route('nonexistent', request),
          throwsA(isA<ClientError>()),
        );
      });

      test('should handle multiple providers with same capability', () async {
        final provider1 = MockRouterProvider(
          id: 'provider-1',
          name: 'Provider 1',
          capabilities: ProviderCapabilities(supportsChat: true),
        );
        final provider2 = MockRouterProvider(
          id: 'provider-2',
          name: 'Provider 2',
          capabilities: ProviderCapabilities(supportsChat: true),
        );

        registry.register(provider1);
        registry.register(provider2);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello'),
          ],
        );

        final provider = await router.route(null, request);

        // Should return the first provider (simple strategy)
        expect(provider.capabilities.supportsChat, isTrue);
        expect(provider.id, isIn(['provider-1', 'provider-2']));
      });
    });
  });
}
