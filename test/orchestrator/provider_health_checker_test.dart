import 'dart:async';

import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/models/common/capabilities.dart';
import 'package:unified_ai_sdk/src/models/requests/chat_request.dart';
import 'package:unified_ai_sdk/src/models/requests/embedding_request.dart';
import 'package:unified_ai_sdk/src/models/requests/image_request.dart';
import 'package:unified_ai_sdk/src/models/requests/stt_request.dart';
import 'package:unified_ai_sdk/src/models/requests/tts_request.dart';
import 'package:unified_ai_sdk/src/models/responses/audio_response.dart';
import 'package:unified_ai_sdk/src/models/responses/chat_response.dart';
import 'package:unified_ai_sdk/src/models/responses/embedding_response.dart';
import 'package:unified_ai_sdk/src/models/responses/image_response.dart';
import 'package:unified_ai_sdk/src/models/responses/transcription_response.dart';
import 'package:unified_ai_sdk/src/orchestrator/provider_health_checker.dart';
import 'package:unified_ai_sdk/src/providers/base/ai_provider.dart';
import 'package:unified_ai_sdk/src/providers/base/model_fetcher.dart';

void main() {
  group('ProviderHealthChecker', () {
    group('Construction', () {
      test('should create health checker with default timeout', () {
        final checker = ProviderHealthChecker();
        expect(checker.healthCheckTimeout, equals(Duration(seconds: 5)));
        expect(checker.checkedCount, equals(0));
      });

      test('should create health checker with custom timeout', () {
        final checker = ProviderHealthChecker(
          healthCheckTimeout: Duration(seconds: 10),
        );
        expect(checker.healthCheckTimeout, equals(Duration(seconds: 10)));
      });
    });

    group('checkHealth()', () {
      test('should mark provider as healthy when healthCheck returns true',
          () async {
        final checker = ProviderHealthChecker();
        final provider = _MockHealthyProvider();

        final result = await checker.checkHealth(provider);

        expect(result.isHealthy, isTrue);
        expect(result.status, equals(ProviderHealthStatus.healthy));
        expect(result.providerId, equals('test-provider'));
        expect(result.errorMessage, isNull);
        expect(result.duration, greaterThan(Duration.zero));
      });

      test('should mark provider as unhealthy when healthCheck returns false',
          () async {
        final checker = ProviderHealthChecker();
        final provider = _MockUnhealthyProvider();

        final result = await checker.checkHealth(provider);

        expect(result.isHealthy, isFalse);
        expect(result.status, equals(ProviderHealthStatus.unhealthy));
        expect(result.providerId, equals('test-provider'));
        expect(result.errorMessage, isNotNull);
        expect(result.errorCode, equals('HEALTH_CHECK_FAILED'));
      });

      test('should handle timeout errors', () async {
        final checker = ProviderHealthChecker(
          healthCheckTimeout: Duration(milliseconds: 100),
        );
        final provider = _MockSlowProvider();

        final result = await checker.checkHealth(provider);

        expect(result.isHealthy, isFalse);
        expect(result.status, equals(ProviderHealthStatus.unhealthy));
        expect(result.errorMessage, contains('timed out'));
        expect(result.errorCode, equals('HEALTH_CHECK_TIMEOUT'));
      });

      test('should handle authentication errors', () async {
        final checker = ProviderHealthChecker();
        final provider = _MockAuthErrorProvider();

        final result = await checker.checkHealth(provider);

        expect(result.isHealthy, isFalse);
        expect(result.status, equals(ProviderHealthStatus.unhealthy));
        expect(result.errorMessage, contains('Authentication failed'));
        expect(result.errorCode, equals('AUTH_ERROR'));
      });

      test('should handle transient errors', () async {
        final checker = ProviderHealthChecker();
        final provider = _MockTransientErrorProvider();

        final result = await checker.checkHealth(provider);

        expect(result.isHealthy, isFalse);
        expect(result.status, equals(ProviderHealthStatus.unhealthy));
        expect(result.errorMessage, contains('Temporary error'));
        expect(result.errorCode, equals('TRANSIENT_ERROR'));
      });

      test('should use ModelFetcher for providers that implement it', () async {
        final checker = ProviderHealthChecker();
        final provider = _MockModelFetcherProvider();

        final result = await checker.checkHealth(provider);

        expect(result.isHealthy, isTrue);
        expect(result.status, equals(ProviderHealthStatus.healthy));
      });

      test('should throw ArgumentError for provider with empty ID', () async {
        final checker = ProviderHealthChecker();
        final provider = _MockProviderWithEmptyId();

        expect(
          () => checker.checkHealth(provider),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('isHealthy()', () {
      test('should return null for unchecked provider', () {
        final checker = ProviderHealthChecker();
        expect(checker.isHealthy('unknown'), isNull);
      });

      test('should return true for healthy provider', () async {
        final checker = ProviderHealthChecker();
        final provider = _MockHealthyProvider();

        await checker.checkHealth(provider);
        expect(checker.isHealthy('test-provider'), isTrue);
      });

      test('should return false for unhealthy provider', () async {
        final checker = ProviderHealthChecker();
        final provider = _MockUnhealthyProvider();

        await checker.checkHealth(provider);
        expect(checker.isHealthy('test-provider'), isFalse);
      });
    });

    group('getHealthResult()', () {
      test('should return null for unchecked provider', () {
        final checker = ProviderHealthChecker();
        expect(checker.getHealthResult('unknown'), isNull);
      });

      test('should return health result for checked provider', () async {
        final checker = ProviderHealthChecker();
        final provider = _MockHealthyProvider();

        await checker.checkHealth(provider);
        final result = checker.getHealthResult('test-provider');

        expect(result, isNotNull);
        expect(result!.providerId, equals('test-provider'));
        expect(result.isHealthy, isTrue);
        expect(result.checkedAt, isA<DateTime>());
      });
    });

    group('getHealthStatus()', () {
      test('should return unknown for unchecked provider', () {
        final checker = ProviderHealthChecker();
        expect(
          checker.getHealthStatus('unknown'),
          equals(ProviderHealthStatus.unknown),
        );
      });

      test('should return healthy for healthy provider', () async {
        final checker = ProviderHealthChecker();
        final provider = _MockHealthyProvider();

        await checker.checkHealth(provider);
        expect(
          checker.getHealthStatus('test-provider'),
          equals(ProviderHealthStatus.healthy),
        );
      });

      test('should return unhealthy for unhealthy provider', () async {
        final checker = ProviderHealthChecker();
        final provider = _MockUnhealthyProvider();

        await checker.checkHealth(provider);
        expect(
          checker.getHealthStatus('test-provider'),
          equals(ProviderHealthStatus.unhealthy),
        );
      });
    });

    group('clearHealthResult()', () {
      test('should clear health result for provider', () async {
        final checker = ProviderHealthChecker();
        final provider = _MockHealthyProvider();

        await checker.checkHealth(provider);
        expect(checker.isHealthy('test-provider'), isTrue);

        final removed = checker.clearHealthResult('test-provider');
        expect(removed, isTrue);
        expect(checker.isHealthy('test-provider'), isNull);
      });

      test('should return false if no result exists', () {
        final checker = ProviderHealthChecker();
        final removed = checker.clearHealthResult('unknown');
        expect(removed, isFalse);
      });
    });

    group('clearAllHealthResults()', () {
      test('should clear all health results', () async {
        final checker = ProviderHealthChecker();
        final provider1 = _MockHealthyProvider();
        final provider2 = _MockProvider('provider-2');

        await checker.checkHealth(provider1);
        await checker.checkHealth(provider2);

        expect(checker.checkedCount, equals(2));

        checker.clearAllHealthResults();

        expect(checker.checkedCount, equals(0));
        expect(checker.isHealthy('test-provider'), isNull);
        expect(checker.isHealthy('provider-2'), isNull);
      });
    });

    group('getCheckedProviderIds()', () {
      test('should return empty list when no providers checked', () {
        final checker = ProviderHealthChecker();
        expect(checker.getCheckedProviderIds(), isEmpty);
      });

      test('should return list of checked provider IDs', () async {
        final checker = ProviderHealthChecker();
        final provider1 = _MockHealthyProvider();
        final provider2 = _MockProvider('provider-2');

        await checker.checkHealth(provider1);
        await checker.checkHealth(provider2);

        final ids = checker.getCheckedProviderIds();
        expect(ids.length, equals(2));
        expect(ids, contains('test-provider'));
        expect(ids, contains('provider-2'));
      });
    });

    group('checkedCount', () {
      test('should return zero initially', () {
        final checker = ProviderHealthChecker();
        expect(checker.checkedCount, equals(0));
      });

      test('should return correct count after checks', () async {
        final checker = ProviderHealthChecker();
        final provider1 = _MockHealthyProvider();
        final provider2 = _MockProvider('provider-2');

        expect(checker.checkedCount, equals(0));

        await checker.checkHealth(provider1);
        expect(checker.checkedCount, equals(1));

        await checker.checkHealth(provider2);
        expect(checker.checkedCount, equals(2));
      });
    });

    group('toString()', () {
      test('should return descriptive string representation', () async {
        final checker = ProviderHealthChecker();
        final provider1 = _MockProvider('provider-1', healthCheckResult: true);
        final provider2 = _MockProvider('provider-2', healthCheckResult: false);

        await checker.checkHealth(provider1);
        await checker.checkHealth(provider2);

        final str = checker.toString();
        expect(str, contains('ProviderHealthChecker'));
        expect(str, contains('checked: 2'));
        expect(str, contains('healthy: 1'));
        expect(str, contains('unhealthy: 1'));
        expect(str, contains('timeout'));
      });
    });
  });
}

// Mock providers for testing

class _MockProvider extends AiProvider {
  final String _id;
  final bool _healthCheckResult;
  final bool _throwError;
  final Exception? _errorToThrow;
  final bool _slow;

  _MockProvider(
    this._id, {
    bool healthCheckResult = true,
    bool throwError = false,
    Exception? errorToThrow,
    bool slow = false,
  })  : _healthCheckResult = healthCheckResult,
        _throwError = throwError,
        _errorToThrow = errorToThrow,
        _slow = slow;

  @override
  String get id => _id;

  @override
  String get name => 'Test Provider';

  @override
  ProviderCapabilities get capabilities => ProviderCapabilities(
        supportsChat: true,
      );

  @override
  Future<void> init(ProviderConfig config) async {
    // No-op
  }

  @override
  Future<bool> healthCheck() async {
    if (_slow) {
      await Future.delayed(Duration(seconds: 1));
    }
    if (_throwError && _errorToThrow != null) {
      throw _errorToThrow!;
    }
    return _healthCheckResult;
  }

  @override
  Future<ChatResponse> chat(ChatRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) {
    throw UnimplementedError();
  }
}

class _MockHealthyProvider extends _MockProvider {
  _MockHealthyProvider() : super('test-provider', healthCheckResult: true);
}

class _MockUnhealthyProvider extends _MockProvider {
  _MockUnhealthyProvider() : super('test-provider', healthCheckResult: false);
}

class _MockSlowProvider extends _MockProvider {
  _MockSlowProvider() : super('test-provider', slow: true);
}

class _MockAuthErrorProvider extends _MockProvider {
  _MockAuthErrorProvider()
      : super(
          'test-provider',
          throwError: true,
          errorToThrow: AuthError(
            message: 'Invalid API key',
            code: 'AUTH_ERROR',
            provider: 'test-provider',
          ),
        );
}

class _MockTransientErrorProvider extends _MockProvider {
  _MockTransientErrorProvider()
      : super(
          'test-provider',
          throwError: true,
          errorToThrow: TransientError(
            message: 'Server error',
            code: 'TRANSIENT_ERROR',
            provider: 'test-provider',
          ),
        );
}

class _MockProviderWithEmptyId extends _MockProvider {
  _MockProviderWithEmptyId() : super('', healthCheckResult: true);
}

class _MockModelFetcherProvider extends _MockProvider implements ModelFetcher {
  _MockModelFetcherProvider() : super('test-provider', healthCheckResult: true);

  @override
  Future<List<String>> fetchAvailableModels() async {
    return ['model-1', 'model-2'];
  }

  @override
  String inferModelType(String modelId) {
    return 'text';
  }
}
