import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../../core/authentication.dart';
import '../../core/provider_config.dart';
import '../../error/error_types.dart';
import '../../models/common/capabilities.dart';
import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/requests/image_request.dart';
import '../../models/requests/stt_request.dart';
import '../../models/requests/tts_request.dart';
import '../../models/responses/audio_response.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/responses/transcription_response.dart';
import '../../error/error_mapper.dart';
import '../../network/http_client_wrapper.dart';
import '../base/ai_provider.dart';
import '../base/provider_mapper.dart';
import 'anthropic_mapper.dart';
import 'anthropic_models.dart';

/// Anthropic Claude provider implementation for the Unified AI SDK.
///
/// This provider integrates with Anthropic's Claude API to provide:
/// - Chat completions (Claude 3 Opus, Sonnet, Haiku)
/// - Streaming support for chat completions
///
/// **Key Features:**
/// - Uses Anthropic's Messages API (`/v1/messages`)
/// - Supports system prompts as separate field
/// - Handles content blocks in responses
/// - Uses `x-api-key` header for authentication
///
/// **Example usage:**
/// ```dart
/// final config = ProviderConfig(
///   id: 'anthropic',
///   auth: ApiKeyAuth(
///     apiKey: 'sk-ant-...',
///     headerName: 'x-api-key',
///   ),
///   settings: {
///     'defaultModel': 'claude-3-opus-20240229',
///   },
/// );
///
/// final provider = AnthropicProvider();
/// await provider.init(config);
///
/// final response = await provider.chat(ChatRequest(
///   messages: [
///     Message(role: Role.system, content: 'You are helpful.'),
///     Message(role: Role.user, content: 'Hello!'),
///   ],
///   maxTokens: 1024,
/// ));
/// ```
class AnthropicProvider extends AiProvider {
  /// Default base URL for Anthropic API.
  static const String _defaultBaseUrl = 'https://api.anthropic.com/v1';

  /// API key for authenticating requests.
  late final String _apiKey;

  /// HTTP client wrapper for making API requests.
  late final HttpClientWrapper _http;

  /// Base URL for API requests (can be overridden in settings).
  late final String _baseUrl;

  /// Default model to use when not specified in requests.
  String? _defaultModel;

  /// Mapper for converting between SDK and Anthropic models.
  final ProviderMapper _mapper = AnthropicMapper.instance;

  /// Fallback models used when dynamic fetch is not available.
  ///
  /// These models are always available as a backup, ensuring the SDK works
  /// even when the API is unreachable or model fetching fails.
  ///
  /// **Latest Models (as of 2025):**
  /// - Claude Sonnet 4.5: Best balance of intelligence, speed, and cost
  /// - Claude Haiku 4.5: Fastest model with near-frontier intelligence
  /// - Claude Opus 4.1: Exceptional model for specialized reasoning tasks
  ///
  /// **Legacy Models (still available):**
  /// - Claude Sonnet 4, Claude Sonnet 3.7, Claude Opus 4
  /// - Claude Haiku 3.5, Claude Haiku 3
  ///
  /// **Reference:**
  /// https://docs.claude.com/en/docs/about-claude/models/overview#latest-models-comparison
  static const List<String> _fallbackModels = [
    // Latest models (recommended)
    'claude-sonnet-4-5-20250929', // Claude Sonnet 4.5 - Best balance
    'claude-haiku-4-5-20251001', // Claude Haiku 4.5 - Fastest
    'claude-opus-4-1-20250805', // Claude Opus 4.1 - Specialized reasoning
    // Legacy models (still available for backward compatibility)
    'claude-sonnet-4-20250514', // Claude Sonnet 4
    'claude-3-7-sonnet-20250219', // Claude Sonnet 3.7
    'claude-opus-4-20250514', // Claude Opus 4
    'claude-3-5-haiku-20241022', // Claude Haiku 3.5
    'claude-3-haiku-20240307', // Claude Haiku 3
  ];

  /// Cached capabilities instance.
  ProviderCapabilities? _capabilities;

  @override
  String get id => 'anthropic';

  @override
  String get name => 'Anthropic Claude';

