import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/retry/retry_policy.dart';

void main() {
  group('RetryPolicy', () {
    group('Construction', () {
      test('should create policy with default values', () {
        final policy = RetryPolicy();
        expect(policy.maxAttempts, equals(3));
        expect(policy.initialDelay, equals(const Duration(milliseconds: 100)));
        expect(policy.maxDelay, equals(const Duration(seconds: 30)));
        expect(policy.multiplier, equals(2.0));
        expect(policy.shouldRetry, isNull);
      });

      test('should create policy with custom values', () {
        final policy = RetryPolicy(
          maxAttempts: 5,
          initialDelay: const Duration(milliseconds: 200),
          maxDelay: const Duration(seconds: 60),
          multiplier: 1.5,
        );
        expect(policy.maxAttempts, equals(5));
        expect(policy.initialDelay, equals(const Duration(milliseconds: 200)));
        expect(policy.maxDelay, equals(const Duration(seconds: 60)));
        expect(policy.multiplier, equals(1.5));
      });

      test('should throw ClientError when maxAttempts is less than 1', () {
        expect(
          () => RetryPolicy(maxAttempts: 0),
          throwsA(isA<ClientError>()),
        );
        expect(
          () => RetryPolicy(maxAttempts: -1),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError when multiplier is zero or negative', () {
        expect(
          () => RetryPolicy(multiplier: 0),
          throwsA(isA<ClientError>()),
        );
        expect(
          () => RetryPolicy(multiplier: -1),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError when delays are negative', () {
        expect(
          () => RetryPolicy(initialDelay: const Duration(milliseconds: -1)),
          throwsA(isA<ClientError>()),
        );
        expect(
          () => RetryPolicy(maxDelay: const Duration(milliseconds: -1)),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError when maxDelay is less than initialDelay',
          () {
        expect(
          () => RetryPolicy(
            initialDelay: const Duration(seconds: 10),
            maxDelay: const Duration(seconds: 5),
          ),
          throwsA(isA<ClientError>()),
        );
      });
    });

    group('defaults()', () {
      test('should return policy with default values', () {
        final policy = RetryPolicy.defaults();
        expect(policy.maxAttempts, equals(3));
        expect(policy.initialDelay, equals(const Duration(milliseconds: 100)));
        expect(policy.maxDelay, equals(const Duration(seconds: 30)));
        expect(policy.multiplier, equals(2.0));
      });
    });

    group('getDelay()', () {
      test('should calculate exponential backoff correctly', () {
        final policy = RetryPolicy(
          initialDelay: const Duration(milliseconds: 100),
          multiplier: 2.0,
        );

        // First retry (attemptNumber = 0): 100ms * 2^0 = 100ms
        final delay0 = policy.getDelay(0);
        expect(delay0.inMilliseconds, greaterThanOrEqualTo(100));
        expect(
            delay0.inMilliseconds, lessThanOrEqualTo(110)); // Allow for jitter

        // Second retry (attemptNumber = 1): 100ms * 2^1 = 200ms
        final delay1 = policy.getDelay(1);
        expect(delay1.inMilliseconds, greaterThanOrEqualTo(200));
        expect(
            delay1.inMilliseconds, lessThanOrEqualTo(220)); // Allow for jitter

        // Third retry (attemptNumber = 2): 100ms * 2^2 = 400ms
        final delay2 = policy.getDelay(2);
        expect(delay2.inMilliseconds, greaterThanOrEqualTo(400));
        expect(
            delay2.inMilliseconds, lessThanOrEqualTo(440)); // Allow for jitter
      });

      test('should cap delay at maxDelay', () {
        final policy = RetryPolicy(
          initialDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 5),
          multiplier: 10.0,
        );

        // With multiplier 10, delay would be 1s * 10^3 = 1000s, but capped at 5s
        final delay = policy.getDelay(3);
        expect(delay.inMilliseconds, lessThanOrEqualTo(5000));
      });

      test('should throw ArgumentError for negative attemptNumber', () {
        final policy = RetryPolicy();
        expect(
          () => policy.getDelay(-1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should include jitter in delay', () {
        final policy = RetryPolicy(
          initialDelay: const Duration(milliseconds: 100),
          multiplier: 1.0, // No exponential growth
        );

        // Run multiple times to verify jitter is applied
        final delays = <int>[];
        for (int i = 0; i < 10; i++) {
          delays.add(policy.getDelay(0).inMilliseconds);
        }

        // All delays should be >= 100ms and <= 110ms (100ms + 10% jitter)
        for (final delay in delays) {
          expect(delay, greaterThanOrEqualTo(100));
          expect(delay, lessThanOrEqualTo(110));
        }
      });
    });

    group('canRetry()', () {
      test('should not retry when max attempts reached', () {
        final policy = RetryPolicy(maxAttempts: 3);
        final error = TransientError(
          message: 'Test error',
          code: 'TEST_ERROR',
          provider: 'test',
        );

        // attemptNumber 0, 1 are valid (maxAttempts=3 means 0,1,2 attempts)
        expect(policy.canRetry(error, 0), isTrue);
        expect(policy.canRetry(error, 1), isTrue);
        expect(policy.canRetry(error, 2), isFalse); // Last attempt
        expect(policy.canRetry(error, 3), isFalse); // Exceeded
      });

      test('should retry TransientError', () {
        final policy = RetryPolicy();
        final error = TransientError(
          message: 'Network error',
          code: 'NETWORK_ERROR',
          provider: 'test',
        );

        expect(policy.canRetry(error, 0), isTrue);
      });

      test('should retry QuotaError', () {
        final policy = RetryPolicy();
        final error = QuotaError(
          message: 'Rate limit exceeded',
          code: 'RATE_LIMIT',
          provider: 'test',
        );

        expect(policy.canRetry(error, 0), isTrue);
      });

      test('should not retry AuthError', () {
        final policy = RetryPolicy();
        final error = AuthError(
          message: 'Invalid API key',
          code: 'INVALID_KEY',
          provider: 'test',
        );

        expect(policy.canRetry(error, 0), isFalse);
      });

      test('should not retry ClientError', () {
        final policy = RetryPolicy();
        final error = ClientError(
          message: 'Invalid request',
          code: 'INVALID_REQUEST',
        );

        expect(policy.canRetry(error, 0), isFalse);
      });

      test('should not retry CapabilityError', () {
        final policy = RetryPolicy();
        final error = CapabilityError(
          message: 'Not supported',
          code: 'NOT_SUPPORTED',
          provider: 'test',
        );

        expect(policy.canRetry(error, 0), isFalse);
      });

      test('should use custom shouldRetry function when provided', () {
        final policy = RetryPolicy(
          shouldRetry: (e) => e is ClientError && e.code == 'CUSTOM_RETRY',
        );

        final retryableError = ClientError(
          message: 'Custom retry',
          code: 'CUSTOM_RETRY',
        );
        expect(policy.canRetry(retryableError, 0), isTrue);

        final nonRetryableError = ClientError(
          message: 'No retry',
          code: 'NO_RETRY',
        );
        expect(policy.canRetry(nonRetryableError, 0), isFalse);
      });

      test('should throw ArgumentError for negative attemptNumber', () {
        final policy = RetryPolicy();
        final error = TransientError(
          message: 'Test',
          code: 'TEST',
          provider: 'test',
        );

        expect(
          () => policy.canRetry(error, -1),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('copyWith()', () {
      test('should create copy with same values when no changes', () {
        final original = RetryPolicy(
          maxAttempts: 5,
          initialDelay: const Duration(milliseconds: 200),
          maxDelay: const Duration(seconds: 60),
          multiplier: 1.5,
        );

        final copy = original.copyWith();

        expect(copy.maxAttempts, equals(original.maxAttempts));
        expect(copy.initialDelay, equals(original.initialDelay));
        expect(copy.maxDelay, equals(original.maxDelay));
        expect(copy.multiplier, equals(original.multiplier));
        expect(copy.shouldRetry, equals(original.shouldRetry));
      });

      test('should create copy with updated values', () {
        final original = RetryPolicy();
        final copy = original.copyWith(
          maxAttempts: 10,
          initialDelay: const Duration(milliseconds: 500),
        );

        expect(copy.maxAttempts, equals(10));
        expect(copy.initialDelay, equals(const Duration(milliseconds: 500)));
        expect(copy.maxDelay, equals(original.maxDelay));
        expect(copy.multiplier, equals(original.multiplier));
      });

      test('should clear shouldRetry when clearShouldRetry is true', () {
        bool customRetry(Exception e) => true;
        final original = RetryPolicy(shouldRetry: customRetry);

        final copy = original.copyWith(clearShouldRetry: true);

        expect(copy.shouldRetry, isNull);
      });
    });

    group('Equality and hashCode', () {
      test('should be equal when all fields match', () {
        final policy1 = RetryPolicy(
          maxAttempts: 5,
          initialDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(seconds: 30),
          multiplier: 2.0,
        );
        final policy2 = RetryPolicy(
          maxAttempts: 5,
          initialDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(seconds: 30),
          multiplier: 2.0,
        );

        expect(policy1, equals(policy2));
        expect(policy1.hashCode, equals(policy2.hashCode));
      });

      test('should not be equal when fields differ', () {
        final policy1 = RetryPolicy(maxAttempts: 5);
        final policy2 = RetryPolicy(maxAttempts: 10);

        expect(policy1, isNot(equals(policy2)));
      });
    });

    group('toString()', () {
      test('should return descriptive string representation', () {
        final policy = RetryPolicy(
          maxAttempts: 5,
          initialDelay: const Duration(milliseconds: 200),
        );

        final str = policy.toString();
        expect(str, contains('RetryPolicy'));
        expect(str, contains('maxAttempts: 5'));
        expect(str, contains('initialDelay'));
        expect(str, contains('shouldRetry'));
      });
    });
  });
}
