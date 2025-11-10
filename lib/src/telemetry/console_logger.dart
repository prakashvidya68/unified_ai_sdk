import 'dart:developer' as developer;

import 'telemetry_handler.dart';
import '../error/ai_exception.dart';

/// Log levels for controlling console output verbosity.
///
/// Log levels are ordered from most verbose (debug) to least verbose (error).
/// When a log level is set, all messages at that level and above are displayed.
///
/// **Level hierarchy:**
/// - [debug]: Most verbose - shows all events (requests, responses, errors)
/// - [info]: Shows important events (requests, responses, errors)
/// - [warning]: Shows warnings and errors only
/// - [error]: Shows errors only
///
/// **Example:**
/// ```dart
/// // Show all events
/// final logger = ConsoleLogger(level: LogLevel.debug);
///
/// // Show only important events
/// final logger = ConsoleLogger(level: LogLevel.info);
///
/// // Show only errors
/// final logger = ConsoleLogger(level: LogLevel.error);
/// ```
enum LogLevel {
  /// Debug level - shows all telemetry events.
  ///
  /// Most verbose level. Logs all requests, responses, and errors.
  /// Useful for development and debugging.
  debug,

  /// Info level - shows important events.
  ///
  /// Logs requests, responses, and errors. Similar to debug but may
  /// exclude some verbose details.
  info,

  /// Warning level - shows warnings and errors.
  ///
  /// Only logs warnings and errors. Requests and successful responses
  /// are not logged.
  warning,

  /// Error level - shows errors only.
  ///
  /// Least verbose level. Only logs errors. Useful for production
  /// when you only want to see problems.
  error,
}

/// Console logger implementation of [TelemetryHandler].
///
/// [ConsoleLogger] provides a simple way to log SDK telemetry events to
/// the console for debugging and monitoring. It supports different log levels
/// to control verbosity and can be easily integrated into the SDK.
///
/// **Key Features:**
/// - **Log levels**: Control verbosity with [LogLevel] enum
/// - **Formatted output**: Human-readable log messages with timestamps
/// - **Error handling**: Gracefully handles errors without affecting SDK
/// - **Request tracking**: Logs request initiation with provider and operation
/// - **Response tracking**: Logs successful responses with latency and tokens
/// - **Error tracking**: Logs errors with full context
///
/// **Example usage:**
/// ```dart
/// // Create logger with debug level (most verbose)
/// final logger = ConsoleLogger(level: LogLevel.debug);
///
/// // Use in SDK configuration
/// await UnifiedAI.init(UnifiedAIConfig(
///   telemetryHandlers: [logger],
///   // ... other config
/// ));
///
/// // Example output:
/// // [2024-01-15 10:30:45.123] 📤 REQUEST: openai.chat (req-123)
/// // [2024-01-15 10:30:46.456] ✅ RESPONSE: 1333ms, 250 tokens (req-123)
/// ```
///
/// **Log Level Examples:**
/// ```dart
/// // Debug: Shows everything
/// ConsoleLogger(level: LogLevel.debug);
/// // Output: All requests, responses, and errors
///
/// // Info: Shows important events
/// ConsoleLogger(level: LogLevel.info);
/// // Output: Requests, responses, and errors
///
/// // Warning: Shows warnings and errors only
/// ConsoleLogger(level: LogLevel.warning);
/// // Output: Only errors (no requests/responses)
///
/// // Error: Shows errors only
/// ConsoleLogger(level: LogLevel.error);
/// // Output: Only errors
/// ```
///
/// **Thread Safety:**
/// This implementation is thread-safe. Multiple threads can safely call
/// logging methods concurrently.
///
/// **Error Handling:**
/// This logger never throws exceptions. If an error occurs during logging
/// (e.g., formatting error), it is silently ignored to prevent affecting
/// the SDK's operation.
class ConsoleLogger implements TelemetryHandler {
  /// The minimum log level to display.
  ///
  /// Events at this level or higher (more severe) will be logged.
  /// Events below this level will be ignored.
  final LogLevel level;

