import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/models/requests/chat_request.dart';
import 'package:unified_ai_sdk/src/models/requests/embedding_request.dart';
import 'package:unified_ai_sdk/src/providers/openai/openai_mapper.dart';
import 'package:unified_ai_sdk/src/providers/openai/openai_models.dart';

// Use instance for all mapper calls
final _mapper = OpenAIMapper.instance;

void main() {
  group('OpenAIMapper', () {
    group('mapChatRequest', () {
      test('should convert basic ChatRequest to OpenAIChatRequest', () {
        final sdkRequest = ChatRequest(
          messages: [
            Message(role: Role.user, content: 'Hello!'),
          ],
          model: 'gpt-4',
          temperature: 0.7,
          maxTokens: 500,
        );

        final openaiRequest = _mapper.mapChatRequest(sdkRequest);

        expect(openaiRequest.model, equals('gpt-4'));
        expect(openaiRequest.messages.length, equals(1));
        expect(openaiRequest.messages.first['role'], equals('user'));
        expect(openaiRequest.messages.first['content'], equals('Hello!'));
        expect(openaiRequest.temperature, equals(0.7));
        expect(openaiRequest.maxTokens, equals(500));
      });

      test('should convert messages with all roles', () {
        final sdkRequest = ChatRequest(
          messages: [
            Message(role: Role.system, content: 'You are helpful'),
            Message(role: Role.user, content: 'Hello!'),
            Message(role: Role.assistant, content: 'Hi there!'),
            Message(
                role: Role.function,
                content: 'Function result',
                name: 'get_weather'),
          ],
          model: 'gpt-4',
        );

        final openaiRequest = _mapper.mapChatRequest(sdkRequest);

        expect(openaiRequest.messages.length, equals(4));
        expect(openaiRequest.messages[0]['role'], equals('system'));
        expect(openaiRequest.messages[1]['role'], equals('user'));
        expect(openaiRequest.messages[2]['role'], equals('assistant'));
        expect(openaiRequest.messages[3]['role'], equals('function'));
        expect(openaiRequest.messages[3]['name'], equals('get_weather'));
      });

      test('should extract OpenAI-specific fields from providerOptions', () {
        final sdkRequest = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hello')],
          model: 'gpt-4',
          providerOptions: {
            'openai': {
              'presence_penalty': 0.5,
              'frequency_penalty': 0.3,
              'logit_bias': {'123': 10, '456': -5},
              'stream': true,
            },
          },
        );

        final openaiRequest = _mapper.mapChatRequest(sdkRequest);

        expect(openaiRequest.presencePenalty, equals(0.5));
        expect(openaiRequest.frequencyPenalty, equals(0.3));
        expect(openaiRequest.logitBias, equals({'123': 10, '456': -5}));
        expect(openaiRequest.stream, equals(true));
      });

      test('should use defaultModel when request.model is null', () {
        final sdkRequest = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hello')],
        );

        final openaiRequest = _mapper.mapChatRequest(
          sdkRequest,
          defaultModel: 'gpt-3.5-turbo',
        );

        expect(openaiRequest.model, equals('gpt-3.5-turbo'));
      });

      test('should throw error when model is missing', () {
        final sdkRequest = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hello')],
        );

        expect(
          () => _mapper.mapChatRequest(sdkRequest),
          throwsA(isA<ClientError>()),
        );
      });

      test('should include message metadata', () {
        final sdkRequest = ChatRequest(
          messages: [
            Message(
              role: Role.user,
              content: 'Hello',
              meta: {'custom_field': 'value'},
            ),
          ],
          model: 'gpt-4',
        );

        final openaiRequest = _mapper.mapChatRequest(sdkRequest);

        expect(openaiRequest.messages.first['custom_field'], equals('value'));
      });

      test('should handle all common fields', () {
        final sdkRequest = ChatRequest(
          messages: [Message(role: Role.user, content: 'Hello')],
          model: 'gpt-4',
          temperature: 0.7,
          maxTokens: 500,
          topP: 0.9,
          n: 2,
          stop: ['\n\n', 'END'],
          user: 'user-123',
        );

        final openaiRequest = _mapper.mapChatRequest(sdkRequest);

        expect(openaiRequest.temperature, equals(0.7));
        expect(openaiRequest.maxTokens, equals(500));
        expect(openaiRequest.topP, equals(0.9));
        expect(openaiRequest.n, equals(2));
        expect(openaiRequest.stop, equals(['\n\n', 'END']));
        expect(openaiRequest.user, equals('user-123'));
      });
    });

    group('mapChatResponse', () {
      test('should convert basic OpenAIChatResponse to ChatResponse', () {
        final openaiResponse = OpenAIChatResponse(
          id: 'chatcmpl-123',
          object: 'chat.completion',
          created: 1677652288,
          model: 'gpt-4',
          choices: [
            OpenAIChatChoice(
              index: 0,
              message: {
                'role': 'assistant',
                'content': 'Hello! How can I help you?',
              },
              finishReason: 'stop',
            ),
          ],
          usage: OpenAIUsage(
            promptTokens: 10,
            completionTokens: 7,
            totalTokens: 17,
          ),
        );

        final sdkResponse = _mapper.mapChatResponse(openaiResponse);

        expect(sdkResponse.id, equals('chatcmpl-123'));
        expect(sdkResponse.model, equals('gpt-4'));
        expect(sdkResponse.provider, equals('openai'));
        expect(sdkResponse.choices.length, equals(1));
        expect(sdkResponse.choices.first.message.role, equals(Role.assistant));
        expect(sdkResponse.choices.first.message.content,
            equals('Hello! How can I help you?'));
        expect(sdkResponse.choices.first.finishReason, equals('stop'));
        expect(sdkResponse.usage.promptTokens, equals(10));
        expect(sdkResponse.usage.completionTokens, equals(7));
        expect(sdkResponse.usage.totalTokens, equals(17));
      });

      test('should convert timestamp correctly', () {
        final openaiResponse = OpenAIChatResponse(
          id: 'chatcmpl-123',
          object: 'chat.completion',
          created: 1677652288, // Unix timestamp in seconds
          model: 'gpt-4',
          choices: [
            OpenAIChatChoice(
              index: 0,
              message: {'role': 'assistant', 'content': 'Hello'},
            ),
          ],
          usage: OpenAIUsage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
        );

        final sdkResponse = _mapper.mapChatResponse(openaiResponse);

        final expectedTime =
            DateTime.fromMillisecondsSinceEpoch(1677652288 * 1000);
        expect(sdkResponse.timestamp, equals(expectedTime));
      });

      test('should include system fingerprint in metadata', () {
        final openaiResponse = OpenAIChatResponse(
          id: 'chatcmpl-123',
          object: 'chat.completion',
          created: 1677652288,
          model: 'gpt-4',
          choices: [
            OpenAIChatChoice(
              index: 0,
              message: {'role': 'assistant', 'content': 'Hello'},
            ),
          ],
          usage: OpenAIUsage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
          systemFingerprint: 'fp_123',
        );

        final sdkResponse = _mapper.mapChatResponse(openaiResponse);

        expect(sdkResponse.metadata?['system_fingerprint'], equals('fp_123'));
        expect(sdkResponse.metadata?['object'], equals('chat.completion'));
        expect(sdkResponse.metadata?['created'], equals(1677652288));
      });

      test('should convert message with name field', () {
        final openaiResponse = OpenAIChatResponse(
          id: 'chatcmpl-123',
          object: 'chat.completion',
          created: 1677652288,
          model: 'gpt-4',
          choices: [
            OpenAIChatChoice(
              index: 0,
              message: {
                'role': 'function',
                'content': 'Result',
                'name': 'get_weather',
              },
            ),
          ],
          usage: OpenAIUsage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
        );

        final sdkResponse = _mapper.mapChatResponse(openaiResponse);

        expect(sdkResponse.choices.first.message.name, equals('get_weather'));
        expect(sdkResponse.choices.first.message.role, equals(Role.function));
      });

      test('should handle multiple choices', () {
        final openaiResponse = OpenAIChatResponse(
          id: 'chatcmpl-123',
          object: 'chat.completion',
          created: 1677652288,
          model: 'gpt-4',
          choices: [
            OpenAIChatChoice(
              index: 0,
              message: {'role': 'assistant', 'content': 'Choice 1'},
            ),
            OpenAIChatChoice(
              index: 1,
              message: {'role': 'assistant', 'content': 'Choice 2'},
            ),
          ],
          usage: OpenAIUsage(
            promptTokens: 10,
            completionTokens: 10,
            totalTokens: 20,
          ),
        );

        final sdkResponse = _mapper.mapChatResponse(openaiResponse);

        expect(sdkResponse.choices.length, equals(2));
        expect(sdkResponse.choices[0].message.content, equals('Choice 1'));
        expect(sdkResponse.choices[1].message.content, equals('Choice 2'));
      });

      test('should handle tool role', () {
        final openaiResponse = OpenAIChatResponse(
          id: 'chatcmpl-123',
          object: 'chat.completion',
          created: 1677652288,
          model: 'gpt-4',
          choices: [
            OpenAIChatChoice(
              index: 0,
              message: {'role': 'tool', 'content': 'Tool result'},
            ),
          ],
          usage: OpenAIUsage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
        );

        final sdkResponse = _mapper.mapChatResponse(openaiResponse);

        expect(sdkResponse.choices.first.message.role, equals(Role.function));
      });
    });

    group('mapEmbeddingRequest', () {
      test('should convert single input EmbeddingRequest', () {
        final sdkRequest = EmbeddingRequest(
          inputs: ['Hello, world!'],
          model: 'text-embedding-3-small',
        );

        final openaiRequest = _mapper.mapEmbeddingRequest(sdkRequest);

        expect(openaiRequest.model, equals('text-embedding-3-small'));
        expect(openaiRequest.input, equals('Hello, world!'));
      });

      test('should convert multiple inputs EmbeddingRequest', () {
        final sdkRequest = EmbeddingRequest(
          inputs: ['Hello', 'World'],
          model: 'text-embedding-3-small',
        );

        final openaiRequest = _mapper.mapEmbeddingRequest(sdkRequest);

        expect(openaiRequest.model, equals('text-embedding-3-small'));
        expect(openaiRequest.input, isA<List<dynamic>>());
        final inputList = openaiRequest.input as List<dynamic>;
        expect(inputList.length, equals(2));
        expect(inputList[0], equals('Hello'));
        expect(inputList[1], equals('World'));
      });

      test('should extract OpenAI-specific options', () {
        final sdkRequest = EmbeddingRequest(
          inputs: ['Hello'],
          model: 'text-embedding-3-small',
          providerOptions: {
            'openai': {
              'encoding_format': 'float',
              'dimensions': 512,
              'user': 'user-123',
            },
          },
        );

        final openaiRequest = _mapper.mapEmbeddingRequest(sdkRequest);

        expect(openaiRequest.encodingFormat, equals('float'));
        expect(openaiRequest.dimensions, equals(512));
        expect(openaiRequest.user, equals('user-123'));
      });

      test('should use defaultModel when request.model is null', () {
        final sdkRequest = EmbeddingRequest(
          inputs: ['Hello'],
        );

        final openaiRequest = _mapper.mapEmbeddingRequest(
          sdkRequest,
          defaultModel: 'text-embedding-ada-002',
        );

        expect(openaiRequest.model, equals('text-embedding-ada-002'));
      });

      test('should throw error when model is missing', () {
        final sdkRequest = EmbeddingRequest(
          inputs: ['Hello'],
        );

        expect(
          () => _mapper.mapEmbeddingRequest(sdkRequest),
          throwsA(isA<ClientError>()),
        );
      });
    });

    group('mapEmbeddingResponse', () {
      test('should convert basic OpenAIEmbeddingResponse', () {
        final openaiResponse = OpenAIEmbeddingResponse(
          data: [
            OpenAIEmbedding(
              index: 0,
              embedding: [0.1, 0.2, 0.3],
              object: 'embedding',
            ),
          ],
          model: 'text-embedding-3-small',
          usage: OpenAIUsage(
            promptTokens: 5,
            completionTokens: 0,
            totalTokens: 5,
          ),
        );

        final sdkResponse = _mapper.mapEmbeddingResponse(openaiResponse);

        expect(sdkResponse.model, equals('text-embedding-3-small'));
        expect(sdkResponse.provider, equals('openai'));
        expect(sdkResponse.embeddings.length, equals(1));
        expect(sdkResponse.embeddings.first.vector, equals([0.1, 0.2, 0.3]));
        expect(sdkResponse.embeddings.first.dimension, equals(3));
        expect(sdkResponse.embeddings.first.index, equals(0));
        expect(sdkResponse.usage?.promptTokens, equals(5));
        expect(sdkResponse.usage?.totalTokens, equals(5));
      });

      test('should convert multiple embeddings', () {
        final openaiResponse = OpenAIEmbeddingResponse(
          data: [
            OpenAIEmbedding(
              index: 0,
              embedding: [0.1, 0.2],
              object: 'embedding',
            ),
            OpenAIEmbedding(
              index: 1,
              embedding: [0.3, 0.4],
              object: 'embedding',
            ),
          ],
          model: 'text-embedding-3-small',
          usage: OpenAIUsage(
            promptTokens: 10,
            completionTokens: 0,
            totalTokens: 10,
          ),
        );

        final sdkResponse = _mapper.mapEmbeddingResponse(openaiResponse);

        expect(sdkResponse.embeddings.length, equals(2));
        expect(sdkResponse.embeddings[0].vector, equals([0.1, 0.2]));
        expect(sdkResponse.embeddings[1].vector, equals([0.3, 0.4]));
      });

      test('should handle integer values in embedding vector', () {
        final openaiResponse = OpenAIEmbeddingResponse(
          data: [
            OpenAIEmbedding(
              index: 0,
              embedding: [1, 2, 3], // Integers instead of doubles
              object: 'embedding',
            ),
          ],
          model: 'text-embedding-3-small',
          usage: OpenAIUsage(
            promptTokens: 5,
            completionTokens: 0,
            totalTokens: 5,
          ),
        );

        final sdkResponse = _mapper.mapEmbeddingResponse(openaiResponse);

        expect(sdkResponse.embeddings.first.vector, equals([1.0, 2.0, 3.0]));
      });

      test('should throw error for base64 format', () {
        final openaiResponse = OpenAIEmbeddingResponse(
          data: [
            OpenAIEmbedding(
              index: 0,
              embedding: 'base64string', // Base64 format
              object: 'embedding',
            ),
          ],
          model: 'text-embedding-3-small',
          usage: OpenAIUsage(
            promptTokens: 5,
            completionTokens: 0,
            totalTokens: 5,
          ),
        );

        expect(
          () => _mapper.mapEmbeddingResponse(openaiResponse),
          throwsA(isA<ClientError>()),
        );
      });
    });

    group('role mapping', () {
      test('should map all SDK roles to OpenAI roles', () {
        expect(
            _mapper
                .mapChatRequest(
                  ChatRequest(
                    messages: [Message(role: Role.system, content: '')],
                    model: 'gpt-4',
                  ),
                )
                .messages
                .first['role'],
            equals('system'));

        expect(
            _mapper
                .mapChatRequest(
                  ChatRequest(
                    messages: [Message(role: Role.user, content: '')],
                    model: 'gpt-4',
                  ),
                )
                .messages
                .first['role'],
            equals('user'));

        expect(
            _mapper
                .mapChatRequest(
                  ChatRequest(
                    messages: [Message(role: Role.assistant, content: '')],
                    model: 'gpt-4',
                  ),
                )
                .messages
                .first['role'],
            equals('assistant'));

        expect(
            _mapper
                .mapChatRequest(
                  ChatRequest(
                    messages: [Message(role: Role.function, content: '')],
                    model: 'gpt-4',
                  ),
                )
                .messages
                .first['role'],
            equals('function'));
      });

      test('should map OpenAI roles to SDK roles', () {
        final response1 = OpenAIChatResponse(
          id: '1',
          object: 'chat.completion',
          created: 1677652288,
          model: 'gpt-4',
          choices: [
            OpenAIChatChoice(
              index: 0,
              message: {'role': 'system', 'content': ''},
            ),
          ],
          usage:
              OpenAIUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
        );
        expect(_mapper.mapChatResponse(response1).choices.first.message.role,
            equals(Role.system));

        final response2 = OpenAIChatResponse(
          id: '2',
          object: 'chat.completion',
          created: 1677652288,
          model: 'gpt-4',
          choices: [
            OpenAIChatChoice(
              index: 0,
              message: {'role': 'tool', 'content': ''},
            ),
          ],
          usage:
              OpenAIUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
        );
        expect(_mapper.mapChatResponse(response2).choices.first.message.role,
            equals(Role.function));
      });
    });
  });
}
