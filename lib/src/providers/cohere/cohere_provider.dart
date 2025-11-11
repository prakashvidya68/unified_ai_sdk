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
import 'cohere_mapper.dart';
import 'cohere_models.dart';

/// Cohere provider implementation for the Unified AI SDK.
///
/// This provider integrates with Cohere's API to provide:
/// - Text embeddings (embed-english-v3.0, embed-multilingual-v3.0, etc.)
///
/// **Key Features:**
/// - Uses Cohere's Embed API (`/v1/embed`)
/// - Supports input_type parameter for optimized embeddings
/// - Supports multiple embedding types (float, int8, uint8, binary, ubinary)
/// - Uses API key authentication with Bearer token
///
/// **Example usage:**
/// ```dart
/// final config = ProviderConfig(
///   id: 'cohere',
///   auth: ApiKeyAuth(apiKey: 'co-...'),
///   settings: {
///     'defaultModel': 'embed-english-v3.0',
///   },
/// );
///
/// final provider = CohereProvider();
/// await provider.init(config);
///
/// final response = await provider.embed(EmbeddingRequest(
///   inputs: ['Hello, world!', 'How are you?'],
///   providerOptions: {
///     'cohere': {
///       'input_type': 'search_document',
///     },
///   },
/// ));
/// ```
class CohereProvider extends AiProvider {
  /// Default base URL for Cohere API.
  static const String _defaultBaseUrl = 'https://api.cohere.ai/v1';

  /// API key for authenticating requests.
  late final String _apiKey;

  /// HTTP client wrapper for making API requests.
  late final HttpClientWrapper _http;

  /// Base URL for API requests (can be overridden in settings).
  late final String _baseUrl;

  /// Default model to use when not specified in requests.
  String? _defaultModel;

  /// Mapper for converting between SDK and Cohere models.
  final ProviderMapper _mapper = CohereMapper.instance;

  /// Fallback models used when dynamic fetch is not available.
  ///
  /// These models are always available as a backup, ensuring the SDK works
  /// even when the API is unreachable or model fetching fails.
  ///
  /// **Latest Models (as of 2025):**
  /// - embed-english-v3.0: High-quality English embeddings
  /// - embed-multilingual-v3.0: Multilingual embeddings
  /// - embed-english-light-v3.0: Faster, lighter English embeddings
  ///
  /// **Reference:**
  /// https://docs.cohere.com/docs/models#embed
  static const List<String> _fallbackModels = [
    'embed-english-v3.0',
    'embed-multilingual-v3.0',
    'embed-english-light-v3.0',
    'embed-english-v2.0',
    'embed-multilingual-v2.0',
  ];

  /// Cached capabilities instance.
  ProviderCapabilities? _capabilities;

  @override
  String get id => 'cohere';

  @override
  String get name => 'Cohere';

  @override
  ProviderCapabilities get capabilities {
    _capabilities ??= ProviderCapabilities(
      supportsChat: false, // Cohere doesn't support chat via this API
      supportsEmbedding: true, // Cohere's primary capability
      supportsImageGeneration: false, // Cohere doesn't support image generation
      supportsTTS: false, // Not yet supported
      supportsSTT: false, // Not yet supported
      supportsStreaming: false, // Embeddings don't support streaming
      fallbackModels: _fallbackModels,
      dynamicModels: false, // Cohere doesn't have a public models endpoint
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
            'Cohere provider requires ApiKeyAuth, got ${config.auth.runtimeType}',
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
    // Cohere uses Authorization: Bearer <api_key>
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
    // Cohere doesn't support chat completions
    throw CapabilityError(
      message: 'Cohere API does not support chat completions',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: id,
    );
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    // Validate that embedding is supported
    validateCapability('embed');

    // Map SDK request to Cohere format
    final cohereRequest = _mapper.mapEmbeddingRequest(
      request,
      defaultModel: _defaultModel,
    ) as CohereEmbeddingRequest;

    // Make HTTP POST request to embed endpoint
    final response = await _http.post(
      '$_baseUrl/embed',
      body: jsonEncode(cohereRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final cohereResponse = CohereEmbeddingResponse.fromJson(responseJson);

    // Map Cohere response to SDK format
    return _mapper.mapEmbeddingResponse(cohereResponse);
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    // Cohere doesn't support image generation
    throw CapabilityError(
      message: 'Cohere API does not support image generation',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: id,
    );
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    // Not yet implemented
    throw UnimplementedError('tts() is not yet implemented for Cohere');
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    // Not yet implemented
    throw UnimplementedError('stt() is not yet implemented for Cohere');
  }

  /// Gets the default model for this provider.
  ///
  /// Returns the default model configured in settings, or null if not set.
  String? get defaultModel => _defaultModel;

  /// Gets the base URL for API requests.
  ///
  /// Returns the configured base URL or the default Cohere API URL.
  String get baseUrl => _baseUrl;

  /// Gets the HTTP client wrapper (for testing purposes).
  ///
  /// This is exposed for testing but should not be used in production code.
  @visibleForTesting
  HttpClientWrapper get httpClient => _http;
}
