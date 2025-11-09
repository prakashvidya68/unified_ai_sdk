import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/core/config.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/core/unified_ai.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/models/requests/chat_request.dart';
import 'package:unified_ai_sdk/src/models/requests/embedding_request.dart';
import 'package:unified_ai_sdk/src/models/requests/image_request.dart';
import 'package:unified_ai_sdk/src/orchestrator/provider_registry.dart';
import 'package:unified_ai_sdk/src/providers/base/ai_provider.dart';
import 'package:unified_ai_sdk/src/retry/retry_handler.dart';
import 'package:unified_ai_sdk/src/retry/retry_policy.dart';

// Mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};

  void setResponse(String url, http.Response response) {
    _responses[url] = response;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = _responses[request.url.toString()];
    if (response != null) {
      final stream = http.ByteStream.fromBytes(utf8.encode(response.body));
      return http.StreamedResponse(
        stream,
        response.statusCode,
        headers: response.headers,
      );
    }
    return http.StreamedResponse(
      http.ByteStream.fromBytes(utf8.encode('Not Found')),
      404,
    );
  }
}

void main() {
  group('UnifiedAI', () {
    tearDown(() async {
      // Clean up singleton instance after each test
      try {
        final instance = UnifiedAI.instance;
        await instance.dispose();
      } catch (e) {
        // Instance not initialized, ignore
      }
    });

    test('should throw StateError when accessing instance before init', () {
      expect(
        () => UnifiedAI.instance,
        throwsA(isA<StateError>()),
      );
    });

    test('should initialize successfully with valid config', () async {
      final mockClient = MockHttpClient();
      final config = UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: 'sk-test123'),
            settings: {
              'httpClient': mockClient,
            },
          ),
        },
      );

      final ai = await UnifiedAI.init(config);

      expect(ai, isNotNull);
      expect(ai.config, equals(config));
      expect(ai.availableProviders, contains('openai'));
    });

    test('should throw StateError when init is called twice', () async {
      final mockClient = MockHttpClient();
      final config = UnifiedAIConfig(
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: 'sk-test123'),
            settings: {
              'httpClient': mockClient,
            },
          ),
        },
      );

      await UnifiedAI.init(config);

      expectLater(
        UnifiedAI.init(config),
        throwsA(isA<StateError>()),
      );
    });

    test('should create and register providers from config', () async {
      final mockClient = MockHttpClient();
      final config = UnifiedAIConfig(
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: 'sk-test123'),
            settings: {
              'httpClient': mockClient,
            },
          ),
        },
      );

      final ai = await UnifiedAI.init(config);

      expect(ai.availableProviders.length, equals(1));
      expect(ai.availableProviders, contains('openai'));

      final provider = ai.getProvider('openai');
      expect(provider, isNotNull);
      expect(provider!.id, equals('openai'));
      expect(provider.name, equals('OpenAI'));
    });

    test('should create RetryHandler from config retry policy', () async {
      final mockClient = MockHttpClient();
      final customPolicy = RetryPolicy(
        maxAttempts: 5,
        initialDelay: const Duration(milliseconds: 200),
      );

      final config = UnifiedAIConfig(
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: 'sk-test123'),
            settings: {
              'httpClient': mockClient,
            },
          ),
        },
        retryPolicy: customPolicy,
      );

      final ai = await UnifiedAI.init(config);

      expect(ai.retryHandler, isA<RetryHandler>());
      expect(ai.retryHandler.policy.maxAttempts, equals(5));
      expect(ai.retryHandler.policy.initialDelay,
          equals(const Duration(milliseconds: 200)));
    });

    test('should throw ClientError for unknown provider ID', () async {
      final config = UnifiedAIConfig(
        perProviderConfig: {
          'unknown-provider': ProviderConfig(
            id: 'unknown-provider',
            auth: ApiKeyAuth(apiKey: 'sk-test123'),
          ),
        },
      );

      expectLater(
        UnifiedAI.init(config),
        throwsA(isA<ClientError>()),
      );
    });

    test('should expose registry for provider queries', () async {
      final mockClient = MockHttpClient();
      final config = UnifiedAIConfig(
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: 'sk-test123'),
            settings: {
              'httpClient': mockClient,
            },
          ),
        },
      );

      final ai = await UnifiedAI.init(config);

      expect(ai.registry, isA<ProviderRegistry>());
      expect(ai.registry.count, equals(1));
      expect(ai.registry.has('openai'), isTrue);
    });

    test('should allow dispose and reinitialize', () async {
      final mockClient1 = MockHttpClient();
      final config1 = UnifiedAIConfig(
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: 'sk-test123'),
            settings: {
              'httpClient': mockClient1,
            },
          ),
        },
      );

      final ai1 = await UnifiedAI.init(config1);
      expect(ai1, isNotNull);

      await ai1.dispose();

      // Should be able to initialize again
      final mockClient2 = MockHttpClient();
      final config2 = UnifiedAIConfig(
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: 'sk-test456'),
            settings: {
              'httpClient': mockClient2,
            },
          ),
        },
      );

      final ai2 = await UnifiedAI.init(config2);
      expect(ai2, isNotNull);
      expect(ai2.config.perProviderConfig['openai']!.auth, isA<ApiKeyAuth>());
    });

    test('should handle multiple providers', () async {
      // Note: This test will fail until more providers are implemented
      // For now, we can only test with OpenAI
      final mockClient = MockHttpClient();
      final config = UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: 'sk-test123'),
            settings: {
              'httpClient': mockClient,
            },
          ),
        },
      );

      final ai = await UnifiedAI.init(config);

      expect(ai.availableProviders.length, equals(1));
      expect(ai.config.defaultProvider, equals('openai'));
    });

    test('should preserve config after initialization', () async {
      final mockClient = MockHttpClient();
      final config = UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: 'sk-test123'),
            settings: {
              'httpClient': mockClient,
            },
          ),
        },
        retryPolicy: RetryPolicy(maxAttempts: 10),
      );

      final ai = await UnifiedAI.init(config);

      expect(ai.config.defaultProvider, equals('openai'));
      expect(ai.config.perProviderConfig.length, equals(1));
      expect(ai.config.retryPolicy.maxAttempts, equals(10));
    });

    group('chat', () {
      late MockHttpClient mockClient;

      setUp(() async {
        mockClient = MockHttpClient();
      });

      test('should successfully send chat request with default provider',
          () async {
        final mockResponseBody = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': 'Hello! How can I help you?',
              },
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 9,
            'completion_tokens': 12,
            'total_tokens': 21,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(mockResponseBody, 200),
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'gpt-4o',
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello!'),
          ],
          model: 'gpt-4o',
        );

        final response = await ai.chat(request: request);

        expect(response, isNotNull);
        expect(response.choices.length, equals(1));
        expect(response.choices.first.message.content,
            equals('Hello! How can I help you?'));
        expect(response.model, equals('gpt-4o'));
      });

      test('should successfully send chat request with specified provider',
          () async {
        final mockResponseBody = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': 'Test response',
              },
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 5,
            'completion_tokens': 2,
            'total_tokens': 7,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(mockResponseBody, 200),
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'gpt-4o',
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Test'),
          ],
          model: 'gpt-4o',
        );

        final response = await ai.chat(provider: 'openai', request: request);

        expect(response.choices.first.message.content, equals('Test response'));
      });

      test('should throw ClientError when no provider specified and no default',
          () async {
        final config = UnifiedAIConfig(
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello'),
          ],
        );

        expectLater(
          ai.chat(request: request),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError when provider not found', () async {
        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello'),
          ],
        );

        expectLater(
          ai.chat(provider: 'nonexistent', request: request),
          throwsA(isA<ClientError>()),
        );
      });

      test('should use retry handler for automatic retries', () async {
        // Set up mock to return 429 on first call (rate limit)
        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(
            '{"error": {"message": "Rate limit exceeded", "type": "rate_limit_error"}}',
            429,
            headers: {'Retry-After': '1'},
          ),
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'gpt-4o',
              },
            ),
          },
          retryPolicy: RetryPolicy(
            maxAttempts: 2,
            initialDelay: const Duration(milliseconds: 10),
          ),
        );

        final ai = await UnifiedAI.init(config);

        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Test'),
          ],
          model: 'gpt-4o',
        );

        // Should retry and eventually throw QuotaError after max attempts
        expectLater(
          ai.chat(request: request),
          throwsA(isA<QuotaError>()),
        );
      });
    });

    group('embed', () {
      late MockHttpClient mockClient;

      setUp(() async {
        mockClient = MockHttpClient();
      });

      test('should successfully generate embeddings with default provider',
          () async {
        final mockResponseBody = jsonEncode({
          'object': 'list',
          'data': [
            {
              'object': 'embedding',
              'index': 0,
              'embedding': [0.1, 0.2, 0.3, 0.4, 0.5],
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

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'text-embedding-3-small',
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
          model: 'text-embedding-3-small',
        );

        final response = await ai.embed(request: request);

        expect(response, isNotNull);
        expect(response.embeddings.length, equals(1));
        final embedding = response.embeddings.first;
        expect(embedding.vector.length, equals(5));
        expect(embedding.vector, equals([0.1, 0.2, 0.3, 0.4, 0.5]));
        expect(response.model, equals('text-embedding-3-small'));
      });

      test('should successfully generate embeddings with specified provider',
          () async {
        final mockResponseBody = jsonEncode({
          'object': 'list',
          'data': [
            {
              'object': 'embedding',
              'index': 0,
              'embedding': [0.9, 0.8, 0.7],
            }
          ],
          'model': 'text-embedding-3-small',
          'usage': {
            'prompt_tokens': 3,
            'completion_tokens': 0,
            'total_tokens': 3,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/embeddings',
          http.Response(mockResponseBody, 200),
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'text-embedding-3-small',
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = EmbeddingRequest(
          inputs: ['Test input'],
          model: 'text-embedding-3-small',
        );

        final response = await ai.embed(provider: 'openai', request: request);

        expect(response.embeddings.length, equals(1));
        final embedding = response.embeddings.first;
        expect(embedding.vector, equals([0.9, 0.8, 0.7]));
      });

      test('should handle multiple inputs', () async {
        final mockResponseBody = jsonEncode({
          'object': 'list',
          'data': [
            {
              'object': 'embedding',
              'index': 0,
              'embedding': [0.1, 0.2],
            },
            {
              'object': 'embedding',
              'index': 1,
              'embedding': [0.3, 0.4],
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

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'text-embedding-3-small',
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = EmbeddingRequest(
          inputs: ['First text', 'Second text'],
          model: 'text-embedding-3-small',
        );

        final response = await ai.embed(request: request);

        expect(response.embeddings.length, equals(2));
        final embedding1 = response.embeddings[0];
        final embedding2 = response.embeddings[1];
        expect(embedding1.vector, equals([0.1, 0.2]));
        expect(embedding2.vector, equals([0.3, 0.4]));
      });

      test('should throw ClientError when no provider specified and no default',
          () async {
        final config = UnifiedAIConfig(
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = EmbeddingRequest(
          inputs: ['Test'],
          model: 'text-embedding-3-small',
        );

        expectLater(
          ai.embed(request: request),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError when provider not found', () async {
        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = EmbeddingRequest(
          inputs: ['Test'],
          model: 'text-embedding-3-small',
        );

        expectLater(
          ai.embed(provider: 'nonexistent', request: request),
          throwsA(isA<ClientError>()),
        );
      });

      test('should use retry handler for automatic retries', () async {
        mockClient.setResponse(
          'https://api.openai.com/v1/embeddings',
          http.Response(
            '{"error": {"message": "Rate limit exceeded", "type": "rate_limit_error"}}',
            429,
            headers: {'Retry-After': '1'},
          ),
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'text-embedding-3-small',
              },
            ),
          },
          retryPolicy: RetryPolicy(
            maxAttempts: 2,
            initialDelay: const Duration(milliseconds: 10),
          ),
        );

        final ai = await UnifiedAI.init(config);

        final request = EmbeddingRequest(
          inputs: ['Test'],
          model: 'text-embedding-3-small',
        );

        // Should retry and eventually throw QuotaError after max attempts
        expectLater(
          ai.embed(request: request),
          throwsA(isA<QuotaError>()),
        );
      });
    });

    group('generateImage', () {
      late MockHttpClient mockClient;

      setUp(() async {
        mockClient = MockHttpClient();
      });

      test('should successfully generate image with default provider',
          () async {
        final mockResponseBody = jsonEncode({
          'created': 1677652288,
          'data': [
            {
              'url': 'https://example.com/image1.png',
              'revised_prompt': 'A beautiful sunset over the ocean',
            }
          ],
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/images/generations',
          http.Response(mockResponseBody, 200),
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'dall-e-3',
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = ImageRequest(
          prompt: 'A beautiful sunset over the ocean',
          model: 'dall-e-3',
          size: ImageSize.w1024h1024,
        );

        final response = await ai.generateImage(request: request);

        expect(response, isNotNull);
        expect(response.assets.length, equals(1));
        expect(response.assets.first.url,
            equals('https://example.com/image1.png'));
        expect(response.assets.first.revisedPrompt,
            equals('A beautiful sunset over the ocean'));
      });

      test('should successfully generate image with specified provider',
          () async {
        final mockResponseBody = jsonEncode({
          'created': 1677652288,
          'data': [
            {
              'url': 'https://example.com/image2.png',
            }
          ],
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/images/generations',
          http.Response(mockResponseBody, 200),
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'dall-e-3',
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = ImageRequest(
          prompt: 'A futuristic cityscape',
          model: 'dall-e-3',
          size: ImageSize.w1024h1024,
        );

        final response =
            await ai.generateImage(provider: 'openai', request: request);

        expect(response.assets.length, equals(1));
        expect(response.assets.first.url,
            equals('https://example.com/image2.png'));
      });

      test('should handle base64 image response', () async {
        final mockResponseBody = jsonEncode({
          'created': 1677652288,
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

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'dall-e-3',
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = ImageRequest(
          prompt: 'Test image',
          model: 'dall-e-3',
          size: ImageSize.w1024h1024,
        );

        final response = await ai.generateImage(request: request);

        expect(response.assets.length, equals(1));
        expect(response.assets.first.base64, isNotNull);
        expect(response.assets.first.url, isNull);
      });

      test('should throw ClientError when no provider specified and no default',
          () async {
        final config = UnifiedAIConfig(
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = ImageRequest(
          prompt: 'Test prompt',
          model: 'dall-e-3',
        );

        expectLater(
          ai.generateImage(request: request),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError when provider not found', () async {
        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = ImageRequest(
          prompt: 'Test prompt',
          model: 'dall-e-3',
        );

        expectLater(
          ai.generateImage(provider: 'nonexistent', request: request),
          throwsA(isA<ClientError>()),
        );
      });

      test('should use retry handler for automatic retries', () async {
        mockClient.setResponse(
          'https://api.openai.com/v1/images/generations',
          http.Response(
            '{"error": {"message": "Rate limit exceeded", "type": "rate_limit_error"}}',
            429,
            headers: {'Retry-After': '1'},
          ),
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'dall-e-3',
              },
            ),
          },
          retryPolicy: RetryPolicy(
            maxAttempts: 2,
            initialDelay: const Duration(milliseconds: 10),
          ),
        );

        final ai = await UnifiedAI.init(config);

        final request = ImageRequest(
          prompt: 'Test prompt',
          model: 'dall-e-3',
        );

        // Should retry and eventually throw QuotaError after max attempts
        expectLater(
          ai.generateImage(request: request),
          throwsA(isA<QuotaError>()),
        );
      });
    });
  });
}
