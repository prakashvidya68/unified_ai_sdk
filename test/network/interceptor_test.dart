import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/network/http_client_wrapper.dart';
import 'package:unified_ai_sdk/src/network/request_interceptor.dart';
import 'package:unified_ai_sdk/src/network/response_interceptor.dart';

// Mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final List<http.BaseRequest> _requests = [];

  void setResponse(String url, http.Response response) {
    _responses[url] = response;
  }

  List<http.BaseRequest> get requests => List.unmodifiable(_requests);

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final request = http.Request('POST', url)
      ..headers.addAll(headers ?? {})
      ..body = body is String ? body : (body != null ? jsonEncode(body) : '');
    _requests.add(request);

    final response = _responses[url.toString()];
    if (response != null) {
      return response;
    }

    return http.Response('Not Found', 404);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _requests.add(request);

    final response = _responses[request.url.toString()];
    if (response != null) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(response.body)),
        response.statusCode,
        headers: response.headers,
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode('Not Found')),
      404,
    );
  }

  @override
  void close() {}
}

// Test interceptors
class TestRequestInterceptor implements RequestInterceptor {
  final List<String> _callLog = [];
  final String Function(http.Request)? _modifier;

  TestRequestInterceptor({String Function(http.Request)? modifier})
      : _modifier = modifier;

  List<String> get callLog => List.unmodifiable(_callLog);

  @override
  Future<http.Request> onRequest(http.Request request) async {
    _callLog.add('onRequest: ${request.url}');
    if (_modifier != null) {
      final headerValue = _modifier!(request);
      request.headers['X-Test-Header'] = headerValue;
    }
    return request;
  }
}

class TestResponseInterceptor implements ResponseInterceptor {
  final List<String> _callLog = [];
  final void Function()? _onCall;

  TestResponseInterceptor({void Function()? onCall}) : _onCall = onCall;

  List<String> get callLog => List.unmodifiable(_callLog);

  @override
  Future<http.Response> onResponse(http.Response response) async {
    _callLog.add('onResponse: ${response.statusCode}');
    _onCall?.call();
    return response;
  }
}

class HeaderAddingInterceptor implements RequestInterceptor {
  final String headerName;
  final String headerValue;

  HeaderAddingInterceptor({
    required this.headerName,
    required this.headerValue,
  });

  @override
  Future<http.Request> onRequest(http.Request request) async {
    request.headers[headerName] = headerValue;
    return request;
  }
}

class ResponseModifyingInterceptor implements ResponseInterceptor {
  final String Function(http.Response) modifier;

  ResponseModifyingInterceptor(this.modifier);

  @override
  Future<http.Response> onResponse(http.Response response) async {
    final modifiedBody = modifier(response);
    return http.Response(modifiedBody, response.statusCode,
        headers: response.headers, request: response.request);
  }
}

