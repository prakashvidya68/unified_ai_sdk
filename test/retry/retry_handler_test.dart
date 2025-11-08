import 'dart:async';

import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/retry/retry_handler.dart';
import 'package:unified_ai_sdk/src/retry/retry_policy.dart';

void main() {
  group('RetryHandler', () {
    test('should execute successful operation immediately', () async {
      final policy = RetryPolicy.defaults();
      final handler = RetryHandler(policy: policy);

      final result = await handler.execute(() async {
        return 'success';
      });

      expect(result, equals('success'));
    });

    test('should retry on TransientError and succeed', () async {
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
      );
      final handler = RetryHandler(policy: policy);

      int attemptCount = 0;
      final result = await handler.execute(() async {
        attemptCount++;
        if (attemptCount < 3) {
          throw TransientError(
            message: 'Temporary failure',
            code: 'TIMEOUT',
          );
        }
        return 'success after retries';
      });

      expect(result, equals('success after retries'));
      expect(attemptCount, equals(3));
    });

    test('should retry on QuotaError and succeed', () async {
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
      );
      final handler = RetryHandler(policy: policy);

      int attemptCount = 0;
      final result = await handler.execute(() async {
        attemptCount++;
        if (attemptCount < 2) {
          throw QuotaError(
            message: 'Rate limit exceeded',
            code: 'RATE_LIMIT',
          );
        }
        return 'success after quota retry';
      });

      expect(result, equals('success after quota retry'));
      expect(attemptCount, equals(2));
    });

    test('should not retry AuthError', () async {
      final policy = RetryPolicy.defaults();
      final handler = RetryHandler(policy: policy);

      int attemptCount = 0;
      expectLater(
        handler.execute(() async {
          attemptCount++;
          throw AuthError(
            message: 'Invalid API key',
            code: 'INVALID_API_KEY',
          );
        }),
        throwsA(isA<AuthError>()),
      );

      // Wait a bit to ensure no retries occurred
      await Future.delayed(Duration(milliseconds: 50));
      expect(attemptCount, equals(1)); // Only one attempt
    });

    test('should not retry ClientError', () async {
      final policy = RetryPolicy.defaults();
      final handler = RetryHandler(policy: policy);

      int attemptCount = 0;
      expectLater(
        handler.execute(() async {
          attemptCount++;
          throw ClientError(
            message: 'Invalid request',
            code: 'INVALID_REQUEST',
          );
        }),
        throwsA(isA<ClientError>()),
      );

      await Future.delayed(Duration(milliseconds: 50));
      expect(attemptCount, equals(1));
    });

    test('should not retry CapabilityError', () async {
      final policy = RetryPolicy.defaults();
      final handler = RetryHandler(policy: policy);

      int attemptCount = 0;
      expectLater(
        handler.execute(() async {
          attemptCount++;
          throw CapabilityError(
            message: 'Feature not supported',
            code: 'NOT_SUPPORTED',
          );
        }),
        throwsA(isA<CapabilityError>()),
      );

      await Future.delayed(Duration(milliseconds: 50));
      expect(attemptCount, equals(1));
    });

    test('should throw last exception after max attempts', () async {
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
      );
      final handler = RetryHandler(policy: policy);

      int attemptCount = 0;
      expectLater(
        handler.execute(() async {
          attemptCount++;
          throw TransientError(
            message: 'Always fails',
            code: 'FAILURE',
          );
        }),
        throwsA(isA<TransientError>()),
      );

      await Future.delayed(Duration(milliseconds: 100));
      expect(attemptCount, equals(3)); // All attempts exhausted
    });

    test('should use exponential backoff delays', () async {
      final policy = RetryPolicy(
        maxAttempts: 4,
        initialDelay: Duration(milliseconds: 50),
        multiplier: 2.0,
      );
      final handler = RetryHandler(policy: policy);

      final delays = <Duration>[];
      final stopwatch = Stopwatch()..start();

      int attemptCount = 0;
      try {
        await handler.execute(() async {
          attemptCount++;
          if (attemptCount < 4) {
            final elapsed =
                Duration(milliseconds: stopwatch.elapsedMilliseconds);
            if (attemptCount > 1) {
              delays.add(elapsed);
            }
            stopwatch.reset();
            stopwatch.start();
            throw TransientError(message: 'Fail', code: 'FAIL');
          }
          return 'success';
        });
      } catch (e) {
        // Expected to fail
      }

      // Verify delays increase (with some tolerance for jitter)
      expect(delays.length, greaterThanOrEqualTo(2));
      // First delay should be around 50ms (with jitter)
      expect(delays[0].inMilliseconds, greaterThanOrEqualTo(40));
      expect(delays[0].inMilliseconds, lessThanOrEqualTo(60));
      // Second delay should be around 100ms (with jitter)
      expect(delays[1].inMilliseconds, greaterThanOrEqualTo(80));
      expect(delays[1].inMilliseconds, lessThanOrEqualTo(120));
    });

    test('should respect QuotaError retryAfter when provided', () async {
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
      );
      final handler = RetryHandler(policy: policy);

      final retryAfterTime = DateTime.now().add(Duration(milliseconds: 100));
      int attemptCount = 0;
      final stopwatch = Stopwatch()..start();

      final result = await handler.execute(() async {
        attemptCount++;
        if (attemptCount == 1) {
          throw QuotaError(
            message: 'Rate limit',
            code: 'RATE_LIMIT',
            retryAfter: retryAfterTime,
          );
        }
        return 'success';
      });

      stopwatch.stop();
      expect(result, equals('success'));
      expect(attemptCount, equals(2));
      // Should have waited at least 100ms (retryAfter) even though policy delay is 10ms
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(90));
    });

    test('should use calculated delay if retryAfter is in the past', () async {
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 50),
      );
      final handler = RetryHandler(policy: policy);

      final pastTime = DateTime.now().subtract(Duration(seconds: 1));
      int attemptCount = 0;
      final stopwatch = Stopwatch()..start();

      final result = await handler.execute(() async {
        attemptCount++;
        if (attemptCount == 1) {
          throw QuotaError(
            message: 'Rate limit',
            code: 'RATE_LIMIT',
            retryAfter: pastTime, // In the past
          );
        }
        return 'success';
      });

      stopwatch.stop();
      expect(result, equals('success'));
      expect(attemptCount, equals(2));
      // Should have used calculated delay (~50ms) not retryAfter
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('should use longer delay when retryAfter is longer than calculated',
        () async {
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
      );
      final handler = RetryHandler(policy: policy);

      final retryAfterTime = DateTime.now().add(Duration(milliseconds: 200));
      int attemptCount = 0;
      final stopwatch = Stopwatch()..start();

      final result = await handler.execute(() async {
        attemptCount++;
        if (attemptCount == 1) {
          throw QuotaError(
            message: 'Rate limit',
            code: 'RATE_LIMIT',
            retryAfter: retryAfterTime, // 200ms
          );
        }
        return 'success';
      });

      stopwatch.stop();
      expect(result, equals('success'));
      expect(attemptCount, equals(2));
      // Should have waited at least 200ms (retryAfter) not 10ms (calculated)
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(180));
    });

    test('should handle custom retry logic from policy', () async {
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
        shouldRetry: (e) {
          // Custom: retry ClientError with specific code
          if (e is ClientError && e.code == 'TEMPORARY') {
            return true;
          }
          return false;
        },
      );
      final handler = RetryHandler(policy: policy);

      int attemptCount = 0;
      final result = await handler.execute(() async {
        attemptCount++;
        if (attemptCount < 2) {
          throw ClientError(
            message: 'Temporary client error',
            code: 'TEMPORARY',
          );
        }
        return 'success';
      });

      expect(result, equals('success'));
      expect(attemptCount, equals(2));
    });

    test('should handle non-Exception errors', () async {
      final policy = RetryPolicy.defaults();
      final handler = RetryHandler(policy: policy);

      int attemptCount = 0;
      expectLater(
        handler.execute(() async {
          attemptCount++;
          throw 'String error'; // Not an Exception
        }),
        throwsA(isA<Exception>()),
      );

      await Future.delayed(Duration(milliseconds: 50));
      expect(attemptCount,
          equals(1)); // Should not retry non-Exception errors by default
    });

    test('should work with different return types', () async {
      final policy = RetryPolicy.defaults();
      final handler = RetryHandler(policy: policy);

      // String
      final stringResult = await handler.execute(() async => 'test');
      expect(stringResult, equals('test'));

      // Int
      final intResult = await handler.execute(() async => 42);
      expect(intResult, equals(42));

      // List
      final listResult = await handler.execute(() async => [1, 2, 3]);
      expect(listResult, equals([1, 2, 3]));

      // Map
      final mapResult = await handler.execute(() async => {'key': 'value'});
      expect(mapResult, equals({'key': 'value'}));
    });

    test('should handle maxAttempts = 1 (no retries)', () async {
      final policy = RetryPolicy(maxAttempts: 1);
      final handler = RetryHandler(policy: policy);

      int attemptCount = 0;
      expectLater(
        handler.execute(() async {
          attemptCount++;
          throw TransientError(message: 'Fail', code: 'FAIL');
        }),
        throwsA(isA<TransientError>()),
      );

      await Future.delayed(Duration(milliseconds: 50));
      expect(attemptCount, equals(1)); // Only one attempt, no retries
    });

    test('should cap delay at maxDelay', () async {
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(milliseconds: 150),
        multiplier: 10.0, // Would normally create very long delays
      );
      final handler = RetryHandler(policy: policy);

      int attemptCount = 0;
      final stopwatch = Stopwatch()..start();

      try {
        await handler.execute(() async {
          attemptCount++;
          if (attemptCount < 3) {
            stopwatch.reset();
            stopwatch.start();
            throw TransientError(message: 'Fail', code: 'FAIL');
          }
          return 'success';
        });
      } catch (e) {
        // Expected
      }

      stopwatch.stop();
      // Delay should be capped at 150ms, not 1000ms (100 * 10)
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });
  });
}
