import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';

void main() {
  group('Authentication', () {
    group('ApiKeyAuth', () {
      test('should create instance with valid API key', () {
        final auth = ApiKeyAuth(apiKey: 'sk-abc123');
        expect(auth.apiKey, equals('sk-abc123'));
        expect(auth.headerName, equals('Authorization'));
      });

      test('should use custom header name when provided', () {
        final auth = ApiKeyAuth(
          apiKey: 'sk-abc123',
          headerName: 'x-api-key',
        );
        expect(auth.headerName, equals('x-api-key'));
      });

      test('should throw ClientError when API key is empty', () {
        expect(
          () => ApiKeyAuth(apiKey: ''),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_API_KEY',
          )),
        );
      });

      test('should throw ClientError when header name is empty', () {
        expect(
          () => ApiKeyAuth(apiKey: 'sk-abc123', headerName: ''),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_HEADER_NAME',
          )),
        );
      });

      group('buildHeaders', () {
        test('should return Bearer token format for Authorization header', () {
          final auth = ApiKeyAuth(apiKey: 'sk-abc123');
          final headers = auth.buildHeaders();

          expect(headers.length, equals(1));
          expect(headers['Authorization'], equals('Bearer sk-abc123'));
        });

        test(
            'should return Bearer token format for case-insensitive Authorization',
            () {
          final auth =
              ApiKeyAuth(apiKey: 'sk-abc123', headerName: 'AUTHORIZATION');
          final headers = auth.buildHeaders();

          expect(headers['AUTHORIZATION'], equals('Bearer sk-abc123'));
        });

        test('should return raw API key for custom headers', () {
          final auth = ApiKeyAuth(
            apiKey: 'sk-abc123',
            headerName: 'x-api-key',
          );
          final headers = auth.buildHeaders();

          expect(headers.length, equals(1));
          expect(headers['x-api-key'], equals('sk-abc123'));
        });

        test('should return raw API key for X-API-Key header', () {
          final auth = ApiKeyAuth(
            apiKey: 'sk-abc123',
            headerName: 'X-API-Key',
          );
          final headers = auth.buildHeaders();

          expect(headers['X-API-Key'], equals('sk-abc123'));
        });

        test('should work with various API key formats', () {
          final testCases = [
            'sk-abc123',
            'sk-ant-abc123',
            'sk-proj-abc123',
            'simple-key',
            'very-long-api-key-with-many-characters-123456789',
          ];

          for (final apiKey in testCases) {
            final auth = ApiKeyAuth(apiKey: apiKey);
            final headers = auth.buildHeaders();
            expect(headers['Authorization'], equals('Bearer $apiKey'));
          }
        });
      });

      group('equality', () {
        test('should be equal when API key and header name match', () {
          final auth1 = ApiKeyAuth(apiKey: 'sk-abc123');
          final auth2 = ApiKeyAuth(apiKey: 'sk-abc123');

          expect(auth1, equals(auth2));
          expect(auth1.hashCode, equals(auth2.hashCode));
        });

        test('should not be equal when API keys differ', () {
          final auth1 = ApiKeyAuth(apiKey: 'sk-abc123');
          final auth2 = ApiKeyAuth(apiKey: 'sk-xyz789');

          expect(auth1, isNot(equals(auth2)));
        });

        test('should not be equal when header names differ', () {
          final auth1 = ApiKeyAuth(apiKey: 'sk-abc123');
          final auth2 = ApiKeyAuth(
            apiKey: 'sk-abc123',
            headerName: 'x-api-key',
          );

          expect(auth1, isNot(equals(auth2)));
        });
      });

      group('toString', () {
        test('should mask API key in toString for security', () {
          final auth = ApiKeyAuth(apiKey: 'sk-very-long-api-key-123456789');
          final str = auth.toString();

          expect(str, contains('ApiKeyAuth'));
          expect(str, contains('headerName'));
          expect(str, isNot(contains('sk-very-long-api-key-123456789')));
          // Should contain masked version (first 4 chars + last 4 chars)
          expect(str, contains('sk-v'));
          expect(str, contains('6789'));
        });

        test('should handle short API keys in toString', () {
          final auth = ApiKeyAuth(apiKey: 'sk-abc');
          final str = auth.toString();

          expect(str, contains('ApiKeyAuth'));
          expect(str, isNot(contains('sk-abc')));
          expect(str, contains('***'));
        });
      });
    });

    group('CustomHeaderAuth', () {
      test('should create instance with valid headers', () {
        final auth = CustomHeaderAuth({
          'X-API-Key': 'custom-key',
        });

        expect(auth.headers['X-API-Key'], equals('custom-key'));
      });

      test('should throw ClientError when headers map is empty', () {
        expect(
          () => CustomHeaderAuth({}),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_HEADERS',
          )),
        );
      });

      test('should throw ClientError when header name is empty', () {
        expect(
          () => CustomHeaderAuth({'': 'value'}),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_HEADER_NAME',
          )),
        );
      });

      test('should throw ClientError when header value is empty', () {
        expect(
          () => CustomHeaderAuth({'X-API-Key': ''}),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_HEADER_VALUE',
          )),
        );
      });

      test('should validate all headers during construction', () {
        expect(
          () => CustomHeaderAuth({
            'X-API-Key': 'valid',
            '': 'invalid', // Empty key
          }),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_HEADER_NAME',
          )),
        );
      });

      group('buildHeaders', () {
        test('should return single header', () {
          final auth = CustomHeaderAuth({
            'X-API-Key': 'custom-key',
          });
          final headers = auth.buildHeaders();

          expect(headers.length, equals(1));
          expect(headers['X-API-Key'], equals('custom-key'));
        });

        test('should return multiple headers', () {
          final auth = CustomHeaderAuth({
            'X-API-Key': 'api-key-value',
            'X-Client-ID': 'client-123',
            'X-Client-Secret': 'secret-456',
          });
          final headers = auth.buildHeaders();

          expect(headers.length, equals(3));
          expect(headers['X-API-Key'], equals('api-key-value'));
          expect(headers['X-Client-ID'], equals('client-123'));
          expect(headers['X-Client-Secret'], equals('secret-456'));
        });

        test('should return a copy of headers (prevent external modification)',
            () {
          final auth = CustomHeaderAuth({
            'X-API-Key': 'original-key',
          });

          final headers1 = auth.buildHeaders();
          headers1['X-API-Key'] = 'modified-key';

          final headers2 = auth.buildHeaders();
          expect(headers2['X-API-Key'], equals('original-key'));
        });

        test('should work with various header name formats', () {
          final testCases = [
            {'Authorization': 'Bearer token'},
            {'x-api-key': 'key-value'},
            {'X-API-Key': 'key-value'},
            {'custom-header': 'value'},
            {'Another-Header-Name': 'value'},
          ];

          for (final headers in testCases) {
            final auth = CustomHeaderAuth(headers);
            final builtHeaders = auth.buildHeaders();
            expect(builtHeaders, equals(headers));
          }
        });
      });

      group('equality', () {
        test('should be equal when headers match', () {
          final auth1 = CustomHeaderAuth({
            'X-API-Key': 'key',
            'X-Client-ID': 'id',
          });
          final auth2 = CustomHeaderAuth({
            'X-API-Key': 'key',
            'X-Client-ID': 'id',
          });

          expect(auth1, equals(auth2));
          expect(auth1.hashCode, equals(auth2.hashCode));
        });

        test('should not be equal when headers differ', () {
          final auth1 = CustomHeaderAuth({'X-API-Key': 'key1'});
          final auth2 = CustomHeaderAuth({'X-API-Key': 'key2'});

          expect(auth1, isNot(equals(auth2)));
        });

        test('should not be equal when header count differs', () {
          final auth1 = CustomHeaderAuth({'X-API-Key': 'key'});
          final auth2 = CustomHeaderAuth({
            'X-API-Key': 'key',
            'X-Client-ID': 'id',
          });

          expect(auth1, isNot(equals(auth2)));
        });

        test('should be equal regardless of header order', () {
          final auth1 = CustomHeaderAuth({
            'X-API-Key': 'key',
            'X-Client-ID': 'id',
          });
          final auth2 = CustomHeaderAuth({
            'X-Client-ID': 'id',
            'X-API-Key': 'key',
          });

          expect(auth1, equals(auth2));
        });
      });

      group('toString', () {
        test('should include header names in toString', () {
          final auth = CustomHeaderAuth({
            'X-API-Key': 'key',
            'X-Client-ID': 'id',
          });
          final str = auth.toString();

          expect(str, contains('CustomHeaderAuth'));
          expect(str, contains('X-API-Key'));
          expect(str, contains('X-Client-ID'));
        });

        test('should not expose header values in toString', () {
          final auth = CustomHeaderAuth({
            'X-API-Key': 'secret-key-value',
          });
          final str = auth.toString();

          expect(str, isNot(contains('secret-key-value')));
        });
      });
    });

    group('Integration tests', () {
      test('ApiKeyAuth should work with OpenAI-style authentication', () {
        final auth = ApiKeyAuth(apiKey: 'sk-openai-abc123');
        final headers = auth.buildHeaders();

        expect(headers, equals({'Authorization': 'Bearer sk-openai-abc123'}));
      });

      test('ApiKeyAuth should work with Anthropic-style authentication', () {
        final auth = ApiKeyAuth(
          apiKey: 'sk-ant-abc123',
          headerName: 'x-api-key',
        );
        final headers = auth.buildHeaders();

        expect(headers, equals({'x-api-key': 'sk-ant-abc123'}));
      });

      test('CustomHeaderAuth should work with complex auth schemes', () {
        final auth = CustomHeaderAuth({
          'X-API-Key': 'api-key',
          'X-Client-ID': 'client-123',
          'X-Client-Secret': 'secret-456',
          'X-Request-ID': 'req-789',
        });
        final headers = auth.buildHeaders();

        expect(headers.length, equals(4));
        expect(headers['X-API-Key'], equals('api-key'));
        expect(headers['X-Client-ID'], equals('client-123'));
        expect(headers['X-Client-Secret'], equals('secret-456'));
        expect(headers['X-Request-ID'], equals('req-789'));
      });

      test('Both auth types should implement Authentication interface', () {
        final apiKeyAuth = ApiKeyAuth(apiKey: 'sk-abc123');
        final customAuth = CustomHeaderAuth({'X-API-Key': 'key'});

        expect(apiKeyAuth, isA<Authentication>());
        expect(customAuth, isA<Authentication>());

        // Both should have buildHeaders method
        expect(apiKeyAuth.buildHeaders(), isA<Map<String, String>>());
        expect(customAuth.buildHeaders(), isA<Map<String, String>>());
      });
    });
  });
}