void main() {
  group('RequestInterceptor', () {
    test('should be an abstract class', () {
      expect(RequestInterceptor, isA<Type>());
    });

    test('should allow implementation', () {
      final interceptor = TestRequestInterceptor();
      expect(interceptor, isA<RequestInterceptor>());
    });
  });

  group('ResponseInterceptor', () {
    test('should be an abstract class', () {
      expect(ResponseInterceptor, isA<Type>());
    });

    test('should allow implementation', () {
      final interceptor = TestResponseInterceptor();
      expect(interceptor, isA<ResponseInterceptor>());
    });
  });

  group('HttpClientWrapper with interceptors', () {
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
    });

    group('request interceptors', () {
      test('should apply request interceptor before sending request', () async {
        final interceptor = TestRequestInterceptor();
        final wrapper = HttpClientWrapper(
          client: mockClient,
          requestInterceptors: [interceptor],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post('https://api.example.com/test');

        expect(interceptor.callLog.length, equals(1));
        expect(interceptor.callLog.first, contains('onRequest'));
      });

      test('should apply multiple request interceptors in order', () async {
        final interceptor1 = TestRequestInterceptor();
        final interceptor2 = TestRequestInterceptor();
        final wrapper = HttpClientWrapper(
          client: mockClient,
          requestInterceptors: [interceptor1, interceptor2],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post('https://api.example.com/test');

        expect(interceptor1.callLog.length, equals(1));
        expect(interceptor2.callLog.length, equals(1));
      });

      test('should allow interceptor to modify request headers', () async {
        final interceptor = HeaderAddingInterceptor(
          headerName: 'X-Custom-Header',
          headerValue: 'custom-value',
        );
        final wrapper = HttpClientWrapper(
          client: mockClient,
          requestInterceptors: [interceptor],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post('https://api.example.com/test');

        final request = mockClient.requests.first;
        expect(request.headers['X-Custom-Header'], equals('custom-value'));
      });

      test('should chain multiple interceptors modifying headers', () async {
        final interceptor1 = HeaderAddingInterceptor(
          headerName: 'X-Header-1',
          headerValue: 'value-1',
        );
        final interceptor2 = HeaderAddingInterceptor(
          headerName: 'X-Header-2',
          headerValue: 'value-2',
        );
        final wrapper = HttpClientWrapper(
          client: mockClient,
          requestInterceptors: [interceptor1, interceptor2],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post('https://api.example.com/test');

        final request = mockClient.requests.first;
        expect(request.headers['X-Header-1'], equals('value-1'));
        expect(request.headers['X-Header-2'], equals('value-2'));
      });

      test('should apply interceptors to streaming requests', () async {
        final interceptor = TestRequestInterceptor();
        final wrapper = HttpClientWrapper(
          client: mockClient,
          requestInterceptors: [interceptor],
        );

        mockClient.setResponse(
          'https://api.example.com/stream',
          http.Response('OK', 200),
        );

        await wrapper
            .postStream('https://api.example.com/stream')
            .drain<void>();

        expect(interceptor.callLog.length, equals(1));
      });
    });

    group('response interceptors', () {
      test('should apply response interceptor after receiving response',
          () async {
        final interceptor = TestResponseInterceptor();
        final wrapper = HttpClientWrapper(
          client: mockClient,
          responseInterceptors: [interceptor],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post('https://api.example.com/test');

        expect(interceptor.callLog.length, equals(1));
        expect(interceptor.callLog.first, contains('onResponse'));
      });

      test('should apply multiple response interceptors in order', () async {
        final interceptor1 = TestResponseInterceptor();
        final interceptor2 = TestResponseInterceptor();
        final wrapper = HttpClientWrapper(
          client: mockClient,
          responseInterceptors: [interceptor1, interceptor2],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post('https://api.example.com/test');

        expect(interceptor1.callLog.length, equals(1));
        expect(interceptor2.callLog.length, equals(1));
      });

      test('should allow interceptor to modify response', () async {
        final interceptor = ResponseModifyingInterceptor((response) {
          final originalBody = jsonEncode(response.body);
          return '{"modified": true, "original": $originalBody}';
        });
        final wrapper = HttpClientWrapper(
          client: mockClient,
          responseInterceptors: [interceptor],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('{"original": true}', 200),
        );

        final response = await wrapper.post('https://api.example.com/test');

        final body = jsonDecode(response.body);
        expect(body['modified'], equals(true));
        expect(body['original'], isA<String>());
      });

      test('should chain multiple response interceptors', () async {
        final interceptor1 = ResponseModifyingInterceptor((response) {
          final bodyJson = jsonEncode(response.body);
          return '{"step1": true, "body": $bodyJson}';
        });
        final interceptor2 = ResponseModifyingInterceptor((response) {
          final data = jsonDecode(response.body);
          return '{"step2": true, "step1": ${data["step1"]}}';
        });
        final wrapper = HttpClientWrapper(
          client: mockClient,
          responseInterceptors: [interceptor1, interceptor2],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('original', 200),
        );

        final response = await wrapper.post('https://api.example.com/test');

        final body = jsonDecode(response.body);
        expect(body['step1'], equals(true));
        expect(body['step2'], equals(true));
      });
    });

    group('combined interceptors', () {
      test('should apply both request and response interceptors', () async {
        final requestInterceptor = TestRequestInterceptor();
        final responseInterceptor = TestResponseInterceptor();
        final wrapper = HttpClientWrapper(
          client: mockClient,
          requestInterceptors: [requestInterceptor],
          responseInterceptors: [responseInterceptor],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post('https://api.example.com/test');

        expect(requestInterceptor.callLog.length, equals(1));
        expect(responseInterceptor.callLog.length, equals(1));
      });

      test('should apply interceptors in correct order', () async {
        final callOrder = <String>[];
        final requestInterceptor = TestRequestInterceptor(
          modifier: (_) {
            callOrder.add('request');
            return 'request-value';
          },
        );
        final responseInterceptor = TestResponseInterceptor(
          onCall: () => callOrder.add('response'),
        );
        final wrapper = HttpClientWrapper(
          client: mockClient,
          requestInterceptors: [requestInterceptor],
          responseInterceptors: [responseInterceptor],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post('https://api.example.com/test');

        expect(callOrder.first, equals('request'));
        expect(callOrder.last, equals('response'));
      });
    });

    group('interceptor edge cases', () {
      test('should work with no interceptors', () async {
        final wrapper = HttpClientWrapper(client: mockClient);

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        final response = await wrapper.post('https://api.example.com/test');

        expect(response.statusCode, equals(200));
      });

      test('should work with empty interceptor lists', () async {
        final wrapper = HttpClientWrapper(
          client: mockClient,
          requestInterceptors: [],
          responseInterceptors: [],
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        final response = await wrapper.post('https://api.example.com/test');

        expect(response.statusCode, equals(200));
      });
    });
  });
}
