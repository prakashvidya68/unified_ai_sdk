import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/providers/openai/openai_models.dart';

void main() {
  group('OpenAIChatRequest', () {
    test('should create instance with required fields', () {
      final request = OpenAIChatRequest(
        model: 'gpt-4',
        messages: [
          {'role': 'user', 'content': 'Hello!'}
        ],
      );

      expect(request.model, equals('gpt-4'));
      expect(request.messages.length, equals(1));
      expect(request.messages.first['role'], equals('user'));
      expect(request.messages.first['content'], equals('Hello!'));
    });

    test('should create instance with all optional fields', () {
      final request = OpenAIChatRequest(
        model: 'gpt-3.5-turbo',
        messages: [
          {'role': 'system', 'content': 'You are helpful'},
          {'role': 'user', 'content': 'Hello!'}
        ],
        temperature: 0.7,
        maxTokens: 500,
        topP: 0.9,
        n: 2,
        stop: ['\n\n'],
        presencePenalty: 0.5,
        frequencyPenalty: 0.3,
        logitBias: {'123': 10},
        user: 'user-123',
        stream: false,
      );

      expect(request.temperature, equals(0.7));
      expect(request.maxTokens, equals(500));
      expect(request.topP, equals(0.9));
      expect(request.n, equals(2));
      expect(request.stop, equals(['\n\n']));
      expect(request.presencePenalty, equals(0.5));
      expect(request.frequencyPenalty, equals(0.3));
      expect(request.logitBias, equals({'123': 10}));
      expect(request.user, equals('user-123'));
      expect(request.stream, equals(false));
    });

    test('should throw error if model is empty', () {
      expect(
        () => OpenAIChatRequest(
          model: '',
          messages: [
            {'role': 'user', 'content': 'Hello'}
          ],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should throw error if messages is empty', () {
      expect(
        () => OpenAIChatRequest(
          model: 'gpt-4',
          messages: [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should throw error if temperature is out of range', () {
      expect(
        () => OpenAIChatRequest(
          model: 'gpt-4',
          messages: [
            {'role': 'user', 'content': 'Hello'}
          ],
          temperature: 3.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should throw error if maxTokens is negative', () {
      expect(
        () => OpenAIChatRequest(
          model: 'gpt-4',
          messages: [
            {'role': 'user', 'content': 'Hello'}
          ],
          maxTokens: -1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should convert to JSON correctly', () {
      final request = OpenAIChatRequest(
        model: 'gpt-4',
        messages: [
          {'role': 'user', 'content': 'Hello!'}
        ],
        temperature: 0.7,
        maxTokens: 500,
        topP: 0.9,
        n: 1,
        stop: ['\n\n'],
        presencePenalty: 0.5,
        frequencyPenalty: 0.3,
        user: 'user-123',
      );

      final json = request.toJson();

      expect(json['model'], equals('gpt-4'));
      expect(json['messages'], isA<List<dynamic>>());
      expect(json['temperature'], equals(0.7));
      expect(json['max_tokens'], equals(500));
      expect(json['top_p'], equals(0.9));
      expect(json['n'], equals(1));
      expect(json['stop'], equals(['\n\n']));
      expect(json['presence_penalty'], equals(0.5));
      expect(json['frequency_penalty'], equals(0.3));
      expect(json['user'], equals('user-123'));
    });

    test('should exclude null fields from JSON', () {
      final request = OpenAIChatRequest(
        model: 'gpt-4',
        messages: [
          {'role': 'user', 'content': 'Hello'}
        ],
      );

      final json = request.toJson();

      expect(json.containsKey('temperature'), isFalse);
      expect(json.containsKey('max_tokens'), isFalse);
      expect(json.containsKey('top_p'), isFalse);
      expect(json.containsKey('n'), isFalse);
      expect(json.containsKey('stop'), isFalse);
    });

    test('should create from JSON correctly', () {
      final json = {
        'model': 'gpt-4',
        'messages': [
          {'role': 'user', 'content': 'Hello!'}
        ],
        'temperature': 0.7,
        'max_tokens': 500,
        'top_p': 0.9,
        'n': 1,
        'stop': ['\n\n'],
        'presence_penalty': 0.5,
        'frequency_penalty': 0.3,
        'user': 'user-123',
      };

      final request = OpenAIChatRequest.fromJson(json);

      expect(request.model, equals('gpt-4'));
      expect(request.messages.length, equals(1));
      expect(request.temperature, equals(0.7));
      expect(request.maxTokens, equals(500));
      expect(request.topP, equals(0.9));
      expect(request.n, equals(1));
      expect(request.stop, equals(['\n\n']));
      expect(request.presencePenalty, equals(0.5));
      expect(request.frequencyPenalty, equals(0.3));
      expect(request.user, equals('user-123'));
    });

    test('should throw error when creating from JSON without model', () {
      final json = {
        'messages': [
          {'role': 'user', 'content': 'Hello'}
        ],
      };

      expect(
        () => OpenAIChatRequest.fromJson(json),
        throwsA(isA<ClientError>()),
      );
    });

    test('should throw error when creating from JSON without messages', () {
      final json = {
        'model': 'gpt-4',
      };

      expect(
        () => OpenAIChatRequest.fromJson(json),
        throwsA(isA<ClientError>()),
      );
    });

    test('should handle logit_bias in JSON', () {
      final json = {
        'model': 'gpt-4',
        'messages': [
          {'role': 'user', 'content': 'Hello'}
        ],
        'logit_bias': {'123': 10, '456': -5},
      };

      final request = OpenAIChatRequest.fromJson(json);

      expect(request.logitBias, equals({'123': 10, '456': -5}));
    });

    test('should handle tools parameter', () {
      final request = OpenAIChatRequest(
        model: 'gpt-4',
        messages: [
          {'role': 'user', 'content': 'Hello'}
        ],
        tools: [
          {
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'description': 'Get weather',
            }
          }
        ],
      );

      final json = request.toJson();
      expect(json['tools'], isA<List<dynamic>>());
      expect(json['tools'].length, equals(1));
    });

    test('should be equal when fields match', () {
      final request1 = OpenAIChatRequest(
        model: 'gpt-4',
        messages: [
          {'role': 'user', 'content': 'Hello'}
        ],
        temperature: 0.7,
      );

      final request2 = OpenAIChatRequest(
        model: 'gpt-4',
        messages: [
          {'role': 'user', 'content': 'Hello'}
        ],
        temperature: 0.7,
      );

      expect(request1, equals(request2));
      expect(request1.hashCode, equals(request2.hashCode));
    });
  });

  group('OpenAIChatResponse', () {
    test('should create from JSON correctly', () {
      final json = {
        'id': 'chatcmpl-123',
        'object': 'chat.completion',
        'created': 1677652288,
        'model': 'gpt-4',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': 'Hello! How can I help you?'
            },
            'finish_reason': 'stop'
          }
        ],
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 7,
          'total_tokens': 17
        },
        'system_fingerprint': 'fp_123',
      };

      final response = OpenAIChatResponse.fromJson(json);

      expect(response.id, equals('chatcmpl-123'));
      expect(response.object, equals('chat.completion'));
      expect(response.created, equals(1677652288));
      expect(response.model, equals('gpt-4'));
      expect(response.choices.length, equals(1));
      expect(response.choices.first.index, equals(0));
      expect(response.choices.first.message['role'], equals('assistant'));
      expect(response.choices.first.message['content'],
          equals('Hello! How can I help you?'));
      expect(response.choices.first.finishReason, equals('stop'));
      expect(response.usage.promptTokens, equals(10));
      expect(response.usage.completionTokens, equals(7));
      expect(response.usage.totalTokens, equals(17));
      expect(response.systemFingerprint, equals('fp_123'));
    });

    test('should convert to JSON correctly', () {
      final response = OpenAIChatResponse(
        id: 'chatcmpl-123',
        object: 'chat.completion',
        created: 1677652288,
        model: 'gpt-4',
        choices: [
          OpenAIChatChoice(
            index: 0,
            message: {'role': 'assistant', 'content': 'Hello!'},
            finishReason: 'stop',
          )
        ],
        usage: OpenAIUsage(
          promptTokens: 10,
          completionTokens: 7,
          totalTokens: 17,
        ),
        systemFingerprint: 'fp_123',
      );

      final json = response.toJson();

      expect(json['id'], equals('chatcmpl-123'));
      expect(json['object'], equals('chat.completion'));
      expect(json['created'], equals(1677652288));
      expect(json['model'], equals('gpt-4'));
      expect(json['choices'], isA<List<dynamic>>());
      expect(json['usage'], isA<Map<String, dynamic>>());
      expect(json['system_fingerprint'], equals('fp_123'));
    });

    test('should handle response without system_fingerprint', () {
      final json = {
        'id': 'chatcmpl-123',
        'object': 'chat.completion',
        'created': 1677652288,
        'model': 'gpt-4',
        'choices': [
          {
            'index': 0,
            'message': {'role': 'assistant', 'content': 'Hello!'},
            'finish_reason': 'stop'
          }
        ],
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 7,
          'total_tokens': 17
        },
      };

      final response = OpenAIChatResponse.fromJson(json);

      expect(response.systemFingerprint, isNull);
    });
  });

  group('OpenAIUsage', () {
    test('should create from JSON correctly', () {
      final json = {
        'prompt_tokens': 10,
        'completion_tokens': 7,
        'total_tokens': 17,
      };

      final usage = OpenAIUsage.fromJson(json);

      expect(usage.promptTokens, equals(10));
      expect(usage.completionTokens, equals(7));
      expect(usage.totalTokens, equals(17));
    });

    test('should convert to JSON correctly', () {
      final usage = OpenAIUsage(
        promptTokens: 10,
        completionTokens: 7,
        totalTokens: 17,
      );

      final json = usage.toJson();

      expect(json['prompt_tokens'], equals(10));
      expect(json['completion_tokens'], equals(7));
      expect(json['total_tokens'], equals(17));
    });
  });

  group('OpenAIEmbeddingRequest', () {
    test('should create instance with string input', () {
      final request = OpenAIEmbeddingRequest(
        model: 'text-embedding-3-small',
        input: 'Hello, world!',
      );

      expect(request.model, equals('text-embedding-3-small'));
      expect(request.input, equals('Hello, world!'));
    });

    test('should create instance with list input', () {
      final request = OpenAIEmbeddingRequest(
        model: 'text-embedding-3-small',
        input: ['Hello', 'World'],
      );

      expect(request.model, equals('text-embedding-3-small'));
      expect(request.input, isA<List<dynamic>>());
      expect((request.input as List).length, equals(2));
    });

    test('should create instance with all fields', () {
      final request = OpenAIEmbeddingRequest(
        model: 'text-embedding-3-small',
        input: 'Hello',
        encodingFormat: 'float',
        dimensions: 512,
        user: 'user-123',
      );

      expect(request.encodingFormat, equals('float'));
      expect(request.dimensions, equals(512));
      expect(request.user, equals('user-123'));
    });

    test('should throw error if model is empty', () {
      expect(
        () => OpenAIEmbeddingRequest(
          model: '',
          input: 'Hello',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should convert to JSON correctly', () {
      final request = OpenAIEmbeddingRequest(
        model: 'text-embedding-3-small',
        input: 'Hello, world!',
        encodingFormat: 'float',
        dimensions: 512,
        user: 'user-123',
      );

      final json = request.toJson();

      expect(json['model'], equals('text-embedding-3-small'));
      expect(json['input'], equals('Hello, world!'));
      expect(json['encoding_format'], equals('float'));
      expect(json['dimensions'], equals(512));
      expect(json['user'], equals('user-123'));
    });

    test('should create from JSON correctly', () {
      final json = {
        'model': 'text-embedding-3-small',
        'input': 'Hello, world!',
        'encoding_format': 'float',
        'dimensions': 512,
        'user': 'user-123',
      };

      final request = OpenAIEmbeddingRequest.fromJson(json);

      expect(request.model, equals('text-embedding-3-small'));
      expect(request.input, equals('Hello, world!'));
      expect(request.encodingFormat, equals('float'));
      expect(request.dimensions, equals(512));
      expect(request.user, equals('user-123'));
    });
  });

  group('OpenAIEmbeddingResponse', () {
    test('should create from JSON correctly', () {
      final json = {
        'data': [
          {
            'index': 0,
            'embedding': [0.1, 0.2, 0.3],
            'object': 'embedding'
          }
        ],
        'model': 'text-embedding-3-small',
        'usage': {'prompt_tokens': 5, 'completion_tokens': 0, 'total_tokens': 5}
      };

      final response = OpenAIEmbeddingResponse.fromJson(json);

      expect(response.data.length, equals(1));
      expect(response.data.first.index, equals(0));
      expect(response.data.first.embedding, isA<List<dynamic>>());
      expect(response.data.first.object, equals('embedding'));
      expect(response.model, equals('text-embedding-3-small'));
      expect(response.usage.promptTokens, equals(5));
    });

    test('should convert to JSON correctly', () {
      final response = OpenAIEmbeddingResponse(
        data: [
          OpenAIEmbedding(
            index: 0,
            embedding: [0.1, 0.2, 0.3],
            object: 'embedding',
          )
        ],
        model: 'text-embedding-3-small',
        usage: OpenAIUsage(
          promptTokens: 5,
          completionTokens: 0,
          totalTokens: 5,
        ),
      );

      final json = response.toJson();

      expect(json['data'], isA<List<dynamic>>());
      expect(json['model'], equals('text-embedding-3-small'));
      expect(json['usage'], isA<Map<String, dynamic>>());
    });
  });

  group('OpenAIImageRequest', () {
    test('should create instance with required fields', () {
      final request = OpenAIImageRequest(
        prompt: 'A beautiful sunset',
        model: 'dall-e-3',
        size: '1024x1024',
      );

      expect(request.prompt, equals('A beautiful sunset'));
      expect(request.model, equals('dall-e-3'));
      expect(request.size, equals('1024x1024'));
    });

    test('should convert to JSON correctly', () {
      final request = OpenAIImageRequest(
        prompt: 'A cat',
        model: 'dall-e-3',
        n: 1,
        size: '1024x1024',
        quality: 'hd',
        style: 'vivid',
        responseFormat: 'url',
        user: 'user123',
      );

      final json = request.toJson();

      expect(json['prompt'], equals('A cat'));
      expect(json['model'], equals('dall-e-3'));
      expect(json['n'], equals(1));
      expect(json['size'], equals('1024x1024'));
      expect(json['quality'], equals('hd'));
      expect(json['style'], equals('vivid'));
      expect(json['response_format'], equals('url'));
      expect(json['user'], equals('user123'));
    });

    test('should create from JSON correctly', () {
      final json = {
        'prompt': 'A beautiful landscape',
        'model': 'dall-e-2',
        'n': 2,
        'size': '512x512',
        'quality': 'standard',
      };

      final request = OpenAIImageRequest.fromJson(json);

      expect(request.prompt, equals('A beautiful landscape'));
      expect(request.model, equals('dall-e-2'));
      expect(request.n, equals(2));
      expect(request.size, equals('512x512'));
      expect(request.quality, equals('standard'));
    });

    test('should handle optional fields', () {
      final request = OpenAIImageRequest(
        prompt: 'A cat',
        // All other fields are optional
      );

      expect(request.model, isNull);
      expect(request.n, isNull);
      expect(request.size, isNull);
    });

    test('should support camelCase in fromJson', () {
      final json = {
        'prompt': 'A cat',
        'responseFormat': 'b64_json', // camelCase
      };

      final request = OpenAIImageRequest.fromJson(json);
      expect(request.responseFormat, equals('b64_json'));
    });
  });

  group('OpenAIImageResponse', () {
    test('should create instance with required fields', () {
      final response = OpenAIImageResponse(
        created: 1234567890,
        data: [
          OpenAIImageData(
            url: 'https://example.com/image.png',
            revisedPrompt: 'A beautiful sunset',
          ),
        ],
      );

      expect(response.created, equals(1234567890));
      expect(response.data.length, equals(1));
      expect(response.data.first.url, equals('https://example.com/image.png'));
    });

    test('should convert to JSON correctly', () {
      final response = OpenAIImageResponse(
        created: 1234567890,
        data: [
          OpenAIImageData(
            url: 'https://example.com/image.png',
            b64Json: null,
            revisedPrompt: 'A beautiful sunset',
          ),
        ],
      );

      final json = response.toJson();

      expect(json['created'], equals(1234567890));
      expect(json['data'], isA<List<dynamic>>());
      expect(json['data'].length, equals(1));
      expect(json['data'][0]['url'], equals('https://example.com/image.png'));
      expect(json['data'][0]['revised_prompt'], equals('A beautiful sunset'));
    });

    test('should create from JSON correctly', () {
      final json = {
        'created': 1234567890,
        'data': [
          {
            'url': 'https://example.com/image.png',
            'revised_prompt': 'A beautiful sunset',
          }
        ],
      };

      final response = OpenAIImageResponse.fromJson(json);

      expect(response.created, equals(1234567890));
      expect(response.data.length, equals(1));
      expect(response.data.first.url, equals('https://example.com/image.png'));
      expect(response.data.first.revisedPrompt, equals('A beautiful sunset'));
    });

    test('should handle base64 format', () {
      final json = {
        'created': 1234567890,
        'data': [
          {
            'b64_json':
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          }
        ],
      };

      final response = OpenAIImageResponse.fromJson(json);

      expect(response.data.first.b64Json, isNotNull);
      expect(response.data.first.url, isNull);
    });

    test('should support camelCase in fromJson', () {
      final json = {
        'created': 1234567890,
        'data': [
          {
            'b64Json': 'base64data', // camelCase
            'revisedPrompt': 'Revised prompt', // camelCase
          }
        ],
      };

      final response = OpenAIImageResponse.fromJson(json);
      expect(response.data.first.b64Json, equals('base64data'));
      expect(response.data.first.revisedPrompt, equals('Revised prompt'));
    });
  });

  group('OpenAIImageData', () {
    test('should create instance with URL', () {
      final data = OpenAIImageData(
        url: 'https://example.com/image.png',
        revisedPrompt: 'A beautiful sunset',
      );

      expect(data.url, equals('https://example.com/image.png'));
      expect(data.revisedPrompt, equals('A beautiful sunset'));
      expect(data.b64Json, isNull);
    });

    test('should create instance with base64', () {
      final data = OpenAIImageData(
        b64Json: 'base64data',
      );

      expect(data.b64Json, equals('base64data'));
      expect(data.url, isNull);
    });

    test('should convert to JSON correctly', () {
      final data = OpenAIImageData(
        url: 'https://example.com/image.png',
        revisedPrompt: 'A beautiful sunset',
      );

      final json = data.toJson();

      expect(json['url'], equals('https://example.com/image.png'));
      expect(json['revised_prompt'], equals('A beautiful sunset'));
      expect(json.containsKey('b64_json'), isFalse);
    });

    test('should create from JSON correctly', () {
      final json = {
        'url': 'https://example.com/image.png',
        'revised_prompt': 'A beautiful sunset',
      };

      final data = OpenAIImageData.fromJson(json);

      expect(data.url, equals('https://example.com/image.png'));
      expect(data.revisedPrompt, equals('A beautiful sunset'));
    });

    test('should support equality', () {
      final data1 = OpenAIImageData(
        url: 'https://example.com/image.png',
        revisedPrompt: 'A beautiful sunset',
      );

      final data2 = OpenAIImageData(
        url: 'https://example.com/image.png',
        revisedPrompt: 'A beautiful sunset',
      );

      expect(data1, equals(data2));
      expect(data1.hashCode, equals(data2.hashCode));
    });
  });
}
