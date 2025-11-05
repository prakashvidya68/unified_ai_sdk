import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/ai_exception.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';

void main() {
  group('TransientError', () {
    test('should create transient error with message', () {
      final error = TransientError(
        message: 'Request timed out',
      );

      expect(error, isA<AiException>());
      expect(error, isA<TransientError>());
      expect(error.message, equals('Request timed out'));
    });

    test('should create transient error with all fields', () {
      final error = TransientError(
        message: 'Server error',
        code: 'SERVER_ERROR',
        provider: 'openai',
        requestId: 'req-123',
      );

      expect(error.code, equals('SERVER_ERROR'));
      expect(error.provider, equals('openai'));
      expect(error.requestId, equals('req-123'));
    });

    test('should be catchable as AiException', () {
      final error = TransientError(message: 'Timeout');

      try {
        throw error;
      } on AiException catch (e) {
        expect(e, isA<TransientError>());
        expect(e.message, equals('Timeout'));
      }
    });

    test('should serialize to JSON', () {
      final error = TransientError(
        message: 'Server error',
        code: 'SERVER_ERROR',
        provider: 'openai',
      );

      final json = error.toJson();

      expect(json['type'], equals('TransientError'));
      expect(json['message'], equals('Server error'));
      expect(json['code'], equals('SERVER_ERROR'));
    });
  });

  group('QuotaError', () {
    test('should create quota error with message', () {
      final error = QuotaError(
        message: 'Rate limit exceeded',
      );

      expect(error, isA<AiException>());
      expect(error, isA<QuotaError>());
      expect(error.message, equals('Rate limit exceeded'));
      expect(error.retryAfter, isNull);
    });

    test('should create quota error with retryAfter', () {
      final retryAfter = DateTime.now().add(const Duration(seconds: 60));
      final error = QuotaError(
        message: 'Rate limit exceeded',
        retryAfter: retryAfter,
      );

      expect(error.retryAfter, equals(retryAfter));
    });

    test('should include retryAfter in toString', () {
      final retryAfter = DateTime(2024, 1, 1, 12, 0, 0);
      final error = QuotaError(
        message: 'Rate limit exceeded',
        retryAfter: retryAfter,
      );

      final str = error.toString();

      expect(str, contains('retryAfter'));
      expect(str, contains(retryAfter.toIso8601String()));
    });

    test('should include retryAfter in toJson', () {
      final retryAfter = DateTime(2024, 1, 1, 12, 0, 0);
      final error = QuotaError(
        message: 'Rate limit exceeded',
        retryAfter: retryAfter,
      );

      final json = error.toJson();

      expect(json['retryAfter'], equals(retryAfter.toIso8601String()));
    });

    test('should not include retryAfter in JSON if null', () {
      final error = QuotaError(
        message: 'Rate limit exceeded',
      );

      final json = error.toJson();

      expect(json.containsKey('retryAfter'), isFalse);
    });

    test('should be equal with same retryAfter', () {
      final retryAfter = DateTime(2024, 1, 1, 12, 0, 0);
      final error1 = QuotaError(
        message: 'Rate limit exceeded',
        retryAfter: retryAfter,
      );
      final error2 = QuotaError(
        message: 'Rate limit exceeded',
        retryAfter: retryAfter,
      );

      expect(error1, equals(error2));
      expect(error1.hashCode, equals(error2.hashCode));
    });

    test('should not be equal with different retryAfter', () {
      final retryAfter1 = DateTime(2024, 1, 1, 12, 0, 0);
      final retryAfter2 = DateTime(2024, 1, 1, 12, 1, 0);
      final error1 = QuotaError(
        message: 'Rate limit exceeded',
        retryAfter: retryAfter1,
      );
      final error2 = QuotaError(
        message: 'Rate limit exceeded',
        retryAfter: retryAfter2,
      );

      expect(error1, isNot(equals(error2)));
    });
  });

  group('AuthError', () {
    test('should create auth error with message', () {
      final error = AuthError(
        message: 'Invalid API key',
      );

      expect(error, isA<AiException>());
      expect(error, isA<AuthError>());
      expect(error.message, equals('Invalid API key'));
    });

    test('should create auth error with all fields', () {
      final error = AuthError(
        message: 'Authentication failed',
        code: 'INVALID_API_KEY',
        provider: 'openai',
        requestId: 'req-123',
      );

      expect(error.code, equals('INVALID_API_KEY'));
      expect(error.provider, equals('openai'));
    });

    test('should be catchable as AiException', () {
      final error = AuthError(message: 'Invalid credentials');

      try {
        throw error;
      } on AiException catch (e) {
        expect(e, isA<AuthError>());
        expect(e.message, equals('Invalid credentials'));
      }
    });

    test('should serialize to JSON', () {
      final error = AuthError(
        message: 'Invalid API key',
        code: 'INVALID_API_KEY',
        provider: 'openai',
      );

      final json = error.toJson();

      expect(json['type'], equals('AuthError'));
      expect(json['message'], equals('Invalid API key'));
    });
  });

  group('ClientError', () {
    test('should create client error with message', () {
      final error = ClientError(
        message: 'Invalid request',
      );

      expect(error, isA<AiException>());
      expect(error, isA<ClientError>());
      expect(error.message, equals('Invalid request'));
    });

    test('should create client error with all fields', () {
      final error = ClientError(
        message: 'Invalid model specified',
        code: 'INVALID_MODEL',
        provider: 'openai',
        providerError: {'model': 'invalid-model'},
      );

      expect(error.code, equals('INVALID_MODEL'));
      expect(error.providerError, equals({'model': 'invalid-model'}));
    });

    test('should be catchable as AiException', () {
      final error = ClientError(message: 'Bad request');

      try {
        throw error;
      } on AiException catch (e) {
        expect(e, isA<ClientError>());
        expect(e.message, equals('Bad request'));
      }
    });

    test('should serialize to JSON', () {
      final error = ClientError(
        message: 'Invalid request',
        code: 'VALIDATION_ERROR',
        provider: 'openai',
      );

      final json = error.toJson();

      expect(json['type'], equals('ClientError'));
      expect(json['message'], equals('Invalid request'));
    });
  });

  group('CapabilityError', () {
    test('should create capability error with message', () {
      final error = CapabilityError(
        message: 'Feature not supported',
      );

      expect(error, isA<AiException>());
      expect(error, isA<CapabilityError>());
      expect(error.message, equals('Feature not supported'));
    });

    test('should create capability error with all fields', () {
      final error = CapabilityError(
        message: 'Streaming not supported',
        code: 'STREAMING_NOT_SUPPORTED',
        provider: 'cohere',
      );

      expect(error.code, equals('STREAMING_NOT_SUPPORTED'));
      expect(error.provider, equals('cohere'));
    });

    test('should be catchable as AiException', () {
      final error = CapabilityError(message: 'Not supported');

      try {
        throw error;
      } on AiException catch (e) {
        expect(e, isA<CapabilityError>());
        expect(e.message, equals('Not supported'));
      }
    });

    test('should serialize to JSON', () {
      final error = CapabilityError(
        message: 'Feature not supported',
        code: 'UNSUPPORTED_FEATURE',
        provider: 'cohere',
      );

      final json = error.toJson();

      expect(json['type'], equals('CapabilityError'));
      expect(json['message'], equals('Feature not supported'));
    });
  });

  group('Exception type differentiation', () {
    test('should differentiate between exception types', () {
      final transient = TransientError(message: 'Error');
      final quota = QuotaError(message: 'Error');
      final auth = AuthError(message: 'Error');
      final client = ClientError(message: 'Error');
      final capability = CapabilityError(message: 'Error');

      expect(transient, isA<TransientError>());
      expect(transient, isNot(isA<QuotaError>()));
      expect(quota, isA<QuotaError>());
      expect(auth, isA<AuthError>());
      expect(client, isA<ClientError>());
      expect(capability, isA<CapabilityError>());
    });

    test('should all be catchable as AiException', () {
      final errors = [
        TransientError(message: 'Error'),
        QuotaError(message: 'Error'),
        AuthError(message: 'Error'),
        ClientError(message: 'Error'),
        CapabilityError(message: 'Error'),
      ];

      for (final error in errors) {
        try {
          throw error;
        } on AiException catch (e) {
          expect(e, isA<AiException>());
        }
      }
    });

    test('should have different runtime types', () {
      final transient = TransientError(message: 'Error');
      final quota = QuotaError(message: 'Error');
      final auth = AuthError(message: 'Error');
      final client = ClientError(message: 'Error');
      final capability = CapabilityError(message: 'Error');

      expect(transient.runtimeType.toString(), equals('TransientError'));
      expect(quota.runtimeType.toString(), equals('QuotaError'));
      expect(auth.runtimeType.toString(), equals('AuthError'));
      expect(client.runtimeType.toString(), equals('ClientError'));
      expect(capability.runtimeType.toString(), equals('CapabilityError'));
    });
  });

  group('Equality across types', () {
    test('should not be equal even with same message', () {
      final transient = TransientError(message: 'Error');
      final quota = QuotaError(message: 'Error');
      final auth = AuthError(message: 'Error');

      expect(transient, isNot(equals(quota)));
      expect(transient, isNot(equals(auth)));
      expect(quota, isNot(equals(auth)));
    });

    test('should be equal within same type with same values', () {
      final error1 = TransientError(
        message: 'Error',
        code: 'CODE',
        provider: 'openai',
      );
      final error2 = TransientError(
        message: 'Error',
        code: 'CODE',
        provider: 'openai',
      );

      expect(error1, equals(error2));
    });
  });

  group('toString() format', () {
    test('should include exception type name', () {
      final transient = TransientError(message: 'Error');
      final quota = QuotaError(message: 'Error');
      final auth = AuthError(message: 'Error');

      expect(transient.toString(), contains('TransientError'));
      expect(quota.toString(), contains('QuotaError'));
      expect(auth.toString(), contains('AuthError'));
    });

    test('should format QuotaError with retryAfter correctly', () {
      final retryAfter = DateTime(2024, 1, 1, 12, 0, 0);
      final error = QuotaError(
        message: 'Rate limit exceeded',
        retryAfter: retryAfter,
      );

      final str = error.toString();

      expect(str, startsWith('QuotaError: Rate limit exceeded'));
      expect(str, contains('retryAfter: ${retryAfter.toIso8601String()}'));
    });
  });
}
