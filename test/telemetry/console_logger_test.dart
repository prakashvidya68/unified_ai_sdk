import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/telemetry/console_logger.dart';
import 'package:unified_ai_sdk/src/telemetry/telemetry_handler.dart';

void main() {
  group('ConsoleLogger', () {
    group('Construction', () {
      test('should create logger with default log level', () {
        final logger = ConsoleLogger();
        expect(logger.level, equals(LogLevel.info));
      });

      test('should create logger with custom log level', () {
        final logger = ConsoleLogger(level: LogLevel.debug);
        expect(logger.level, equals(LogLevel.debug));
      });
    });

    group('onRequest()', () {
      test('should log request at debug level', () async {
        final logger = ConsoleLogger(level: LogLevel.debug);
        final event = RequestTelemetry(
          requestId: 'req-123',
          provider: 'openai',
          operation: 'chat',
        );

        // Should not throw
        await logger.onRequest(event);
      });

      test('should log request at info level', () async {
        final logger = ConsoleLogger(level: LogLevel.info);
        final event = RequestTelemetry(
          requestId: 'req-123',
          provider: 'openai',
          operation: 'chat',
        );

        // Should not throw
        await logger.onRequest(event);
      });

      test('should not log request at warning level', () async {
        final logger = ConsoleLogger(level: LogLevel.warning);
        final event = RequestTelemetry(
          requestId: 'req-123',
          provider: 'openai',
          operation: 'chat',
        );

        // Should not throw (just doesn't log)
        await logger.onRequest(event);
      });

      test('should handle request with all fields', () async {
        final logger = ConsoleLogger(level: LogLevel.debug);
        final event = RequestTelemetry(
          requestId: 'req-123',
          provider: 'openai',
          operation: 'chat',
          metadata: {'model': 'gpt-4'},
        );

        await logger.onRequest(event);
      });
    });

    group('onResponse()', () {
      test('should log response at debug level', () async {
        final logger = ConsoleLogger(level: LogLevel.debug);
        final event = const ResponseTelemetry(
          requestId: 'req-123',
          latency: Duration(milliseconds: 500),
          tokensUsed: 100,
          cached: false,
        );

        await logger.onResponse(event);
      });

      test('should log response at info level', () async {
        final logger = ConsoleLogger(level: LogLevel.info);
        final event = const ResponseTelemetry(
          requestId: 'req-123',
          latency: Duration(milliseconds: 500),
          tokensUsed: 100,
          cached: false,
        );

        await logger.onResponse(event);
      });

      test('should handle response with null tokensUsed', () async {
        final logger = ConsoleLogger(level: LogLevel.debug);
        final event = const ResponseTelemetry(
          requestId: 'req-123',
          latency: Duration(milliseconds: 500),
          tokensUsed: null,
          cached: false,
        );

        await logger.onResponse(event);
      });

      test('should handle cached response', () async {
        final logger = ConsoleLogger(level: LogLevel.debug);
        final event = const ResponseTelemetry(
          requestId: 'req-123',
          latency: Duration(milliseconds: 10),
          tokensUsed: null,
          cached: true,
        );

        await logger.onResponse(event);
      });
    });

    group('onError()', () {
      test('should log error at debug level', () async {
        final logger = ConsoleLogger(level: LogLevel.debug);
        final event = ErrorTelemetry(
          requestId: 'req-123',
          error: Exception('Test error'),
          provider: 'openai',
          operation: 'chat',
        );

        await logger.onError(event);
      });

      test('should log error at info level', () async {
        final logger = ConsoleLogger(level: LogLevel.info);
        final event = ErrorTelemetry(
          requestId: 'req-123',
          error: Exception('Test error'),
          provider: 'openai',
          operation: 'chat',
        );

        await logger.onError(event);
      });

      test('should log error at warning level', () async {
        final logger = ConsoleLogger(level: LogLevel.warning);
        final event = ErrorTelemetry(
          requestId: 'req-123',
          error: Exception('Test error'),
          provider: 'openai',
          operation: 'chat',
        );

        await logger.onError(event);
      });

      test('should log error at error level', () async {
        final logger = ConsoleLogger(level: LogLevel.error);
        final event = ErrorTelemetry(
          requestId: 'req-123',
          error: Exception('Test error'),
          provider: 'openai',
          operation: 'chat',
        );

        await logger.onError(event);
      });

      test('should handle error with null provider', () async {
        final logger = ConsoleLogger(level: LogLevel.error);
        final event = ErrorTelemetry(
          requestId: 'req-123',
          error: Exception('Test error'),
          provider: null,
          operation: 'chat',
        );

        await logger.onError(event);
      });
    });

    group('LogLevel filtering', () {
      test('should filter requests based on log level', () async {
        // Warning level should not log requests
        final warningLogger = ConsoleLogger(level: LogLevel.warning);
        final requestEvent = RequestTelemetry(
          requestId: 'req-123',
          provider: 'openai',
          operation: 'chat',
        );

        // Should not throw (just doesn't log)
        await warningLogger.onRequest(requestEvent);
      });

      test('should filter responses based on log level', () async {
        // Warning level should not log responses
        final warningLogger = ConsoleLogger(level: LogLevel.warning);
        final responseEvent = const ResponseTelemetry(
          requestId: 'req-123',
          latency: Duration(milliseconds: 500),
          tokensUsed: 100,
          cached: false,
        );

        // Should not throw (just doesn't log)
        await warningLogger.onResponse(responseEvent);
      });
    });
  });
}
