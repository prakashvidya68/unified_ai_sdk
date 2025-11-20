# unified_ai_sdk

A unified, provider-agnostic Dart SDK for interacting with multiple AI providers through a single, consistent interface. Supports chat completions, embeddings, image generation, streaming, and more.

[![pub package](https://img.shields.io/pub/v/unified_ai_sdk.svg)](https://pub.dev/packages/unified_ai_sdk)
[![Dart SDK](https://img.shields.io/badge/Dart-3.0.0+-blue.svg)](https://dart.dev)

## Features

- **Unified Interface**: Single API for multiple AI providers (OpenAI, Anthropic, Google, Cohere, xAI, Mistral)
- **Provider Agnostic**: Switch between providers without changing your code
- **Automatic Routing**: Intelligent provider selection based on request intent and capabilities
- **Streaming Support**: Real-time streaming responses for chat completions
- **Automatic Retries**: Built-in retry logic with exponential backoff
- **Type Safe**: Strong Dart typing throughout
- **BYOK (Bring Your Own Key)**: You control your API keys
- **Telemetry**: Built-in observability and metrics collection
- **Health Checking**: Monitor provider availability and performance
- **Rate Limiting**: Automatic rate limit management
- **Caching**: Configurable response caching to reduce API costs
- **Error Handling**: Structured error types for better error handling
- **Extensible**: Easy to add new providers

## Supported Providers

The SDK supports 6 major AI providers, each with different capabilities:

| Provider      | Chat | Embeddings | Image Gen | Streaming | Dynamic Models |
| ------------- | ---- | ---------- | --------- | --------- | -------------- |
| **OpenAI**    | ✅   | ✅         | ✅        | ✅        | ✅             |
| **Anthropic** | ✅   | ❌         | ❌        | ✅        | ❌             |
| **Google**    | ✅   | ✅         | ❌        | ✅        | ✅             |
| **Cohere**    | ✅   | ✅         | ❌        | ✅        | ✅             |
| **xAI**       | ✅   | ❌         | ❌        | ✅        | ❌             |
| **Mistral**   | ✅   | ✅         | ❌        | ✅        | ✅             |

### Provider Capabilities

- **OpenAI**: GPT-5.1, GPT-5, GPT-4o series, embeddings, DALL-E image generation, Sora video generation, TTS/STT
- **Anthropic**: Claude 3 Opus, Sonnet, Haiku models
- **Google**: Gemini models, embeddings
- **Cohere**: Command models, embeddings
- **xAI**: Grok models
- **Mistral**: Mistral models, embeddings

## Installation

Add `unified_ai_sdk` to your `pubspec.yaml`:

```yaml
dependencies:
  unified_ai_sdk: ^0.0.1
```

Then run:

```bash
dart pub get
```

## Quick Start

### 1. Initialize the SDK

```dart
import 'package:unified_ai_sdk/unified_ai_sdk.dart';

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
import 'package:unified_ai_sdk/unified_ai_sdk.dart';

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

### Streaming Chat

```dart
final ai = UnifiedAI.instance;

// Streaming chat for real-time responses
final stream = ai.chatStream(
  request: ChatRequest(
    messages: [
      Message(role: Role.user, content: 'Tell me a story'),
    ],
  ),
);

String accumulatedText = '';
await for (final event in stream) {
  if (event.delta != null) {
    accumulatedText += event.delta!;
    print(event.delta!); // Print incrementally
  }

  if (event.done) {
    print('\n\nStream completed!');
    if (event.metadata != null) {
      final usage = event.metadata!['usage'];
      print('Tokens used: ${usage['total_tokens']}');
    }
    break;
  }
}
```

### Embeddings

```dart
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

### Multi-Provider Usage

```dart
// Configure multiple providers
await UnifiedAI.init(
  UnifiedAIConfig(
    defaultProvider: 'openai',
    perProviderConfig: {
      'openai': ProviderConfig(
        id: 'openai',
        auth: ApiKeyAuth(apiKey: 'sk-openai-key'),
      ),
      'anthropic': ProviderConfig(
        id: 'anthropic',
        auth: ApiKeyAuth(
          apiKey: 'sk-ant-anthropic-key',
          headerName: 'x-api-key',
        ),
      ),
    },
  ),
);

final ai = UnifiedAI.instance;

// Use default provider
final response1 = await ai.chat(request: chatRequest);

// Use specific provider
final response2 = await ai.chat(
  provider: 'openai',
  request: chatRequest,
);

// Automatic intent-based routing
// SDK automatically selects appropriate provider based on request
final response3 = await ai.chat(
  request: ChatRequest(
    messages: [
      Message(role: Role.user, content: 'Draw a picture of a cat'),
    ],
  ),
);
// Automatically routes to a provider that supports image generation
```

### Error Handling

```dart
import 'package:unified_ai_sdk/unified_ai_sdk.dart';

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
import 'package:unified_ai_sdk/unified_ai_sdk.dart';

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

### Configuration with Telemetry

```dart
final config = UnifiedAIConfig(
  defaultProvider: 'openai',
  perProviderConfig: {
    'openai': ProviderConfig(
      id: 'openai',
      auth: ApiKeyAuth(apiKey: 'sk-...'),
    ),
  },
  telemetryHandlers: [
    ConsoleLogger(),
    MetricsCollector(),
  ],
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

## Advanced Features

### Intent-Based Routing

The SDK can automatically route requests to appropriate providers based on the request type:

```dart
// Chat request - routes to any provider with chat capability
final chatResponse = await ai.chat(request: chatRequest);

// Embedding request - routes to provider with embedding capability
final embedResponse = await ai.embed(request: embeddingRequest);

// Image generation - routes to provider with image generation capability
final imageResponse = await ai.generateImage(request: imageRequest);
```

### Provider Health Checking

```dart
final ai = UnifiedAI.instance;
final provider = ai.getProvider('openai');

if (provider != null) {
  // Check provider capabilities
  print('Supports chat: ${provider.capabilities.supportsChat}');
  print('Supports streaming: ${provider.capabilities.supportsStreaming}');
  print('Supported models: ${provider.capabilities.supportedModels}');
}
```

### Telemetry and Observability

```dart
import 'package:unified_ai_sdk/unified_ai_sdk.dart';

// Configure telemetry handlers
await UnifiedAI.init(
  UnifiedAIConfig(
    defaultProvider: 'openai',
    perProviderConfig: {...},
    telemetryHandlers: [
      ConsoleLogger(), // Logs to console
      MetricsCollector(), // Collects metrics
    ],
  ),
);

// Telemetry events are automatically emitted for:
// - Request start
// - Response completion (with latency and token usage)
// - Errors
```

## API Reference

### UnifiedAI

Main entry point for the SDK. Singleton pattern for global access.

#### Methods

- `chat({String? provider, required ChatRequest request})` - Send a chat completion request
- `chatStream({String? provider, required ChatRequest request})` - Generate streaming chat completion
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
  double? topP,
  int? n,
  bool? stream,
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
  String? quality,
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
  Usage? usage,
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

### Error Types

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

- **01_simple_chat**: Basic chat completion example
- **02_streaming_chat**: Real-time streaming chat responses
- **03_embeddings_search**: Semantic search using embeddings
- **04_image_generation**: AI-powered image generation
- **05_multi_provider**: Using multiple providers with auto-routing
- **06_error_handling**: Comprehensive error handling patterns
- **07_telemetry**: Observability and monitoring
- **08_provider_health**: Provider health checking and monitoring

Run an example:

```bash
export OPENAI_API_KEY='sk-your-key-here'
dart run example/01_simple_chat/main.dart
```

For more details, see [example/README.md](example/README.md).

## Requirements

- Dart SDK >= 3.0.0
- Valid API keys for the providers you want to use

## Dependencies

This package depends on:

- `http` ^1.2.0 - For HTTP requests
- `meta` ^1.12.0 - For annotations
- `collection` ^1.18.0 - For collection utilities

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/your-org/unified_ai_sdk/issues)
- **Documentation**: [Full Documentation](https://your-docs-url.com)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes.
