import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';

void main() {
  group('ProviderConfig', () {
    late ApiKeyAuth testAuth;

    setUp(() {
      testAuth = ApiKeyAuth(apiKey: 'sk-test-abc123');
    });

    group('construction', () {
      test('should create instance with required fields', () {
        final config = ProviderConfig(
          id: 'test-provider',
          auth: testAuth,
        );

        expect(config.id, equals('test-provider'));
        expect(config.auth, equals(testAuth));
        expect(config.settings, isEmpty);
        expect(config.timeout, isNull);
      });

      test('should create instance with all fields', () {
        final settings = {
          'baseUrl': 'https://api.example.com',
          'model': 'gpt-4'
        };
        final timeout = Duration(seconds: 30);

        final config = ProviderConfig(
          id: 'test-provider',
          auth: testAuth,
          settings: settings,
          timeout: timeout,
        );

        expect(config.id, equals('test-provider'));
        expect(config.auth, equals(testAuth));
        expect(config.settings, equals(settings));
        expect(config.timeout, equals(timeout));
      });

      test('should throw ClientError when id is empty', () {
        expect(
          () => ProviderConfig(id: '', auth: testAuth),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_PROVIDER_ID',
          )),
        );
      });

      test('should make settings unmodifiable', () {
        final settings = {'key': 'value'};
        final config = ProviderConfig(
          id: 'test',
          auth: testAuth,
          settings: settings,
        );

        expect(() => config.settings['newKey'] = 'newValue',
            throwsA(isA<UnsupportedError>()));
      });

      test('should use empty map when settings is null', () {
        final config = ProviderConfig(
          id: 'test',
          auth: testAuth,
          settings: null,
        );

        expect(config.settings, isEmpty);
        expect(config.settings, isA<Map<String, dynamic>>());
      });
    });

    group('copyWith', () {
      test('should create copy with same values when no changes', () {
        final original = ProviderConfig(
          id: 'test',
          auth: testAuth,
          settings: {'key': 'value'},
          timeout: Duration(seconds: 30),
        );

        final copy = original.copyWith();

        expect(copy.id, equals(original.id));
        expect(copy.auth, equals(original.auth));
        expect(copy.settings, equals(original.settings));
        expect(copy.timeout, equals(original.timeout));
        expect(copy, equals(original));
      });

      test('should create copy with updated id', () {
        final original = ProviderConfig(
          id: 'test',
          auth: testAuth,
        );

        final copy = original.copyWith(id: 'new-id');

        expect(copy.id, equals('new-id'));
        expect(copy.auth, equals(original.auth));
        expect(copy, isNot(equals(original)));
      });

      test('should create copy with updated auth', () {
        final original = ProviderConfig(
          id: 'test',
          auth: testAuth,
        );

        final newAuth = ApiKeyAuth(apiKey: 'sk-different-key');
        final copy = original.copyWith(auth: newAuth);

        expect(copy.id, equals(original.id));
        expect(copy.auth, equals(newAuth));
        expect(copy.auth, isNot(equals(original.auth)));
      });

      test('should create copy with updated settings', () {
        final original = ProviderConfig(
          id: 'test',
          auth: testAuth,
          settings: {'old': 'value'},
        );

        final newSettings = {'new': 'value'};
        final copy = original.copyWith(settings: newSettings);

        expect(copy.settings, equals(newSettings));
        expect(copy.settings, isNot(equals(original.settings)));
      });

      test('should create copy with updated timeout', () {
        final original = ProviderConfig(
          id: 'test',
          auth: testAuth,
          timeout: Duration(seconds: 30),
        );

        final newTimeout = Duration(seconds: 60);
        final copy = original.copyWith(timeout: newTimeout);

        expect(copy.timeout, equals(newTimeout));
        expect(copy.timeout, isNot(equals(original.timeout)));
      });

      test('should clear timeout when clearTimeout is true', () {
        final original = ProviderConfig(
          id: 'test',
          auth: testAuth,
          timeout: Duration(seconds: 30),
        );

        final copy = original.copyWith(clearTimeout: true);

        expect(copy.timeout, isNull);
        expect(original.timeout, isNotNull);
      });

      test('should ignore timeout when clearTimeout is true', () {
        final original = ProviderConfig(
          id: 'test',
          auth: testAuth,
          timeout: Duration(seconds: 30),
        );

        final copy = original.copyWith(
          timeout: Duration(seconds: 60),
          clearTimeout: true,
        );

        expect(copy.timeout, isNull);
      });
    });

    group('toJson', () {
      test('should serialize basic config to JSON', () {
        final config = ProviderConfig(
          id: 'test-provider',
          auth: testAuth,
        );

        final json = config.toJson();

        expect(json['id'], equals('test-provider'));
        expect(json['settings'], isA<Map<String, dynamic>>());
        expect(json['settings'], isEmpty);
        expect(json, isNot(contains('timeout')));
      });

      test('should serialize config with settings to JSON', () {
        final config = ProviderConfig(
          id: 'test',
          auth: testAuth,
          settings: {
            'baseUrl': 'https://api.example.com',
            'model': 'gpt-4',
            'organization': 'org-123',
          },
        );

        final json = config.toJson();

        expect(json['settings'], isA<Map<String, dynamic>>());
        expect(json['settings']['baseUrl'], equals('https://api.example.com'));
        expect(json['settings']['model'], equals('gpt-4'));
        expect(json['settings']['organization'], equals('org-123'));
      });

      test('should serialize config with timeout to JSON', () {
        final config = ProviderConfig(
          id: 'test',
          auth: testAuth,
          timeout: Duration(seconds: 30),
        );

        final json = config.toJson();

        expect(json['timeout'], equals(30000)); // milliseconds
      });

      test('should serialize ApiKeyAuth to JSON', () {
        final auth = ApiKeyAuth(apiKey: 'sk-abc123', headerName: 'x-api-key');
        final config = ProviderConfig(
          id: 'test',
          auth: auth,
        );

        final json = config.toJson();
        final authJson = json['auth'] as Map<String, dynamic>;

        expect(authJson['type'], equals('apiKey'));
        expect(authJson['apiKey'], equals('sk-abc123'));
        expect(authJson['headerName'], equals('x-api-key'));
      });

      test('should serialize CustomHeaderAuth to JSON', () {
        final auth = CustomHeaderAuth({
          'X-API-Key': 'key-value',
          'X-Client-ID': 'client-123',
        });
        final config = ProviderConfig(
          id: 'test',
          auth: auth,
        );

        final json = config.toJson();
        final authJson = json['auth'] as Map<String, dynamic>;

        expect(authJson['type'], equals('custom'));
        expect(authJson['headers'], isA<Map<String, dynamic>>());
        expect(authJson['headers']['X-API-Key'], equals('key-value'));
        expect(authJson['headers']['X-Client-ID'], equals('client-123'));
      });
    });

    group('fromJson', () {
      test('should deserialize basic config from JSON', () {
        final json = <String, dynamic>{
          'id': 'test-provider',
          'auth': <String, dynamic>{
            'type': 'apiKey',
            'apiKey': 'sk-abc123',
            'headerName': 'Authorization',
          },
          'settings': <String, dynamic>{},
        };

        final config = ProviderConfig.fromJson(json);

        expect(config.id, equals('test-provider'));
        expect(config.auth, isA<ApiKeyAuth>());
        expect((config.auth as ApiKeyAuth).apiKey, equals('sk-abc123'));
        expect(config.settings, isEmpty);
        expect(config.timeout, isNull);
      });

      test('should deserialize config with settings from JSON', () {
        final json = {
          'id': 'test',
          'auth': {
            'type': 'apiKey',
            'apiKey': 'sk-abc123',
          },
          'settings': {
            'baseUrl': 'https://api.example.com',
            'model': 'gpt-4',
          },
        };

        final config = ProviderConfig.fromJson(json);

        expect(config.settings['baseUrl'], equals('https://api.example.com'));
        expect(config.settings['model'], equals('gpt-4'));
      });

      test('should deserialize config with timeout from JSON', () {
        final json = {
          'id': 'test',
          'auth': {
            'type': 'apiKey',
            'apiKey': 'sk-abc123',
          },
          'timeout': 30000, // milliseconds
        };

        final config = ProviderConfig.fromJson(json);

        expect(config.timeout, equals(Duration(seconds: 30)));
      });

      test('should deserialize CustomHeaderAuth from JSON', () {
        final json = {
          'id': 'test',
          'auth': {
            'type': 'custom',
            'headers': {
              'X-API-Key': 'key-value',
              'X-Client-ID': 'client-123',
            },
          },
        };

        final config = ProviderConfig.fromJson(json);

        expect(config.auth, isA<CustomHeaderAuth>());
        final customAuth = config.auth as CustomHeaderAuth;
        expect(customAuth.headers['X-API-Key'], equals('key-value'));
        expect(customAuth.headers['X-Client-ID'], equals('client-123'));
      });

      test('should throw ClientError when id is missing', () {
        final json = {
          'auth': {
            'type': 'apiKey',
            'apiKey': 'sk-abc123',
          },
        };

        expect(
          () => ProviderConfig.fromJson(json),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_JSON',
          )),
        );
      });

      test('should throw ClientError when id is empty', () {
        final json = {
          'id': '',
          'auth': {
            'type': 'apiKey',
            'apiKey': 'sk-abc123',
          },
        };

        expect(
          () => ProviderConfig.fromJson(json),
          throwsA(isA<ClientError>()),
        );
      });

      test('should throw ClientError when auth is missing', () {
        final json = {
          'id': 'test',
        };

        expect(
          () => ProviderConfig.fromJson(json),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_JSON',
          )),
        );
      });

      test('should throw ClientError for unknown auth type', () {
        final json = {
          'id': 'test',
          'auth': {
            'type': 'unknown-type',
          },
        };

        expect(
          () => ProviderConfig.fromJson(json),
          throwsA(isA<ClientError>().having(
            (e) => e.code,
            'code',
            'INVALID_AUTH_TYPE',
          )),
        );
      });

      test('should use default headerName for ApiKeyAuth', () {
        final json = {
          'id': 'test',
          'auth': {
            'type': 'apiKey',
            'apiKey': 'sk-abc123',
            // headerName not provided
          },
        };

        final config = ProviderConfig.fromJson(json);
        final auth = config.auth as ApiKeyAuth;

        expect(auth.headerName, equals('Authorization'));
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        final config1 = ProviderConfig(
          id: 'test',
          auth: testAuth,
          settings: {'key': 'value'},
          timeout: Duration(seconds: 30),
        );
        final config2 = ProviderConfig(
          id: 'test',
          auth: testAuth,
          settings: {'key': 'value'},
          timeout: Duration(seconds: 30),
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('should not be equal when id differs', () {
        final config1 = ProviderConfig(id: 'test1', auth: testAuth);
        final config2 = ProviderConfig(id: 'test2', auth: testAuth);

        expect(config1, isNot(equals(config2)));
      });

      test('should not be equal when auth differs', () {
        final auth1 = ApiKeyAuth(apiKey: 'sk-key1');
        final auth2 = ApiKeyAuth(apiKey: 'sk-key2');

        final config1 = ProviderConfig(id: 'test', auth: auth1);
        final config2 = ProviderConfig(id: 'test', auth: auth2);

        expect(config1, isNot(equals(config2)));
      });

      test('should not be equal when settings differ', () {
        final config1 = ProviderConfig(
          id: 'test',
          auth: testAuth,
          settings: {'key1': 'value1'},
        );
        final config2 = ProviderConfig(
          id: 'test',
          auth: testAuth,
          settings: {'key2': 'value2'},
        );

        expect(config1, isNot(equals(config2)));
      });

      test('should not be equal when timeout differs', () {
        final config1 = ProviderConfig(
          id: 'test',
          auth: testAuth,
          timeout: Duration(seconds: 30),
        );
        final config2 = ProviderConfig(
          id: 'test',
          auth: testAuth,
          timeout: Duration(seconds: 60),
        );

        expect(config1, isNot(equals(config2)));
      });

      test('should not be equal when one has timeout and other does not', () {
        final config1 = ProviderConfig(
          id: 'test',
          auth: testAuth,
          timeout: Duration(seconds: 30),
        );
        final config2 = ProviderConfig(
          id: 'test',
          auth: testAuth,
        );

        expect(config1, isNot(equals(config2)));
      });
    });

    group('toString', () {
      test('should include id in toString', () {
        final config = ProviderConfig(
          id: 'test-provider',
          auth: testAuth,
        );

        final str = config.toString();
        expect(str, contains('test-provider'));
      });

      test('should show timeout in seconds', () {
        final config = ProviderConfig(
          id: 'test',
          auth: testAuth,
          timeout: Duration(seconds: 30),
        );

        final str = config.toString();
        expect(str, contains('30s'));
      });

      test('should show default when timeout is null', () {
        final config = ProviderConfig(
          id: 'test',
          auth: testAuth,
        );

        final str = config.toString();
        expect(str, contains('default'));
      });

      test('should show settings count', () {
        final config = ProviderConfig(
          id: 'test',
          auth: testAuth,
          settings: {'key1': 'value1', 'key2': 'value2'},
        );

        final str = config.toString();
        expect(str, contains('2 setting(s)'));
      });

      test('should show none when no settings', () {
        final config = ProviderConfig(
          id: 'test',
          auth: testAuth,
        );

        final str = config.toString();
        expect(str, contains('none'));
      });
    });

    group('integration', () {
      test('should work with ApiKeyAuth', () {
        final auth = ApiKeyAuth(apiKey: 'sk-openai-abc123');
        final config = ProviderConfig(
          id: 'openai',
          auth: auth,
          settings: {'defaultModel': 'gpt-4'},
          timeout: Duration(seconds: 30),
        );

        expect(config.id, equals('openai'));
        expect(config.auth, isA<ApiKeyAuth>());
        expect(config.settings['defaultModel'], equals('gpt-4'));
      });

      test('should work with CustomHeaderAuth', () {
        final auth = CustomHeaderAuth({
          'X-API-Key': 'custom-key',
          'X-Client-ID': 'client-123',
        });
        final config = ProviderConfig(
          id: 'custom-provider',
          auth: auth,
        );

        expect(config.auth, isA<CustomHeaderAuth>());
      });

      test('should round-trip through JSON', () {
        final original = ProviderConfig(
          id: 'test',
          auth: ApiKeyAuth(apiKey: 'sk-abc123', headerName: 'x-api-key'),
          settings: {'key': 'value'},
          timeout: Duration(seconds: 45),
        );

        final json = original.toJson();
        final restored = ProviderConfig.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.auth, isA<ApiKeyAuth>());
        expect((restored.auth as ApiKeyAuth).apiKey, equals('sk-abc123'));
        expect((restored.auth as ApiKeyAuth).headerName, equals('x-api-key'));
        expect(restored.settings, equals(original.settings));
        expect(restored.timeout, equals(original.timeout));
      });
    });
  });
}
