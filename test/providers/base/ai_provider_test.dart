import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';
import 'package:unified_ai_sdk/src/models/common/capabilities.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/models/common/usage.dart';
import 'package:unified_ai_sdk/src/models/requests/chat_request.dart';
import 'package:unified_ai_sdk/src/models/requests/embedding_request.dart';
import 'package:unified_ai_sdk/src/models/requests/image_request.dart';
import 'package:unified_ai_sdk/src/models/requests/stt_request.dart';
import 'package:unified_ai_sdk/src/models/requests/tts_request.dart';
import 'package:unified_ai_sdk/src/models/responses/audio_response.dart';
import 'package:unified_ai_sdk/src/models/responses/chat_response.dart';
import 'package:unified_ai_sdk/src/models/responses/embedding_response.dart';
import 'package:unified_ai_sdk/src/models/responses/image_response.dart';
import 'package:unified_ai_sdk/src/models/responses/transcription_response.dart';
import 'package:unified_ai_sdk/src/providers/base/ai_provider.dart';

/// Mock implementation of AiProvider for testing
class MockProvider extends AiProvider {
  final String _id;
  final String _name;
  final ProviderCapabilities _capabilities;
  bool _initialized = false;
  bool _disposed = false;

  MockProvider({
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
    _initialized = true;
  }

  @override
  Future<ChatResponse> chat(ChatRequest request) async {
    validateCapability('chat');
    return ChatResponse(
      id: 'test-id',
      choices: [
        ChatChoice(
          index: 0,
          message: Message(role: Role.assistant, content: 'Test response'),
        ),
      ],
      usage: Usage(
        promptTokens: 10,
        completionTokens: 5,
        totalTokens: 15,
      ),
      model: 'test-model',
      provider: _id,
    );
  }

  @override
  Stream<ChatStreamEvent>? chatStream(ChatRequest request) {
    if (!_capabilities.supportsStreaming) {
      return null;
    }
    return Stream.value(ChatStreamEvent());
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    validateCapability('embed');
    throw UnimplementedError('Mock embed not implemented');
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    validateCapability('image');
    throw UnimplementedError('Mock generateImage not implemented');
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    validateCapability('tts');
    throw UnimplementedError('Mock tts not implemented');
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    validateCapability('stt');
    throw UnimplementedError('Mock stt not implemented');
  }

  @override
  Future<bool> healthCheck() async {
    return _initialized && !_disposed;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }

  bool get isInitialized => _initialized;
  bool get isDisposed => _disposed;
}

void main() {
  group('AiProvider', () {
    group('Properties', () {
      test('should have id, name, and capabilities', () {
        final provider = MockProvider(
          id: 'test-provider',
          name: 'Test Provider',
          capabilities: ProviderCapabilities(),
        );

        expect(provider.id, equals('test-provider'));
        expect(provider.name, equals('Test Provider'));
        expect(provider.capabilities, isA<ProviderCapabilities>());
      });
    });

    group('init', () {
      test('should initialize provider', () async {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(),
        );

        await provider.init(ProviderConfig(
          id: 'test',
          auth: ApiKeyAuth(apiKey: 'test-key'),
        ));

        expect(provider.isInitialized, isTrue);
      });
    });

    group('capability validation', () {
      test('should throw CapabilityError for unsupported chat', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(supportsChat: false),
        );

        expect(
          () => provider.validateCapability('chat'),
          throwsA(isA<CapabilityError>()),
        );
      });

      test('should not throw for supported chat', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(supportsChat: true),
        );

        expect(() => provider.validateCapability('chat'), returnsNormally);
      });

      test('should throw CapabilityError for unsupported embedding', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(supportsEmbedding: false),
        );

