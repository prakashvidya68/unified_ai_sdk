import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/core/constants.dart';

void main() {
  group('SDK Constants', () {
    test('sdkVersion should be defined', () {
      expect(sdkVersion, isNotEmpty);
      expect(sdkVersion, isA<String>());
      // Version should follow semantic versioning (x.y.z)
      expect(sdkVersion, matches(r'^\d+\.\d+\.\d+'));
    });

    test('defaultMaxTokens should be a positive integer', () {
      expect(defaultMaxTokens, isA<int>());
      expect(defaultMaxTokens, greaterThan(0));
      expect(defaultMaxTokens, equals(1000));
    });

    test('defaultTemperature should be between 0 and 1', () {
      expect(defaultTemperature, isA<double>());
      expect(defaultTemperature, greaterThanOrEqualTo(0.0));
      expect(defaultTemperature, lessThanOrEqualTo(1.0));
      expect(defaultTemperature, equals(0.7));
    });

    test('defaultCacheTTL should be a valid Duration', () {
      expect(defaultCacheTTL, isA<Duration>());
      expect(defaultCacheTTL.inHours, equals(1));
      expect(defaultCacheTTL.inMinutes, equals(60));
      expect(defaultCacheTTL.inSeconds, equals(3600));
    });
  });

  group('Constants Usage', () {
    test('constants can be used in variable assignments', () {
      final maxTokens = defaultMaxTokens;
      final temperature = defaultTemperature;
      final cacheTTL = defaultCacheTTL;

      expect(maxTokens, equals(1000));
      expect(temperature, equals(0.7));
      expect(cacheTTL.inHours, equals(1));
    });

    test('constants can be used in calculations', () {
      // Example: Calculate adjusted temperature
      final adjustedTemp = defaultTemperature * 0.9;
      expect(adjustedTemp, closeTo(0.63, 0.01));

      // Example: Calculate token budget
      final tokenBudget = defaultMaxTokens * 2;
      expect(tokenBudget, equals(2000));

      // Example: Calculate cache expiry time
      final expiryTime = DateTime.now().add(defaultCacheTTL);
      expect(expiryTime.isAfter(DateTime.now()), isTrue);
    });

    test('constants can be used in conditional logic', () {
      // Example: Check if temperature is in acceptable range
      final isTemperatureValid =
          defaultTemperature >= 0.0 && defaultTemperature <= 1.0;
      expect(isTemperatureValid, isTrue);

      // Example: Check if maxTokens is reasonable
      final isMaxTokensReasonable =
          defaultMaxTokens > 0 && defaultMaxTokens <= 100000;
      expect(isMaxTokensReasonable, isTrue);
    });

    test('sdkVersion can be used in string operations', () {
      final versionParts = sdkVersion.split('.');
      expect(versionParts.length, equals(3));
      expect(int.parse(versionParts[0]), greaterThanOrEqualTo(0));
      expect(int.parse(versionParts[1]), greaterThanOrEqualTo(0));
      expect(int.parse(versionParts[2]), greaterThanOrEqualTo(0));
    });
  });
}
