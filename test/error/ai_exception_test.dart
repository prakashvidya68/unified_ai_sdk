import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/ai_exception.dart';

/// Test implementation of AiException for testing purposes.
class TestAiException extends AiException {
  TestAiException({
    required super.message,
    super.code,
    super.provider,
    super.providerError,
    super.requestId,
  });
}

void main() {
  group('AiException', () {
    group('Construction', () {
      test('should create exception with required message', () {
        final exception = TestAiException(
          message: 'Something went wrong',
        );

        expect(exception.message, equals('Something went wrong'));
        expect(exception.code, isNull);
        expect(exception.provider, isNull);
        expect(exception.providerError, isNull);
        expect(exception.requestId, isNull);
      });

      test('should create exception with all fields', () {
        final exception = TestAiException(
          message: 'Failed to connect',
          code: 'CONNECTION_ERROR',
          provider: 'openai',
          providerError: {'status': 500},
          requestId: 'req-123',
        );

        expect(exception.message, equals('Failed to connect'));
        expect(exception.code, equals('CONNECTION_ERROR'));
        expect(exception.provider, equals('openai'));
        expect(exception.providerError, equals({'status': 500}));
        expect(exception.requestId, equals('req-123'));
      });

      test('should throw assertion error if message is empty', () {
        expect(
          () => TestAiException(message: ''),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('toString()', () {
      test('should return string with message only', () {
        final exception = TestAiException(
          message: 'Something went wrong',
        );

        final str = exception.toString();

        expect(str, contains('TestAiException'));
        expect(str, contains('Something went wrong'));
        expect(str, isNot(contains('code')));
        expect(str, isNot(contains('provider')));
      });

      test('should include code in string representation', () {
        final exception = TestAiException(
          message: 'Failed to connect',
          code: 'CONNECTION_ERROR',
        );

        final str = exception.toString();

        expect(str, contains('CONNECTION_ERROR'));
        expect(str, contains('code: CONNECTION_ERROR'));
      });

      test('should include provider in string representation', () {
        final exception = TestAiException(
          message: 'Failed to connect',
          provider: 'openai',
        );

        final str = exception.toString();

        expect(str, contains('openai'));
        expect(str, contains('provider: openai'));
      });

      test('should include requestId in string representation', () {
        final exception = TestAiException(
          message: 'Failed to connect',
          requestId: 'req-123',
        );

        final str = exception.toString();

        expect(str, contains('req-123'));
        expect(str, contains('requestId: req-123'));
      });

      test('should include all optional fields', () {
        final exception = TestAiException(
          message: 'Failed to connect',
          code: 'CONNECTION_ERROR',
          provider: 'openai',
          requestId: 'req-123',
        );

        final str = exception.toString();

        expect(str, contains('CONNECTION_ERROR'));
        expect(str, contains('openai'));
        expect(str, contains('req-123'));
      });

      test('should format correctly with multiple fields', () {
        final exception = TestAiException(
          message: 'Rate limit exceeded',
          code: 'RATE_LIMIT',
          provider: 'openai',
          requestId: 'req-456',
        );

        final str = exception.toString();

        // Should have format: TestAiException: Rate limit exceeded (code: RATE_LIMIT, provider: openai, requestId: req-456)
        expect(str, startsWith('TestAiException: Rate limit exceeded'));
        expect(str, contains('code: RATE_LIMIT'));
        expect(str, contains('provider: openai'));
        expect(str, contains('requestId: req-456'));
      });
    });

    group('toJson()', () {
      test('should serialize exception to JSON with message only', () {
        final exception = TestAiException(
          message: 'Something went wrong',
        );

        final json = exception.toJson();

        expect(json['type'], equals('TestAiException'));
        expect(json['message'], equals('Something went wrong'));
        expect(json.containsKey('code'), isFalse);
        expect(json.containsKey('provider'), isFalse);
      });

      test('should serialize exception with all fields', () {
        final exception = TestAiException(
          message: 'Failed to connect',
          code: 'CONNECTION_ERROR',
          provider: 'openai',
          providerError: {'status': 500, 'error': 'Internal Server Error'},
          requestId: 'req-123',
        );

        final json = exception.toJson();

        expect(json['type'], equals('TestAiException'));
        expect(json['message'], equals('Failed to connect'));
        expect(json['code'], equals('CONNECTION_ERROR'));
        expect(json['provider'], equals('openai'));
        expect(json['providerError'],
            equals({'status': 500, 'error': 'Internal Server Error'}));
        expect(json['requestId'], equals('req-123'));
      });

      test('should serialize providerError even if complex', () {
        final complexError = {
          'error': {
            'message': 'Invalid request',
            'type': 'invalid_request_error',
            'param': 'model',
          },
        };
        final exception = TestAiException(
          message: 'Validation failed',
          providerError: complexError,
        );

        final json = exception.toJson();

        expect(json['providerError'], equals(complexError));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final exception1 = TestAiException(
          message: 'Failed to connect',
          code: 'CONNECTION_ERROR',
          provider: 'openai',
          requestId: 'req-123',
        );
        final exception2 = TestAiException(
          message: 'Failed to connect',
          code: 'CONNECTION_ERROR',
          provider: 'openai',
          requestId: 'req-123',
        );

        expect(exception1, equals(exception2));
        expect(exception1.hashCode, equals(exception2.hashCode));
      });

      test('should not be equal with different messages', () {
        final exception1 = TestAiException(message: 'Error 1');
        final exception2 = TestAiException(message: 'Error 2');

        expect(exception1, isNot(equals(exception2)));
      });

      test('should not be equal with different codes', () {
        final exception1 = TestAiException(
          message: 'Error',
          code: 'ERROR_1',
        );
        final exception2 = TestAiException(
          message: 'Error',
          code: 'ERROR_2',
        );

        expect(exception1, isNot(equals(exception2)));
      });

      test('should not be equal with different providers', () {
        final exception1 = TestAiException(
          message: 'Error',
          provider: 'openai',
        );
        final exception2 = TestAiException(
          message: 'Error',
          provider: 'anthropic',
        );

        expect(exception1, isNot(equals(exception2)));
      });

      test('should not be equal with different requestIds', () {
        final exception1 = TestAiException(
          message: 'Error',
          requestId: 'req-1',
        );
        final exception2 = TestAiException(
          message: 'Error',
          requestId: 'req-2',
        );

        expect(exception1, isNot(equals(exception2)));
      });

      test('should handle null providerError correctly', () {
        final exception1 = TestAiException(message: 'Error');
        final exception2 = TestAiException(
          message: 'Error',
          providerError: null,
        );

        expect(exception1, equals(exception2));
      });
    });

    group('Exception behavior', () {
      test('should be catchable as Exception', () {
        final exception = TestAiException(message: 'Test error');

        expect(exception, isA<Exception>());

        try {
          throw exception;
        } on Exception catch (e) {
          expect(e, isA<Exception>());
          expect(e, isA<AiException>());
          expect(e, isA<TestAiException>());
        }
      });

      test('should be catchable as AiException', () {
        final exception = TestAiException(message: 'Test error');

        try {
          throw exception;
        } on AiException catch (e) {
          expect(e.message, equals('Test error'));
        }
      });

      test('should preserve all fields when caught', () {
        final exception = TestAiException(
          message: 'Failed to connect',
          code: 'CONNECTION_ERROR',
          provider: 'openai',
          requestId: 'req-123',
        );

        try {
          throw exception;
        } on AiException catch (e) {
          expect(e.message, equals('Failed to connect'));
          expect(e.code, equals('CONNECTION_ERROR'));
          expect(e.provider, equals('openai'));
          expect(e.requestId, equals('req-123'));
        }
      });
    });

    group('Edge cases', () {
      test('should handle very long messages', () {
        final longMessage = 'A' * 1000;
        final exception = TestAiException(message: longMessage);

        expect(exception.message, equals(longMessage));
        expect(exception.toString(), contains(longMessage.substring(0, 50)));
      });

      test('should handle special characters in message', () {
        final exception = TestAiException(
          message: 'Error: "Invalid \'request\' with <special> chars & symbols',
        );

        expect(exception.message, contains('"'));
        expect(exception.message, contains("'"));
        expect(exception.message, contains('<'));
        expect(exception.message, contains('>'));
        expect(exception.message, contains('&'));
      });

      test('should handle empty string in optional fields', () {
        final exception = TestAiException(
          message: 'Error',
          code: '',
          provider: '',
          requestId: '',
        );

        expect(exception.code, equals(''));
        expect(exception.provider, equals(''));
        expect(exception.requestId, equals(''));
      });
    });
  });
}
