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
import '../../network/http_client_wrapper.dart';
import '../base/ai_provider.dart';
import '../base/model_fetcher.dart';
import '../base/provider_mapper.dart';
import 'openai_mapper.dart';

/// OpenAI provider implementation for the Unified AI SDK.
///
/// This provider integrates with OpenAI's API to provide:
/// - Chat completions (GPT-4, GPT-3.5-turbo, etc.)
/// - Text embeddings (text-embedding-3-small, text-embedding-ada-002)
/// - Image generation (DALL-E 3)
/// - Text-to-speech (TTS)
/// - Speech-to-text (Whisper)
/// - Streaming support for chat completions
///
/// **Example usage:**
/// ```dart
/// final config = ProviderConfig(
///   id: 'openai',
///   auth: ApiKeyAuth(apiKey: 'sk-...'),
///   settings: {
///     'defaultModel': 'gpt-4',
///   },
/// );
///
/// final provider = OpenAIProvider();
/// await provider.init(config);
///
/// final response = await provider.chat(ChatRequest(
///   messages: [Message(role: Role.user, content: 'Hello!')],
/// ));
/// ```
class OpenAIProvider extends AiProvider implements ModelFetcher {
  /// Default base URL for OpenAI API.
  static const String _defaultBaseUrl = 'https://api.openai.com/v1';

  /// API key for authenticating requests.
  late final String _apiKey;

  /// HTTP client wrapper for making API requests.
  late final HttpClientWrapper _http;

  /// Base URL for API requests (can be overridden in settings).
  late final String _baseUrl;

  /// Default model to use when not specified in requests.
  String? _defaultModel;

  /// Mapper for converting between SDK and OpenAI models.
  // ignore: unused_field
  final ProviderMapper _mapper = OpenAIMapper.instance;

  /// Fallback models used when dynamic fetch fails or is not available.
  ///
  /// These models are always available as a backup, ensuring the SDK works
  /// even when the API is unreachable or the models endpoint fails.
  static const List<String> _fallbackModels = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-4',
    'gpt-4-32k',
    'gpt-3.5-turbo',
    'gpt-3.5-turbo-16k',
    'text-embedding-3-large',
    'text-embedding-3-small',
    'text-embedding-ada-002',
    'dall-e-3',
    'dall-e-2',
    'tts-1',
    'tts-1-hd',
    'whisper-1',
  ];

  /// Cached capabilities instance (created once, updated when models are fetched).
  ProviderCapabilities? _capabilities;

  @override
  String get id => 'openai';

  @override
  String get name => 'OpenAI';

  @override
  ProviderCapabilities get capabilities {
    _capabilities ??= ProviderCapabilities(
      supportsChat: true,
      supportsEmbedding: true,
      supportsImageGeneration: true,
      supportsTTS: true,
      supportsSTT: true,
      supportsStreaming: true,
      fallbackModels: _fallbackModels,
      dynamicModels: true, // Enable dynamic model fetching
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
            'OpenAI provider requires ApiKeyAuth, got ${config.auth.runtimeType}',
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
    final authHeaders = apiKeyAuth.buildHeaders();

    // Initialize HTTP client wrapper with authentication headers
    _http = HttpClientWrapper(
      client: http.Client(),
      defaultHeaders: {
        ...authHeaders,
        'Content-Type': 'application/json',
      },
    );

    // Optionally fetch models during initialization if configured
    if (config.settings['fetchModelsOnInit'] == true) {
      try {
        await refreshModels();
      } on Exception {
        // Silently fail - fallback models will be used
        // Log error if telemetry is configured
      }
    }
  }

  // ModelFetcher implementation

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      final response = await _http.get('$_baseUrl/models');

      if (response.statusCode != 200) {
        // Return fallback models on error
        return _fallbackModels;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final modelsList = data['data'] as List<dynamic>?;

      if (modelsList == null) {
        return _fallbackModels;
      }

      // Extract model IDs and filter out unsupported models
      final models = modelsList
          .map((m) => m['id'] as String?)
          .whereType<String>()
          .where((id) => _isSupportedModel(id))
          .toList();

      // Update capabilities cache
      capabilities.updateModels(models);

      return models.isEmpty ? _fallbackModels : models;
    } on Exception {
      // On any error, return fallback models
      return _fallbackModels;
    }
  }

  @override
  String inferModelType(String modelId) {
    final lowerId = modelId.toLowerCase();
    if (lowerId.startsWith('gpt')) return 'text';
    if (lowerId.contains('embedding')) return 'embedding';
    if (lowerId.startsWith('dall-e')) return 'image';
    if (lowerId.startsWith('tts-')) return 'tts';
    if (lowerId.startsWith('whisper-')) return 'stt';
    return 'other';
  }

  /// Refreshes the list of available models from the API.
  ///
  /// This method fetches the latest models from OpenAI's API and updates
  /// the capabilities cache. If the fetch fails, fallback models are used.
  ///
  /// **Returns:**
  /// The list of available model IDs (either from API or fallback)
  ///
  /// **Example:**
  /// ```dart
  /// final models = await provider.refreshModels();
  /// print('Available models: ${models.length}');
  /// ```
  Future<List<String>> refreshModels() async {
    return await fetchAvailableModels();
  }

  /// Checks if a model ID should be included in the supported models list.
  ///
  /// Filters out deprecated, internal, or unsupported models.
  bool _isSupportedModel(String modelId) {
    // Filter out:
    // - Models with colons (usually fine-tuned models or deprecated formats)
    // - Models marked as deprecated
    // - Empty or invalid IDs
    if (modelId.isEmpty) return false;
    if (modelId.contains(':')) return false;
    if (modelId.toLowerCase().contains('deprecated')) return false;
    if (modelId.toLowerCase().contains('internal')) return false;

    // Include known model prefixes
    final lowerId = modelId.toLowerCase();
    return lowerId.startsWith('gpt-') ||
        lowerId.startsWith('text-embedding-') ||
        lowerId.startsWith('dall-e-') ||
        lowerId.startsWith('tts-') ||
        lowerId.startsWith('whisper-');
  }

  @override
  Future<ChatResponse> chat(ChatRequest request) async {
    // Will be implemented in Step 8.4
    throw UnimplementedError('chat() will be implemented in Step 8.4');
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    // Will be implemented in Step 8.5
    throw UnimplementedError('embed() will be implemented in Step 8.5');
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    // Will be implemented in Step 8.6
    throw UnimplementedError('generateImage() will be implemented in Step 8.6');
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    // Will be implemented later
    throw UnimplementedError('tts() is not yet implemented');
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    // Will be implemented later
    throw UnimplementedError('stt() is not yet implemented');
  }

  /// Gets the default model for this provider.
  ///
  /// Returns the default model configured in settings, or null if not set.
  String? get defaultModel => _defaultModel;

  /// Gets the base URL for API requests.
  ///
  /// Returns the configured base URL or the default OpenAI API URL.
  String get baseUrl => _baseUrl;

  /// Gets the HTTP client wrapper (for testing purposes).
  ///
  /// This is exposed for testing but should not be used in production code.
  @visibleForTesting
  HttpClientWrapper get httpClient => _http;
}