  /// Creates a new [ConsoleLogger] instance.
  ///
  /// **Parameters:**
  /// - [level]: Minimum log level to display. Defaults to [LogLevel.info].
  ///
  /// **Example:**
  /// ```dart
  /// // Default info level
  /// final logger = ConsoleLogger();
  ///
  /// // Debug level (most verbose)
  /// final debugLogger = ConsoleLogger(level: LogLevel.debug);
  ///
  /// // Error level (least verbose)
  /// final errorLogger = ConsoleLogger(level: LogLevel.error);
  /// ```
  ConsoleLogger({this.level = LogLevel.info});

  @override
  Future<void> onRequest(RequestTelemetry event) async {
    // Only log requests at debug or info level
    if (level.index <= LogLevel.info.index) {
      _logRequest(event);
    }
  }

  @override
  Future<void> onResponse(ResponseTelemetry event) async {
    // Only log responses at debug or info level
    if (level.index <= LogLevel.info.index) {
      _logResponse(event);
    }
  }

  @override
  Future<void> onError(ErrorTelemetry event) async {
    // Always log errors (all levels)
    _logError(event);
  }

  /// Logs a request event to the console.
  void _logRequest(RequestTelemetry event) {
    try {
      final message =
          '📤 REQUEST: ${event.provider}.${event.operation} (${event.requestId})';
      developer.log(
        message,
        name: 'UnifiedAI',
        time: event.timestamp,
        level: level.index,
      );

      // Log metadata at debug level
      if (level == LogLevel.debug && event.metadata != null) {
        developer.log(
          '    Metadata: ${event.metadata}',
          name: 'UnifiedAI',
          time: event.timestamp,
          level: level.index,
        );
      }
    } on Object {
      // Silently ignore logging errors
    }
  }

  /// Logs a response event to the console.
  void _logResponse(ResponseTelemetry event) {
    try {
      final timestamp = DateTime.now();
      final latency = event.latency.inMilliseconds;
      final tokens = event.tokensUsed != null
          ? '${event.tokensUsed} tokens'
          : 'tokens unknown';
      final cache = event.cached ? ' (cached)' : '';
      final message =
          '✅ RESPONSE: ${latency}ms, $tokens$cache (${event.requestId})';
      developer.log(
        message,
        name: 'UnifiedAI',
        time: timestamp,
        level: level.index,
      );

      // Log metadata at debug level
      if (level == LogLevel.debug && event.metadata != null) {
        developer.log(
          '    Metadata: ${event.metadata}',
          name: 'UnifiedAI',
          time: timestamp,
          level: level.index,
        );
      }
    } on Object {
      // Silently ignore logging errors
    }
  }

  /// Logs an error event to the console.
  void _logError(ErrorTelemetry event) {
    try {
      final provider = event.provider ?? 'unknown';
      final operation = event.operation ?? 'unknown';
      final errorType = event.error.runtimeType.toString();

      // Format error message
      String errorMessage;
      String? errorCode;

      if (event.error is AiException) {
        final aiError = event.error as AiException;
        errorMessage = aiError.message;
        errorCode = aiError.code;
      } else {
        errorMessage = event.error.toString();
      }

      // Main error log
      final errorTimestamp = event.timestamp;
      developer.log(
        '❌ ERROR: $provider.$operation (${event.requestId})\n'
        '    Type: $errorType\n'
        '${errorCode != null ? '    Code: $errorCode\n' : ''}'
        '    Message: $errorMessage',
        name: 'UnifiedAI',
        time: errorTimestamp,
        level: LogLevel.error.index,
        error: event.error,
      );

      // Log metadata at debug level
      if (level == LogLevel.debug) {
        if (event.metadata != null) {
          developer.log(
            '    Metadata: ${event.metadata}',
            name: 'UnifiedAI',
            time: errorTimestamp,
            level: LogLevel.debug.index,
          );
        }
        // Log full error details at debug level
        developer.log(
          '    Full error: ${event.error}',
          name: 'UnifiedAI',
          time: errorTimestamp,
          level: LogLevel.debug.index,
          error: event.error,
        );
      }
    } on Object {
      // Silently ignore logging errors
    }
  }
}
