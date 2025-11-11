import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/providers/base/rate_limiter_factory.dart';
import 'package:unified_ai_sdk/src/retry/rate_limiter.dart';

void main() {
  group('RateLimiterFactory', () {
    group('create()', () {
      test('should create default rate limiter for OpenAI', () {
        final limiter = RateLimiterFactory.create('openai', {});

        expect(limiter, isNotNull);
        expect(limiter!.maxRequests, equals(60));
        expect(limiter.window, equals(const Duration(minutes: 1)));
      });

      test('should create default rate limiter for Anthropic', () {
        final limiter = RateLimiterFactory.create('anthropic', {});

        expect(limiter, isNotNull);
        expect(limiter!.maxRequests, equals(50));
        expect(limiter.window, equals(const Duration(minutes: 1)));
      });

      test('should create default rate limiter for Google', () {
        final limiter = RateLimiterFactory.create('google', {});

        expect(limiter, isNotNull);
        expect(limiter!.maxRequests, equals(60));
        expect(limiter.window, equals(const Duration(minutes: 1)));
      });

      test('should create default rate limiter for Cohere', () {
        final limiter = RateLimiterFactory.create('cohere', {});

        expect(limiter, isNotNull);
        expect(limiter!.maxRequests, equals(100));
        expect(limiter.window, equals(const Duration(minutes: 1)));
      });

      test('should return null for unknown provider', () {
        final limiter = RateLimiterFactory.create('unknown-provider', {});

        expect(limiter, isNull);
      });

      test('should use custom RateLimiter instance when provided', () {
        final customLimiter = RateLimiter(
          maxRequests: 200,
          window: const Duration(minutes: 1),
        );

        final limiter = RateLimiterFactory.create('openai', {
          'rateLimiter': customLimiter,
        });

        expect(limiter, equals(customLimiter));
      });

      test('should return null when rateLimiter is explicitly set to null', () {
        final limiter = RateLimiterFactory.create('openai', {
          'rateLimiter': null,
        });

        expect(limiter, isNull);
      });

      test('should create custom rate limiter from settings', () {
        final limiter = RateLimiterFactory.create('openai', {
          'rateLimitMaxRequests': 100,
          'rateLimitWindow': const Duration(minutes: 1),
        });

        expect(limiter, isNotNull);
        expect(limiter!.maxRequests, equals(100));
        expect(limiter.window, equals(const Duration(minutes: 1)));
      });

      test('should create custom rate limiter with window as milliseconds', () {
        final limiter = RateLimiterFactory.create('openai', {
          'rateLimitMaxRequests': 50,
          'rateLimitWindow': 60000, // milliseconds
        });

        expect(limiter, isNotNull);
        expect(limiter!.maxRequests, equals(50));
        expect(limiter.window, equals(const Duration(milliseconds: 60000)));
      });

      test('should throw ArgumentError for invalid window type', () {
        expect(
          () => RateLimiterFactory.create('openai', {
            'rateLimitMaxRequests': 100,
            'rateLimitWindow': 'invalid',
          }),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should prioritize custom RateLimiter over settings', () {
        final customLimiter = RateLimiter(
          maxRequests: 300,
          window: const Duration(minutes: 1),
        );

        final limiter = RateLimiterFactory.create('openai', {
          'rateLimiter': customLimiter,
          'rateLimitMaxRequests': 100,
          'rateLimitWindow': const Duration(minutes: 1),
        });

        expect(limiter, equals(customLimiter));
        expect(limiter!.maxRequests, equals(300));
      });

      test('should be case-insensitive for provider ID', () {
        final limiter1 = RateLimiterFactory.create('OPENAI', {});
        final limiter2 = RateLimiterFactory.create('openai', {});

        expect(limiter1, isNotNull);
        expect(limiter2, isNotNull);
        expect(limiter1!.maxRequests, equals(limiter2!.maxRequests));
        expect(limiter1.window, equals(limiter2.window));
      });
    });
  });
}
