/// Unified AI SDK for Dart and Flutter.
///
/// A comprehensive SDK that provides a unified interface for interacting with
/// multiple AI providers (OpenAI, Anthropic, Google, Cohere, etc.) through a
/// single, consistent API.
///
/// **Key Features:**
/// - **Multi-provider support**: Switch between providers seamlessly
/// - **Unified API**: Same interface for all providers
/// - **Automatic routing**: Intelligent provider selection based on capabilities
/// - **Retry logic**: Built-in retry with exponential backoff
/// - **Streaming support**: Real-time streaming responses
/// - **Telemetry**: Built-in observability and metrics
/// - **Rate limiting**: Automatic rate limit management
/// - **Health checking**: Monitor provider availability
///
/// **Quick Start:**
/// ```dart
/// import 'package:unified_ai_sdk/unified_ai_sdk.dart';
///
/// // Initialize the SDK
/// await UnifiedAI.init(
///   UnifiedAIConfig(
///     defaultProvider: 'openai',
///     perProviderConfig: {
///       'openai': ProviderConfig(
///         id: 'openai',
///         auth: ApiKeyAuth(apiKey: 'sk-your-key-here'),
///       ),
///     },
///   ),
/// );
///
/// // Use the SDK
/// final ai = UnifiedAI.instance;
/// final response = await ai.chat(
///   request: ChatRequest(
///     messages: [
///       Message(role: Role.user, content: 'Hello!'),
///     ],
///   ),
/// );
///
/// print(response.choices.first.message.content);
/// ```
///
/// **Supported Providers:**
/// - OpenAI (GPT-4, GPT-3.5, etc.)
/// - Anthropic (Claude)
/// - Google (Gemini)
/// - Cohere
/// - xAI (Grok)
///
/// **Documentation:**
/// For detailed API documentation, see the generated docs or visit the
/// project repository.
library unified_ai_sdk;

// Core SDK
export 'src/core/unified_ai.dart';
export 'src/core/config.dart';
export 'src/core/provider_config.dart';
export 'src/core/authentication.dart';

// Models - Requests
export 'src/models/requests/chat_request.dart';
export 'src/models/requests/embedding_request.dart';
export 'src/models/requests/image_request.dart';
export 'src/models/requests/stt_request.dart';
export 'src/models/requests/tts_request.dart';

// Models - Responses
export 'src/models/responses/chat_response.dart';
export 'src/models/responses/chat_stream_event.dart';
export 'src/models/responses/embedding_response.dart';
export 'src/models/responses/image_response.dart';
export 'src/models/responses/audio_response.dart';
export 'src/models/responses/transcription_response.dart';

// Models - Common
export 'src/models/common/message.dart';
export 'src/models/common/usage.dart';
export 'src/models/common/capabilities.dart';
export 'src/models/common/conversation.dart';

// Models - Enums
export 'src/models/base_enums.dart';

// Error Handling
export 'src/error/ai_exception.dart';
export 'src/error/error_types.dart';

// Telemetry
export 'src/telemetry/telemetry_handler.dart';
export 'src/telemetry/console_logger.dart';
export 'src/telemetry/metrics_collector.dart';

// Retry
export 'src/retry/retry_policy.dart';

// Cache
export 'src/cache/cache_config.dart';
