import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/core/config.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/retry/retry_policy.dart';
import 'package:unified_ai_sdk/src/telemetry/telemetry_handler.dart';

// Mock implementations for testing
class MockTelemetryHandler implements TelemetryHandler {
  @override
  Future<void> onRequest(RequestTelemetry event) async {}

  @override
  Future<void> onResponse(ResponseTelemetry event) async {}

  @override
  Future<void> onError(ErrorTelemetry event) async {}
}

void main() {
  group('UnifiedAIConfig', () {
    late ProviderConfig testProviderConfig;

    setUp(() {
      testProviderConfig = ProviderConfig(
        id: 'test-provider',
        auth: ApiKeyAuth(apiKey: 'sk-test-abc123'),
      );
    });

    group('construction', () {
      test('should create instance with required fields', () {
        final config = UnifiedAIConfig(
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
        );

        expect(config.perProviderConfig.length, equals(1));
        expect(config.perProviderConfig['test-provider'],
            equals(testProviderConfig));
        expect(config.defaultProvider, isNull);
        expect(config.telemetryHandlers, isEmpty);
        expect(config.retryPolicy, isA<RetryPolicy>());
      });

      test('should create instance with all fields', () {
        final telemetryHandlers = [MockTelemetryHandler()];
        final retryPolicy = RetryPolicy();

        final config = UnifiedAIConfig(
          defaultProvider: 'test-provider',
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
          telemetryHandlers: telemetryHandlers,
          retryPolicy: retryPolicy,
        );

        expect(config.defaultProvider, equals('test-provider'));
        expect(config.telemetryHandlers, equals(telemetryHandlers));
        expect(config.retryPolicy, equals(retryPolicy));
      });

      test('should use empty telemetry handlers when not provided', () {
        final config = UnifiedAIConfig(
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
        );

        expect(config.telemetryHandlers, isEmpty);
      });

      test('should use default retry policy when not provided', () {
        final config = UnifiedAIConfig(
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
        );

        expect(config.retryPolicy, isA<RetryPolicy>());
      });

      test('should throw ClientError when perProviderConfig is empty', () {
        expect(
          () => UnifiedAIConfig(perProviderConfig: {}),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_CONFIG',
          )),
        );
      });

      test('should throw ClientError when defaultProvider not in config', () {
        expect(
          () => UnifiedAIConfig(
            defaultProvider: 'non-existent',
            perProviderConfig: {
              'test-provider': testProviderConfig,
            },
          ),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_DEFAULT_PROVIDER',
          )),
        );
      });

      test('should throw ClientError when provider ID mismatches map key', () {
        final mismatchedConfig = ProviderConfig(
          id: 'different-id',
          auth: ApiKeyAuth(apiKey: 'sk-test'),
        );

        expect(
          () => UnifiedAIConfig(
            perProviderConfig: {
              'test-provider': mismatchedConfig,
            },
          ),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'MISMATCHED_PROVIDER_ID',
          )),
        );
      });

      test('should accept multiple providers', () {
        final provider1 = ProviderConfig(
          id: 'provider-1',
          auth: ApiKeyAuth(apiKey: 'sk-key1'),
        );
        final provider2 = ProviderConfig(
          id: 'provider-2',
          auth: ApiKeyAuth(apiKey: 'sk-key2'),
        );
        final provider3 = ProviderConfig(
          id: 'provider-3',
          auth: ApiKeyAuth(apiKey: 'sk-key3'),
        );

        final config = UnifiedAIConfig(
          perProviderConfig: {
            'provider-1': provider1,
            'provider-2': provider2,
            'provider-3': provider3,
          },
        );

        expect(config.perProviderConfig.length, equals(3));
        expect(config.perProviderConfig['provider-1'], equals(provider1));
        expect(config.perProviderConfig['provider-2'], equals(provider2));
        expect(config.perProviderConfig['provider-3'], equals(provider3));
      });
    });

    group('copyWith', () {
      test('should create copy with same values when no changes', () {
        final original = UnifiedAIConfig(
          defaultProvider: 'test-provider',
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
        );

        final copy = original.copyWith();

        expect(copy.defaultProvider, equals(original.defaultProvider));
        expect(copy.perProviderConfig, equals(original.perProviderConfig));
        expect(copy.telemetryHandlers, equals(original.telemetryHandlers));
        expect(copy.retryPolicy, equals(original.retryPolicy));
        expect(copy, equals(original));
      });

      test('should create copy with updated defaultProvider', () {
        final provider1 = ProviderConfig(
          id: 'provider-1',
          auth: ApiKeyAuth(apiKey: 'sk-key1'),
        );
        final provider2 = ProviderConfig(
          id: 'provider-2',
          auth: ApiKeyAuth(apiKey: 'sk-key2'),
        );

        final original = UnifiedAIConfig(
          defaultProvider: 'provider-1',
          perProviderConfig: {
            'provider-1': provider1,
            'provider-2': provider2,
          },
        );

        final copy = original.copyWith(defaultProvider: 'provider-2');

        expect(copy.defaultProvider, equals('provider-2'));
        expect(copy.perProviderConfig, equals(original.perProviderConfig));
      });

      test('should create copy with updated perProviderConfig', () {
        final original = UnifiedAIConfig(
          perProviderConfig: {
            'provider-1': ProviderConfig(
              id: 'provider-1',
              auth: ApiKeyAuth(apiKey: 'sk-key1'),
            ),
          },
        );

        final newProvider = ProviderConfig(
          id: 'provider-2',
          auth: ApiKeyAuth(apiKey: 'sk-key2'),
        );

        final copy = original.copyWith(
          perProviderConfig: {
            'provider-2': newProvider,
          },
        );

        expect(copy.perProviderConfig.length, equals(1));
        expect(copy.perProviderConfig['provider-2'], equals(newProvider));
      });

      test('should create copy with updated telemetryHandlers', () {
        final original = UnifiedAIConfig(
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
        );

        final newHandlers = [MockTelemetryHandler()];
        final copy = original.copyWith(telemetryHandlers: newHandlers);

        expect(copy.telemetryHandlers, equals(newHandlers));
        expect(copy.telemetryHandlers.length, equals(1));
      });

      test('should create copy with updated retryPolicy', () {
        final original = UnifiedAIConfig(
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
        );

        final newRetryPolicy = RetryPolicy();
        final copy = original.copyWith(retryPolicy: newRetryPolicy);

        expect(copy.retryPolicy, equals(newRetryPolicy));
      });

      test('should clear defaultProvider when clearDefaultProvider is true',
          () {
        final original = UnifiedAIConfig(
          defaultProvider: 'test-provider',
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
        );

        final copy = original.copyWith(clearDefaultProvider: true);

        expect(copy.defaultProvider, isNull);
        expect(original.defaultProvider, isNotNull);
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        final config1 = UnifiedAIConfig(
          defaultProvider: 'test-provider',
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
        );
        final config2 = UnifiedAIConfig(
          defaultProvider: 'test-provider',
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('should not be equal when defaultProvider differs', () {
        final provider1 = ProviderConfig(
          id: 'provider-1',
          auth: ApiKeyAuth(apiKey: 'sk-key1'),
        );
        final provider2 = ProviderConfig(
          id: 'provider-2',
          auth: ApiKeyAuth(apiKey: 'sk-key2'),
        );

        final config1 = UnifiedAIConfig(
          defaultProvider: 'provider-1',
          perProviderConfig: {
            'provider-1': provider1,
            'provider-2': provider2,
          },
        );
        final config2 = UnifiedAIConfig(
          defaultProvider: 'provider-2',
          perProviderConfig: {
            'provider-1': provider1,
            'provider-2': provider2,
          },
        );

        expect(config1, isNot(equals(config2)));
      });

      test('should not be equal when perProviderConfig differs', () {
        final config1 = UnifiedAIConfig(
          perProviderConfig: {
            'provider-1': ProviderConfig(
              id: 'provider-1',
              auth: ApiKeyAuth(apiKey: 'sk-key1'),
            ),
          },
        );
        final config2 = UnifiedAIConfig(
          perProviderConfig: {
            'provider-2': ProviderConfig(
              id: 'provider-2',
              auth: ApiKeyAuth(apiKey: 'sk-key2'),
            ),
          },
        );

        expect(config1, isNot(equals(config2)));
      });
    });

    group('toString', () {
      test('should include provider count and names', () {
        final config = UnifiedAIConfig(
          perProviderConfig: {
            'provider-1': ProviderConfig(
              id: 'provider-1',
              auth: ApiKeyAuth(apiKey: 'sk-key1'),
            ),
            'provider-2': ProviderConfig(
              id: 'provider-2',
              auth: ApiKeyAuth(apiKey: 'sk-key2'),
            ),
          },
        );

        final str = config.toString();
        expect(str, contains('2 provider(s)'));
        expect(str, contains('provider-1'));
        expect(str, contains('provider-2'));
      });

      test('should include default provider when set', () {
        final config = UnifiedAIConfig(
          defaultProvider: 'test-provider',
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
        );

        final str = config.toString();
        expect(str, contains('default: test-provider'));
      });

      test('should include telemetry handler count', () {
        final config = UnifiedAIConfig(
          perProviderConfig: {
            'test-provider': testProviderConfig,
          },
          telemetryHandlers: [
            MockTelemetryHandler(),
            MockTelemetryHandler(),
          ],
        );

        final str = config.toString();
        expect(str, contains('2 handler(s)'));
      });
    });

    group('integration', () {
      test('should work with multiple providers and custom settings', () {
        final config = UnifiedAIConfig(
          defaultProvider: 'openai',
          perProviderConfig: {
            'openai': ProviderConfig(
              id: 'openai',
              auth: ApiKeyAuth(apiKey: 'sk-openai-abc123'),
              settings: {'defaultModel': 'gpt-4'},
              timeout: Duration(seconds: 30),
            ),
            'anthropic': ProviderConfig(
              id: 'anthropic',
              auth: ApiKeyAuth(
                apiKey: 'sk-ant-abc123',
                headerName: 'x-api-key',
              ),
              settings: {'defaultModel': 'claude-3-opus'},
            ),
          },
          telemetryHandlers: [MockTelemetryHandler()],
        );

        expect(config.defaultProvider, equals('openai'));
        expect(config.perProviderConfig.length, equals(2));
        expect(config.telemetryHandlers.length, equals(1));
      });
    });
  });
}
