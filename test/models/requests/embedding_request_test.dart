import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/requests/embedding_request.dart';

void main() {
  group('EmbeddingRequest', () {
    group('Construction', () {
      test('should create request with required fields', () {
        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
        );

        expect(request.inputs, equals(['Hello, world!']));
        expect(request.model, isNull);
        expect(request.providerOptions, isNull);
      });

      test('should create request with all fields', () {
        final request = EmbeddingRequest(
          inputs: ['Hello', 'World'],
          model: 'text-embedding-3-small',
          providerOptions: {
            'openai': {'encoding_format': 'float'},
          },
        );

        expect(request.inputs, equals(['Hello', 'World']));
        expect(request.model, equals('text-embedding-3-small'));
        expect(
            request.providerOptions,
            equals({
              'openai': {'encoding_format': 'float'},
            }));
      });

      test('should create request with multiple inputs', () {
        final request = EmbeddingRequest(
          inputs: ['Text 1', 'Text 2', 'Text 3'],
        );

        expect(request.inputs.length, equals(3));
        expect(request.inputs[0], equals('Text 1'));
        expect(request.inputs[1], equals('Text 2'));
        expect(request.inputs[2], equals('Text 3'));
      });

      test('should throw assertion error if inputs is empty', () {
        expect(
          () => EmbeddingRequest(inputs: []),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('toJson()', () {
      test('should serialize request to JSON with only required fields', () {
        final request = EmbeddingRequest(
          inputs: ['Hello, world!'],
        );

        final json = request.toJson();

        expect(json, isA<Map<String, dynamic>>());
        expect(json['inputs'], equals(['Hello, world!']));
        expect(json.containsKey('model'), isFalse);
        expect(json.containsKey('provider_options'), isFalse);
      });

      test('should serialize request with all fields', () {
        final request = EmbeddingRequest(
          inputs: ['Hello', 'World'],
          model: 'text-embedding-3-small',
          providerOptions: {
            'openai': {'encoding_format': 'float'},
            'cohere': {'input_type': 'search_document'},
          },
        );

        final json = request.toJson();

        expect(json['inputs'], equals(['Hello', 'World']));
        expect(json['model'], equals('text-embedding-3-small'));
        expect(
            json['provider_options'],
            equals({
              'openai': {'encoding_format': 'float'},
              'cohere': {'input_type': 'search_document'},
            }));
      });

      test('should serialize empty model as null (not included)', () {
        final request = EmbeddingRequest(
          inputs: ['Test'],
          model: null,
        );

        final json = request.toJson();

        expect(json.containsKey('model'), isFalse);
      });

      test('should produce valid JSON structure', () {
        final request = EmbeddingRequest(
          inputs: ['Sample text'],
          model: 'text-embedding-ada-002',
        );

        final json = request.toJson();

        expect(json, isA<Map<String, dynamic>>());
        expect(json['inputs'], isA<List>());
        expect(json['model'], isA<String>());
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with only required fields', () {
        final json = {
          'inputs': ['Hello, world!'],
        };

        final request = EmbeddingRequest.fromJson(json);

        expect(request.inputs, equals(['Hello, world!']));
        expect(request.model, isNull);
        expect(request.providerOptions, isNull);
      });

      test('should deserialize JSON with all fields', () {
        final json = {
          'inputs': ['Hello', 'World'],
          'model': 'text-embedding-3-small',
          'provider_options': {
            'openai': {'encoding_format': 'float'},
          },
        };

        final request = EmbeddingRequest.fromJson(json);

        expect(request.inputs, equals(['Hello', 'World']));
        expect(request.model, equals('text-embedding-3-small'));
        expect(
            request.providerOptions,
            equals({
              'openai': {'encoding_format': 'float'},
            }));
      });

      test('should throw FormatException if inputs is missing', () {
        final json = <String, dynamic>{};

        expect(
          () => EmbeddingRequest.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if inputs is not a List', () {
        final json = {
          'inputs': 'not a list',
        };

        expect(
          () => EmbeddingRequest.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if inputs is empty', () {
        final json = {
          'inputs': <String>[],
        };

        expect(
          () => EmbeddingRequest.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should handle inputs with various string types', () {
        final json = {
          'inputs': ['Text 1', 'Text 2', 123, true], // Mixed types
        };

        final request = EmbeddingRequest.fromJson(json);

        expect(request.inputs.length, equals(4));
        expect(request.inputs[0], equals('Text 1'));
        expect(request.inputs[1], equals('Text 2'));
        expect(request.inputs[2], equals('123'));
        expect(request.inputs[3], equals('true'));
      });
    });

    group('copyWith()', () {
      test('should create copy with updated inputs', () {
        final original = EmbeddingRequest(
          inputs: ['Original'],
          model: 'text-embedding-3-small',
        );

        final copy = original.copyWith(inputs: ['Updated']);

        expect(copy.inputs, equals(['Updated']));
        expect(copy.model, equals('text-embedding-3-small'));
      });

      test('should create copy with updated model', () {
        final original = EmbeddingRequest(
          inputs: ['Text'],
          model: 'text-embedding-3-small',
        );

        final copy = original.copyWith(model: 'text-embedding-ada-002');

        expect(copy.inputs, equals(['Text']));
        expect(copy.model, equals('text-embedding-ada-002'));
      });

      test('should create copy with updated providerOptions', () {
        final original = EmbeddingRequest(
          inputs: ['Text'],
        );

        final copy = original.copyWith(
          providerOptions: {
            'openai': {'test': 'value'}
          },
        );

        expect(
            copy.providerOptions,
            equals({
              'openai': {'test': 'value'}
            }));
      });

      test('should create copy with null model', () {
        final original = EmbeddingRequest(
          inputs: ['Text'],
          model: 'text-embedding-3-small',
        );

        // Note: copyWith doesn't support setting to null directly,
        // but we can test that copyWith() preserves the original
        final copy = original.copyWith();

        expect(copy.model, equals(original.model));
      });

      test('should create copy that is equal but not identical', () {
        final original = EmbeddingRequest(
          inputs: ['Text'],
          model: 'text-embedding-3-small',
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy, isNot(same(original)));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final request1 = EmbeddingRequest(
          inputs: ['Hello'],
          model: 'text-embedding-3-small',
        );
        final request2 = EmbeddingRequest(
          inputs: ['Hello'],
          model: 'text-embedding-3-small',
        );

        expect(request1, equals(request2));
        expect(request1.hashCode, equals(request2.hashCode));
      });

      test('should not be equal with different inputs', () {
        final request1 = EmbeddingRequest(
          inputs: ['Hello'],
        );
        final request2 = EmbeddingRequest(
          inputs: ['World'],
        );

        expect(request1, isNot(equals(request2)));
      });

      test('should not be equal with different models', () {
        final request1 = EmbeddingRequest(
          inputs: ['Hello'],
          model: 'text-embedding-3-small',
        );
        final request2 = EmbeddingRequest(
          inputs: ['Hello'],
          model: 'text-embedding-ada-002',
        );

        expect(request1, isNot(equals(request2)));
      });

      test('should not be equal with different providerOptions', () {
        final request1 = EmbeddingRequest(
          inputs: ['Hello'],
          providerOptions: {
            'openai': {'a': 1}
          },
        );
        final request2 = EmbeddingRequest(
          inputs: ['Hello'],
          providerOptions: {
            'openai': {'a': 2}
          },
        );

        expect(request1, isNot(equals(request2)));
      });

      test('should handle null providerOptions correctly', () {
        final request1 = EmbeddingRequest(
          inputs: ['Hello'],
        );
        final request2 = EmbeddingRequest(
          inputs: ['Hello'],
          providerOptions: null,
        );

        expect(request1, equals(request2));
      });
    });

    group('toString()', () {
      test('should return string representation', () {
        final request = EmbeddingRequest(
          inputs: ['Hello', 'World'],
          model: 'text-embedding-3-small',
        );

        final str = request.toString();

        expect(str, contains('EmbeddingRequest'));
        expect(str, contains('2 item(s)'));
        expect(str, contains('text-embedding-3-small'));
      });

      test('should handle request without model', () {
        final request = EmbeddingRequest(
          inputs: ['Hello'],
        );

        final str = request.toString();

        expect(str, contains('EmbeddingRequest'));
        expect(str, isNot(contains('model')));
      });
    });

    group('Round-trip serialization', () {
      test('should serialize and deserialize correctly', () {
        final original = EmbeddingRequest(
          inputs: ['Hello', 'World'],
          model: 'text-embedding-3-small',
          providerOptions: {
            'openai': {'encoding_format': 'float'},
          },
        );

        final json = original.toJson();
        final restored = EmbeddingRequest.fromJson(json);

        expect(restored, equals(original));
      });

      test('should handle empty providerOptions', () {
        final original = EmbeddingRequest(
          inputs: ['Text'],
          model: 'text-embedding-3-small',
        );

        final json = original.toJson();
        final restored = EmbeddingRequest.fromJson(json);

        expect(restored, equals(original));
      });
    });
  });
}
