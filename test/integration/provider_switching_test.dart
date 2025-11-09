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

/// Mock HTTP client for provider switching tests.
class ProviderSwitchingMockHttpClient extends http.BaseClient {
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
  group('Provider Switching Tests', () {
    late ProviderSwitchingMockHttpClient mockClient;

    setUp(() {
      mockClient = ProviderSwitchingMockHttpClient();
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

    group('Provider Registration', () {
      test('should register all providers from config', () async {
        // Setup mock responses for all providers
        final openaiResponse = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'Hello from OpenAI!'},
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 5,
            'total_tokens': 15,
          },
        });

        final anthropicResponse = jsonEncode({
          'id': 'msg_123',
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Hello from Anthropic!'}
          ],
          'model': 'claude-sonnet-4-5-20250929',
          'usage': {
            'input_tokens': 10,
            'output_tokens': 5,
          },
        });

        final googleResponse = jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Hello from Google!'}
                ],
              },
              'finish_reason': 'STOP',
            }
          ],
          'usage_metadata': {
            'prompt_token_count': 10,
            'candidates_token_count': 5,
            'total_token_count': 15,
          },
        });

        final cohereResponse = jsonEncode({
          'embeddings': [
            [0.1, 0.2, 0.3, 0.4, 0.5],
            [0.6, 0.7, 0.8, 0.9, 1.0],
          ],
          'id': 'embed-english-v3.0',
          'meta': {
            'tokens': 10,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(openaiResponse, 200),
        );
        mockClient.setResponse(
          'https://api.anthropic.com/v1/messages',
          http.Response(anthropicResponse, 200),
        );
        mockClient.setResponse(
          'https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=test-key',
          http.Response(googleResponse, 200),
        );
        mockClient.setResponse(
          'https://api.cohere.ai/v1/embed',
          http.Response(cohereResponse, 200),
        );

        // Initialize SDK with all providers
        await UnifiedAI.init(
          UnifiedAIConfig(
            defaultProvider: 'openai',
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
              'google': ProviderConfig(
                id: 'google',
                auth: ApiKeyAuth(apiKey: 'test-key'),
                settings: {
                  'defaultModel': 'gemini-pro',
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

        // Verify all providers are registered
        expect(ai.availableProviders.length, equals(4));
        expect(ai.availableProviders,
            containsAll(['openai', 'anthropic', 'google', 'cohere']));

        // Verify providers can be retrieved
        expect(ai.getProvider('openai'), isNotNull);
        expect(ai.getProvider('anthropic'), isNotNull);
        expect(ai.getProvider('google'), isNotNull);
        expect(ai.getProvider('cohere'), isNotNull);

        // Verify provider names
        expect(ai.getProvider('openai')?.name, equals('OpenAI'));
        expect(ai.getProvider('anthropic')?.name, equals('Anthropic Claude'));
        expect(ai.getProvider('google')?.name, equals('Google Gemini'));
        expect(ai.getProvider('cohere')?.name, equals('Cohere'));
      });

      test('should throw error when registering duplicate provider ID',
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
        final registry = ai.registry;

        // Try to register duplicate provider
        final duplicateProvider = ai.getProvider('openai')!;
        expect(
          () => registry.register(duplicateProvider),
          throwsA(isA<ClientError>()),
        );
      });
    });

    group('Provider Switching - Chat', () {
      test('should switch between OpenAI and Anthropic for chat', () async {
        final openaiResponse = jsonEncode({
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

        final anthropicResponse = jsonEncode({
          'id': 'msg_123',
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
          http.Response(openaiResponse, 200),
        );
        mockClient.setResponse(
          'https://api.anthropic.com/v1/messages',
          http.Response(anthropicResponse, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            defaultProvider: 'openai',
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
        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello!')],
          model: 'gpt-4o',
        );

        // Use OpenAI (default)
        final openaiResult = await ai.chat(request: request);
        expect(openaiResult.choices.first.message.content, contains('OpenAI'));
        expect(openaiResult.provider, equals('openai'));

        // Switch to Anthropic
        final anthropicResult = await ai.chat(
          provider: 'anthropic',
          request: ChatRequest(
            messages: [const Message(role: Role.user, content: 'Hello!')],
            model: 'claude-sonnet-4-5-20250929',
            maxTokens: 1024,
          ),
        );
        expect(anthropicResult.choices.first.message.content,
            contains('Anthropic'));
        expect(anthropicResult.provider, equals('anthropic'));

        // Verify correct endpoints were called
        expect(mockClient.requestUrls.length, equals(2));
        expect(mockClient.requestUrls[0],
            contains('api.openai.com/v1/chat/completions'));
        expect(mockClient.requestUrls[1],
            contains('api.anthropic.com/v1/messages'));
      });

      test('should switch between OpenAI and Google for chat', () async {
        final openaiResponse = jsonEncode({
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

        final googleResponse = jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Google response'}
                ],
              },
              'finish_reason': 'STOP',
            }
          ],
          'usage_metadata': {
            'prompt_token_count': 10,
            'candidates_token_count': 5,
            'total_token_count': 15,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(openaiResponse, 200),
        );
        mockClient.setResponse(
          'https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=test-key',
          http.Response(googleResponse, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            defaultProvider: 'openai',
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {
                  'defaultModel': 'gpt-4o',
                  'httpClient': mockClient,
                },
              ),
              'google': ProviderConfig(
                id: 'google',
                auth: ApiKeyAuth(apiKey: 'test-key'),
                settings: {
                  'defaultModel': 'gemini-pro',
                  'httpClient': mockClient,
                },
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;

        // Use OpenAI
        final openaiResult = await ai.chat(
          provider: 'openai',
          request: ChatRequest(
            messages: [const Message(role: Role.user, content: 'Hello!')],
            model: 'gpt-4o',
          ),
        );
        expect(openaiResult.provider, equals('openai'));

        // Switch to Google
        final googleResult = await ai.chat(
          provider: 'google',
          request: ChatRequest(
            messages: [const Message(role: Role.user, content: 'Hello!')],
            model: 'gemini-pro',
          ),
        );
        expect(googleResult.provider, equals('google'));
      });
    });

    group('Provider Switching - Embeddings', () {
      test('should switch between OpenAI and Cohere for embeddings', () async {
        final openaiResponse = jsonEncode({
          'object': 'list',
          'data': [
            {
              'object': 'embedding',
              'index': 0,
              'embedding': [0.1, 0.2, 0.3, 0.4, 0.5],
            },
            {
              'object': 'embedding',
              'index': 1,
              'embedding': [0.6, 0.7, 0.8, 0.9, 1.0],
            },
          ],
          'model': 'text-embedding-3-small',
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 0,
            'total_tokens': 10,
          },
        });

        final cohereResponse = jsonEncode({
          'embeddings': [
            [0.1, 0.2, 0.3, 0.4, 0.5],
            [0.6, 0.7, 0.8, 0.9, 1.0],
          ],
          'id': 'embed-english-v3.0',
          'meta': {
            'tokens': 10,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/embeddings',
          http.Response(openaiResponse, 200),
        );
        mockClient.setResponse(
          'https://api.cohere.ai/v1/embed',
          http.Response(cohereResponse, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            defaultProvider: 'openai',
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
        final request = EmbeddingRequest(
          inputs: ['Hello, world!', 'How are you?'],
        );

        // Use OpenAI
        final openaiResult = await ai.embed(
          provider: 'openai',
          request: request.copyWith(model: 'text-embedding-3-small'),
        );
        expect(openaiResult.provider, equals('openai'));
        expect(openaiResult.embeddings.length, equals(2));

        // Switch to Cohere
        final cohereResult = await ai.embed(
          provider: 'cohere',
          request: request.copyWith(model: 'embed-english-v3.0'),
        );
        expect(cohereResult.provider, equals('cohere'));
        expect(cohereResult.embeddings.length, equals(2));

        // Verify correct endpoints were called
        expect(mockClient.requestUrls.length, equals(2));
        expect(mockClient.requestUrls[0],
            contains('api.openai.com/v1/embeddings'));
        expect(mockClient.requestUrls[1], contains('api.cohere.ai/v1/embed'));
      });
    });

    group('Capability-Based Provider Selection', () {
      test('should find providers by capability', () async {
        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {'httpClient': mockClient},
              ),
              'anthropic': ProviderConfig(
                id: 'anthropic',
                auth: ApiKeyAuth(
                  apiKey: 'sk-ant-test',
                  headerName: 'x-api-key',
                ),
                settings: {'httpClient': mockClient},
              ),
              'google': ProviderConfig(
                id: 'google',
                auth: ApiKeyAuth(apiKey: 'test-key'),
                settings: {'httpClient': mockClient},
              ),
              'cohere': ProviderConfig(
                id: 'cohere',
                auth: ApiKeyAuth(apiKey: 'co-test'),
                settings: {'httpClient': mockClient},
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;
        final registry = ai.registry;

        // Find chat providers
        final chatProviders = registry.getByCapability('chat');
        expect(chatProviders.length, equals(3)); // OpenAI, Anthropic, Google
        expect(chatProviders.map((p) => p.id),
            containsAll(['openai', 'anthropic', 'google']));
        expect(chatProviders.map((p) => p.id), isNot(contains('cohere')));

        // Find embedding providers
        final embeddingProviders = registry.getByCapability('embedding');
        expect(embeddingProviders.length, equals(2)); // OpenAI, Cohere
        expect(embeddingProviders.map((p) => p.id),
            containsAll(['openai', 'cohere']));

        // Find providers that support streaming
        final streamingProviders = registry.getByCapability('streaming');
        expect(streamingProviders.length, greaterThan(0));
        expect(streamingProviders.map((p) => p.id), contains('openai'));
      });

      test('should throw error when using provider without required capability',
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

        // Cohere doesn't support chat
        expect(
          () => ai.chat(
            provider: 'cohere',
            request: ChatRequest(
              messages: [const Message(role: Role.user, content: 'Hello!')],
            ),
          ),
          throwsA(isA<CapabilityError>()),
        );
      });
    });

    group('Default Provider Selection', () {
      test('should use default provider when not specified', () async {
        final openaiResponse = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'Default response'},
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
          http.Response(openaiResponse, 200),
        );

        await UnifiedAI.init(
          UnifiedAIConfig(
            defaultProvider: 'openai',
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

        // Don't specify provider - should use default
        final response = await ai.chat(
          request: ChatRequest(
            messages: [const Message(role: Role.user, content: 'Hello!')],
            model: 'gpt-4o',
          ),
        );

        expect(response.provider, equals('openai'));
        expect(mockClient.requestUrls.length, equals(1));
        expect(mockClient.requestUrls[0],
            contains('api.openai.com/v1/chat/completions'));
      });

      test('should throw error when no default provider and none specified',
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

        expect(
          () => ai.chat(
            request: ChatRequest(
              messages: [const Message(role: Role.user, content: 'Hello!')],
            ),
          ),
          throwsA(isA<ClientError>()),
        );
      });
    });

    group('Provider Registry Queries', () {
      test('should query registry for provider information', () async {
        await UnifiedAI.init(
          UnifiedAIConfig(
            perProviderConfig: {
              'openai': ProviderConfig(
                id: 'openai',
                auth: ApiKeyAuth(apiKey: 'sk-test'),
                settings: {'httpClient': mockClient},
              ),
              'anthropic': ProviderConfig(
                id: 'anthropic',
                auth: ApiKeyAuth(
                  apiKey: 'sk-ant-test',
                  headerName: 'x-api-key',
                ),
                settings: {'httpClient': mockClient},
              ),
              'google': ProviderConfig(
                id: 'google',
                auth: ApiKeyAuth(apiKey: 'test-key'),
                settings: {'httpClient': mockClient},
              ),
              'cohere': ProviderConfig(
                id: 'cohere',
                auth: ApiKeyAuth(apiKey: 'co-test'),
                settings: {'httpClient': mockClient},
              ),
            },
          ),
        );

        final ai = UnifiedAI.instance;
        final registry = ai.registry;

        // Test getAllIds
        final allIds = registry.getAllIds();
        expect(allIds.length, equals(4));
        expect(
            allIds, containsAll(['openai', 'anthropic', 'google', 'cohere']));

        // Test getAll
        final allProviders = registry.getAll();
        expect(allProviders.length, equals(4));

        // Test has
        expect(registry.has('openai'), isTrue);
        expect(registry.has('anthropic'), isTrue);
        expect(registry.has('nonexistent'), isFalse);

        // Test count
        expect(registry.count, equals(4));

        // Test toString
        final registryString = registry.toString();
        expect(registryString, contains('4 providers'));
        expect(registryString, contains('openai'));
        expect(registryString, contains('anthropic'));
        expect(registryString, contains('google'));
        expect(registryString, contains('cohere'));
      });
    });
  });
}
