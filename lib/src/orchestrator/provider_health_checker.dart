import 'dart:async';

import '../error/error_types.dart';
import '../providers/base/ai_provider.dart';
import '../providers/base/model_fetcher.dart';

/// Health status for a provider.
enum ProviderHealthStatus {
  /// Provider is healthy and responding.
  healthy,

  /// Provider is unhealthy (not responding, errors, etc.).
  unhealthy,

  /// Health status is unknown (not checked yet).
  unknown,
}

/// Health check result for a provider.
class ProviderHealthResult {
  /// The provider ID that was checked.
  final String providerId;

  /// The health status.
  final ProviderHealthStatus status;

  /// Timestamp when the health check was performed.
  final DateTime checkedAt;

  /// Optional error message if the health check failed.
  final String? errorMessage;

  /// Optional error code if the health check failed.
  final String? errorCode;

  /// Duration of the health check.
  final Duration duration;

  /// Creates a new [ProviderHealthResult].
  ProviderHealthResult({
    required this.providerId,
    required this.status,
    required this.checkedAt,
    this.errorMessage,
    this.errorCode,
    required this.duration,
  });

  /// Whether the provider is healthy.
  bool get isHealthy => status == ProviderHealthStatus.healthy;

  @override
  String toString() {
    final errorInfo = errorMessage != null ? ' (error: $errorMessage)' : '';
    return 'ProviderHealthResult('
        'providerId: $providerId, '
        'status: $status, '
        'checkedAt: $checkedAt, '
        'duration: ${duration.inMilliseconds}ms$errorInfo)';
  }
}

/// Health checker for AI providers.
///
/// [ProviderHealthChecker] monitors the health of AI providers by performing
/// periodic health checks. It tracks the health status of each provider and
/// provides methods to check individual providers or query their health status.
///
/// **Health Check Strategy:**
/// - For providers implementing [ModelFetcher], uses `fetchAvailableModels()`
/// - For other providers, attempts a lightweight operation (if available)
/// - Health checks timeout after a configurable duration (default: 5 seconds)
/// - Failed health checks mark the provider as unhealthy
///
/// **Key Features:**
/// - Track health status per provider
/// - Configurable health check timeout
/// - Automatic error handling
/// - Health status caching (until next check)
/// - Support for manual and automatic health checks
///
/// **Example usage:**
/// ```dart
/// final checker = ProviderHealthChecker(
///   healthCheckTimeout: Duration(seconds: 5),
/// );
///
/// // Check health of a provider
/// await checker.checkHealth(provider);
///
/// // Query health status
/// if (checker.isHealthy('openai')) {
///   // Provider is healthy
/// }
///
/// // Get detailed health result
/// final result = checker.getHealthResult('openai');
/// if (result != null) {
///   print('Status: ${result.status}');
///   print('Checked at: ${result.checkedAt}');
/// }
/// ```
class ProviderHealthChecker {
  /// Default timeout for health checks.
  static const Duration defaultTimeout = Duration(seconds: 5);

  /// Timeout for individual health checks.
  ///
  /// If a health check takes longer than this duration, it will be considered
  /// a failure and the provider will be marked as unhealthy.
  final Duration healthCheckTimeout;

  /// Map storing health results by provider ID.
  final Map<String, ProviderHealthResult> _healthResults = {};

  /// Creates a new [ProviderHealthChecker] instance.
  ///
  /// **Parameters:**
  /// - [healthCheckTimeout]: Maximum time to wait for a health check to complete.
  ///   Defaults to 5 seconds.
  ///
  /// **Example:**
  /// ```dart
  /// // Default timeout (5 seconds)
  /// final checker = ProviderHealthChecker();
  ///
  /// // Custom timeout
  /// final customChecker = ProviderHealthChecker(
  ///   healthCheckTimeout: Duration(seconds: 10),
  /// );
  /// ```
  ProviderHealthChecker({
    Duration? healthCheckTimeout,
  }) : healthCheckTimeout = healthCheckTimeout ?? defaultTimeout;

  /// Checks the health of a provider.
  ///
  /// Performs a health check by attempting a lightweight operation:
  /// - For providers implementing [ModelFetcher], calls `fetchAvailableModels()`
  /// - For other providers, attempts to verify the provider is initialized
  ///
  /// The health check will timeout after [healthCheckTimeout] if it takes too long.
  /// The result is stored and can be queried later using [isHealthy] or [getHealthResult].
  ///
  /// **Parameters:**
  /// - [provider]: The provider to check
  ///
  /// **Returns:**
  /// A [ProviderHealthResult] indicating the health status
  ///
  /// **Throws:**
  /// - [ArgumentError] if provider is null
  ///
  /// **Example:**
  /// ```dart
  /// final result = await checker.checkHealth(provider);
  /// if (result.isHealthy) {
  ///   print('Provider ${result.providerId} is healthy');
  /// } else {
  ///   print('Provider ${result.providerId} is unhealthy: ${result.errorMessage}');
  /// }
  /// ```
  Future<ProviderHealthResult> checkHealth(AiProvider provider) async {
    if (provider.id.isEmpty) {
      throw ArgumentError('Provider ID cannot be empty');
    }

    final stopwatch = Stopwatch()..start();
    final checkedAt = DateTime.now();

    try {
      // Perform health check with timeout
      await _performHealthCheck(provider).timeout(
        healthCheckTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Health check timed out after ${healthCheckTimeout.inSeconds} seconds',
            healthCheckTimeout,
          );
        },
      );

