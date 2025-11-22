import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/telemetry/metrics_collector.dart';
import 'package:unified_ai_sdk/src/telemetry/telemetry_handler.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';

void main() {
  group('MetricsCollector', () {
    late MetricsCollector collector;

    setUp(() {
      collector = MetricsCollector();
    });

    group('construction', () {
      test('should create empty collector', () {
        expect(collector.getAllProviders(), isEmpty);
        expect(collector.getMetrics('openai').totalRequests, equals(0));
      });
    });

    group('onRequest', () {
      test('should track request for provider', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.totalRequests, equals(1));
        expect(metrics.successfulRequests, equals(0));
        expect(metrics.errorCount, equals(0));
      });

      test('should track multiple requests for same provider', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-3',
          provider: 'openai',
          operation: 'embed',
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.totalRequests, equals(3));
      });

      test('should track requests for different providers', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'anthropic',
          operation: 'chat',
        ));

        expect(collector.getMetrics('openai').totalRequests, equals(1));
        expect(collector.getMetrics('anthropic').totalRequests, equals(1));
      });
    });

    group('onResponse', () {
      test('should track successful response', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));

        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-1',
          latency: Duration(milliseconds: 1500),
          tokensUsed: 250,
          cached: false,
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.totalRequests, equals(1));
        expect(metrics.successfulRequests, equals(1));
        expect(metrics.errorCount, equals(0));
        expect(metrics.totalTokens, equals(250));
        expect(metrics.cacheHits, equals(0));
      });

      test('should track cached response', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));

        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-1',
          latency: Duration(milliseconds: 10),
          tokensUsed: 100,
          cached: true,
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.successfulRequests, equals(1));
        expect(metrics.cacheHits, equals(1));
        expect(metrics.cacheHitRate, equals(100.0));
      });

      test('should track latency', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));

        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-1',
          latency: Duration(milliseconds: 1500),
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.averageLatency.inMilliseconds, equals(1500));
        expect(metrics.minLatency.inMilliseconds, equals(1500));
        expect(metrics.maxLatency.inMilliseconds, equals(1500));
      });

      test('should calculate average latency', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-3',
          provider: 'openai',
          operation: 'chat',
        ));

        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-1',
          latency: Duration(milliseconds: 1000),
        ));
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-2',
          latency: Duration(milliseconds: 2000),
        ));
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-3',
          latency: Duration(milliseconds: 3000),
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.averageLatency.inMilliseconds, equals(2000));
        expect(metrics.minLatency.inMilliseconds, equals(1000));
        expect(metrics.maxLatency.inMilliseconds, equals(3000));
      });

      test('should handle response without request tracking', () async {
        // Response without prior request (should be ignored)
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-unknown',
          latency: Duration(milliseconds: 1000),
        ));

        // Should not crash, but metrics won't be updated
        final metrics = collector.getMetrics('openai');
        expect(metrics.successfulRequests, equals(0));
      });

      test('should track tokens across multiple requests', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'openai',
          operation: 'chat',
        ));

        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-1',
          latency: Duration(milliseconds: 1000),
          tokensUsed: 100,
        ));
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-2',
          latency: Duration(milliseconds: 2000),
          tokensUsed: 200,
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.totalTokens, equals(300));
        expect(metrics.averageTokensPerRequest, equals(150.0));
      });
    });

    group('onError', () {
      test('should track error for provider', () async {
        await collector.onError(ErrorTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
          error: AuthError(message: 'Invalid API key'),
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.errorCount, equals(1));
        expect(metrics.totalRequests,
            equals(0)); // Error doesn't increment requests
      });

      test('should track multiple errors', () async {
        await collector.onError(ErrorTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
          error: AuthError(message: 'Invalid API key'),
        ));
        await collector.onError(ErrorTelemetry(
          requestId: 'req-2',
          provider: 'openai',
          operation: 'chat',
          error: QuotaError(message: 'Rate limit exceeded'),
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.errorCount, equals(2));
      });

      test('should handle error without provider', () async {
        await collector.onError(ErrorTelemetry(
          requestId: 'req-1',
          error: Exception('Some error'),
        ));

        // Should not crash, but metrics won't be updated
        expect(collector.getAllProviders(), isEmpty);
      });
    });

    group('getMetrics', () {
      test('should return empty metrics for unknown provider', () {
        final metrics = collector.getMetrics('unknown');
        expect(metrics.totalRequests, equals(0));
        expect(metrics.successfulRequests, equals(0));
        expect(metrics.errorCount, equals(0));
      });

      test('should return metrics for known provider', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.totalRequests, equals(1));
      });
    });

    group('getAllProviders', () {
      test('should return empty list when no metrics', () {
        expect(collector.getAllProviders(), isEmpty);
      });

      test('should return all provider IDs', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'anthropic',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-3',
          provider: 'google',
          operation: 'chat',
        ));

        final providers = collector.getAllProviders();
        expect(providers.length, equals(3));
        expect(providers, contains('openai'));
        expect(providers, contains('anthropic'));
        expect(providers, contains('google'));
      });
    });

    group('getAllMetrics', () {
      test('should return empty metrics when no data', () {
        final allMetrics = collector.getAllMetrics();
        expect(allMetrics.totalRequests, equals(0));
      });

      test('should combine metrics from all providers', () async {
        // OpenAI requests
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'openai',
          operation: 'chat',
        ));

        // Anthropic requests
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-3',
          provider: 'anthropic',
          operation: 'chat',
        ));

        final allMetrics = collector.getAllMetrics();
        expect(allMetrics.totalRequests, equals(3));
      });
    });

    group('clearMetrics', () {
      test('should clear metrics for specific provider', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'anthropic',
          operation: 'chat',
        ));

        collector.clearMetrics('openai');

        expect(collector.getMetrics('openai').totalRequests, equals(0));
        expect(collector.getMetrics('anthropic').totalRequests, equals(1));
      });
    });

    group('clearAll', () {
      test('should clear all metrics', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'anthropic',
          operation: 'chat',
        ));

        collector.clearAll();

        expect(collector.getAllProviders(), isEmpty);
        expect(collector.getMetrics('openai').totalRequests, equals(0));
        expect(collector.getMetrics('anthropic').totalRequests, equals(0));
      });
    });

    group('ProviderMetrics calculations', () {
      test('should calculate cache hit rate', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-3',
          provider: 'openai',
          operation: 'chat',
        ));

        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-1',
          latency: Duration(milliseconds: 1000),
          cached: true,
        ));
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-2',
          latency: Duration(milliseconds: 2000),
          cached: true,
        ));
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-3',
          latency: Duration(milliseconds: 3000),
          cached: false,
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.cacheHits, equals(2));
        expect(metrics.successfulRequests, equals(3));
        expect(metrics.cacheHitRate, closeTo(66.67, 0.1));
      });

      test('should calculate error rate', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-3',
          provider: 'openai',
          operation: 'chat',
        ));

        await collector.onError(ErrorTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
          error: AuthError(message: 'Invalid key'),
        ));

        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-2',
          latency: Duration(milliseconds: 1000),
        ));
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-3',
          latency: Duration(milliseconds: 2000),
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.totalRequests, equals(3));
        expect(metrics.errorCount, equals(1));
        expect(metrics.errorRate, closeTo(33.33, 0.1));
      });

      test('should handle zero values gracefully', () {
        final metrics = collector.getMetrics('openai');
        expect(metrics.averageLatency, equals(Duration.zero));
        expect(metrics.minLatency, equals(Duration.zero));
        expect(metrics.maxLatency, equals(Duration.zero));
        expect(metrics.cacheHitRate, equals(0.0));
        expect(metrics.errorRate, equals(0.0));
        expect(metrics.averageTokensPerRequest, equals(0.0));
      });
    });

    group('integration', () {
      test('should track complete request lifecycle', () async {
        // Request
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));

        // Response
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-1',
          latency: Duration(milliseconds: 1500),
          tokensUsed: 250,
          cached: false,
        ));

        final metrics = collector.getMetrics('openai');
        expect(metrics.totalRequests, equals(1));
        expect(metrics.successfulRequests, equals(1));
        expect(metrics.errorCount, equals(0));
        expect(metrics.totalTokens, equals(250));
        expect(metrics.averageLatency.inMilliseconds, equals(1500));
      });

      test('should track multiple providers independently', () async {
        // OpenAI
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-1',
          latency: Duration(milliseconds: 1000),
          tokensUsed: 100,
        ));

        // Anthropic
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-2',
          provider: 'anthropic',
          operation: 'chat',
        ));
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-2',
          latency: Duration(milliseconds: 2000),
          tokensUsed: 200,
        ));

        final openaiMetrics = collector.getMetrics('openai');
        final anthropicMetrics = collector.getMetrics('anthropic');

        expect(openaiMetrics.totalRequests, equals(1));
        expect(openaiMetrics.totalTokens, equals(100));
        expect(openaiMetrics.averageLatency.inMilliseconds, equals(1000));

        expect(anthropicMetrics.totalRequests, equals(1));
        expect(anthropicMetrics.totalTokens, equals(200));
        expect(anthropicMetrics.averageLatency.inMilliseconds, equals(2000));
      });
    });

    group('toJson', () {
      test('should serialize metrics to JSON', () async {
        await collector.onRequest(RequestTelemetry(
          requestId: 'req-1',
          provider: 'openai',
          operation: 'chat',
        ));
        await collector.onResponse(const ResponseTelemetry(
          requestId: 'req-1',
          latency: Duration(milliseconds: 1500),
          tokensUsed: 250,
          cached: true,
        ));

        final metrics = collector.getMetrics('openai');
        final json = metrics.toJson();

        expect(json['totalRequests'], equals(1));
        expect(json['successfulRequests'], equals(1));
        expect(json['errorCount'], equals(0));
        expect(json['cacheHits'], equals(1));
        expect(json['totalTokens'], equals(250));
        expect(json['averageLatency'], equals(1500));
        expect(json['cacheHitRate'], equals(100.0));
      });
    });
  });
}
