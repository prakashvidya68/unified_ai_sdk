import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/providers/openai/openai_provider.dart';

void main() {
  group('OpenAIProvider', () {
    test('should have correct id and name', () {
      final provider = OpenAIProvider();

      expect(provider.id, equals('openai'));
      expect(provider.name, equals('OpenAI'));
    });

    test('should have correct capabilities', () {
      final provider = OpenAIProvider();
      final capabilities = provider.capabilities;

      expect(capabilities.supportsChat, isTrue);
      expect(capabilities.supportsEmbedding, isTrue);
      expect(capabilities.supportsImageGeneration, isTrue);
      expect(capabilities.supportsTTS, isTrue);
      expect(capabilities.supportsSTT, isTrue);
      expect(capabilities.supportsStreaming, isTrue);
      expect(capabilities.supportedModels, isNotEmpty);
      expect(capabilities.supportedModels, contains('gpt-4'));
      expect(capabilities.supportedModels, contains('gpt-3.5-turbo'));
      expect(capabilities.supportedModels, contains('text-embedding-3-small'));
      expect(capabilities.supportedModels, contains('dall-e-3'));
      expect(capabilities.supportedModels, contains('tts-1'));
      expect(capabilities.supportedModels, contains('whisper-1'));
    });

    group('init', () {
      test('should initialize successfully with ApiKeyAuth', () async {
        final provider = OpenAIProvider();
        final config = ProviderConfig(
          id: 'openai',
          auth: ApiKeyAuth(apiKey: 'sk-test123'),
        );

        await provider.init(config);

        expect(provider.defaultModel, isNull);
        expect(provider.baseUrl, equals('https://api.openai.com/v1'));
      });

      test('should initialize with custom base URL', () async {
        final provider = OpenAIProvider();
        final config = ProviderConfig(
          id: 'openai',
          auth: ApiKeyAuth(apiKey: 'sk-test123'),
          settings: {
            'baseUrl': 'https://custom-api.example.com/v1',
          },
        );

        await provider.init(config);

        expect(provider.baseUrl, equals('https://custom-api.example.com/v1'));
      });

      test('should initialize with default model', () async {
        final provider = OpenAIProvider();
        final config = ProviderConfig(
          id: 'openai',
          auth: ApiKeyAuth(apiKey: 'sk-test123'),
          settings: {
            'defaultModel': 'gpt-4',
          },
        );

        await provider.init(config);

        expect(provider.defaultModel, equals('gpt-4'));
      });

      test('should throw AuthError if auth is not ApiKeyAuth', () async {
        final provider = OpenAIProvider();
        final config = ProviderConfig(
          id: 'openai',
          auth: CustomHeaderAuth({'X-API-Key': 'test'}),
        );

        expect(
          () => provider.init(config),
          throwsA(isA<AuthError>()),
        );
      });

      test('should throw ClientError if API key is empty', () {
        // ApiKeyAuth constructor throws ClientError when API key is empty
        expect(
          () => ApiKeyAuth(apiKey: ''),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError if config ID does not match provider ID',
          () async {
        final provider = OpenAIProvider();
        final config = ProviderConfig(
          id: 'anthropic', // Wrong ID
          auth: ApiKeyAuth(apiKey: 'sk-test123'),
        );

        expect(
          () => provider.init(config),
          throwsA(isA<ClientError>()),
        );
      });

      test('should initialize HTTP client with correct headers', () async {
        final provider = OpenAIProvider();
        final config = ProviderConfig(
          id: 'openai',
          auth: ApiKeyAuth(apiKey: 'sk-test123'),
        );

        await provider.init(config);

        final httpClient = provider.httpClient;
        expect(httpClient, isNotNull);
        // HTTP client should be initialized (we can't easily test headers without making a request)
      });
    });
  });
}
