import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/responses/embedding_response.dart';
import 'package:unified_ai_sdk/src/models/common/usage.dart';

void main() {
  group('EmbeddingData', () {
    group('Construction', () {
      test('should create embedding data with required fields', () {
        final embedding = EmbeddingData(
          vector: [0.1, 0.2, 0.3],
          dimension: 3,
        );

        expect(embedding.vector, equals([0.1, 0.2, 0.3]));
        expect(embedding.dimension, equals(3));
        expect(embedding.index, isNull);
      });

      test('should create embedding data with all fields', () {
        final embedding = EmbeddingData(
          vector: [0.1, 0.2, 0.3, 0.4],
          dimension: 4,
          index: 0,
        );

        expect(embedding.vector.length, equals(4));
        expect(embedding.dimension, equals(4));
        expect(embedding.index, equals(0));
      });

      test('should throw assertion error if vector length != dimension', () {
        expect(
          () => EmbeddingData(
            vector: [0.1, 0.2, 0.3],
            dimension: 4,
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('toJson()', () {
      test('should serialize embedding data to JSON', () {
        final embedding = EmbeddingData(
          vector: [0.1, 0.2, 0.3],
          dimension: 3,
          index: 0,
        );

        final json = embedding.toJson();

        expect(json['vector'], equals([0.1, 0.2, 0.3]));
        expect(json['dimension'], equals(3));
        expect(json['index'], equals(0));
      });

      test('should serialize without index if null', () {
        final embedding = EmbeddingData(
          vector: [0.1, 0.2],
          dimension: 2,
        );

        final json = embedding.toJson();

        expect(json.containsKey('index'), isFalse);
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with all fields', () {
        final json = {
          'vector': [0.1, 0.2, 0.3],
          'dimension': 3,
          'index': 0,
        };

        final embedding = EmbeddingData.fromJson(json);

        expect(embedding.vector, equals([0.1, 0.2, 0.3]));
        expect(embedding.dimension, equals(3));
        expect(embedding.index, equals(0));
      });

      test('should deserialize JSON without index', () {
        final json = {
          'vector': [0.1, 0.2],
          'dimension': 2,
        };

        final embedding = EmbeddingData.fromJson(json);

        expect(embedding.index, isNull);
      });

      test('should handle integer values in vector', () {
        final json = {
          'vector': [1, 2, 3],
          'dimension': 3,
        };

        final embedding = EmbeddingData.fromJson(json);

        expect(embedding.vector, equals([1.0, 2.0, 3.0]));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final embedding1 = EmbeddingData(
          vector: [0.1, 0.2, 0.3],
          dimension: 3,
          index: 0,
        );
        final embedding2 = EmbeddingData(
          vector: [0.1, 0.2, 0.3],
          dimension: 3,
          index: 0,
        );

        expect(embedding1, equals(embedding2));
        expect(embedding1.hashCode, equals(embedding2.hashCode));
      });

      test('should not be equal with different vectors', () {
        final embedding1 = EmbeddingData(
          vector: [0.1, 0.2, 0.3],
          dimension: 3,
        );
        final embedding2 = EmbeddingData(
          vector: [0.1, 0.2, 0.4],
          dimension: 3,
        );

        expect(embedding1, isNot(equals(embedding2)));
      });
    });
  });

  group('EmbeddingResponse', () {
    group('Construction', () {
      test('should create response with required fields', () {
        final response = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1, 0.2], dimension: 2),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
        );

        expect(response.embeddings.length, equals(1));
        expect(response.model, equals('text-embedding-3-small'));
        expect(response.provider, equals('openai'));
        expect(response.usage, isNull);
        expect(response.metadata, isNull);
      });

      test('should create response with all fields', () {
        final usage = const Usage(
          promptTokens: 10,
          completionTokens: 0,
          totalTokens: 10,
        );
        final response = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1, 0.2], dimension: 2, index: 0),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
          usage: usage,
          metadata: {'request_id': '123'},
        );

        expect(response.usage, equals(usage));
        expect(response.metadata, equals({'request_id': '123'}));
      });

      test('should default timestamp to current time', () {
        final before = DateTime.now();
        final response = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1], dimension: 1),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
        );
        final after = DateTime.now();

        expect(
            response.timestamp.isAfter(before) ||
                response.timestamp.isAtSameMomentAs(before),
            isTrue);
        expect(
            response.timestamp.isBefore(after) ||
                response.timestamp.isAtSameMomentAs(after),
            isTrue);
      });

      test('should throw assertion error if embeddings is empty', () {
        expect(
          () => EmbeddingResponse(
            embeddings: [],
            model: 'text-embedding-3-small',
            provider: 'openai',
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('Convenience getters', () {
      test('should return vectors list', () {
        final response = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1, 0.2], dimension: 2),
            EmbeddingData(vector: [0.3, 0.4], dimension: 2),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
        );

        expect(
            response.vectors,
            equals([
              [0.1, 0.2],
              [0.3, 0.4],
            ]));
      });

      test('should return dimensions list', () {
        final response = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1, 0.2], dimension: 2),
            EmbeddingData(vector: [0.3, 0.4, 0.5], dimension: 3),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
        );

        expect(response.dimensions, equals([2, 3]));
      });
    });

    group('toJson()', () {
      test('should serialize response to JSON', () {
        final usage = const Usage(
          promptTokens: 10,
          completionTokens: 0,
          totalTokens: 10,
        );
        final response = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1, 0.2], dimension: 2, index: 0),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
          usage: usage,
          metadata: {'test': 'value'},
        );

        final json = response.toJson();

        expect(json['embeddings'], isA<List<dynamic>>());
        expect(json['embeddings'].length, equals(1));
        expect(json['model'], equals('text-embedding-3-small'));
        expect(json['provider'], equals('openai'));
        expect(json['usage'], isA<Map<String, dynamic>>());
        expect(json['metadata'], equals({'test': 'value'}));
        expect(json['timestamp'], isA<String>());
      });

      test('should serialize without optional fields', () {
        final response = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1], dimension: 1),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
        );

        final json = response.toJson();

        expect(json.containsKey('usage'), isFalse);
        expect(json.containsKey('metadata'), isFalse);
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with new format (embeddings array)', () {
        final json = {
          'embeddings': [
            {
              'vector': [0.1, 0.2, 0.3],
              'dimension': 3,
              'index': 0,
            },
          ],
          'model': 'text-embedding-3-small',
          'provider': 'openai',
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 0,
            'total_tokens': 10,
          },
        };

        final response = EmbeddingResponse.fromJson(json);

        expect(response.embeddings.length, equals(1));
        expect(response.embeddings.first.vector, equals([0.1, 0.2, 0.3]));
        expect(response.model, equals('text-embedding-3-small'));
        expect(response.provider, equals('openai'));
        expect(response.usage, isNotNull);
      });

      test('should deserialize JSON with legacy format (vectors/dimensions)',
          () {
        final json = {
          'vectors': [
            [0.1, 0.2, 0.3],
            [0.4, 0.5, 0.6],
          ],
          'dimensions': [3, 3],
          'model': 'text-embedding-3-small',
          'provider': 'openai',
        };

        final response = EmbeddingResponse.fromJson(json);

        expect(response.embeddings.length, equals(2));
        expect(response.embeddings[0].vector, equals([0.1, 0.2, 0.3]));
        expect(response.embeddings[1].vector, equals([0.4, 0.5, 0.6]));
        expect(response.embeddings[0].index, equals(0));
        expect(response.embeddings[1].index, equals(1));
      });

      test(
          'should throw FormatException if vectors and dimensions length mismatch',
          () {
        final json = {
          'vectors': [
            [0.1, 0.2],
          ],
          'dimensions': [2, 3], // Mismatch
          'model': 'text-embedding-3-small',
          'provider': 'openai',
        };

        expect(
          () => EmbeddingResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if neither format is present', () {
        final json = {
          'model': 'text-embedding-3-small',
          'provider': 'openai',
        };

        expect(
          () => EmbeddingResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should handle missing optional fields', () {
        final json = {
          'embeddings': [
            {
              'vector': [0.1, 0.2],
              'dimension': 2,
            },
          ],
          'model': 'text-embedding-3-small',
          'provider': 'openai',
        };

        final response = EmbeddingResponse.fromJson(json);

        expect(response.usage, isNull);
        expect(response.metadata, isNull);
      });

      test('should parse timestamp if provided', () {
        final timestamp = DateTime.now().toIso8601String();
        final json = {
          'embeddings': [
            {
              'vector': [0.1],
              'dimension': 1,
            },
          ],
          'model': 'text-embedding-3-small',
          'provider': 'openai',
          'timestamp': timestamp,
        };

        final response = EmbeddingResponse.fromJson(json);

        expect(response.timestamp.toIso8601String(), equals(timestamp));
      });
    });

    group('copyWith()', () {
      test('should create copy with updated embeddings', () {
        final original = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1], dimension: 1),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
        );

        final copy = original.copyWith(
          embeddings: [
            EmbeddingData(vector: [0.2], dimension: 1),
          ],
        );

        expect(copy.embeddings.first.vector, equals([0.2]));
        expect(copy.model, equals('text-embedding-3-small'));
      });

      test('should create copy with updated model', () {
        final original = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1], dimension: 1),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
        );

        final copy = original.copyWith(model: 'text-embedding-ada-002');

        expect(copy.model, equals('text-embedding-ada-002'));
        expect(copy.provider, equals('openai'));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final timestamp = DateTime.now();
        final response1 = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1, 0.2], dimension: 2),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
          timestamp: timestamp,
        );
        final response2 = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1, 0.2], dimension: 2),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
          timestamp: timestamp,
        );

        expect(response1, equals(response2));
        expect(response1.hashCode, equals(response2.hashCode));
      });

      test('should not be equal with different embeddings', () {
        final response1 = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1], dimension: 1),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
        );
        final response2 = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.2], dimension: 1),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
        );

        expect(response1, isNot(equals(response2)));
      });
    });

    group('Round-trip serialization', () {
      test('should serialize and deserialize correctly', () {
        final usage = const Usage(
          promptTokens: 10,
          completionTokens: 0,
          totalTokens: 10,
        );
        final original = EmbeddingResponse(
          embeddings: [
            EmbeddingData(vector: [0.1, 0.2, 0.3], dimension: 3, index: 0),
            EmbeddingData(vector: [0.4, 0.5, 0.6], dimension: 3, index: 1),
          ],
          model: 'text-embedding-3-small',
          provider: 'openai',
          usage: usage,
          metadata: {'test': 'value'},
        );

        final json = original.toJson();
        final restored = EmbeddingResponse.fromJson(json);

        expect(restored.embeddings.length, equals(original.embeddings.length));
        expect(restored.model, equals(original.model));
        expect(restored.provider, equals(original.provider));
        expect(restored.usage, equals(original.usage));
        expect(restored.metadata, equals(original.metadata));
      });
    });
  });
}
