import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';

void main() {
  group('ImageSize enum', () {
    test('should have all expected values', () {
      expect(ImageSize.values.length, equals(5));
      expect(ImageSize.values, contains(ImageSize.w256h256));
      expect(ImageSize.values, contains(ImageSize.w512h512));
      expect(ImageSize.values, contains(ImageSize.w1024h1024));
      expect(ImageSize.values, contains(ImageSize.w1024h1792));
      expect(ImageSize.values, contains(ImageSize.w1792h1024));
    });

    group('toString() conversion', () {
      test('w256h256 should convert to "256x256"', () {
        expect(ImageSize.w256h256.toString(), equals('256x256'));
      });

      test('w512h512 should convert to "512x512"', () {
        expect(ImageSize.w512h512.toString(), equals('512x512'));
      });

      test('w1024h1024 should convert to "1024x1024"', () {
        expect(ImageSize.w1024h1024.toString(), equals('1024x1024'));
      });

      test('w1024h1792 should convert to "1024x1792"', () {
        expect(ImageSize.w1024h1792.toString(), equals('1024x1792'));
      });

      test('w1792h1024 should convert to "1792x1024"', () {
        expect(ImageSize.w1792h1024.toString(), equals('1792x1024'));
      });
    });

    group('toString() format validation', () {
      test('all values should follow WIDTHxHEIGHT format', () {
        for (final size in ImageSize.values) {
          final stringValue = size.toString();
          // Should contain 'x' separator
          expect(stringValue, contains('x'));
          // Should be parseable as WIDTHxHEIGHT
          final parts = stringValue.split('x');
          expect(parts.length, equals(2));
          // Both parts should be numeric
          expect(int.tryParse(parts[0]), isNotNull,
              reason: 'Width should be numeric: $stringValue');
          expect(int.tryParse(parts[1]), isNotNull,
              reason: 'Height should be numeric: $stringValue');
        }
      });

      test('square sizes should have equal width and height', () {
        expect(ImageSize.w256h256.toString().split('x')[0],
            equals(ImageSize.w256h256.toString().split('x')[1]));
        expect(ImageSize.w512h512.toString().split('x')[0],
            equals(ImageSize.w512h512.toString().split('x')[1]));
        expect(ImageSize.w1024h1024.toString().split('x')[0],
            equals(ImageSize.w1024h1024.toString().split('x')[1]));
      });

      test('portrait size should have height > width', () {
        final portrait = ImageSize.w1024h1792.toString().split('x');
        expect(int.parse(portrait[1]), greaterThan(int.parse(portrait[0])));
      });

      test('landscape size should have width > height', () {
        final landscape = ImageSize.w1792h1024.toString().split('x');
        expect(int.parse(landscape[0]), greaterThan(int.parse(landscape[1])));
      });
    });

    group('ImageSize usage examples', () {
      test('can be used in ImageRequest-like scenarios', () {
        final size = ImageSize.w1024h1024;
        final sizeString = size.toString();

        // Simulate how it would be used in ImageRequest.toJson()
        final requestData = {
          'prompt': 'A beautiful sunset',
          'size': sizeString,
        };

        expect(requestData['size'], equals('1024x1024'));
        expect(requestData['size'], isA<String>());
      });

      test('can be used in switch statements', () {
        final ImageSize size = ImageSize.w512h512;
        String description;

        switch (size) {
          case ImageSize.w256h256:
            description = 'Small square';
            break;
          case ImageSize.w512h512:
            description = 'Medium square';
            break;
          case ImageSize.w1024h1024:
            description = 'Large square';
            break;
          case ImageSize.w1024h1792:
            description = 'Portrait';
            break;
          case ImageSize.w1792h1024:
            description = 'Landscape';
            break;
        }

        expect(description, equals('Medium square'));
      });

      test('can be used in collections', () {
        final supportedSizes = [
          ImageSize.w256h256,
          ImageSize.w512h512,
          ImageSize.w1024h1024,
        ];

        expect(supportedSizes.length, equals(3));
        expect(supportedSizes, contains(ImageSize.w256h256));
        expect(supportedSizes, contains(ImageSize.w512h512));
        expect(supportedSizes, contains(ImageSize.w1024h1024));
      });

      test('toString() can be used for API serialization', () {
        final sizes = ImageSize.values;
        final serialized = sizes.map((s) => s.toString()).toList();

        expect(serialized, contains('256x256'));
        expect(serialized, contains('512x512'));
        expect(serialized, contains('1024x1024'));
        expect(serialized, contains('1024x1792'));
        expect(serialized, contains('1792x1024'));

        // All should be valid API format
        for (final s in serialized) {
          expect(s, matches(r'^\d+x\d+$'));
        }
      });
    });
  });
}
