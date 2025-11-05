import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/requests/image_request.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';

void main() {
  group('ImageRequest', () {
    group('Construction', () {
      test('should create request with required fields', () {
        final request = ImageRequest(
          prompt: 'A beautiful sunset',
        );

        expect(request.prompt, equals('A beautiful sunset'));
        expect(request.model, isNull);
        expect(request.size, isNull);
        expect(request.n, isNull);
        expect(request.quality, isNull);
        expect(request.style, isNull);
        expect(request.providerOptions, isNull);
      });

      test('should create request with all fields', () {
        final request = ImageRequest(
          prompt: 'A cat playing piano',
          model: 'dall-e-3',
          size: ImageSize.w1024h1024,
          n: 2,
          quality: 'hd',
          style: 'vivid',
          providerOptions: {
            'openai': {'response_format': 'url'},
          },
        );

        expect(request.prompt, equals('A cat playing piano'));
        expect(request.model, equals('dall-e-3'));
        expect(request.size, equals(ImageSize.w1024h1024));
        expect(request.n, equals(2));
        expect(request.quality, equals('hd'));
        expect(request.style, equals('vivid'));
        expect(request.providerOptions, equals({
          'openai': {'response_format': 'url'},
        }));
      });

      test('should throw assertion error if prompt is empty', () {
        expect(
          () => ImageRequest(prompt: ''),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('toJson()', () {
      test('should serialize request to JSON with only required fields', () {
        final request = ImageRequest(
          prompt: 'A beautiful sunset',
        );

        final json = request.toJson();

        expect(json, isA<Map<String, dynamic>>());
        expect(json['prompt'], equals('A beautiful sunset'));
        expect(json.containsKey('model'), isFalse);
        expect(json.containsKey('size'), isFalse);
        expect(json.containsKey('n'), isFalse);
      });

      test('should serialize request with all fields', () {
        final request = ImageRequest(
          prompt: 'A cat',
          model: 'dall-e-3',
          size: ImageSize.w1024h1024,
          n: 1,
          quality: 'hd',
          style: 'vivid',
          providerOptions: {
            'openai': {'response_format': 'url'},
          },
        );

        final json = request.toJson();

        expect(json['prompt'], equals('A cat'));
        expect(json['model'], equals('dall-e-3'));
        expect(json['size'], equals('1024x1024'));
        expect(json['n'], equals(1));
        expect(json['quality'], equals('hd'));
        expect(json['style'], equals('vivid'));
        expect(json['provider_options'], equals({
          'openai': {'response_format': 'url'},
        }));
      });

      test('should serialize size enum to string format', () {
        final request1 = ImageRequest(
          prompt: 'Test',
          size: ImageSize.w256h256,
        );
        final request2 = ImageRequest(
          prompt: 'Test',
          size: ImageSize.w1024h1792,
        );

        expect(request1.toJson()['size'], equals('256x256'));
        expect(request2.toJson()['size'], equals('1024x1792'));
      });

      test('should not include null optional fields', () {
        final request = ImageRequest(
          prompt: 'Test',
        );

        final json = request.toJson();

        expect(json.keys, contains('prompt'));
        expect(json.keys.length, equals(1));
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with only required fields', () {
        final json = {
          'prompt': 'A beautiful sunset',
        };

        final request = ImageRequest.fromJson(json);

        expect(request.prompt, equals('A beautiful sunset'));
        expect(request.model, isNull);
        expect(request.size, isNull);
      });

      test('should deserialize JSON with all fields', () {
        final json = {
          'prompt': 'A cat',
          'model': 'dall-e-3',
          'size': '1024x1024',
          'n': 1,
          'quality': 'hd',
          'style': 'vivid',
          'provider_options': {
            'openai': {'response_format': 'url'},
          },
        };

        final request = ImageRequest.fromJson(json);

        expect(request.prompt, equals('A cat'));
        expect(request.model, equals('dall-e-3'));
        expect(request.size, equals(ImageSize.w1024h1024));
        expect(request.n, equals(1));
        expect(request.quality, equals('hd'));
        expect(request.style, equals('vivid'));
      });

      test('should parse all ImageSize enum values', () {
        final sizes = [
          ('256x256', ImageSize.w256h256),
          ('512x512', ImageSize.w512h512),
          ('1024x1024', ImageSize.w1024h1024),
          ('1024x1792', ImageSize.w1024h1792),
          ('1792x1024', ImageSize.w1792h1024),
        ];

        for (final (sizeString, expectedSize) in sizes) {
          final json = {
            'prompt': 'Test',
            'size': sizeString,
          };

          final request = ImageRequest.fromJson(json);

          expect(request.size, equals(expectedSize));
        }
      });

      test('should throw FormatException if prompt is missing', () {
        final json = <String, dynamic>{};

        expect(
          () => ImageRequest.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if prompt is empty', () {
        final json = {'prompt': ''};

        expect(
          () => ImageRequest.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if size is invalid', () {
        final json = {
          'prompt': 'Test',
          'size': '999x999',
        };

        expect(
          () => ImageRequest.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('copyWith()', () {
      test('should create copy with updated prompt', () {
        final original = ImageRequest(
          prompt: 'Original',
          model: 'dall-e-3',
        );

        final copy = original.copyWith(prompt: 'Updated');

        expect(copy.prompt, equals('Updated'));
        expect(copy.model, equals('dall-e-3'));
      });

      test('should create copy with updated size', () {
        final original = ImageRequest(
          prompt: 'Test',
          size: ImageSize.w256h256,
        );

        final copy = original.copyWith(size: ImageSize.w1024h1024);

        expect(copy.size, equals(ImageSize.w1024h1024));
        expect(copy.prompt, equals('Test'));
      });

      test('should create copy that is equal but not identical', () {
        final original = ImageRequest(
          prompt: 'Test',
          model: 'dall-e-3',
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy, isNot(same(original)));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final request1 = ImageRequest(
          prompt: 'A cat',
          model: 'dall-e-3',
          size: ImageSize.w1024h1024,
        );
        final request2 = ImageRequest(
          prompt: 'A cat',
          model: 'dall-e-3',
          size: ImageSize.w1024h1024,
        );

        expect(request1, equals(request2));
        expect(request1.hashCode, equals(request2.hashCode));
      });

      test('should not be equal with different prompts', () {
        final request1 = ImageRequest(prompt: 'A cat');
        final request2 = ImageRequest(prompt: 'A dog');

        expect(request1, isNot(equals(request2)));
      });

      test('should not be equal with different sizes', () {
        final request1 = ImageRequest(
          prompt: 'Test',
          size: ImageSize.w256h256,
        );
        final request2 = ImageRequest(
          prompt: 'Test',
          size: ImageSize.w1024h1024,
        );

        expect(request1, isNot(equals(request2)));
      });

      test('should not be equal with different models', () {
        final request1 = ImageRequest(
          prompt: 'Test',
          model: 'dall-e-3',
        );
        final request2 = ImageRequest(
          prompt: 'Test',
          model: 'dall-e-2',
        );

        expect(request1, isNot(equals(request2)));
      });
    });

    group('toString()', () {
      test('should return string representation', () {
        final request = ImageRequest(
          prompt: 'A beautiful sunset over the ocean',
          model: 'dall-e-3',
          size: ImageSize.w1024h1024,
        );

        final str = request.toString();

        expect(str, contains('ImageRequest'));
        expect(str, contains('A beautiful sunset'));
        expect(str, contains('dall-e-3'));
        expect(str, contains('1024x1024'));
      });

      test('should truncate long prompts', () {
        final longPrompt = 'A' * 100;
        final request = ImageRequest(prompt: longPrompt);

        final str = request.toString();

        expect(str, contains('...'));
        expect(str.length, lessThan(longPrompt.length + 50));
      });
    });

    group('Round-trip serialization', () {
      test('should serialize and deserialize correctly', () {
        final original = ImageRequest(
          prompt: 'A cat playing piano',
          model: 'dall-e-3',
          size: ImageSize.w1024h1024,
          n: 2,
          quality: 'hd',
          style: 'vivid',
          providerOptions: {
            'openai': {'response_format': 'url'},
          },
        );

        final json = original.toJson();
        final restored = ImageRequest.fromJson(json);

        expect(restored.prompt, equals(original.prompt));
        expect(restored.model, equals(original.model));
        expect(restored.size, equals(original.size));
        expect(restored.n, equals(original.n));
        expect(restored.quality, equals(original.quality));
        expect(restored.style, equals(original.style));
        expect(restored.providerOptions, equals(original.providerOptions));
      });
    });
  });
}

