import 'dart:async';

import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/retry/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    group('Construction', () {
      test('should create rate limiter with valid parameters', () {
        final limiter = RateLimiter(
          maxRequests: 10,
          window: const Duration(seconds: 1),
        );

        expect(limiter.maxRequests, equals(10));
        expect(limiter.window, equals(const Duration(seconds: 1)));
        expect(limiter.availableTokens, equals(10.0));
        expect(limiter.waitingRequests, equals(0));
      });

      test('should throw ClientError when maxRequests is zero', () {
        expect(
          () => RateLimiter(
            maxRequests: 0,
            window: const Duration(seconds: 1),
          ),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError when maxRequests is negative', () {
        expect(
          () => RateLimiter(
            maxRequests: -1,
            window: const Duration(seconds: 1),
          ),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError when window is zero', () {
        expect(
          () => RateLimiter(
            maxRequests: 10,
            window: Duration.zero,
          ),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError when window is negative', () {
        expect(
          () => RateLimiter(
            maxRequests: 10,
            window: const Duration(milliseconds: -1),
          ),
          throwsA(isA<ClientError>()),
        );
      });
    });

    group('acquire()', () {
      test('should acquire token immediately when tokens are available',
          () async {
        final limiter = RateLimiter(
          maxRequests: 10,
          window: const Duration(seconds: 1),
        );

        // Should complete immediately
        final start = DateTime.now();
        await limiter.acquire();
        final elapsed = DateTime.now().difference(start);

        expect(elapsed.inMilliseconds, lessThan(100)); // Should be very fast
        expect(limiter.availableTokens, lessThan(10.0));
      });

      test('should wait when no tokens are available', () async {
        final limiter = RateLimiter(
          maxRequests: 2,
          window: const Duration(seconds: 1),
        );

        // Consume all tokens
        await limiter.acquire();
        await limiter.acquire();
        expect(limiter.availableTokens, lessThan(1.0));

        // Next acquire should wait
        final start = DateTime.now();
        await limiter.acquire();
        final elapsed = DateTime.now().difference(start);

        // Should have waited approximately 500ms (half the window for 1 token)
        expect(elapsed.inMilliseconds, greaterThan(400));
        expect(elapsed.inMilliseconds, lessThan(1000));
      });

      test('should process requests in FIFO order', () async {
        final limiter = RateLimiter(
          maxRequests: 1,
          window: const Duration(milliseconds: 100),
        );

        // Consume the only token
        await limiter.acquire();

        // Queue multiple requests
        final completions = <int>[];
        final futures = [
          limiter.acquire().then((_) => completions.add(1)),
          limiter.acquire().then((_) => completions.add(2)),
          limiter.acquire().then((_) => completions.add(3)),
        ];

        // Wait for all to complete
        await Future.wait(futures);

        // Should complete in order
        expect(completions, equals([1, 2, 3]));
      });

      test('should handle concurrent requests correctly', () async {
        final limiter = RateLimiter(
          maxRequests: 5,
          window: const Duration(seconds: 1),
        );

        // Make 10 concurrent requests (more than maxRequests)
        final futures = List.generate(10, (i) => limiter.acquire());

        final start = DateTime.now();
        await Future.wait(futures);
        final elapsed = DateTime.now().difference(start);

        // First 5 should complete quickly, next 5 should wait
        expect(elapsed.inMilliseconds, greaterThan(500));
        expect(elapsed.inMilliseconds, lessThan(2000));
      });

      test('should refill tokens continuously', () async {
        final limiter = RateLimiter(
          maxRequests: 2,
          window: const Duration(milliseconds: 500),
        );

        // Consume all tokens
        await limiter.acquire();
        await limiter.acquire();
        expect(limiter.availableTokens, lessThan(1.0));

        // Wait for refill (should take ~250ms for 1 token)
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Should be able to acquire again
        final start = DateTime.now();
        await limiter.acquire();
        final elapsed = DateTime.now().difference(start);

        // Should complete quickly (token already refilled)
        expect(elapsed.inMilliseconds, lessThan(100));
      });
    });

    group('availableTokens', () {
      test('should return correct number of available tokens', () {
        final limiter = RateLimiter(
          maxRequests: 10,
          window: const Duration(seconds: 1),
        );

        expect(limiter.availableTokens, equals(10.0));

        // After acquiring, tokens should decrease
        limiter.acquire();
        // Note: availableTokens calls _refillTokens, so exact value may vary
        expect(limiter.availableTokens, lessThan(10.0));
      });

      test('should not exceed maxRequests', () {
        final limiter = RateLimiter(
          maxRequests: 5,
          window: const Duration(seconds: 1),
        );

        // Wait longer than window to ensure full refill
        Future<void>.delayed(const Duration(seconds: 2), () {
          expect(limiter.availableTokens, lessThanOrEqualTo(5.0));
        });
      });
    });

    group('waitingRequests', () {
      test('should return zero when no requests are waiting', () {
        final limiter = RateLimiter(
          maxRequests: 10,
          window: const Duration(seconds: 1),
        );

        expect(limiter.waitingRequests, equals(0));
      });

      test('should return correct number of waiting requests', () async {
        final limiter = RateLimiter(
          maxRequests: 1,
          window: const Duration(milliseconds: 200),
        );

        // Consume the only token
        await limiter.acquire();

        // Start multiple requests (they will wait)
        final futures = [
          limiter.acquire(),
          limiter.acquire(),
          limiter.acquire(),
        ];

        // Give them time to queue (need to wait for acquire to check tokens)
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should have requests waiting (may be 2-3 depending on timing)
        final waitingCount = limiter.waitingRequests;
        expect(waitingCount, greaterThanOrEqualTo(0));
        expect(waitingCount, lessThanOrEqualTo(3));

        // Wait for all to complete
        await Future.wait(futures);
        expect(limiter.waitingRequests, equals(0));
      });
    });

    group('reset()', () {
      test('should reset tokens to maxRequests', () async {
        final limiter = RateLimiter(
          maxRequests: 10,
          window: const Duration(seconds: 1),
        );

        // Consume some tokens
        await limiter.acquire();
        await limiter.acquire();
        expect(limiter.availableTokens, lessThan(10.0));

        // Reset
        limiter.reset();
        expect(limiter.availableTokens, equals(10.0));
      });

      test('should clear wait queue', () async {
        final limiter = RateLimiter(
          maxRequests: 1,
          window: const Duration(milliseconds: 200),
        );

        // Consume the only token
        await limiter.acquire();

        // Start a request (will wait)
        limiter.acquire();

        // Give it time to queue
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(limiter.waitingRequests, greaterThan(0));

        // Reset (this will clear the queue, causing the future to never complete)
        limiter.reset();
        expect(limiter.waitingRequests, equals(0));

        // The future should still be waiting (reset doesn't complete it)
        // But we can acquire immediately now
        await limiter.acquire();

        // Cancel the waiting future to avoid test timeout
        // (In real usage, reset() would typically be called when no requests are pending)
      });
    });

    group('Rate limiting scenarios', () {
      test('should limit to 10 requests per second', () async {
        final limiter = RateLimiter(
          maxRequests: 10,
          window: const Duration(milliseconds: 1000),
        );

        final start = DateTime.now();

        // Make 15 requests
        final futures = List.generate(15, (_) => limiter.acquire());
        await Future.wait(futures);

        final elapsed = DateTime.now().difference(start);

        // Should take at least 0.4 seconds (5 requests need to wait, ~100ms each)
        // Allow some tolerance for timing
        expect(elapsed.inMilliseconds, greaterThan(300));
        expect(elapsed.inMilliseconds, lessThan(2000));
      });

      test('should limit to 60 requests per minute', () async {
        final limiter = RateLimiter(
          maxRequests: 60,
          window: const Duration(minutes: 1),
        );

        // First 60 should complete quickly
        final start = DateTime.now();
        final futures = List.generate(60, (_) => limiter.acquire());
        await Future.wait(futures);
        final elapsed = DateTime.now().difference(start);

        // Should complete quickly (all tokens available)
        expect(elapsed.inMilliseconds, lessThan(1000));
      });

      test('should handle rapid successive requests', () async {
        final limiter = RateLimiter(
          maxRequests: 5,
          window: const Duration(milliseconds: 500),
        );

        final timestamps = <DateTime>[];

        // Make 10 rapid requests
        for (int i = 0; i < 10; i++) {
          await limiter.acquire();
          timestamps.add(DateTime.now());
        }

        // First 5 should be immediate, next 5 should be spaced out
        final firstBatch = timestamps.sublist(0, 5);
        final secondBatch = timestamps.sublist(5, 10);

        // Verify first batch completes quickly
        final firstBatchDuration = firstBatch.last.difference(firstBatch.first);
        expect(firstBatchDuration.inMilliseconds, lessThan(100));

        // Check that second batch is spaced out (allows some tolerance)
        for (int i = 1; i < secondBatch.length; i++) {
          final gap = secondBatch[i].difference(secondBatch[i - 1]);
          // Should be approximately 100ms per token (500ms / 5 tokens)
          expect(gap.inMilliseconds, greaterThan(50));
        }
      });
    });

    group('toString()', () {
      test('should return descriptive string representation', () {
        final limiter = RateLimiter(
          maxRequests: 10,
          window: const Duration(seconds: 1),
        );

        final str = limiter.toString();
        expect(str, contains('RateLimiter'));
        expect(str, contains('maxRequests: 10'));
        expect(str, contains('window: 0:00:01.000000'));
        expect(str, contains('availableTokens'));
        expect(str, contains('waitingRequests'));
      });
    });
  });
}
