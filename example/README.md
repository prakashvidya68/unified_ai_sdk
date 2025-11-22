# Unified AI SDK Examples

Comprehensive examples demonstrating all features of the Unified AI SDK.

## Examples

### 1. Simple Chat (`01_simple_chat/`)

Basic chat completion example showing initialization and a simple request.

**Features:**

- SDK initialization
- Basic chat request
- Response handling

**Run:**

```bash
export OPENAI_API_KEY='sk-your-key-here'
dart run example/01_simple_chat/main.dart
```

---

### 2. Streaming Chat (`02_streaming_chat/`)

Real-time streaming chat responses with incremental text display.

**Features:**

- Streaming chat with `chatStream()`
- Handling stream events (delta, done, metadata)
- Real-time text display

**Run:**

```bash
export OPENAI_API_KEY='sk-your-key-here'
dart run example/02_streaming_chat/main.dart
```

---

### 3. Embeddings Search (`03_embeddings_search/`)

Semantic search using embeddings and cosine similarity.

**Features:**

- Generating embeddings for documents
- Query embedding generation
- Cosine similarity calculation
- Document ranking by relevance

**Run:**

```bash
export OPENAI_API_KEY='sk-your-key-here'
dart run example/03_embeddings_search/main.dart
```

---

### 4. Image Generation (`04_image_generation/`)

AI-powered image generation from text prompts.

**Features:**

- Image generation with DALL-E
- Image size and quality configuration
- Multiple image generation
- URL and base64 access

**Run:**

```bash
export OPENAI_API_KEY='sk-your-key-here'
dart run example/04_image_generation/main.dart
```

---

### 5. Multi-Provider (`05_multi_provider/`)

Using multiple AI providers with explicit selection and auto-routing.

**Features:**

- Multiple provider configuration
- Explicit provider selection
- Automatic provider routing
- Provider capability inspection
- Response comparison

**Run:**

```bash
export OPENAI_API_KEY='sk-your-key-here'
export ANTHROPIC_API_KEY='sk-ant-your-key-here'  # Optional
dart run example/05_multi_provider/main.dart
```

---

### 6. Error Handling (`06_error_handling/`)

Comprehensive error handling patterns and best practices.

**Features:**

- Handling different error types (AuthError, QuotaError, etc.)
- Retry logic configuration
- Graceful error degradation
- User-friendly error messages
- Error recovery strategies

**Run:**

```bash
export OPENAI_API_KEY='sk-your-key-here'
dart run example/06_error_handling/main.dart
```

---

### 7. Telemetry (`07_telemetry/`)

Observability and monitoring with telemetry handlers.

**Features:**

- Console logging with different log levels
- Metrics collection (requests, latency, tokens)
- Error tracking and breakdown
- Performance analysis
- Usage statistics

**Run:**

```bash
export OPENAI_API_KEY='sk-your-key-here'
dart run example/07_telemetry/main.dart
```

---

### 8. Provider Health (`08_provider_health/`)

Monitoring provider health and implementing health-based routing.

**Features:**

- Provider health checking
- Health status monitoring
- Health-based provider selection
- Latency tracking
- Unhealthy provider handling

**Run:**

```bash
export OPENAI_API_KEY='sk-your-key-here'
export ANTHROPIC_API_KEY='sk-ant-your-key-here'  # Optional
dart run example/08_provider_health/main.dart
```

---

## Prerequisites

All examples require API keys. Set them as environment variables:

```bash
export OPENAI_API_KEY='sk-your-openai-key'
export ANTHROPIC_API_KEY='sk-ant-your-anthropic-key'  # For multi-provider examples
```

## Running All Examples

Run all examples sequentially:

```bash
for example in example/*/main.dart; do
  echo "Running $example..."
  dart run "$example"
  echo ""
done
```

## Example Output

Each example includes:

- ✅ Clear status indicators
- 📊 Detailed output formatting
- ❌ Error handling demonstrations
- 💡 Helpful tips and explanations