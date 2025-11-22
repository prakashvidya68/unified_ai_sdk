import 'package:test/test.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';

void main() {
  group('Role enum', () {
    test('should have all expected values', () {
      expect(Role.values.length, equals(4));
      expect(Role.values, contains(Role.system));
      expect(Role.values, contains(Role.user));
      expect(Role.values, contains(Role.assistant));
      expect(Role.values, contains(Role.function));
    });

    test('should have correct string representation', () {
      expect(Role.system.toString(), contains('system'));
      expect(Role.user.toString(), contains('user'));
      expect(Role.assistant.toString(), contains('assistant'));
      expect(Role.function.toString(), contains('function'));
    });
  });

  group('TaskType enum', () {
    test('should have all expected values', () {
      expect(TaskType.values.length, equals(5));
      expect(TaskType.values, contains(TaskType.chat));
      expect(TaskType.values, contains(TaskType.embedding));
      expect(TaskType.values, contains(TaskType.imageGeneration));
      expect(TaskType.values, contains(TaskType.tts));
      expect(TaskType.values, contains(TaskType.stt));
    });

    test('should have correct string representation', () {
      expect(TaskType.chat.toString(), contains('chat'));
      expect(TaskType.embedding.toString(), contains('embedding'));
      expect(TaskType.imageGeneration.toString(), contains('imageGeneration'));
      expect(TaskType.tts.toString(), contains('tts'));
      expect(TaskType.stt.toString(), contains('stt'));
    });
  });

  group('ProviderType enum', () {
    test('should have all expected values', () {
      expect(ProviderType.values.length, equals(6));
      expect(ProviderType.values, contains(ProviderType.openai));
      expect(ProviderType.values, contains(ProviderType.anthropic));
      expect(ProviderType.values, contains(ProviderType.google));
      expect(ProviderType.values, contains(ProviderType.cohere));
      expect(ProviderType.values, contains(ProviderType.stability));
      expect(ProviderType.values, contains(ProviderType.custom));
    });

    test('should have correct string representation', () {
      expect(ProviderType.openai.toString(), contains('openai'));
      expect(ProviderType.anthropic.toString(), contains('anthropic'));
      expect(ProviderType.google.toString(), contains('google'));
      expect(ProviderType.cohere.toString(), contains('cohere'));
      expect(ProviderType.stability.toString(), contains('stability'));
      expect(ProviderType.custom.toString(), contains('custom'));
    });
  });

  group('Enum usage examples', () {
    test('Role can be used in variable assignment', () {
      final userRole = Role.user;
      expect(userRole, equals(Role.user));
      expect(userRole, isNot(equals(Role.system)));
    });

    test('TaskType can be used in switch statements', () {
      final TaskType task = TaskType.chat;
      String description;

      switch (task) {
        case TaskType.chat:
          description = 'Chat completion';
          break;
        case TaskType.embedding:
          description = 'Text embedding';
          break;
        case TaskType.imageGeneration:
          description = 'Image generation';
          break;
        case TaskType.tts:
          description = 'Text to speech';
          break;
        case TaskType.stt:
          description = 'Speech to text';
          break;
      }

      expect(description, equals('Chat completion'));
    });

    test('ProviderType can be used in collections', () {
      final supportedProviders = [
        ProviderType.openai,
        ProviderType.anthropic,
        ProviderType.google,
      ];

      expect(supportedProviders.length, equals(3));
      expect(supportedProviders, contains(ProviderType.openai));
      expect(supportedProviders, contains(ProviderType.anthropic));
      expect(supportedProviders, contains(ProviderType.google));
    });
  });
}

