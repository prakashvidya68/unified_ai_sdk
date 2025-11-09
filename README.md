# unified_ai_sdk

A unified, provider-agnostic Dart SDK for interacting with multiple AI providers through a single, consistent interface. Supports chat completions, embeddings, image generation, and more.

[![pub package](https://img.shields.io/pub/v/unified_ai_sdk.svg)](https://pub.dev/packages/unified_ai_sdk)
[![Dart SDK](https://img.shields.io/badge/Dart-3.0.0+-blue.svg)](https://dart.dev)

## Features

- **Unified Interface**: Single API for multiple AI providers (OpenAI, Anthropic, etc.)
- **Provider Agnostic**: Switch between providers without changing your code
- **Automatic Retries**: Built-in retry logic with exponential backoff
- **Type Safe**: Strong Dart typing throughout
- **BYOK (Bring Your Own Key)**: You control your API keys
- **Extensible**: Easy to add new providers
- **Error Handling**: Structured error types for better error handling

## Supported Providers

- **OpenAI** ✅ (Chat, Embeddings, Image Generation)

More providers coming soon!

## Installation

Add `unified_ai_sdk` to your `pubspec.yaml`:

```yaml
dependencies:
  unified_ai_sdk: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### 1. Initialize the SDK

```dart
import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/core/config.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/core/unified_ai.dart';

// Initialize with your provider configuration
await UnifiedAI.init(
  UnifiedAIConfig(
    defaultProvider: 'openai',
    perProviderConfig: {
      'openai': ProviderConfig(
        id: 'openai',
        auth: ApiKeyAuth(apiKey: 'sk-your-api-key-here'),
        settings: {
          'defaultModel': 'gpt-4o',
        },
      ),
    },
  ),
);
```

### 2. Use the SDK

```dart
final ai = UnifiedAI.instance;

// Chat completion
final response = await ai.chat(
  request: ChatRequest(
    messages: [
      Message(role: Role.user, content: 'Hello! How are you?'),
    ],
  ),
);

print(response.choices.first.message.content);
```

## Usage Examples

### Chat Completions

```dart
import 'package:unified_ai_sdk/src/core/unified_ai.dart';
import 'package:unified_ai_sdk/src/models/requests/chat_request.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';

final ai = UnifiedAI.instance;

// Simple chat
final response = await ai.chat(
  request: ChatRequest(
    messages: [
      Message(role: Role.user, content: 'Explain quantum computing in simple terms'),
    ],
    maxTokens: 500,
    temperature: 0.7,
  ),
);

print('Response: ${response.choices.first.message.content}');
print('Model: ${response.model}');
print('Tokens used: ${response.usage.totalTokens}');

// Multi-turn conversation
final conversation = [
  Message(role: Role.system, content: 'You are a helpful assistant.'),
  Message(role: Role.user, content: 'What is the capital of France?'),
];

final response2 = await ai.chat(
  request: ChatRequest(messages: conversation),
);
```

### Embeddings

```dart
import 'package:unified_ai_sdk/src/core/unified_ai.dart';
import 'package:unified_ai_sdk/src/models/requests/embedding_request.dart';

final ai = UnifiedAI.instance;

// Generate embeddings
final embeddingResponse = await ai.embed(
  request: EmbeddingRequest(
    inputs: ['Hello, world!', 'How are you?'],
    model: 'text-embedding-3-small',
  ),
);

// Access embedding vectors
for (final embedding in embeddingResponse.embeddings) {
  print('Dimension: ${embedding.dimension}');
  print('Vector: ${embedding.vector}');
}
```

### Image Generation

```dart
import 'package:unified_ai_sdk/src/core/unified_ai.dart';
import 'package:unified_ai_sdk/src/models/requests/image_request.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';

final ai = UnifiedAI.instance;

// Generate an image
final imageResponse = await ai.generateImage(
  request: ImageRequest(
    prompt: 'A beautiful sunset over the ocean',
    size: ImageSize.w1024h1024,
    n: 1,
  ),
);

// Access generated images
for (final asset in imageResponse.assets) {
  print('Image URL: ${asset.url}');
  if (asset.base64 != null) {
    print('Base64 available: ${asset.base64!.isNotEmpty}');
  }
}
```

### Using Specific Providers

```dart
// Use default provider
final response1 = await ai.chat(request: chatRequest);

// Use specific provider
final response2 = await ai.chat(
  provider: 'openai',
  request: chatRequest,
);
```

### Error Handling

```dart
import 'package:unified_ai_sdk/src/core/unified_ai.dart';
import 'package:unified_ai_sdk/src/error/error_types.dart';

try {
  final response = await ai.chat(request: chatRequest);
} on AuthError catch (e) {
  print('Authentication failed: ${e.message}');
} on QuotaError catch (e) {
  print('Rate limit exceeded: ${e.message}');
  if (e.retryAfter != null) {
    print('Retry after: ${e.retryAfter}');
  }
} on TransientError catch (e) {
  print('Temporary error: ${e.message}');
  // SDK will automatically retry
} on ClientError catch (e) {
  print('Client error: ${e.message}');
} on CapabilityError catch (e) {
  print('Provider does not support this operation: ${e.message}');
}
```

## Configuration

### Basic Configuration

```dart
final config = UnifiedAIConfig(
  defaultProvider: 'openai',
  perProviderConfig: {
    'openai': ProviderConfig(
      id: 'openai',
      auth: ApiKeyAuth(apiKey: 'sk-...'),
      settings: {
        'defaultModel': 'gpt-4o',
        'baseUrl': 'https://api.openai.com/v1', // Optional
      },
    ),
  },
);
```

### Advanced Configuration with Retry Policy

```dart
import 'package:unified_ai_sdk/src/core/config.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/retry/retry_policy.dart';

final config = UnifiedAIConfig(
  defaultProvider: 'openai',
  perProviderConfig: {
    'openai': ProviderConfig(
      id: 'openai',
      auth: ApiKeyAuth(apiKey: 'sk-...'),
    ),
  },
  retryPolicy: RetryPolicy(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 200),
    maxDelay: Duration(seconds: 60),
    multiplier: 2.0,
  ),
);
```

### Custom Authentication

```dart
// API Key with custom header name
final auth1 = ApiKeyAuth(
  apiKey: 'sk-...',
  headerName: 'X-API-Key', // Default: 'Authorization'
);

// Custom headers
final auth2 = CustomHeaderAuth({
  'X-API-Key': 'custom-key',
  'X-Client-ID': 'client-123',
});
```

## API Reference

### UnifiedAI

Main entry point for the SDK. Singleton pattern for global access.

#### Methods

- `chat({String? provider, required ChatRequest request})` - Send a chat completion request
- `embed({String? provider, required EmbeddingRequest request})` - Generate embeddings
- `generateImage({String? provider, required ImageRequest request})` - Generate images
- `getProvider(String id)` - Get a provider by ID
- `availableProviders` - Get list of registered provider IDs
- `dispose()` - Clean up and reset the singleton

### Request Models

#### ChatRequest

```dart
ChatRequest({
  required List<Message> messages,
  String? model,
  int? maxTokens,
  double? temperature,
  // ... more options
})
```

#### EmbeddingRequest

```dart
EmbeddingRequest({
  required List<String> inputs,
  String? model,
})
```

#### ImageRequest

```dart
ImageRequest({
  required String prompt,
  ImageSize? size,
  int? n,
  // ... more options
})
```

### Response Models

#### ChatResponse

```dart
ChatResponse({
  required String id,
  required List<ChatChoice> choices,
  required Usage usage,
  required String model,
  required String provider,
})
```

#### EmbeddingResponse

```dart
EmbeddingResponse({
  required List<EmbeddingData> embeddings,
  required String model,
  required String provider,
})
```

#### ImageResponse

```dart
ImageResponse({
  required List<ImageAsset> assets,
  required String model,
  required String provider,
})
```

## Error Types

The SDK uses structured error types for better error handling:

- **`AuthError`**: Authentication failed (invalid API key, etc.)
- **`QuotaError`**: Rate limit exceeded or quota exhausted
- **`TransientError`**: Temporary errors (network issues, server errors)
- **`ClientError`**: Client-side errors (invalid request, etc.)
- **`CapabilityError`**: Provider doesn't support the requested operation

All errors extend `AiException` and include:

- `message`: Human-readable error message
- `code`: Error code (optional)
- `provider`: Provider that generated the error (optional)
- `requestId`: Request ID for debugging (optional)

## Retry Logic

The SDK includes automatic retry logic with exponential backoff:

- **Default**: 3 attempts, 100ms initial delay, 30s max delay
- **Retries**: `TransientError` and `QuotaError` (respects `retryAfter`)
- **No Retries**: `AuthError`, `ClientError`, `CapabilityError`

Customize retry behavior via `RetryPolicy`:

```dart
retryPolicy: RetryPolicy(
  maxAttempts: 5,
  initialDelay: Duration(milliseconds: 200),
  maxDelay: Duration(seconds: 60),
  multiplier: 2.0,
  shouldRetry: (e) {
    // Custom retry logic
    return e is TransientError;
  },
)
```

## Examples

See the `example/` directory for complete examples:

- **Simple Chat**: `example/simple_chat/main.dart` - Basic chat completion example

Run an example:

```bash
export OPENAI_API_KEY='sk-your-key-here'
dart run example/simple_chat/main.dart
```

## Requirements

- Dart SDK >= 3.0.0
- Valid API keys for the providers you want to use

## Dependencies

This package depends on:

- `http` ^1.2.0 - For HTTP requests
- `meta` ^1.12.0 - For annotations

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/your-org/unified_ai_sdk/issues)
- **Documentation**: [Full Documentation](https://your-docs-url.com)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes.
