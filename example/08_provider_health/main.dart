// ignore_for_file: avoid_print, prefer_const_constructors

import 'dart:io';

import 'package:unified_ai_sdk/unified_ai_sdk.dart';
import 'package:unified_ai_sdk/src/orchestrator/provider_health_checker.dart';

/// Provider Health Check Example
///
/// Demonstrates monitoring provider health.
/// Shows how to:
/// - Check provider health status
/// - Monitor provider availability
/// - Handle unhealthy providers
/// - Implement health-based routing
///
/// **Prerequisites:**
/// - Set `OPENAI_API_KEY` environment variable
/// - Set `ANTHROPIC_API_KEY` environment variable (optional)
///
/// **Run:**
/// ```bash
/// dart run example/08_provider_health/main.dart
/// ```
void main() async {
  final openaiKey = Platform.environment['OPENAI_API_KEY'];
  final anthropicKey = Platform.environment['ANTHROPIC_API_KEY'];

  if (openaiKey == null || openaiKey.isEmpty) {
    print('❌ Error: OPENAI_API_KEY not set');
    exit(1);
  }

  try {
    print('🚀 Initializing SDK...');

    final providers = <String, ProviderConfig>{
      'openai': ProviderConfig(
        id: 'openai',
        auth: ApiKeyAuth(apiKey: openaiKey),
      ),
    };

    if (anthropicKey != null && anthropicKey.isNotEmpty) {
      providers['anthropic'] = ProviderConfig(
        id: 'anthropic',
        auth: ApiKeyAuth(
          apiKey: anthropicKey,
          headerName: 'x-api-key',
        ),
      );
    }

    await UnifiedAI.init(
      UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: providers,
      ),
    );
    print('✅ SDK initialized\n');

    final ai = UnifiedAI.instance;
    final healthChecker = ProviderHealthChecker();

    print('🏥 Checking provider health...\n');

    // Check health for all providers
    for (final providerId in ai.availableProviders) {
      print('Checking $providerId...');
      try {
        final provider = ai.getProvider(providerId);
        if (provider == null) {
          print('  ❌ Provider not found\n');
          continue;
        }
        final health = await healthChecker.checkHealth(provider);
        print('  Status: ${health.status}');
        print('  Duration: ${health.duration.inMilliseconds}ms');
        if (health.errorMessage != null) {
          print('  Error: ${health.errorMessage}');
        }
        if (health.errorCode != null) {
          print('  Error Code: ${health.errorCode}');
        }
        print('');
      } on Exception catch (e) {
        print('  ❌ Health check failed: $e\n');
      }
    }

    // Get health summary
    print('─' * 50);
    print('📊 Health Summary\n');

    final checkedProviders = healthChecker.getCheckedProviderIds();
    int healthy = 0;
    int unhealthy = 0;
    for (final providerId in checkedProviders) {
      final status = healthChecker.getHealthStatus(providerId);
      if (status == ProviderHealthStatus.healthy) {
        healthy++;
      } else if (status == ProviderHealthStatus.unhealthy) {
        unhealthy++;
      }
    }
    print('Total checked: ${checkedProviders.length}');
    print('Healthy: $healthy');
    print('Unhealthy: $unhealthy');
    print(
        'Unknown: ${ai.availableProviders.length - checkedProviders.length}\n');

    // Health-based routing example
    print('🔄 Health-based routing example...\n');

    final healthyProviders = ai.availableProviders.where((id) {
      final status = healthChecker.getHealthStatus(id);
      return status == ProviderHealthStatus.healthy;
    }).toList();

    if (healthyProviders.isEmpty) {
      print('⚠️  No healthy providers available');
    } else {
      print('✅ Healthy providers: ${healthyProviders.join(", ")}');
      print('Using first healthy provider: ${healthyProviders.first}\n');

      try {
        final response = await ai.chat(
          provider: healthyProviders.first,
          request: ChatRequest(
            messages: [
              Message(role: Role.user, content: 'Hello, are you healthy?'),
            ],
          ),
        );
        print('Response: ${response.choices.first.message.content}');
      } on Exception catch (e) {
        print('❌ Request failed: $e');
      }
    }

    print('\n─' * 50);
    print('✅ Health check demo complete');
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
