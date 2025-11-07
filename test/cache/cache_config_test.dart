import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/cache/cache_config.dart';
import 'package:unified_ai_sdk/src/core/constants.dart';

void main() {
  group('CacheBackendType', () {
    test('should have all expected values', () {
      expect(CacheBackendType.values.length, equals(4));
      expect(CacheBackendType.values, contains(CacheBackendType.none));
      expect(CacheBackendType.values, contains(CacheBackendType.memory));
      expect(CacheBackendType.values, contains(CacheBackendType.objectbox));
      expect(CacheBackendType.values, contains(CacheBackendType.custom));
    });
  });

  group('CacheConfig', () {
    group('construction', () {
      test('should create instance with all fields', () {
        final config = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
          maxSizeMB: 100,
        );

        expect(config.backend, equals(CacheBackendType.memory));
        expect(config.defaultTTL, equals(Duration(hours: 1)));
        expect(config.maxSizeMB, equals(100));
      });

      test('should use default maxSizeMB when not provided', () {
        final config = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
        );

        expect(config.maxSizeMB, equals(100));
      });

      test('should allow zero maxSizeMB', () {
        final config = CacheConfig(
          backend: CacheBackendType.none,
          defaultTTL: Duration.zero,
          maxSizeMB: 0,
        );

        expect(config.maxSizeMB, equals(0));
      });

      test('should work with all backend types', () {
        for (final backend in CacheBackendType.values) {
          final config = CacheConfig(
            backend: backend,
            defaultTTL: Duration(hours: 1),
          );

          expect(config.backend, equals(backend));
        }
      });

      test('should work with various TTL durations', () {
        final testCases = [
          Duration.zero,
          Duration(minutes: 30),
          Duration(hours: 1),
          Duration(hours: 24),
          Duration(days: 7),
        ];

        for (final ttl in testCases) {
          final config = CacheConfig(
            backend: CacheBackendType.memory,
            defaultTTL: ttl,
          );

          expect(config.defaultTTL, equals(ttl));
        }
      });
    });

    group('defaults', () {
      test('should create default config with memory backend', () {
        final config = CacheConfig.defaults();

        expect(config.backend, equals(CacheBackendType.memory));
      });

      test('should create default config with defaultCacheTTL', () {
        final config = CacheConfig.defaults();

        expect(config.defaultTTL, equals(defaultCacheTTL));
      });

      test('should create default config with 100MB max size', () {
        final config = CacheConfig.defaults();

        expect(config.maxSizeMB, equals(100));
      });

      test('should return consistent defaults', () {
        final config1 = CacheConfig.defaults();
        final config2 = CacheConfig.defaults();

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });
    });

    group('copyWith', () {
      test('should create copy with same values when no changes', () {
        final original = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
          maxSizeMB: 100,
        );

        final copy = original.copyWith();

        expect(copy.backend, equals(original.backend));
        expect(copy.defaultTTL, equals(original.defaultTTL));
        expect(copy.maxSizeMB, equals(original.maxSizeMB));
        expect(copy, equals(original));
      });

      test('should create copy with updated backend', () {
        final original = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
        );

        final copy = original.copyWith(backend: CacheBackendType.objectbox);

        expect(copy.backend, equals(CacheBackendType.objectbox));
        expect(copy.defaultTTL, equals(original.defaultTTL));
        expect(copy.maxSizeMB, equals(original.maxSizeMB));
        expect(copy, isNot(equals(original)));
      });

      test('should create copy with updated defaultTTL', () {
        final original = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
        );

        final newTTL = Duration(hours: 24);
        final copy = original.copyWith(defaultTTL: newTTL);

        expect(copy.backend, equals(original.backend));
        expect(copy.defaultTTL, equals(newTTL));
        expect(copy.maxSizeMB, equals(original.maxSizeMB));
        expect(copy, isNot(equals(original)));
      });

      test('should create copy with updated maxSizeMB', () {
        final original = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
          maxSizeMB: 100,
        );

        final copy = original.copyWith(maxSizeMB: 500);

        expect(copy.backend, equals(original.backend));
        expect(copy.defaultTTL, equals(original.defaultTTL));
        expect(copy.maxSizeMB, equals(500));
        expect(copy, isNot(equals(original)));
      });

      test('should allow updating multiple fields', () {
        final original = CacheConfig.defaults();

        final copy = original.copyWith(
          backend: CacheBackendType.objectbox,
          defaultTTL: Duration(hours: 24),
          maxSizeMB: 500,
        );

        expect(copy.backend, equals(CacheBackendType.objectbox));
        expect(copy.defaultTTL, equals(Duration(hours: 24)));
        expect(copy.maxSizeMB, equals(500));
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        final config1 = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
          maxSizeMB: 100,
        );
        final config2 = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
          maxSizeMB: 100,
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('should not be equal when backend differs', () {
        final config1 = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
        );
        final config2 = CacheConfig(
          backend: CacheBackendType.objectbox,
          defaultTTL: Duration(hours: 1),
        );

        expect(config1, isNot(equals(config2)));
      });

      test('should not be equal when defaultTTL differs', () {
        final config1 = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
        );
        final config2 = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 2),
        );

        expect(config1, isNot(equals(config2)));
      });

      test('should not be equal when maxSizeMB differs', () {
        final config1 = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
          maxSizeMB: 100,
        );
        final config2 = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
          maxSizeMB: 200,
        );

        expect(config1, isNot(equals(config2)));
      });
    });

    group('toString', () {
      test('should include backend in toString', () {
        final config = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
        );

        final str = config.toString();
        expect(str, contains('memory'));
      });

      test('should format TTL with hours and minutes', () {
        final config = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 2, minutes: 30),
        );

        final str = config.toString();
        expect(str, contains('2h'));
        expect(str, contains('30m'));
      });

      test('should format TTL with only hours when minutes are zero', () {
        final config = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 3),
        );

        final str = config.toString();
        expect(str, contains('3h'));
        expect(str, isNot(contains('0m')));
      });

      test('should format TTL with only minutes when less than an hour', () {
        final config = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(minutes: 45),
        );

        final str = config.toString();
        expect(str, contains('45m'));
        // Check that TTL part doesn't contain 'h' (hours)
        final ttlPart = str.substring(str.indexOf('defaultTTL:'));
        expect(ttlPart, isNot(contains('h')));
      });

      test('should include maxSizeMB in toString', () {
        final config = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(hours: 1),
          maxSizeMB: 200,
        );

        final str = config.toString();
        expect(str, contains('200'));
      });
    });

    group('use cases', () {
      test('should support no-cache configuration', () {
        final config = CacheConfig(
          backend: CacheBackendType.none,
          defaultTTL: Duration.zero,
          maxSizeMB: 0,
        );

        expect(config.backend, equals(CacheBackendType.none));
        expect(config.defaultTTL, equals(Duration.zero));
        expect(config.maxSizeMB, equals(0));
      });

      test('should support memory cache configuration', () {
        final config = CacheConfig(
          backend: CacheBackendType.memory,
          defaultTTL: Duration(minutes: 30),
          maxSizeMB: 50,
        );

        expect(config.backend, equals(CacheBackendType.memory));
        expect(config.defaultTTL, equals(Duration(minutes: 30)));
        expect(config.maxSizeMB, equals(50));
      });

      test('should support persistent cache configuration', () {
        final config = CacheConfig(
          backend: CacheBackendType.objectbox,
          defaultTTL: Duration(hours: 24),
          maxSizeMB: 500,
        );

        expect(config.backend, equals(CacheBackendType.objectbox));
        expect(config.defaultTTL, equals(Duration(hours: 24)));
        expect(config.maxSizeMB, equals(500));
      });

      test('should support custom cache configuration', () {
        final config = CacheConfig(
          backend: CacheBackendType.custom,
          defaultTTL: Duration(hours: 12),
          maxSizeMB: 250,
        );

        expect(config.backend, equals(CacheBackendType.custom));
      });
    });
  });
}

