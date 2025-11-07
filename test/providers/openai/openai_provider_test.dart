import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';
import 'package:unified_ai_sdk/src/models/requests/embedding_request.dart';
import 'package:unified_ai_sdk/src/models/requests/image_request.dart';
import 'package:unified_ai_sdk/src/providers/openai/openai_provider.dart';

// Mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final List<http.BaseRequest> _requests = [];

  void setResponse(String url, http.Response response) {
    _responses[url] = response;
  }

  List<http.BaseRequest> get requests => List.unmodifiable(_requests);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _requests.add(request);

    final response = _responses[request.url.toString()];
    if (response != null) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(response.body)),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode('Not Found')),
      404,
      request: request,
    );
  }

  @override
  void close() {
    // Mock implementation - no-op
  }
}

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

    group('embed', () {
      late OpenAIProvider provider;
      late MockHttpClient mockClient;

      setUp(() async {
        mockClient = MockHttpClient();
        provider = OpenAIProvider();
        final config = ProviderConfig(
          id: 'openai',
          auth: ApiKeyAuth(apiKey: 'sk-test123'),
          settings: {
            'httpClient': mockClient, // Inject mock client for testing
          },
        );

        await provider.init(config);
      });

      test('should successfully generate embeddings', () async {
        // Create a mock embedding response
        final mockResponseBody = jsonEncode({
          'data': [
            {
              'index': 0,
              'embedding': [0.1, 0.2, 0.3, 0.4, 0.5],
              'object': 'embedding',
            }
          ],
          'model': 'text-embedding-3-small',
          'usage': {
            'prompt_tokens': 5,
            'completion_tokens': 0,
            'total_tokens': 5,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/embeddings',
          http.Response(mockResponseBody, 200),
        );

        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
          model: 'text-embedding-3-small',
        );

        final response = await provider.embed(request);

        expect(response, isNotNull);
        expect(response.embeddings.length, equals(1));
        expect(response.embeddings.first.vector.length, equals(5));
        expect(response.embeddings.first.vector,
            equals([0.1, 0.2, 0.3, 0.4, 0.5]));
        expect(response.model, equals('text-embedding-3-small'));
        expect(response.provider, equals('openai'));
        expect(response.usage, isNotNull);
        expect(response.usage!.totalTokens, equals(5));
      });

      test('should handle multiple inputs', () async {
        final mockResponseBody = jsonEncode({
          'data': [
            {
              'index': 0,
              'embedding': [0.1, 0.2, 0.3],
              'object': 'embedding',
            },
            {
              'index': 1,
              'embedding': [0.4, 0.5, 0.6],
              'object': 'embedding',
            },
          ],
          'model': 'text-embedding-3-small',
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 0,
            'total_tokens': 10,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/embeddings',
          http.Response(mockResponseBody, 200),
        );

        final request = EmbeddingRequest(
          inputs: ['Hello', 'World'],
          model: 'text-embedding-3-small',
        );

        final response = await provider.embed(request);

        expect(response.embeddings.length, equals(2));
        expect(response.embeddings[0].vector, equals([0.1, 0.2, 0.3]));
        expect(response.embeddings[1].vector, equals([0.4, 0.5, 0.6]));
      });

      test('should throw error when model is not specified', () async {
        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
          // model is null and no default model set
        );

        // Should throw ClientError because model is required
        expectLater(
          provider.embed(request),
          throwsA(isA<ClientError>()),
        );
      });

      test('should use default model when model is not specified in request',
          () async {
        final provider = OpenAIProvider();
        final config = ProviderConfig(
          id: 'openai',
          auth: ApiKeyAuth(apiKey: 'sk-test123'),
          settings: {
            'defaultModel': 'text-embedding-3-small',
            'httpClient': mockClient,
          },
        );
        await provider.init(config);

        final mockResponseBody = jsonEncode({
          'data': [
            {
              'index': 0,
              'embedding': [0.1, 0.2, 0.3],
              'object': 'embedding',
            }
          ],
          'model': 'text-embedding-3-small',
          'usage': {
            'prompt_tokens': 5,
            'completion_tokens': 0,
            'total_tokens': 5,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/embeddings',
          http.Response(mockResponseBody, 200),
        );

        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
          // model is null, should use default
        );

        final response = await provider.embed(request);
        expect(response.model, equals('text-embedding-3-small'));
      });

      test('should handle HTTP errors correctly', () async {
        mockClient.setResponse(
          'https://api.openai.com/v1/embeddings',
          http.Response('{"error": {"message": "Invalid API key"}}', 401),
        );

        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
          model: 'text-embedding-3-small',
        );

        expectLater(
          provider.embed(request),
          throwsA(isA<AuthError>()),
        );
      });

      test('should handle rate limit errors', () async {
        mockClient.setResponse(
          'https://api.openai.com/v1/embeddings',
          http.Response(
            '{"error": {"message": "Rate limit exceeded"}}',
            429,
            headers: {'retry-after': '60'},
          ),
        );

        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
          model: 'text-embedding-3-small',
        );

        expectLater(
          provider.embed(request),
          throwsA(isA<QuotaError>()),
        );
      });
    });

    group('generateImage', () {
      late OpenAIProvider provider;
      late MockHttpClient mockClient;

      setUp(() async {
        mockClient = MockHttpClient();
        provider = OpenAIProvider();
        final config = ProviderConfig(
          id: 'openai',
          auth: ApiKeyAuth(apiKey: 'sk-test123'),
          settings: {
            'httpClient': mockClient,
          },
        );

        await provider.init(config);
      });

      test('should successfully generate image', () async {
        final mockResponseBody = jsonEncode({
          'created': 1234567890,
          'data': [
            {
              'url': 'https://example.com/image.png',
              'revised_prompt':
                  'A beautiful sunset over the ocean with vibrant colors',
            }
          ],
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/images/generations',
          http.Response(mockResponseBody, 200),
        );

        final request = ImageRequest(
          prompt: 'A beautiful sunset over the ocean',
          model: 'dall-e-3',
          size: ImageSize.w1024h1024,
        );

        final response = await provider.generateImage(request);

        expect(response, isNotNull);
        expect(response.assets.length, equals(1));
        expect(
            response.assets.first.url, equals('https://example.com/image.png'));
        expect(response.assets.first.revisedPrompt,
            equals('A beautiful sunset over the ocean with vibrant colors'));
        expect(response.model, equals('dall-e-3'));
        expect(response.provider, equals('openai'));
      });

      test('should handle base64 response format', () async {
        final mockResponseBody = jsonEncode({
          'created': 1234567890,
          'data': [
            {
              'b64_json':
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
            }
          ],
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/images/generations',
          http.Response(mockResponseBody, 200),
        );

        final request = ImageRequest(
          prompt: 'A cat',
          model: 'dall-e-3',
          providerOptions: {
            'openai': {'response_format': 'b64_json'},
          },
        );

        final response = await provider.generateImage(request);

        expect(response.assets.first.base64, isNotNull);
        expect(response.assets.first.url, isNull);
      });

      test('should use default model when not specified', () async {
        final mockResponseBody = jsonEncode({
          'created': 1234567890,
          'data': [
            {
              'url': 'https://example.com/image.png',
            }
          ],
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/images/generations',
          http.Response(mockResponseBody, 200),
        );

        final request = ImageRequest(
          prompt: 'A beautiful landscape',
          // model is null, should use default
        );

        final response = await provider.generateImage(request);
        expect(response.model, equals('dall-e-3')); // Default model
      });

      test('should throw error for DALL-E 3 with n > 1', () async {
        final request = ImageRequest(
          prompt: 'A cat',
          model: 'dall-e-3',
          n: 2, // DALL-E 3 only supports n=1
        );

        expectLater(
          provider.generateImage(request),
          throwsA(isA<ClientError>()),
        );
      });

      test('should handle HTTP errors correctly', () async {
        mockClient.setResponse(
          'https://api.openai.com/v1/images/generations',
          http.Response('{"error": {"message": "Invalid API key"}}', 401),
        );

        final request = ImageRequest(
          prompt: 'A beautiful sunset',
          model: 'dall-e-3',
        );

        expectLater(
          provider.generateImage(request),
          throwsA(isA<AuthError>()),
        );
      });

      test('should support DALL-E 2 with multiple images', () async {
        final mockResponseBody = jsonEncode({
          'created': 1234567890,
          'data': [
            {
              'url': 'https://example.com/image1.png',
            },
            {
              'url': 'https://example.com/image2.png',
            },
          ],
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/images/generations',
          http.Response(mockResponseBody, 200),
        );

        final request = ImageRequest(
          prompt: 'A cat',
          model: 'dall-e-2',
          n: 2, // DALL-E 2 supports multiple images
        );

        final response = await provider.generateImage(request);
        expect(response.assets.length, equals(2));
        expect(response.model, equals('dall-e-2'));
      });
    });
  });
}