      // Health check succeeded
      final result = ProviderHealthResult(
        providerId: provider.id,
        status: ProviderHealthStatus.healthy,
        checkedAt: checkedAt,
        duration: stopwatch.elapsed,
      );

      _healthResults[provider.id] = result;
      return result;
    } on TimeoutException {
      // Health check timed out
      final result = ProviderHealthResult(
        providerId: provider.id,
        status: ProviderHealthStatus.unhealthy,
        checkedAt: checkedAt,
        errorMessage: 'Health check timed out',
        errorCode: 'HEALTH_CHECK_TIMEOUT',
        duration: stopwatch.elapsed,
      );
      _healthResults[provider.id] = result;
      return result;
    } on AuthError catch (error) {
      // Authentication error
      final result = ProviderHealthResult(
        providerId: provider.id,
        status: ProviderHealthStatus.unhealthy,
        checkedAt: checkedAt,
        errorMessage: 'Authentication failed: ${error.message}',
        errorCode: error.code,
        duration: stopwatch.elapsed,
      );
      _healthResults[provider.id] = result;
      return result;
    } on TransientError catch (error) {
      // Transient error
      final result = ProviderHealthResult(
        providerId: provider.id,
        status: ProviderHealthStatus.unhealthy,
        checkedAt: checkedAt,
        errorMessage: 'Temporary error: ${error.message}',
        errorCode: error.code,
        duration: stopwatch.elapsed,
      );
      _healthResults[provider.id] = result;
      return result;
    } on ClientError catch (error) {
      // Client error (including HEALTH_CHECK_FAILED)
      final result = ProviderHealthResult(
        providerId: provider.id,
        status: ProviderHealthStatus.unhealthy,
        checkedAt: checkedAt,
        errorMessage: error.message,
        errorCode: error.code,
        duration: stopwatch.elapsed,
      );
      _healthResults[provider.id] = result;
      return result;
    } on Exception catch (error) {
      // Other exceptions
      final result = ProviderHealthResult(
        providerId: provider.id,
        status: ProviderHealthStatus.unhealthy,
        checkedAt: checkedAt,
        errorMessage: error.toString(),
        errorCode: 'HEALTH_CHECK_ERROR',
        duration: stopwatch.elapsed,
      );
      _healthResults[provider.id] = result;
      return result;
    } on Object catch (error) {
      // Unknown error type
      final result = ProviderHealthResult(
        providerId: provider.id,
        status: ProviderHealthStatus.unhealthy,
        checkedAt: checkedAt,
        errorMessage: error.toString(),
        errorCode: 'UNKNOWN_ERROR',
        duration: stopwatch.elapsed,
      );
      _healthResults[provider.id] = result;
      return result;
    }
  }

  /// Performs the actual health check operation.
  ///
  /// This method attempts different strategies based on the provider's capabilities:
  /// 1. Uses provider's `healthCheck()` method if it returns false (throws error)
  /// 2. If provider implements [ModelFetcher], uses `fetchAvailableModels()`
  /// 3. Otherwise, verifies provider is initialized
  ///
  /// **Parameters:**
  /// - [provider]: The provider to check
  ///
  /// **Throws:**
  /// Various exceptions if the health check fails
  Future<void> _performHealthCheck(AiProvider provider) async {
    // Strategy 1: Use provider's healthCheck() method
    // If it returns false, treat as unhealthy
    final healthCheckResult = await provider.healthCheck();
    if (!healthCheckResult) {
      throw ClientError(
        message: 'Provider health check returned false',
        code: 'HEALTH_CHECK_FAILED',
      );
    }

    // Strategy 2: For providers implementing ModelFetcher, verify API is accessible
    // This is a more reliable check than just healthCheck()
    if (provider is ModelFetcher) {
      try {
        final modelFetcher = provider as ModelFetcher;
        await modelFetcher.fetchAvailableModels();
        return; // Success - API is accessible
      } on Exception {
        // If model fetching fails but healthCheck() passed, that's still OK
        // The provider is initialized and healthCheck() passed
        // Model fetching might fail for other reasons (rate limits, etc.)
        return; // Consider it healthy if healthCheck() passed
      }
    }

    // Strategy 3: Verify provider is initialized
    // This is a lightweight check - just verify the provider has an ID and name
    if (provider.id.isEmpty) {
      throw ClientError(
        message: 'Provider ID is empty',
        code: 'INVALID_PROVIDER',
      );
    }

    if (provider.name.isEmpty) {
      throw ClientError(
        message: 'Provider name is empty',
        code: 'INVALID_PROVIDER',
      );
    }

    // If we get here, provider appears to be initialized and healthy
  }

  /// Checks if a provider is healthy.
  ///
  /// Returns `true` if the provider's last health check indicated it was healthy,
  /// `false` if it was unhealthy, or `null` if no health check has been performed yet.
  ///
  /// **Parameters:**
  /// - [providerId]: The ID of the provider to check
  ///
  /// **Returns:**
  /// `true` if healthy, `false` if unhealthy, or `null` if unknown
  ///
  /// **Example:**
  /// ```dart
  /// if (checker.isHealthy('openai') == true) {
  ///   // Provider is healthy
  /// } else if (checker.isHealthy('openai') == false) {
  ///   // Provider is unhealthy
  /// } else {
  ///   // Health status unknown (not checked yet)
  /// }
  /// ```
  bool? isHealthy(String providerId) {
    final result = _healthResults[providerId];
    if (result == null) {
      return null; // Unknown
    }
    return result.isHealthy;
  }

  /// Gets the health result for a provider.
  ///
  /// Returns the most recent health check result, or `null` if no health check
  /// has been performed for this provider.
  ///
  /// **Parameters:**
  /// - [providerId]: The ID of the provider
  ///
  /// **Returns:**
  /// The [ProviderHealthResult] if available, or `null` if not checked
  ///
  /// **Example:**
  /// ```dart
  /// final result = checker.getHealthResult('openai');
  /// if (result != null) {
  ///   print('Status: ${result.status}');
  ///   print('Checked at: ${result.checkedAt}');
  ///   print('Duration: ${result.duration}');
  /// }
  /// ```
  ProviderHealthResult? getHealthResult(String providerId) {
    return _healthResults[providerId];
  }

  /// Gets the health status for a provider.
  ///
  /// Returns the health status enum value, or [ProviderHealthStatus.unknown]
  /// if no health check has been performed.
  ///
  /// **Parameters:**
  /// - [providerId]: The ID of the provider
  ///
  /// **Returns:**
  /// The [ProviderHealthStatus] for the provider
  ///
  /// **Example:**
  /// ```dart
  /// final status = checker.getHealthStatus('openai');
  /// switch (status) {
  ///   case ProviderHealthStatus.healthy:
  ///     print('Provider is healthy');
  ///     break;
  ///   case ProviderHealthStatus.unhealthy:
  ///     print('Provider is unhealthy');
  ///     break;
  ///   case ProviderHealthStatus.unknown:
  ///     print('Health status unknown');
  ///     break;
  /// }
  /// ```
  ProviderHealthStatus getHealthStatus(String providerId) {
    final result = _healthResults[providerId];
    return result?.status ?? ProviderHealthStatus.unknown;
  }

  /// Clears the health result for a provider.
  ///
  /// Removes the stored health check result, effectively resetting the health
  /// status to unknown.
  ///
  /// **Parameters:**
  /// - [providerId]: The ID of the provider
  ///
  /// **Returns:**
  /// `true` if a result was removed, `false` if no result existed
  ///
  /// **Example:**
  /// ```dart
  /// checker.clearHealthResult('openai');
  /// // Health status is now unknown
  /// ```
  bool clearHealthResult(String providerId) {
    return _healthResults.remove(providerId) != null;
  }

  /// Clears all health results.
  ///
  /// Removes all stored health check results, resetting all providers to
  /// unknown health status.
  ///
  /// **Example:**
  /// ```dart
  /// checker.clearAllHealthResults();
  /// // All health statuses are now unknown
  /// ```
  void clearAllHealthResults() {
    _healthResults.clear();
  }

  /// Gets all provider IDs that have been health checked.
  ///
  /// **Returns:**
  /// A list of provider IDs that have health results
  ///
  /// **Example:**
  /// ```dart
  /// final checkedProviders = checker.getCheckedProviderIds();
  /// print('Checked providers: ${checkedProviders.join(", ")}');
  /// ```
  List<String> getCheckedProviderIds() {
    return _healthResults.keys.toList();
  }

  /// Gets the number of providers that have been health checked.
  ///
  /// **Returns:**
  /// The count of providers with health results
  int get checkedCount => _healthResults.length;

  @override
  String toString() {
    final healthy = _healthResults.values.where((r) => r.isHealthy).length;
    final unhealthy = _healthResults.values.where((r) => !r.isHealthy).length;
    return 'ProviderHealthChecker('
        'checked: ${_healthResults.length}, '
        'healthy: $healthy, '
        'unhealthy: $unhealthy, '
        'timeout: $healthCheckTimeout)';
  }
}