  @override
  ProviderCapabilities get capabilities {
    _capabilities ??= ProviderCapabilities(
      supportsChat: true,
      supportsEmbedding: false, // Anthropic doesn't support embeddings
      supportsImageGeneration:
          false, // Anthropic doesn't support image generation
      supportsTTS: false, // Not yet supported
      supportsSTT: false, // Not yet supported
      supportsStreaming: true, // Anthropic supports streaming
      fallbackModels: _fallbackModels,
      dynamicModels: false, // Anthropic doesn't have a public models endpoint
    );
    return _capabilities!;
  }

  @override
  Future<void> init(ProviderConfig config) async {
    // Validate that config ID matches provider ID
    if (config.id != id) {
      throw ClientError(
        message:
            'Provider config ID (${config.id}) does not match provider ID ($id)',
        code: 'CONFIG_ID_MISMATCH',
      );
    }

    // Extract API key from authentication
    // Anthropic uses x-api-key header, but ApiKeyAuth can handle it
    if (config.auth is! ApiKeyAuth) {
      throw AuthError(
        message:
            'Anthropic provider requires ApiKeyAuth, got ${config.auth.runtimeType}',
        code: 'INVALID_AUTH_TYPE',
        provider: id,
      );
    }

    final apiKeyAuth = config.auth as ApiKeyAuth;
    _apiKey = apiKeyAuth.apiKey;

    if (_apiKey.isEmpty) {
      throw AuthError(
        message: 'API key cannot be empty',
        code: 'EMPTY_API_KEY',
        provider: id,
      );
    }

    // Extract base URL from settings or use default
    _baseUrl = config.settings['baseUrl'] as String? ?? _defaultBaseUrl;

    // Extract default model from settings
    _defaultModel = config.settings['defaultModel'] as String?;

    // Build authentication headers
    // Anthropic uses x-api-key header (not Authorization: Bearer)
    // Create ApiKeyAuth with x-api-key header if not already set
    Map<String, String> authHeaders;
    if (apiKeyAuth.headerName.toLowerCase() == 'x-api-key') {
      // Already configured correctly, use as-is
      authHeaders = apiKeyAuth.buildHeaders();
    } else {
      // Override to use x-api-key header for Anthropic
      // ApiKeyAuth.buildHeaders() returns just the key for non-Authorization headers
      final customAuth = ApiKeyAuth(
        apiKey: _apiKey,
        headerName: 'x-api-key',
      );
      authHeaders = customAuth.buildHeaders();
    }

    // Ensure anthropic-version header is present (required by Anthropic API)
    authHeaders['anthropic-version'] = '2023-06-01';

    // Initialize HTTP client wrapper with authentication headers
    // Allow injecting custom client for testing via settings
    final customClient = config.settings['httpClient'] as http.Client?;
    _http = HttpClientWrapper(
      client: customClient ?? http.Client(),
      defaultHeaders: {
        ...authHeaders,
        'Content-Type': 'application/json',
      },
    );
  }

  @override
  Future<ChatResponse> chat(ChatRequest request) async {
    // Validate that chat is supported
    validateCapability('chat');

    // Map SDK request to Anthropic format
    final anthropicRequest = _mapper.mapChatRequest(
      request,
      defaultModel: _defaultModel,
    ) as AnthropicChatRequest;

    // Make HTTP POST request to messages endpoint
    final response = await _http.post(
      '$_baseUrl/messages',
      body: jsonEncode(anthropicRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final anthropicResponse = AnthropicChatResponse.fromJson(responseJson);

    // Map Anthropic response to SDK format
    return _mapper.mapChatResponse(anthropicResponse);
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    // Anthropic doesn't support embeddings
    throw CapabilityError(
      message: 'Anthropic Claude API does not support embeddings',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: id,
    );
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    // Anthropic doesn't support image generation
    throw CapabilityError(
      message: 'Anthropic Claude API does not support image generation',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: id,
    );
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    // Not yet implemented
    throw UnimplementedError('tts() is not yet implemented for Anthropic');
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    // Not yet implemented
    throw UnimplementedError('stt() is not yet implemented for Anthropic');
  }

  /// Gets the default model for this provider.
  ///
  /// Returns the default model configured in settings, or null if not set.
  String? get defaultModel => _defaultModel;

  /// Gets the base URL for API requests.
  ///
  /// Returns the configured base URL or the default Anthropic API URL.
  String get baseUrl => _baseUrl;

  /// Gets the HTTP client wrapper (for testing purposes).
  ///
  /// This is exposed for testing but should not be used in production code.
  @visibleForTesting
  HttpClientWrapper get httpClient => _http;
}
