import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/error_mapper.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';

void main() {
  group('ErrorMapper', () {
    group('mapHttpError', () {
      test('should map 429 to QuotaError', () {
        final response = http.Response(
          '{"error": {"message": "Rate limit exceeded", "type": "rate_limit_error"}}',
          429,
          headers: {'retry-after': '60'},
        );

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<QuotaError>());
        expect(error.message, equals('Rate limit exceeded'));
        expect(error.code, equals('rate_limit_error'));
        expect(error.provider, equals('openai'));
        expect((error as QuotaError).retryAfter, isNotNull);
      });

      test('should map 401 to AuthError', () {
        final response = http.Response(
          '{"error": {"message": "Invalid API key", "type": "invalid_api_key"}}',
          401,
        );

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<AuthError>());
        expect(error.message, equals('Invalid API key'));
        expect(error.code, equals('invalid_api_key'));
        expect(error.provider, equals('openai'));
      });

      test('should map 403 to AuthError', () {
        final response = http.Response(
          '{"error": {"message": "Forbidden", "type": "forbidden"}}',
          403,
        );

        final error = ErrorMapper.mapHttpError(response, 'anthropic');

        expect(error, isA<AuthError>());
        expect(error.message, equals('Forbidden'));
        expect(error.code, equals('forbidden'));
        expect(error.provider, equals('anthropic'));
      });

      test('should map 500 to TransientError', () {
        final response = http.Response(
          '{"error": {"message": "Internal server error", "type": "server_error"}}',
          500,
        );

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<TransientError>());
        expect(error.message, equals('Internal server error'));
        expect(error.code, equals('server_error'));
        expect(error.provider, equals('openai'));
      });

      test('should map 502 to TransientError', () {
        final response = http.Response('Bad Gateway', 502);

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<TransientError>());
        expect(error.message, equals('Bad Gateway'));
        expect(error.code, equals('SERVER_ERROR'));
      });

      test('should map 503 to TransientError', () {
        final response = http.Response('Service Unavailable', 503);

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<TransientError>());
        expect(error.message, equals('Service Unavailable'));
      });

      test('should map 400 to ClientError', () {
        final response = http.Response(
          '{"error": {"message": "Invalid request", "type": "invalid_request"}}',
          400,
        );

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<ClientError>());
        expect(error.message, equals('Invalid request'));
        expect(error.code, equals('invalid_request'));
      });

      test('should map 404 to ClientError', () {
        final response = http.Response('Not Found', 404);

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<ClientError>());
        expect(error.message, equals('Not Found'));
        expect(error.code, equals('CLIENT_ERROR'));
      });

      test('should map 409 to ClientError', () {
        final response = http.Response('Conflict', 409);

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<ClientError>());
        expect(error.message, equals('Conflict'));
      });

      test('should extract requestId from response', () {
        final response = http.Response(
          '{"error": {"message": "Error"}, "request_id": "req-123"}',
          400,
        );

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error.requestId, equals('req-123'));
      });

      test('should handle empty response body', () {
        final response = http.Response('', 500);

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<TransientError>());
        expect(error.message, equals('HTTP 500'));
      });

      test('should handle plain text error response', () {
        final response = http.Response('Simple error message', 400);

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<ClientError>());
        expect(error.message, equals('Simple error message'));
      });

      test('should handle invalid JSON gracefully', () {
        final response = http.Response('Invalid JSON {', 400);

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error, isA<ClientError>());
        expect(error.message, equals('Invalid JSON {'));
      });

      test('should parse Retry-After header as seconds', () {
        final response = http.Response(
          'Rate limit exceeded',
          429,
          headers: {'retry-after': '120'},
        );

        final error =
            ErrorMapper.mapHttpError(response, 'openai') as QuotaError;

        expect(error.retryAfter, isNotNull);
        final now = DateTime.now();
        final retryAfter = error.retryAfter!;
        final difference = retryAfter.difference(now).inSeconds;
        // Allow 1 second tolerance
        expect(difference, greaterThanOrEqualTo(119));
        expect(difference, lessThanOrEqualTo(121));
      });

      test('should parse Retry-After header as HTTP date', () {
        final futureDate = DateTime.now().add(const Duration(seconds: 60));
        final httpDate = HttpDate.format(futureDate);
        final response = http.Response(
          'Rate limit exceeded',
          429,
          headers: {'retry-after': httpDate},
        );

        final error =
            ErrorMapper.mapHttpError(response, 'openai') as QuotaError;

        expect(error.retryAfter, isNotNull);
        // Allow 1 second tolerance
        final difference =
            error.retryAfter!.difference(futureDate).inSeconds.abs();
        expect(difference, lessThanOrEqualTo(1));
      });

      test('should handle invalid Retry-After header', () {
        final response = http.Response(
          'Rate limit exceeded',
          429,
          headers: {'retry-after': 'invalid'},
        );

        final error =
            ErrorMapper.mapHttpError(response, 'openai') as QuotaError;

        expect(error.retryAfter, isNull);
      });

      test('should handle missing Retry-After header', () {
        final response = http.Response('Rate limit exceeded', 429);

        final error =
            ErrorMapper.mapHttpError(response, 'openai') as QuotaError;

        expect(error.retryAfter, isNull);
      });

      test('should preserve providerError from response', () {
        final providerError = {
          'type': 'rate_limit_error',
          'message': 'Rate limit exceeded',
          'limit': 100,
        };
        final response = http.Response(
          jsonEncode({'error': providerError}),
          429,
        );

        final error = ErrorMapper.mapHttpError(response, 'openai');

        expect(error.providerError, equals(providerError));
      });
    });

    group('mapException', () {
      test('should return AiException as-is', () {
        final originalError = TransientError(
          message: 'Already mapped',
          provider: 'openai',
        );

        final mapped = ErrorMapper.mapException(originalError, 'openai');

        expect(mapped, same(originalError));
      });

      test('should map SocketException to TransientError', () {
        final exception = SocketException('Connection refused');

        final error = ErrorMapper.mapException(exception, 'openai');

        expect(error, isA<TransientError>());
        expect(error.message, contains('Network error'));
        expect(error.message, contains('Connection refused'));
        expect(error.code, equals('NETWORK_ERROR'));
        expect(error.provider, equals('openai'));
      });

      test('should map timeout-like exceptions to TransientError', () {
        // Simulate a timeout exception with a message containing "timeout"
        final exception = Exception('Operation timed out');

        final error = ErrorMapper.mapException(exception, 'openai');

        expect(error, isA<TransientError>());
        expect(error.message, contains('Request timed out'));
        expect(error.message, contains('Operation timed out'));
        expect(error.code, equals('TIMEOUT'));
        expect(error.provider, equals('openai'));
      });

      test('should map timeout-like exceptions with "timed out" message', () {
        final exception = Exception('Connection timed out after 30 seconds');

        final error = ErrorMapper.mapException(exception, 'openai');

        expect(error, isA<TransientError>());
        expect(error.message, contains('Request timed out'));
        expect(error.code, equals('TIMEOUT'));
      });

      test('should map HttpException to TransientError', () {
        final exception = HttpException('HTTP error occurred');

        final error = ErrorMapper.mapException(exception, 'openai');

        expect(error, isA<TransientError>());
        expect(error.message, contains('HTTP error'));
        expect(error.message, contains('HTTP error occurred'));
        expect(error.code, equals('HTTP_ERROR'));
      });

      test('should map FormatException to ClientError', () {
        final exception = FormatException('Invalid JSON');

        final error = ErrorMapper.mapException(exception, 'openai');

        expect(error, isA<ClientError>());
        expect(error.message, contains('Invalid response format'));
        expect(error.message, contains('Invalid JSON'));
        expect(error.code, equals('PARSE_ERROR'));
      });

      test('should map unknown exception to ClientError', () {
        final exception = StateError('Some state error');

        final error = ErrorMapper.mapException(exception, 'openai');

        expect(error, isA<ClientError>());
        expect(error.message, contains('Some state error'));
        expect(error.code, equals('UNKNOWN_ERROR'));
        expect(error.provider, equals('openai'));
      });

      test('should map string exception to ClientError', () {
        final error = ErrorMapper.mapException('String error', 'openai');

        expect(error, isA<ClientError>());
        expect(error.message, equals('String error'));
        expect(error.code, equals('UNKNOWN_ERROR'));
      });

      test('should preserve provider in mapped exception', () {
        final exception = SocketException('Connection failed');

        final error = ErrorMapper.mapException(exception, 'anthropic');

        expect(error.provider, equals('anthropic'));
      });
    });

    group('Edge cases', () {
      test('should handle all 4xx status codes as ClientError', () {
        final statusCodes = [
          400,
          402,
          404,
          405,
          406,
          407,
          408,
          409,
          410,
          411,
          412,
          413,
          414,
          415,
          416,
          417,
          418,
          421,
          422,
          423,
          424,
          426,
          428,
          431,
          451
        ];

        for (final statusCode in statusCodes) {
          if (statusCode == 401 || statusCode == 403 || statusCode == 429) {
            continue; // These are handled separately
          }

          final response = http.Response('Error', statusCode);
          final error = ErrorMapper.mapHttpError(response, 'openai');

          expect(error, isA<ClientError>(),
              reason: 'Status code $statusCode should map to ClientError');
        }
      });

      test('should handle all 5xx status codes as TransientError', () {
        final statusCodes = [
          500,
          501,
          502,
          503,
          504,
          505,
          506,
          507,
          508,
          510,
          511
        ];

        for (final statusCode in statusCodes) {
          final response = http.Response('Error', statusCode);
          final error = ErrorMapper.mapHttpError(response, 'openai');

          expect(error, isA<TransientError>(),
              reason: 'Status code $statusCode should map to TransientError');
        }
      });

      test('should handle Retry-After with zero seconds', () {
        final response = http.Response(
          'Rate limit exceeded',
          429,
          headers: {'retry-after': '0'},
        );

        final error =
            ErrorMapper.mapHttpError(response, 'openai') as QuotaError;

        expect(error.retryAfter, isNotNull);
        // Zero seconds means retry immediately (now or very soon)
        final now = DateTime.now();
        final retryAfter = error.retryAfter!;
        final difference = retryAfter.difference(now).inSeconds.abs();
        expect(difference, lessThanOrEqualTo(1)); // Allow 1 second tolerance
      });

      test('should ignore Retry-After date in the past', () {
        final pastDate = DateTime.now().subtract(const Duration(seconds: 60));
        final httpDate = HttpDate.format(pastDate);
        final response = http.Response(
          'Rate limit exceeded',
          429,
          headers: {'retry-after': httpDate},
        );

        final error =
            ErrorMapper.mapHttpError(response, 'openai') as QuotaError;

        expect(error.retryAfter, isNull);
      });

      test('should handle case-insensitive Retry-After header', () {
        final response = http.Response(
          'Rate limit exceeded',
          429,
          headers: {'Retry-After': '60'},
        );

        final error =
            ErrorMapper.mapHttpError(response, 'openai') as QuotaError;

        expect(error.retryAfter, isNotNull);
      });
    });
  });
}
