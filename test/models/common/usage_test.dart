import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/common/usage.dart';

void main() {
  group('Usage', () {
    group('Construction', () {
      test('should create usage with all required fields', () {
        const usage = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );

        expect(usage.promptTokens, equals(50));
        expect(usage.completionTokens, equals(100));
        expect(usage.totalTokens, equals(150));
      });

      test('should be immutable (const constructor)', () {
        const usage1 = Usage(
          promptTokens: 10,
          completionTokens: 20,
          totalTokens: 30,
        );
        const usage2 = Usage(
          promptTokens: 10,
          completionTokens: 20,
          totalTokens: 30,
        );

        expect(usage1, equals(usage2));
        expect(usage1.hashCode, equals(usage2.hashCode));
      });

      test(
          'should allow totalTokens to differ from sum of prompt and completion',
          () {
        // Some providers may report slightly different totals due to overhead
        const usage = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 151, // Slightly different due to provider overhead
        );

        expect(usage.promptTokens, equals(50));
        expect(usage.completionTokens, equals(100));
        expect(usage.totalTokens, equals(151));
      });
    });

    group('toJson()', () {
      test('should serialize usage to JSON with snake_case keys', () {
        const usage = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );

        final json = usage.toJson();

        expect(json, isA<Map<String, dynamic>>());
        expect(json['prompt_tokens'], equals(50));
        expect(json['completion_tokens'], equals(100));
        expect(json['total_tokens'], equals(150));
      });

      test('should serialize zero tokens correctly', () {
        const usage = Usage(
          promptTokens: 0,
          completionTokens: 0,
          totalTokens: 0,
        );

        final json = usage.toJson();

        expect(json['prompt_tokens'], equals(0));
        expect(json['completion_tokens'], equals(0));
        expect(json['total_tokens'], equals(0));
      });

      test('should serialize large token counts correctly', () {
        const usage = Usage(
          promptTokens: 1000000,
          completionTokens: 2000000,
          totalTokens: 3000000,
        );

        final json = usage.toJson();

        expect(json['prompt_tokens'], equals(1000000));
        expect(json['completion_tokens'], equals(2000000));
        expect(json['total_tokens'], equals(3000000));
      });

      test('should produce valid JSON structure', () {
        const usage = Usage(
          promptTokens: 42,
          completionTokens: 84,
          totalTokens: 126,
        );

        final json = usage.toJson();

        expect(json.keys.length, equals(3));
        expect(
            json.keys,
            containsAll(
                ['prompt_tokens', 'completion_tokens', 'total_tokens']));
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with snake_case keys', () {
        final json = {
          'prompt_tokens': 50,
          'completion_tokens': 100,
          'total_tokens': 150,
        };

        final usage = Usage.fromJson(json);

        expect(usage.promptTokens, equals(50));
        expect(usage.completionTokens, equals(100));
        expect(usage.totalTokens, equals(150));
      });

      test('should deserialize JSON with camelCase keys', () {
        final json = {
          'promptTokens': 50,
          'completionTokens': 100,
          'totalTokens': 150,
        };

        final usage = Usage.fromJson(json);

        expect(usage.promptTokens, equals(50));
        expect(usage.completionTokens, equals(100));
        expect(usage.totalTokens, equals(150));
      });

      test('should deserialize zero tokens correctly', () {
        final json = {
          'prompt_tokens': 0,
          'completion_tokens': 0,
          'total_tokens': 0,
        };

        final usage = Usage.fromJson(json);

        expect(usage.promptTokens, equals(0));
        expect(usage.completionTokens, equals(0));
        expect(usage.totalTokens, equals(0));
      });

      test('should throw FormatException for missing prompt_tokens', () {
        final json = {
          'completion_tokens': 100,
          'total_tokens': 150,
          // Missing prompt_tokens
        };

        expect(
          () => Usage.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException for missing completion_tokens', () {
        final json = {
          'prompt_tokens': 50,
          'total_tokens': 150,
          // Missing completion_tokens
        };

        expect(
          () => Usage.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException for missing total_tokens', () {
        final json = {
          'prompt_tokens': 50,
          'completion_tokens': 100,
          // Missing total_tokens
        };

        expect(
          () => Usage.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw TypeError for wrong types', () {
        final json = {
          'prompt_tokens': '50', // Should be int
          'completion_tokens': 100,
          'total_tokens': 150,
        };

        expect(
          () => Usage.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('Round-trip serialization', () {
      test('toJson and fromJson should be inverse operations', () {
        const original = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );

        final json = original.toJson();
        final restored = Usage.fromJson(json);

        expect(restored.promptTokens, equals(original.promptTokens));
        expect(restored.completionTokens, equals(original.completionTokens));
        expect(restored.totalTokens, equals(original.totalTokens));
        expect(restored, equals(original));
      });

      test('should handle round-trip with zero values', () {
        const original = Usage(
          promptTokens: 0,
          completionTokens: 0,
          totalTokens: 0,
        );

        final json = original.toJson();
        final restored = Usage.fromJson(json);

        expect(restored, equals(original));
      });

      test('should handle round-trip with large values', () {
        const original = Usage(
          promptTokens: 1000000,
          completionTokens: 2000000,
          totalTokens: 3000000,
        );

        final json = original.toJson();
        final restored = Usage.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('copyWith()', () {
      test('should create copy with modified promptTokens', () {
        const original = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );

        final copy = original.copyWith(promptTokens: 60);

        expect(copy.promptTokens, equals(60));
        expect(copy.completionTokens, equals(original.completionTokens));
        expect(copy.totalTokens, equals(original.totalTokens));
      });

      test('should create copy with modified completionTokens', () {
        const original = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );

        final copy = original.copyWith(completionTokens: 110);

        expect(copy.completionTokens, equals(110));
        expect(copy.promptTokens, equals(original.promptTokens));
        expect(copy.totalTokens, equals(original.totalTokens));
      });

      test('should create copy with modified totalTokens', () {
        const original = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );

        final copy = original.copyWith(totalTokens: 160);

        expect(copy.totalTokens, equals(160));
        expect(copy.promptTokens, equals(original.promptTokens));
        expect(copy.completionTokens, equals(original.completionTokens));
      });

      test('should create copy with multiple modified fields', () {
        const original = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );

        final copy = original.copyWith(
          promptTokens: 60,
          completionTokens: 110,
          totalTokens: 170,
        );

        expect(copy.promptTokens, equals(60));
        expect(copy.completionTokens, equals(110));
        expect(copy.totalTokens, equals(170));
      });
    });

    group('Addition operator', () {
      test('should add two Usage objects correctly', () {
        const usage1 = Usage(
          promptTokens: 10,
          completionTokens: 20,
          totalTokens: 30,
        );
        const usage2 = Usage(
          promptTokens: 15,
          completionTokens: 25,
          totalTokens: 40,
        );

        final combined = usage1 + usage2;

        expect(combined.promptTokens, equals(25));
        expect(combined.completionTokens, equals(45));
        expect(combined.totalTokens, equals(70));
      });

      test('should handle addition with zero values', () {
        const usage1 = Usage(
          promptTokens: 10,
          completionTokens: 20,
          totalTokens: 30,
        );
        const usage2 = Usage(
          promptTokens: 0,
          completionTokens: 0,
          totalTokens: 0,
        );

        final combined = usage1 + usage2;

        expect(combined, equals(usage1));
      });

      test('should be commutative', () {
        const usage1 = Usage(
          promptTokens: 10,
          completionTokens: 20,
          totalTokens: 30,
        );
        const usage2 = Usage(
          promptTokens: 15,
          completionTokens: 25,
          totalTokens: 40,
        );

        expect(usage1 + usage2, equals(usage2 + usage1));
      });
    });

    group('Equality and hashCode', () {
      test('should be equal when all fields match', () {
        const usage1 = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );
        const usage2 = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );

        expect(usage1, equals(usage2));
        expect(usage1.hashCode, equals(usage2.hashCode));
      });

      test('should not be equal when promptTokens differs', () {
        const usage1 = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );
        const usage2 = Usage(
          promptTokens: 60,
          completionTokens: 100,
          totalTokens: 150,
        );

        expect(usage1, isNot(equals(usage2)));
      });

      test('should not be equal when completionTokens differs', () {
        const usage1 = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );
        const usage2 = Usage(
          promptTokens: 50,
          completionTokens: 110,
          totalTokens: 150,
        );

        expect(usage1, isNot(equals(usage2)));
      });

      test('should not be equal when totalTokens differs', () {
        const usage1 = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );
        const usage2 = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 160,
        );

        expect(usage1, isNot(equals(usage2)));
      });
    });

    group('toString()', () {
      test('should return readable string representation', () {
        const usage = Usage(
          promptTokens: 50,
          completionTokens: 100,
          totalTokens: 150,
        );

        final str = usage.toString();

        expect(str, contains('Usage'));
        expect(str, contains('50'));
        expect(str, contains('100'));
        expect(str, contains('150'));
      });

      test('should include all token counts', () {
        const usage = Usage(
          promptTokens: 42,
          completionTokens: 84,
          totalTokens: 126,
        );

        final str = usage.toString();

        expect(str, contains('promptTokens: 42'));
        expect(str, contains('completionTokens: 84'));
        expect(str, contains('totalTokens: 126'));
      });
    });
  });
}
