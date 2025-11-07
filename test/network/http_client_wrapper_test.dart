import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';
import 'package:unified_ai_sdk/src/network/http_client_wrapper.dart';

// Mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final Map<String, Stream<List<int>>> _streams = {};
  final List<http.BaseRequest> _requests = [];

  void setResponse(String url, http.Response response) {
    _responses[url] = response;
  }

  void setStream(String url, Stream<List<int>> stream) {
    _streams[url] = stream;
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

    // Check if we have a response for this URL
    final response = _responses[request.url.toString()];
    if (response != null) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(response.body)),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }

    // Check if we have a stream for this URL
    final stream = _streams[request.url.toString()];
    if (stream != null) {
      return http.StreamedResponse(stream, 200, request: request);
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode('Not Found')),
      404,
      request: request,
    );
  }

  @override
  void close() {
    // Mock implementation - no-op
  }
}

void main() {
  group('HttpClientWrapper', () {
    late MockHttpClient mockClient;
    late HttpClientWrapper wrapper;

    setUp(() {
      mockClient = MockHttpClient();
      wrapper = HttpClientWrapper(client: mockClient);
    });

    group('construction', () {
      test('should create instance with client', () {
        final wrapper = HttpClientWrapper(client: mockClient);
        expect(wrapper, isNotNull);
      });

      test('should use empty default headers when not provided', () {
        final wrapper = HttpClientWrapper(client: mockClient);
        expect(wrapper.defaultHeaders, isEmpty);
      });

      test('should use provided default headers', () {
        final headers = {
          'Authorization': 'Bearer sk-abc123',
          'Content-Type': 'application/json',
        };
        final wrapper = HttpClientWrapper(
          client: mockClient,
          defaultHeaders: headers,
        );
        expect(wrapper.defaultHeaders, equals(headers));
      });
    });

    group('post', () {
      test('should make POST request successfully', () async {
        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('{"success": true}', 200),
        );

        final response = await wrapper.post('https://api.example.com/test');

        expect(response.statusCode, equals(200));
        expect(response.body, equals('{"success": true}'));
        expect(mockClient.requests.length, equals(1));
      });

      test('should merge default headers with request headers', () async {
        final wrapper = HttpClientWrapper(
          client: mockClient,
          defaultHeaders: {
            'Authorization': 'Bearer sk-default',
            'Content-Type': 'application/json',
          },
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post(
          'https://api.example.com/test',
          headers: {'X-Custom': 'value'},
        );

        final request = mockClient.requests.first;
        expect(request.headers['Authorization'], equals('Bearer sk-default'));
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(request.headers['X-Custom'], equals('value'));
      });

      test('should override default headers with request headers', () async {
        final wrapper = HttpClientWrapper(
          client: mockClient,
          defaultHeaders: {
            'Authorization': 'Bearer sk-default',
            'Content-Type': 'application/json',
          },
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post(
          'https://api.example.com/test',
          headers: {'Authorization': 'Bearer sk-override'},
        );

        final request = mockClient.requests.first;
        expect(request.headers['Authorization'], equals('Bearer sk-override'));
      });

      test('should JSON-encode Map body', () async {
        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post(
          'https://api.example.com/test',
          body: {'key': 'value', 'number': 42},
        );

        final request = mockClient.requests.first;
        if (request is http.Request) {
          final body = jsonDecode(request.body);
          expect(body['key'], equals('value'));
          expect(body['number'], equals(42));
        }
      });

      test('should JSON-encode List body', () async {
        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post(
          'https://api.example.com/test',
          body: ['item1', 'item2'],
        );

        final request = mockClient.requests.first;
        if (request is http.Request) {
          final body = jsonDecode(request.body);
          expect(body, equals(['item1', 'item2']));
        }
      });

      test('should send String body as-is', () async {
        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post(
          'https://api.example.com/test',
          body: 'raw string body',
        );

        final request = mockClient.requests.first;
        if (request is http.Request) {
          expect(request.body, equals('raw string body'));
        }
      });

      test('should send empty body when body is null', () async {
        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post('https://api.example.com/test');

        final request = mockClient.requests.first;
        if (request is http.Request) {
          expect(request.body, isEmpty);
        }
      });

      test('should handle network errors', () async {
        final errorClient = _ErrorHttpClient();
        final wrapper = HttpClientWrapper(client: errorClient);

        expect(
          () => wrapper.post('https://api.example.com/test'),
          throwsA(isA<TransientError>()),
        );
      });

      test('should include Content-Type for JSON body', () async {
        final wrapper = HttpClientWrapper(
          client: mockClient,
          defaultHeaders: {},
        );

        mockClient.setResponse(
          'https://api.example.com/test',
          http.Response('OK', 200),
        );

        await wrapper.post(
          'https://api.example.com/test',
          body: {'key': 'value'},
        );

        final request = mockClient.requests.first;
        // Content-Type should be set automatically for JSON
        expect(request.headers['Content-Type'], contains('application/json'));
      });
    });

    group('postStream', () {
      test('should return stream of bytes', () async {
        final chunks = [
          utf8.encode('chunk1\n'),
          utf8.encode('chunk2\n'),
          utf8.encode('chunk3\n'),
        ];
        final stream = Stream<List<int>>.fromIterable(chunks);

        mockClient.setStream('https://api.example.com/stream', stream);

        final resultStream =
            wrapper.postStream('https://api.example.com/stream');

        final receivedChunks = <List<int>>[];
        await for (final chunk in resultStream) {
          receivedChunks.add(chunk);
        }

        expect(receivedChunks.length, equals(3));
        expect(String.fromCharCodes(receivedChunks[0]), equals('chunk1\n'));
      });

      test('should merge default headers for streaming', () async {
        final wrapper = HttpClientWrapper(
          client: mockClient,
          defaultHeaders: {
            'Authorization': 'Bearer sk-abc123',
          },
        );

        final stream = Stream<List<int>>.value(utf8.encode('test'));
        mockClient.setStream('https://api.example.com/stream', stream);

        await wrapper.postStream(
          'https://api.example.com/stream',
          body: {'key': 'value'},
        ).drain<void>();

        final request = mockClient.requests.first;
        expect(request.headers['Authorization'], equals('Bearer sk-abc123'));
      });

      test('should JSON-encode Map body for streaming', () async {
        final stream = Stream<List<int>>.value(utf8.encode('test'));
        mockClient.setStream('https://api.example.com/stream', stream);

        await wrapper.postStream(
          'https://api.example.com/stream',
          body: {'key': 'value'},
        ).drain<void>();

        final request = mockClient.requests.first;
        if (request is http.Request) {
          final body = jsonDecode(request.body);
          expect(body['key'], equals('value'));
        }
      });

      test('should handle network errors in streaming', () async {
        final errorClient = _ErrorHttpClient();
        final wrapper = HttpClientWrapper(client: errorClient);

        final stream = wrapper.postStream('https://api.example.com/stream');

        expect(
          () async {
            await for (final _ in stream) {
              // Consume stream to trigger error
            }
          },
          throwsA(isA<TransientError>()),
        );
      });
    });

    group('close', () {
      test('should close underlying client', () {
        final wrapper = HttpClientWrapper(client: mockClient);
        expect(() => wrapper.close(), returnsNormally);
      });
    });

    group('integration', () {
      test('should work with real HTTP client for basic request', () async {
        // This test requires network access - skip in CI
        // Uncomment to test with real HTTP client
        /*
        final realClient = http.Client();
        final wrapper = HttpClientWrapper(
          client: realClient,
          defaultHeaders: {
            'Content-Type': 'application/json',
          },
        );

        try {
          // Use a test endpoint that always returns 200
          final response = await wrapper.post(
            'https://httpbin.org/post',
            body: {'test': 'data'},
          );
          expect(response.statusCode, equals(200));
        } finally {
          realClient.close();
        }
        */
      });
    });
  });
}

// Helper class for testing error handling
class _ErrorHttpClient extends http.BaseClient {
  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    throw SocketException('Connection failed');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw SocketException('Connection failed');
  }

  @override
  void close() {}
}
