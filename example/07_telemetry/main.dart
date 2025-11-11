// ignore_for_file: avoid_print, prefer_const_constructors

import 'dart:io';

import 'package:unified_ai_sdk/unified_ai_sdk.dart';

/// Telemetry Example
///
/// Demonstrates observability and monitoring.
/// Shows how to:
/// - Configure telemetry handlers (ConsoleLogger, MetricsCollector)
/// - Monitor request/response/error events
/// - Track usage metrics
/// - Analyze performance
///
/// **Prerequisites:**
/// - Set `OPENAI_API_KEY` environment variable
///
/// **Run:**
/// ```bash
/// dart run example/07_telemetry/main.dart
/// ```
void main() async {
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Error: OPENAI_API_KEY not set');
    exit(1);
  }

  try {
    print('🚀 Initializing SDK with telemetry...');

    // Create telemetry handlers
    final consoleLogger = ConsoleLogger(level: LogLevel.info);
    final metricsCollector = MetricsCollector();

    await UnifiedAI.init(
      UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: apiKey),
          ),
        },
        telemetryHandlers: [
          consoleLogger,
          metricsCollector,
        ],
      ),
    );
    print('✅ SDK initialized with telemetry enabled\n');

    final ai = UnifiedAI.instance;

    print('📊 Making requests with telemetry...\n');

    // Make several requests to generate metrics
    final requests = [
      'What is machine learning?',
      'Explain quantum computing',
      'Tell me about Flutter',
    ];

    for (int i = 0; i < requests.length; i++) {
      print('Request ${i + 1}/${requests.length}: "${requests[i]}"');
      try {
        await ai.chat(
          request: ChatRequest(
            messages: [Message(role: Role.user, content: requests[i])],
            maxTokens: 100,
          ),
        );
        print('✅ Completed\n');
      } on Exception catch (e) {
        print('❌ Error: $e\n');
      }

      // Small delay between requests
      await Future<void>.delayed(Duration(milliseconds: 500));
    }

    // Display metrics
    print('─' * 50);
    print('📈 Telemetry Metrics Summary\n');

    for (final providerId in ai.availableProviders) {
      final metrics = metricsCollector.getMetrics(providerId);
      if (metrics.totalRequests > 0) {
        print('Provider: $providerId');
        print('  Total Requests: ${metrics.totalRequests}');
        print('  Successful: ${metrics.successfulRequests}');
        print('  Failed: ${metrics.errorCount}');
        print('  Total Tokens: ${metrics.totalTokens}');
        if (metrics.averageLatency != Duration.zero) {
          print('  Avg Latency: ${metrics.averageLatency.inMilliseconds}ms');
        }
        if (metrics.minLatency != Duration.zero) {
          print('  Min Latency: ${metrics.minLatency.inMilliseconds}ms');
        }
        if (metrics.maxLatency != Duration.zero) {
          print('  Max Latency: ${metrics.maxLatency.inMilliseconds}ms');
        }
        print('');
      }
    }

    // Error rate summary
    print('Error Rates:');
    for (final providerId in ai.availableProviders) {
      final metrics = metricsCollector.getMetrics(providerId);
      if (metrics.totalRequests > 0) {
        print('  $providerId: ${metrics.errorRate.toStringAsFixed(2)}%');
      }
    }
    print('');

    print('─' * 50);
    print('✅ Telemetry demo complete');
    print('💡 Check console logs above for detailed telemetry events');
  } on Exception catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    try {
      await UnifiedAI.instance.dispose();
    } on Object {
      // Ignore
    }
  }
}