        expect(
          () => provider.validateCapability('embed'),
          throwsA(isA<CapabilityError>()),
        );
      });

      test('should throw CapabilityError for unsupported image generation', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(
            supportsImageGeneration: false,
          ),
        );

        expect(
          () => provider.validateCapability('image'),
          throwsA(isA<CapabilityError>()),
        );
      });

      test('should throw CapabilityError for unsupported TTS', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(supportsTTS: false),
        );

        expect(
          () => provider.validateCapability('tts'),
          throwsA(isA<CapabilityError>()),
        );
      });

      test('should throw CapabilityError for unsupported STT', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(supportsSTT: false),
        );

        expect(
          () => provider.validateCapability('stt'),
          throwsA(isA<CapabilityError>()),
        );
      });

      test('should throw CapabilityError for unsupported streaming', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(supportsStreaming: false),
        );

        expect(
          () => provider.validateCapability('streaming'),
          throwsA(isA<CapabilityError>()),
        );
      });

      test('should handle unknown operation gracefully', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(),
        );

        expect(() => provider.validateCapability('unknown'), returnsNormally);
      });
    });

    group('chat', () {
      test('should validate chat capability before execution', () async {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(supportsChat: false),
        );

        await provider.init(ProviderConfig(
          id: 'test',
          auth: ApiKeyAuth(apiKey: 'test-key'),
        ));

        expect(
          () => provider.chat(ChatRequest(
            messages: [Message(role: Role.user, content: 'Test')],
          )),
          throwsA(isA<CapabilityError>()),
        );
      });

      test('should succeed when chat is supported', () async {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(supportsChat: true),
        );

        await provider.init(ProviderConfig(
          id: 'test',
          auth: ApiKeyAuth(apiKey: 'test-key'),
        ));

        final response = await provider.chat(ChatRequest(
          messages: [Message(role: Role.user, content: 'Test')],
        ));
        expect(response, isA<ChatResponse>());
      });
    });

    group('chatStream', () {
      test('should return null when streaming not supported', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(supportsStreaming: false),
        );

        final stream = provider.chatStream(ChatRequest(
          messages: [Message(role: Role.user, content: 'Test')],
        ));
        expect(stream, isNull);
      });

      test('should return stream when streaming is supported', () {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(
            supportsChat: true,
            supportsStreaming: true,
          ),
        );

        final stream = provider.chatStream(ChatRequest(
          messages: [Message(role: Role.user, content: 'Test')],
        ));
        expect(stream, isNotNull);
      });
    });

    group('healthCheck', () {
      test('should return true by default when initialized', () async {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(),
        );

        await provider.init(ProviderConfig(
          id: 'test',
          auth: ApiKeyAuth(apiKey: 'test-key'),
        ));
        final healthy = await provider.healthCheck();
        expect(healthy, isTrue);
      });

      test('should return false after dispose', () async {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(),
        );

        await provider.init(ProviderConfig(
          id: 'test',
          auth: ApiKeyAuth(apiKey: 'test-key'),
        ));
        await provider.dispose();

        final healthy = await provider.healthCheck();
        expect(healthy, isFalse);
      });
    });

    group('dispose', () {
      test('should dispose provider resources', () async {
        final provider = MockProvider(
          id: 'test',
          name: 'Test',
          capabilities: ProviderCapabilities(),
        );

        await provider.init(ProviderConfig(
          id: 'test',
          auth: ApiKeyAuth(apiKey: 'test-key'),
        ));
        expect(provider.isDisposed, isFalse);

        await provider.dispose();
        expect(provider.isDisposed, isTrue);
      });
    });

    group('Full-featured provider', () {
      test('should support all capabilities', () {
        final provider = MockProvider(
          id: 'full-featured',
          name: 'Full Featured Provider',
          capabilities: ProviderCapabilities(
            supportsChat: true,
            supportsEmbedding: true,
            supportsImageGeneration: true,
            supportsTTS: true,
            supportsSTT: true,
            supportsStreaming: true,
            fallbackModels: ['model-1', 'model-2'],
          ),
        );

        expect(provider.capabilities.supportsChat, isTrue);
        expect(provider.capabilities.supportsEmbedding, isTrue);
        expect(provider.capabilities.supportsImageGeneration, isTrue);
        expect(provider.capabilities.supportsTTS, isTrue);
        expect(provider.capabilities.supportsSTT, isTrue);
        expect(provider.capabilities.supportsStreaming, isTrue);
        expect(provider.capabilities.supportedModels.length, equals(2));
      });
    });
  });
}
