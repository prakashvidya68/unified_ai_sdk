import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/responses/image_response.dart';

void main() {
  group('ImageAsset', () {
    group('Construction', () {
      test('should create asset with URL', () {
        const asset = ImageAsset(
          url: 'https://example.com/image.png',
        );

        expect(asset.url, equals('https://example.com/image.png'));
        expect(asset.base64, isNull);
        expect(asset.width, isNull);
        expect(asset.height, isNull);
        expect(asset.revisedPrompt, isNull);
      });

      test('should create asset with base64', () {
        const asset = ImageAsset(
          base64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        );

        expect(asset.base64, isNotNull);
        expect(asset.url, isNull);
      });

      test('should create asset with all fields', () {
        const asset = ImageAsset(
          url: 'https://example.com/image.png',
          base64: 'base64data',
          width: 1024,
          height: 1024,
          revisedPrompt: 'A beautiful sunset over the ocean',
        );

        expect(asset.url, equals('https://example.com/image.png'));
        expect(asset.base64, equals('base64data'));
        expect(asset.width, equals(1024));
        expect(asset.height, equals(1024));
        expect(asset.revisedPrompt, equals('A beautiful sunset over the ocean'));
      });

      test('should create asset with only dimensions', () {
        const asset = ImageAsset(
          width: 512,
          height: 512,
        );

        expect(asset.width, equals(512));
        expect(asset.height, equals(512));
        expect(asset.url, isNull);
        expect(asset.base64, isNull);
      });
    });

    group('toJson()', () {
      test('should serialize asset with URL', () {
        const asset = ImageAsset(
          url: 'https://example.com/image.png',
        );

        final json = asset.toJson();

        expect(json['url'], equals('https://example.com/image.png'));
        expect(json.containsKey('base64'), isFalse);
        expect(json.containsKey('width'), isFalse);
      });

      test('should serialize asset with all fields', () {
        const asset = ImageAsset(
          url: 'https://example.com/image.png',
          base64: 'base64data',
          width: 1024,
          height: 1024,
          revisedPrompt: 'Revised prompt',
        );

        final json = asset.toJson();

        expect(json['url'], equals('https://example.com/image.png'));
        expect(json['base64'], equals('base64data'));
        expect(json['width'], equals(1024));
        expect(json['height'], equals(1024));
        expect(json['revised_prompt'], equals('Revised prompt'));
      });

      test('should not include null fields', () {
        const asset = ImageAsset();

        final json = asset.toJson();

        expect(json.isEmpty, isTrue);
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with URL', () {
        final json = {
          'url': 'https://example.com/image.png',
        };

        final asset = ImageAsset.fromJson(json);

        expect(asset.url, equals('https://example.com/image.png'));
        expect(asset.base64, isNull);
      });

      test('should deserialize JSON with base64', () {
        final json = {
          'base64': 'base64data',
        };

        final asset = ImageAsset.fromJson(json);

        expect(asset.base64, equals('base64data'));
        expect(asset.url, isNull);
      });

      test('should deserialize JSON with all fields', () {
        final json = {
          'url': 'https://example.com/image.png',
          'base64': 'base64data',
          'width': 1024,
          'height': 1024,
          'revised_prompt': 'Revised prompt',
        };

        final asset = ImageAsset.fromJson(json);

        expect(asset.url, equals('https://example.com/image.png'));
        expect(asset.base64, equals('base64data'));
        expect(asset.width, equals(1024));
        expect(asset.height, equals(1024));
        expect(asset.revisedPrompt, equals('Revised prompt'));
      });

      test('should support both revised_prompt and revisedPrompt', () {
        final json1 = {'revised_prompt': 'Snake case'};
        final json2 = {'revisedPrompt': 'Camel case'};

        final asset1 = ImageAsset.fromJson(json1);
        final asset2 = ImageAsset.fromJson(json2);

        expect(asset1.revisedPrompt, equals('Snake case'));
        expect(asset2.revisedPrompt, equals('Camel case'));
      });

      test('should prefer revised_prompt over revisedPrompt', () {
        final json = {
          'revised_prompt': 'Snake case',
          'revisedPrompt': 'Camel case',
        };

        final asset = ImageAsset.fromJson(json);

        expect(asset.revisedPrompt, equals('Snake case'));
      });
    });

    group('copyWith()', () {
      test('should create copy with updated URL', () {
        const original = ImageAsset(
          url: 'https://example.com/old.png',
          width: 1024,
        );

        final copy = original.copyWith(url: 'https://example.com/new.png');

        expect(copy.url, equals('https://example.com/new.png'));
        expect(copy.width, equals(1024));
      });

      test('should create copy that is equal but not identical', () {
        const original = ImageAsset(
          url: 'https://example.com/image.png',
          width: 1024,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy, isNot(same(original)));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        const asset1 = ImageAsset(
          url: 'https://example.com/image.png',
          width: 1024,
          height: 1024,
        );
        const asset2 = ImageAsset(
          url: 'https://example.com/image.png',
          width: 1024,
          height: 1024,
        );

        expect(asset1, equals(asset2));
        expect(asset1.hashCode, equals(asset2.hashCode));
      });

      test('should not be equal with different URLs', () {
        const asset1 = ImageAsset(url: 'https://example.com/image1.png');
        const asset2 = ImageAsset(url: 'https://example.com/image2.png');

        expect(asset1, isNot(equals(asset2)));
      });

      test('should not be equal with different dimensions', () {
        const asset1 = ImageAsset(width: 1024, height: 1024);
        const asset2 = ImageAsset(width: 512, height: 512);

        expect(asset1, isNot(equals(asset2)));
      });
    });

    group('toString()', () {
      test('should return string representation', () {
        const asset = ImageAsset(
          url: 'https://example.com/image.png',
          width: 1024,
          height: 1024,
        );

        final str = asset.toString();

        expect(str, contains('ImageAsset'));
        expect(str, contains('1024x1024'));
      });

      test('should handle asset with only URL', () {
        const asset = ImageAsset(url: 'https://example.com/image.png');

        final str = asset.toString();

        expect(str, contains('url'));
      });
    });
  });

  group('ImageResponse', () {
    group('Construction', () {
      test('should create response with required fields', () {
        final response = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
        );

        expect(response.assets.length, equals(1));
        expect(response.model, equals('dall-e-3'));
        expect(response.provider, equals('openai'));
        expect(response.metadata, isNull);
      });

      test('should create response with all fields', () {
        final response = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
          metadata: {'request_id': '123'},
        );

        expect(response.metadata, equals({'request_id': '123'}));
      });

      test('should default timestamp to current time', () {
        final before = DateTime.now();
        final response = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
        );
        final after = DateTime.now();

        expect(response.timestamp.isAfter(before) || response.timestamp.isAtSameMomentAs(before), isTrue);
        expect(response.timestamp.isBefore(after) || response.timestamp.isAtSameMomentAs(after), isTrue);
      });

      test('should throw assertion error if assets is empty', () {
        expect(
          () => ImageResponse(
            assets: [],
            model: 'dall-e-3',
            provider: 'openai',
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should handle multiple assets', () {
        final response = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image1.png'),
            const ImageAsset(url: 'https://example.com/image2.png'),
            const ImageAsset(url: 'https://example.com/image3.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
        );

        expect(response.assets.length, equals(3));
      });
    });

    group('toJson()', () {
      test('should serialize response to JSON', () {
        final response = ImageResponse(
          assets: [
            const ImageAsset(
              url: 'https://example.com/image.png',
              width: 1024,
              height: 1024,
            ),
          ],
          model: 'dall-e-3',
          provider: 'openai',
          metadata: {'test': 'value'},
        );

        final json = response.toJson();

        expect(json['assets'], isA<List<dynamic>>());
        expect(json['assets'].length, equals(1));
        expect(json['model'], equals('dall-e-3'));
        expect(json['provider'], equals('openai'));
        expect(json['metadata'], equals({'test': 'value'}));
        expect(json['timestamp'], isA<String>());
      });

      test('should serialize without optional fields', () {
        final response = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
        );

        final json = response.toJson();

        expect(json.containsKey('metadata'), isFalse);
      });
    });

    group('fromJson()', () {
      test('should deserialize JSON with required fields', () {
        final json = {
          'assets': [
            {
              'url': 'https://example.com/image.png',
            },
          ],
          'model': 'dall-e-3',
          'provider': 'openai',
        };

        final response = ImageResponse.fromJson(json);

        expect(response.assets.length, equals(1));
        expect(response.assets.first.url, equals('https://example.com/image.png'));
        expect(response.model, equals('dall-e-3'));
        expect(response.provider, equals('openai'));
      });

      test('should deserialize JSON with all fields', () {
        final timestamp = DateTime.now().toIso8601String();
        final json = {
          'assets': [
            {
              'url': 'https://example.com/image.png',
              'width': 1024,
              'height': 1024,
            },
          ],
          'model': 'dall-e-3',
          'provider': 'openai',
          'timestamp': timestamp,
          'metadata': {'request_id': '123'},
        };

        final response = ImageResponse.fromJson(json);

        expect(response.metadata, equals({'request_id': '123'}));
        expect(response.timestamp.toIso8601String(), equals(timestamp));
      });

      test('should throw FormatException if assets is missing', () {
        final json = {
          'model': 'dall-e-3',
          'provider': 'openai',
        };

        expect(
          () => ImageResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if assets is not a List', () {
        final json = {
          'assets': 'not a list',
          'model': 'dall-e-3',
          'provider': 'openai',
        };

        expect(
          () => ImageResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw FormatException if assets is empty', () {
        final json = {
          'assets': <dynamic>[],
          'model': 'dall-e-3',
          'provider': 'openai',
        };

        expect(
          () => ImageResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('should handle multiple assets', () {
        final json = {
          'assets': [
            {'url': 'https://example.com/image1.png'},
            {'url': 'https://example.com/image2.png'},
          ],
          'model': 'dall-e-3',
          'provider': 'openai',
        };

        final response = ImageResponse.fromJson(json);

        expect(response.assets.length, equals(2));
        expect(response.assets[0].url, equals('https://example.com/image1.png'));
        expect(response.assets[1].url, equals('https://example.com/image2.png'));
      });
    });

    group('copyWith()', () {
      test('should create copy with updated assets', () {
        final original = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image1.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
        );

        final copy = original.copyWith(
          assets: [
            const ImageAsset(url: 'https://example.com/image2.png'),
          ],
        );

        expect(copy.assets.first.url, equals('https://example.com/image2.png'));
        expect(copy.model, equals('dall-e-3'));
      });

      test('should create copy with updated model', () {
        final original = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
        );

        final copy = original.copyWith(model: 'dall-e-2');

        expect(copy.model, equals('dall-e-2'));
        expect(copy.provider, equals('openai'));
      });
    });

    group('Equality', () {
      test('should be equal with same values', () {
        final timestamp = DateTime.now();
        final response1 = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
          timestamp: timestamp,
        );
        final response2 = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
          timestamp: timestamp,
        );

        expect(response1, equals(response2));
        expect(response1.hashCode, equals(response2.hashCode));
      });

      test('should not be equal with different assets', () {
        final response1 = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image1.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
        );
        final response2 = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image2.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
        );

        expect(response1, isNot(equals(response2)));
      });

      test('should not be equal with different models', () {
        final response1 = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image.png'),
          ],
          model: 'dall-e-3',
          provider: 'openai',
        );
        final response2 = ImageResponse(
          assets: [
            const ImageAsset(url: 'https://example.com/image.png'),
          ],
          model: 'dall-e-2',
          provider: 'openai',
        );

        expect(response1, isNot(equals(response2)));
      });
    });

    group('Round-trip serialization', () {
      test('should serialize and deserialize correctly', () {
        final timestamp = DateTime.now();
        final original = ImageResponse(
          assets: [
            const ImageAsset(
              url: 'https://example.com/image.png',
              width: 1024,
              height: 1024,
              revisedPrompt: 'Revised prompt',
            ),
            const ImageAsset(
              base64: 'base64data',
              width: 512,
              height: 512,
            ),
          ],
          model: 'dall-e-3',
          provider: 'openai',
          timestamp: timestamp,
          metadata: {'test': 'value'},
        );

        final json = original.toJson();
        final restored = ImageResponse.fromJson(json);

        expect(restored.assets.length, equals(original.assets.length));
        expect(restored.assets[0].url, equals(original.assets[0].url));
        expect(restored.assets[1].base64, equals(original.assets[1].base64));
        expect(restored.model, equals(original.model));
        expect(restored.provider, equals(original.provider));
        expect(restored.metadata, equals(original.metadata));
        expect(restored.timestamp.millisecondsSinceEpoch, equals(original.timestamp.millisecondsSinceEpoch));
      });
    });
  });
}

