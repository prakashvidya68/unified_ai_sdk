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

/// Mock HTTP client for auto-routing tests
class AutoRoutingMockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final List<String> _requestUrls = [];

  void setResponse(String url, http.Response response) {
    _responses[url] = response;
  }

  List<String> get requestUrls => List.unmodifiable(_requestUrls);

  void clear() {
    _responses.clear();
    _requestUrls.clear();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _requestUrls.add(request.url.toString());

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
  group('Auto-Routing Integration Tests', () {
    late AutoRoutingMockHttpClient mockClient;

    setUp(() {
      mockClient = AutoRoutingMockHttpClient();
    });

    tearDown(() async {
      // Clean up singleton instance after each test
      try {
        UnifiedAI.instance.dispose();
      } on Exception {
        // Ignore if not initialized or other exceptions
      } on Object {
        // Ignore errors (StateError, etc.)
      }
      mockClient.clear();
    });

    group('Automatic Intent-Based Routing', () {
      test('should automatically route chat request to chat provider',
          () async {
        final chatResponse = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'Hello!'},
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 5,
            'total_tokens': 15,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(chatResponse, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {
                  'defaultModel': 'gpt-4o',
                  'httpClient': mockClient,
                },
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        // No provider specified - should auto-route to chat provider
        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello!')],
          model: 'gpt-4o',
        );

        final response = await ai.chat(request: request);

        expect(response.provider, equals('openai'));
        expect(response.choices.first.message.content, equals('Hello!'));
        expect(mockClient.requestUrls.length, equals(1));
        expect(mockClient.requestUrls[0],
            contains('api.openai.com/v1/chat/completions'));
      });

      test('should automatically route image request to image provider',
          () async {
        final imageResponse = jsonEncode({
          'created': 1677652288,
          'data': [
            {
              'url': 'https://example.com/image.png',
            }
          ],
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/images/generations',
          http.Response(imageResponse, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {
                  'defaultModel': 'dall-e-3',
                  'httpClient': mockClient,
                },
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        // No provider specified - should auto-route to image provider
        final request = ImageRequest(
          prompt: 'A beautiful sunset',
          model: 'dall-e-3',
        );

        final response = await ai.generateImage(request: request);

        expect(response.provider, equals('openai'));
        expect(response.assets.length, equals(1));
        expect(mockClient.requestUrls.length, equals(1));
        expect(mockClient.requestUrls[0],
            contains('api.openai.com/v1/images/generations'));
      });

      test('should automatically route embedding request to embedding provider',
          () async {
        final embeddingResponse = jsonEncode({
          'object': 'list',
          'data': [
            {
              'object': 'embedding',
              'index': 0,
              'embedding': [0.1, 0.2, 0.3],
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
          http.Response(embeddingResponse, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {
                  'defaultModel': 'text-embedding-3-small',
                  'httpClient': mockClient,
                },
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        // No provider specified - should auto-route to embedding provider
        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
          model: 'text-embedding-3-small',
        );

        final response = await ai.embed(request: request);

        expect(response.provider, equals('openai'));
        expect(response.embeddings.length, equals(1));
        expect(mockClient.requestUrls.length, equals(1));
        expect(mockClient.requestUrls[0],
            contains('api.openai.com/v1/embeddings'));
      });

      test(
          'should detect image intent but route to chat provider for chat() method',
          () async {
        final chatResponse = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': 'I can help with that'
              },
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 5,
            'total_tokens': 15,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(chatResponse, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {
                  'defaultModel': 'gpt-4o',
                  'httpClient': mockClient,
                },
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        // Chat request with image intent keywords
        // Note: The router detects image intent, but chat() method always
        // calls provider.chat(). The router routes to a chat provider
        // because that's what the chat() method requires. This is expected behavior.
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Draw a picture of a cat'),
          ],
          model: 'gpt-4o',
        );

        final response = await ai.chat(request: request);
        // Router routes to chat provider (correct for chat() method)
        expect(response.provider, equals('openai'));
        expect(mockClient.requestUrls.length, equals(1));
        expect(mockClient.requestUrls[0],
            contains('api.openai.com/v1/chat/completions'));
      });
    });

    group('Explicit Provider Override', () {
      test('should use explicit provider even when intent suggests different',
          () async {
        final chatResponse = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'Response'},
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 5,
            'total_tokens': 15,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(chatResponse, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {
                  'defaultModel': 'gpt-4o',
                  'httpClient': mockClient,
                },
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        // Explicit provider should override intent-based routing
        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello!')],
          model: 'gpt-4o',
        );

        final response = await ai.chat(
          provider: 'openai',
          request: request,
        );

        expect(response.provider, equals('openai'));
        expect(mockClient.requestUrls.length, equals(1));
      });
    });

    group('Multi-Provider Auto-Routing', () {
      test('should route to first provider that supports capability', () async {
        final chatResponse1 = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'OpenAI response'},
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 5,
            'total_tokens': 15,
          },
        });

        final chatResponse2 = jsonEncode({
          'id': 'msg-123',
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Anthropic response'}
          ],
          'model': 'claude-sonnet-4-5-20250929',
          'usage': {
            'input_tokens': 10,
            'output_tokens': 5,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(chatResponse1, 200),
        );
        mockClient.setResponse(
          'https://api.anthropic.com/v1/messages',
          http.Response(chatResponse2, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {
                  'defaultModel': 'gpt-4o',
                  'httpClient': mockClient,
                },
              ),
              'anthropic': ProviderConfig(
                id: 'anthropic',
                auth: ApiKeyAuth(
                  apiKey: 'sk-ant-test',
                  headerName: 'x-api-key',
                ),
                settings: {
                  'defaultModel': 'claude-sonnet-4-5-20250929',
                  'httpClient': mockClient,
                },
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        // No provider specified - should auto-route to first chat provider
        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello!')],
          model: 'gpt-4o',
        );

        final response = await ai.chat(request: request);

        // Should route to first provider that supports chat (OpenAI)
        expect(response.provider, equals('openai'));
        expect(response.choices.first.message.content, contains('OpenAI'));
      });

      test(
          'should route embedding to embedding provider when multiple providers available',
          () async {
        final openaiEmbeddingResponse = jsonEncode({
          'object': 'list',
          'data': [
            {
              'object': 'embedding',
              'index': 0,
              'embedding': [0.1, 0.2, 0.3],
            }
          ],
          'model': 'text-embedding-3-small',
          'usage': {
            'prompt_tokens': 5,
            'completion_tokens': 0,
            'total_tokens': 5,
          },
        });

        final cohereEmbeddingResponse = jsonEncode({
          'embeddings': [
            [0.1, 0.2, 0.3],
          ],
          'id': 'embed-english-v3.0',
          'meta': {
            'tokens': 5,
          },
        });

        // Set responses for both providers
        mockClient.setResponse(
          'https://api.openai.com/v1/embeddings',
          http.Response(openaiEmbeddingResponse, 200),
        );
        mockClient.setResponse(
          'https://api.cohere.ai/v1/embed',
          http.Response(cohereEmbeddingResponse, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {
                  'defaultModel': 'text-embedding-3-small',
                  'httpClient': mockClient,
                },
              ),
              'cohere': ProviderConfig(
                id: 'cohere',
                auth: ApiKeyAuth(apiKey: 'co-test'),
                settings: {
                  'defaultModel': 'embed-english-v3.0',
                  'httpClient': mockClient,
                },
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        // No provider specified - should auto-route to embedding provider
        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
          model: 'text-embedding-3-small',
        );

        final response = await ai.embed(request: request);

        // Should route to a provider that supports embeddings (OpenAI is first)
        expect(response.provider, isIn(['openai', 'cohere']));
        expect(response.embeddings.length, equals(1));
      });
    });

    group('Error Handling in Auto-Routing', () {
      test('should throw CapabilityError when no providers support capability',
          () async {
        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'cohere': ProviderConfig(
                id: 'cohere',
                auth: ApiKeyAuth(apiKey: 'co-test'),
                settings: {'httpClient': mockClient},
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        // Cohere doesn't support chat - should throw CapabilityError
        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello!')],
        );

        expect(
          () => ai.chat(request: request),
          throwsA(isA<CapabilityError>()),
        );
      });

      test('should throw ClientError when explicit provider not found',
          () async {
        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {'httpClient': mockClient},
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello!')],
        );

        expect(
          () => ai.chat(provider: 'nonexistent', request: request),
          throwsA(isA<ClientError>()),
        );
      });
    });

    group('Router Access', () {
      test('should expose router via getter', () async {
        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {'httpClient': mockClient},
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        expect(ai.router, isNotNull);
        expect(ai.router.providerRegistry, equals(ai.registry));
        expect(ai.router.detector, isNotNull);
      });
    });
  });
}
