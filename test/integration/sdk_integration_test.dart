import 'dart:convert';
import 'dart:developer';

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
import 'package:unified_ai_sdk/src/retry/retry_policy.dart';

/// Mock HTTP client for integration testing.
///
/// This client allows us to simulate API responses while testing
/// the full SDK integration flow.
class IntegrationMockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final List<http.BaseRequest> _requests = [];

  void setResponse(String url, http.Response response) {
    _responses[url] = response;
  }

  List<http.BaseRequest> get requests => List.unmodifiable(_requests);

  void clear() {
    _responses.clear();
    _requests.clear();
  }

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
  group('SDK Integration Tests', () {
    late IntegrationMockHttpClient mockClient;

    setUp(() {
      mockClient = IntegrationMockHttpClient();
    });

    tearDown(() async {
      // Clean up singleton instance after each test
      try {
        UnifiedAI.instance.dispose();
      } on Exception catch (e) {
        log('Error: $e');
        // Ignore errors (StateError, etc.)
      }
      mockClient.clear();
    });

    group('Full SDK Flow: Init → Chat → Response', () {
      test('should complete full chat flow successfully', () async {
        // Setup mock response
        final mockChatResponse = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': 'Hello! How can I assist you today?',
              },
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 12,
            'total_tokens': 22,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(mockChatResponse, 200),
        );

        // Step 1: Initialize SDK
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

        // Verify initialization
        expect(ai, isNotNull);
        expect(ai.availableProviders, contains('openai'));

        // Step 2: Make chat request
        final request = ChatRequest(
          messages: [
            const Message(role: Role.user, content: 'Hello!'),
          ],
        );

        final response = await ai.chat(request: request);

        // Step 3: Verify response
        expect(response, isNotNull);
        expect(response.choices, isNotEmpty);
        expect(response.choices.first.message.content,
            equals('Hello! How can I assist you today?'));
        expect(response.model, equals('gpt-4o'));
        expect(response.provider, equals('openai'));
        expect(response.usage, isNotNull);
        expect(response.usage.totalTokens, equals(22));

        // Verify HTTP request was made correctly
        expect(mockClient.requests.length, equals(1));
        final httpRequest = mockClient.requests.first;
        expect(httpRequest.url.toString(),
            equals('https://api.openai.com/v1/chat/completions'));
        expect(httpRequest.method, equals('POST'));
      });

      test('should complete full embedding flow successfully', () async {
        // Setup mock response
        final mockEmbeddingResponse = jsonEncode({
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
          http.Response(mockEmbeddingResponse, 200),
        );

        // Initialize SDK
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

        // Make embedding request
        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
        );

        final response = await ai.embed(request: request);

        // Verify response
        expect(response, isNotNull);
        expect(response.embeddings.length, equals(1));
        expect(response.embeddings.first.vector.length, equals(5));
        expect(response.model, equals('text-embedding-3-small'));
        expect(response.provider, equals('openai'));
      });

      test('should complete full image generation flow successfully', () async {
        // Setup mock response
        final mockImageResponse = jsonEncode({
          'created': 1677652288,
          'data': [
            {
              'url': 'https://example.com/generated-image.png',
              'revised_prompt': 'A beautiful sunset over the ocean',
            }
          ],
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/images/generations',
          http.Response(mockImageResponse, 200),
        );

        // Initialize SDK
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

        // Make image generation request
        final request = ImageRequest(
          prompt: 'A beautiful sunset over the ocean',
          size: ImageSize.w1024h1024,
        );

        final response = await ai.generateImage(request: request);

        // Verify response
        expect(response, isNotNull);
        expect(response.assets.length, equals(1));
        expect(response.assets.first.url,
            equals('https://example.com/generated-image.png'));
        expect(response.model, equals('dall-e-3'));
        expect(response.provider, equals('openai'));
      });

      test('should handle multiple providers in one flow', () async {
        // Setup mock responses for different providers
        final mockChatResponse = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': 'Chat response',
              },
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 5,
            'completion_tokens': 10,
            'total_tokens': 15,
          },
        });

        final mockEmbeddingResponse = jsonEncode({
          'data': [
            {
              'index': 0,
              'embedding': [0.1, 0.2, 0.3],
              'object': 'embedding',
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
          'https://api.openai.com/v1/chat/completions',
          http.Response(mockChatResponse, 200),
        );
        mockClient.setResponse(
          'https://api.openai.com/v1/embeddings',
          http.Response(mockEmbeddingResponse, 200),
        );

        // Initialize SDK with single provider
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

        // Use same provider for different operations
        final chatResponse = await ai.chat(
          provider: 'openai',
          request: ChatRequest(
            messages: [const Message(role: Role.user, content: 'Hello')],
          ),
        );

        final embedResponse = await ai.embed(
          provider: 'openai',
          request: EmbeddingRequest(
            inputs: ['Test'],
            model: 'text-embedding-3-small',
          ),
        );

        // Verify both operations worked
        expect(chatResponse.choices.first.message.content,
            equals('Chat response'));
        expect(embedResponse.embeddings.length, equals(1));
        expect(mockClient.requests.length, equals(2));
      });
    });

    group('Error Handling Integration', () {
      test('should handle authentication errors end-to-end', () async {
        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(
            '{"error": {"message": "Invalid API key", "type": "invalid_request_error"}}',
            401,
          ),
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-invalid'),
              settings: {
                'httpClient': mockClient,
                'defaultModel': 'gpt-4o',
              },
            ),
          },
        );

        final ai = await UnifiedAI.init(config);

        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        // Should throw AuthError through the entire stack
        expectLater(
          ai.chat(request: request),
          throwsA(isA<AuthError>()),
        );
      });

      test('should handle rate limit errors end-to-end', () async {
        // Use a custom mock that can return multiple responses
        final retryMockClient = _RetryTestMockHttpClient();
        retryMockClient.setRetryBehavior(
          'https://api.openai.com/v1/chat/completions',
          [
            http.Response(
              '{"error": {"message": "Rate limit exceeded", "type": "rate_limit_error"}}',
              429,
              headers: {
                'retry-after': '0'
              }, // Use 0 to avoid long waits in tests
            ),
            http.Response(
              '{"error": {"message": "Rate limit exceeded", "type": "rate_limit_error"}}',
              429,
              headers: {'retry-after': '0'},
            ),
          ],
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': retryMockClient,
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
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        // Should throw QuotaError after retries
        try {
          await ai.chat(request: request);
          fail('Expected QuotaError to be thrown');
        } on QuotaError {
          // Expected
        }

        // Verify retry attempts were made
        expect(retryMockClient.attemptCount, equals(2));
      });

      test('should handle server errors end-to-end', () async {
        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(
            '{"error": {"message": "Internal server error"}}',
            500,
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
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        // Should throw TransientError after retries
        expectLater(
          ai.chat(request: request),
          throwsA(isA<TransientError>()),
        );
      });

      test('should handle client errors end-to-end', () async {
        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(
            '{"error": {"message": "Invalid request", "type": "invalid_request_error"}}',
            400,
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
        );

        final ai = await UnifiedAI.init(config);

        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        // Should throw ClientError (no retries for client errors)
        expectLater(
          ai.chat(request: request),
          throwsA(isA<ClientError>()),
        );

        // Verify only one attempt was made (no retries)
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(mockClient.requests.length, equals(1));
      });
    });

    group('Retry Logic Integration', () {
      test('should retry on transient errors and eventually succeed', () async {
        // First two attempts fail, third succeeds
        final retryMockClient = _RetryTestMockHttpClient();

        // Setup: First two calls return 500, third returns success
        final successResponse = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': 'Success after retry',
              },
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 5,
            'completion_tokens': 10,
            'total_tokens': 15,
          },
        });

        retryMockClient.setRetryBehavior(
          'https://api.openai.com/v1/chat/completions',
          [
            http.Response('{"error": "Internal server error"}', 500),
            http.Response('{"error": "Internal server error"}', 500),
            http.Response(successResponse, 200),
          ],
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': retryMockClient,
                'defaultModel': 'gpt-4o',
              },
            ),
          },
          retryPolicy: RetryPolicy(
            maxAttempts: 3,
            initialDelay: const Duration(milliseconds: 10),
          ),
        );

        final ai = await UnifiedAI.init(config);

        final request = ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        final response = await ai.chat(request: request);

        // Should eventually succeed
        expect(response.choices.first.message.content,
            equals('Success after retry'));
        expect(retryMockClient.attemptCount, equals(3));
      });

      test('should respect retry-after header from QuotaError', () async {
        final retryMockClient = _RetryTestMockHttpClient();
        retryMockClient.setRetryBehavior(
          'https://api.openai.com/v1/chat/completions',
          [
            http.Response(
              '{"error": {"message": "Rate limit exceeded"}}',
              429,
              headers: {
                'retry-after': '0'
              }, // Use 0 to avoid long waits in tests
            ),
            http.Response(
              '{"error": {"message": "Rate limit exceeded"}}',
              429,
              headers: {'retry-after': '0'},
            ),
          ],
        );

        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-test123'),
              settings: {
                'httpClient': retryMockClient,
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
          messages: [const Message(role: Role.user, content: 'Hello')],
        );

        // Should throw QuotaError after max attempts
        try {
          await ai.chat(request: request);
          fail('Expected QuotaError to be thrown');
        } on QuotaError {
          // Expected
        }

        // Verify retry attempts were made
        expect(retryMockClient.attemptCount, equals(2));
      });
    });

    group('Provider Selection Integration', () {
      test('should use default provider when not specified', () async {
        final mockResponse = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': 'Response',
              },
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 5,
            'completion_tokens': 10,
            'total_tokens': 15,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(mockResponse, 200),
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

        // Don't specify provider - should use default
        final response = await ai.chat(
          request: ChatRequest(
            messages: [const Message(role: Role.user, content: 'Hello')],
          ),
        );

        expect(response.provider, equals('openai'));
      });

      test('should use specified provider when provided', () async {
        final mockResponse = jsonEncode({
          'id': 'chatcmpl-123',
          'object': 'chat.completion',
          'created': 1677652288,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': 'Response',
              },
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 5,
            'completion_tokens': 10,
            'total_tokens': 15,
          },
        });

        mockClient.setResponse(
          'https://api.openai.com/v1/chat/completions',
          http.Response(mockResponse, 200),
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

        // Explicitly specify provider
        final response = await ai.chat(
          provider: 'openai',
          request: ChatRequest(
            messages: [const Message(role: Role.user, content: 'Hello')],
          ),
        );

        expect(response.provider, equals('openai'));
      });
    });
  });
}

/// Custom mock HTTP client that supports retry testing.
///
/// This client can return different responses for the same URL
/// based on the attempt number, allowing us to test retry logic.
class _RetryTestMockHttpClient extends http.BaseClient {
  final Map<String, List<http.Response>> _responseSequences = {};
  final Map<String, int> _attemptCounts = {};

  void setRetryBehavior(String url, List<http.Response> responses) {
    _responseSequences[url] = responses;
    _attemptCounts[url] = 0;
  }

  int get attemptCount {
    return _attemptCounts.values.fold(0, (sum, count) => sum + count);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    final sequence = _responseSequences[url];

    if (sequence != null) {
      final attempt = _attemptCounts[url] ?? 0;
      _attemptCounts[url] = attempt + 1;

      if (attempt < sequence.length) {
        final response = sequence[attempt];
        return http.StreamedResponse(
          Stream.value(utf8.encode(response.body)),
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }
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
