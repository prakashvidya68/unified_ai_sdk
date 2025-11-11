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
import '../base/rate_limiter_factory.dart';
import 'google_mapper.dart';
import 'google_models.dart';

/// Google Gemini provider implementation for the Unified AI SDK.
///
/// This provider integrates with Google's Gemini API to provide:
/// - Chat completions (Gemini Pro, Gemini Ultra, etc.)
/// - Multimodal inputs (text + images)
/// - Streaming support for chat completions
///
/// **Key Features:**
/// - Uses Google's GenerateContent API (`/v1/models/{model}:generateContent`)
/// - Supports multimodal inputs (text and images) via message.meta
/// - Handles system instructions as separate field
/// - Uses API key authentication
/// - Supports Vertex AI integration (via baseUrl configuration)
///
/// **Example usage:**
/// ```dart
/// final config = ProviderConfig(
///   id: 'google',
///   auth: ApiKeyAuth(apiKey: 'AIza...'),
///   settings: {
///     'defaultModel': 'gemini-pro',
///     'baseUrl': 'https://generativelanguage.googleapis.com/v1', // Optional
///   },
/// );
///
/// final provider = GoogleProvider();
/// await provider.init(config);
///
/// final response = await provider.chat(ChatRequest(
///   messages: [
///     Message(role: Role.system, content: 'You are helpful.'),
///     Message(
///       role: Role.user,
///       content: 'What is in this image?',
///       meta: {
///         'images': [
///           {'mime_type': 'image/jpeg', 'data': 'base64...'},
///         ],
///       },
///     ),
///   ],
///   maxTokens: 1024,
/// ));
/// ```
class GoogleProvider extends AiProvider {
  /// Default base URL for Google Gemini API.
  static const String _defaultBaseUrl =
      'https://generativelanguage.googleapis.com/v1';

  /// API key for authenticating requests.
  late final String _apiKey;

  /// HTTP client wrapper for making API requests.
  late final HttpClientWrapper _http;

  /// Base URL for API requests (can be overridden in settings).
  late final String _baseUrl;

  /// Default model to use when not specified in requests.
  String? _defaultModel;

  /// Mapper for converting between SDK and Google models.
  final ProviderMapper _mapper = GoogleMapper.instance;

  /// Fallback models used when dynamic fetch is not available.
  ///
  /// These models are always available as a backup, ensuring the SDK works
  /// even when the API is unreachable or model fetching fails.
  ///
  /// **Latest Models (as of 2025):**
  /// - gemini-2.0-flash-exp: Fast and efficient
  /// - gemini-1.5-pro: Advanced reasoning
  /// - gemini-1.5-flash: Fast responses
  ///
  /// **Reference:**
  /// https://ai.google.dev/models/gemini
  static const List<String> _fallbackModels = [
    'gemini-2.0-flash-exp',
    'gemini-1.5-pro',
    'gemini-1.5-flash',
    'gemini-pro',
    'gemini-pro-vision',
  ];

  /// Cached capabilities instance.
  ProviderCapabilities? _capabilities;

  @override
  String get id => 'google';

  @override
  String get name => 'Google Gemini';

  @override
  ProviderCapabilities get capabilities {
    _capabilities ??= ProviderCapabilities(
      supportsChat: true,
      supportsEmbedding:
          false, // Gemini doesn't support embeddings via this API
      supportsImageGeneration: false, // Gemini doesn't support image generation
      supportsTTS: false, // Not yet supported
      supportsSTT: false, // Not yet supported
      supportsStreaming: true, // Gemini supports streaming
      fallbackModels: _fallbackModels,
      dynamicModels: false, // Google doesn't have a public models endpoint
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
    if (config.auth is! ApiKeyAuth) {
      throw AuthError(
        message:
            'Google provider requires ApiKeyAuth, got ${config.auth.runtimeType}',
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
    // Supports both standard API and Vertex AI
    _baseUrl = config.settings['baseUrl'] as String? ?? _defaultBaseUrl;

    // Extract default model from settings
    _defaultModel = config.settings['defaultModel'] as String?;

    // Build authentication headers
    // Google uses API key as query parameter, but we'll also set it in headers
    // for compatibility with Vertex AI which may use different auth
    final authHeaders = apiKeyAuth.buildHeaders();

    // Initialize HTTP client wrapper with authentication headers
    // Allow injecting custom client for testing via settings
    final customClient = config.settings['httpClient'] as http.Client?;

    // Create rate limiter for this provider
    final rateLimiter = RateLimiterFactory.create(id, config.settings);

    _http = HttpClientWrapper(
      client: customClient ?? http.Client(),
      defaultHeaders: {
        ...authHeaders,
        'Content-Type': 'application/json',
      },
      rateLimiter: rateLimiter,
    );
  }

  @override
  Future<ChatResponse> chat(ChatRequest request) async {
    // Validate that chat is supported
    validateCapability('chat');

    // Map SDK request to Google format
    final googleRequest = _mapper.mapChatRequest(
      request,
      defaultModel: _defaultModel,
    ) as GoogleChatRequest;

    // Determine model from request
    final model = googleRequest.model ?? _defaultModel;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in ChatRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Build request body (remove model from body, it goes in URL)
    final requestBody = googleRequest.toJson();
    requestBody.remove('model');

    // Build URL with model and API key
    // Google uses query parameter for API key: ?key=API_KEY
    final url = '$_baseUrl/models/$model:generateContent?key=$_apiKey';

    // Make HTTP POST request
    final response = await _http.post(
      url,
      body: jsonEncode(requestBody),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final googleResponse = GoogleChatResponse.fromJson(responseJson);

    // Map Google response to SDK format
    final chatResponse = _mapper.mapChatResponse(googleResponse);

    // Update model name in response
    return ChatResponse(
      id: chatResponse.id,
      choices: chatResponse.choices,
      usage: chatResponse.usage,
      model: model, // Use the model from request
      provider: chatResponse.provider,
      timestamp: chatResponse.timestamp,
      metadata: chatResponse.metadata,
    );
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    // Google Gemini doesn't support embeddings via this API
    throw CapabilityError(
      message:
          'Google Gemini API does not support embeddings via the GenerateContent API',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: id,
    );
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    // Google Gemini doesn't support image generation
    throw CapabilityError(
      message: 'Google Gemini API does not support image generation',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: id,
    );
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    // Not yet implemented
    throw UnimplementedError('tts() is not yet implemented for Google');
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    // Not yet implemented
    throw UnimplementedError('stt() is not yet implemented for Google');
  }

  /// Gets the default model for this provider.
  ///
  /// Returns the default model configured in settings, or null if not set.
  String? get defaultModel => _defaultModel;

  /// Gets the base URL for API requests.
  ///
  /// Returns the configured base URL or the default Google API URL.
  String get baseUrl => _baseUrl;

  /// Gets the HTTP client wrapper (for testing purposes).
  ///
  /// This is exposed for testing but should not be used in production code.
  @visibleForTesting
  HttpClientWrapper get httpClient => _http;
}
