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
import '../../models/requests/video_analysis_request.dart';
import '../../models/requests/video_request.dart';
import '../../models/responses/audio_response.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/responses/transcription_response.dart';
import '../../models/responses/video_analysis_response.dart';
import '../../models/responses/video_response.dart';
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

  /// Underlying HTTP client for multipart requests.
  late final http.Client _httpClient;

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
    // Chat models
    'gemini-2.0-flash-exp',
    'gemini-1.5-pro',
    'gemini-1.5-flash',
    'gemini-pro',
    'gemini-pro-vision',
    // Embedding models
    'text-embedding-004',
    'text-embedding-3',
    'textembedding-gecko@003',
    'textembedding-gecko@002',
    'textembedding-gecko-multilingual@001',
    'gemini-embedding-001',
    // Image generation models (Imagen)
    'imagegeneration@006',
    'imagegeneration@005',
    // Video generation models (Veo)
    'video-generate@001',
    'veo-3.1',
    'veo-3',
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
      supportsEmbedding: true, // gemini-embedding-001
      supportsImageGeneration: true, // Imagen API
      supportsTTS: true, // Google TTS API
      supportsSTT: true, // Google STT API
      supportsVideoGeneration: true, // Veo 3.1
      supportsVideoAnalysis: true, // Multimodal input
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
    _httpClient = customClient ?? http.Client();

    // Create rate limiter for this provider
    final rateLimiter = RateLimiterFactory.create(id, config.settings);

    _http = HttpClientWrapper(
      client: _httpClient,
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
    // Validate that embedding is supported
    validateCapability('embed');

    // Map SDK request to Google format
    final googleRequest = _mapper.mapEmbeddingRequest(
      request,
      defaultModel: _defaultModel,
    ) as GoogleEmbeddingRequest;

    // Determine model from request
    final model = googleRequest.model ?? _defaultModel ?? 'text-embedding-004';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in EmbeddingRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Build URL with model and API key
    // Google uses different endpoints for embeddings
    final url = '$_baseUrl/models/$model:embedContent?key=$_apiKey';

    // Build request body (remove model from body, it goes in URL)
    final requestBody = googleRequest.toJson();
    requestBody.remove('model');

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
    final googleResponse = GoogleEmbeddingResponse.fromJson(responseJson);

    // Map Google response to SDK format
    return _mapper.mapEmbeddingResponse(googleResponse);
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    // Validate that image generation is supported
    validateCapability('image');

    // Map SDK request to Google format
    final googleRequest = _mapper.mapImageRequest(
      request,
      defaultModel: _defaultModel,
    ) as GoogleImageRequest;

    // Determine model from request
    final model = googleRequest.model ?? _defaultModel ?? 'imagegeneration@006';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in ImageRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Build URL with model and API key
    // Google Imagen uses different endpoint
    final url = '$_baseUrl/models/$model:predict?key=$_apiKey';

    // Build request body
    final requestBody = googleRequest.toJson();
    requestBody.remove('model');

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
    final googleResponse = GoogleImageResponse.fromJson(responseJson);

    // Map Google response to SDK format
    return _mapper.mapImageResponse(googleResponse);
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    // Validate that TTS is supported
    validateCapability('tts');

    // Map SDK request to Google format
    final googleRequest = _mapper.mapTtsRequest(
      request,
      defaultModel: _defaultModel,
    ) as GoogleTtsRequest;

    // Google TTS API endpoint
    final url = '$_baseUrl/text:synthesize?key=$_apiKey';

    // Make HTTP POST request
    final response = await _http.post(
      url,
      body: jsonEncode(googleRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON (Google TTS returns JSON with base64 audio)
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final audioBase64 = responseJson['audioContent'] as String?;

    if (audioBase64 == null) {
      throw ClientError(
        message: 'Invalid TTS response: missing audioContent',
        code: 'INVALID_RESPONSE',
        provider: id,
      );
    }

    // Decode base64 audio
    final audioBytes = base64Decode(audioBase64);

    // Map Google response to SDK format
    return _mapper.mapTtsResponse(response, audioBytes, request);
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    // Validate that STT is supported
    validateCapability('stt');

    // Map SDK request to Google format
    final googleRequest = _mapper.mapSttRequest(
      request,
      defaultModel: _defaultModel,
    ) as GoogleSttRequest;

    // Google STT API endpoint
    final url = '$_baseUrl/speech:recognize?key=$_apiKey';

    // Google STT requires multipart/form-data for audio
    final multipartRequest = http.MultipartRequest('POST', Uri.parse(url));

    // Add authentication headers
    final authHeaders = _http.defaultHeaders;
    multipartRequest.headers.addAll(authHeaders);

    // Add form fields
    final formFields = googleRequest.toFormFields();
    multipartRequest.fields.addAll(
      formFields.map((key, value) => MapEntry(key, value.toString())),
    );

    // Add audio file
    multipartRequest.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        googleRequest.audio,
        filename: 'audio.wav',
      ),
    );

    // Send the request using the underlying client
    final streamedResponse = await _httpClient.send(multipartRequest);
    final response = await http.Response.fromStream(streamedResponse);

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;

    // Map Google response to SDK format
    return _mapper.mapSttResponse(responseJson, request);
  }

  @override
  Future<VideoResponse> generateVideo(VideoRequest request) async {
    // Validate that video generation is supported
    validateCapability('video');

    // Map SDK request to Google format
    final googleRequest = _mapper.mapVideoRequest(
      request,
      defaultModel: _defaultModel,
    ) as GoogleVideoRequest;

    // Determine model from request
    final model = googleRequest.model ?? _defaultModel ?? 'veo-3.1';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in VideoRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Build URL with model and API key
    // Google Veo uses different endpoint
    final url = '$_baseUrl/models/$model:generateVideo?key=$_apiKey';

    // Build request body (remove model from body, it goes in URL)
    final requestBody = googleRequest.toJson();
    requestBody.remove('model');

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
    final googleResponse = GoogleVideoResponse.fromJson(responseJson);

    // Map Google response to SDK format
    return _mapper.mapVideoResponse(googleResponse);
  }

  @override
  Future<VideoAnalysisResponse> analyzeVideo(VideoAnalysisRequest request) async {
    // Validate that video analysis is supported
    validateCapability('videoAnalysis');

    // Google video analysis uses Gemini's multimodal capabilities
    // We'll use the chat API with video content
    final googleRequest = _mapper.mapVideoAnalysisRequest(
      request,
      defaultModel: _defaultModel,
    ) as GoogleVideoAnalysisRequest;

    // Determine model from request (use vision-capable model)
    final model = googleRequest.model ?? _defaultModel ?? 'gemini-1.5-pro';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in VideoAnalysisRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Build URL with model and API key
    final url = '$_baseUrl/models/$model:generateContent?key=$_apiKey';

    // Build request body (remove model from body, it goes in URL)
    final requestBody = googleRequest.toJson();
    requestBody.remove('model');

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
    final googleResponse = GoogleVideoAnalysisResponse.fromJson(responseJson);

    // Map Google response to SDK format
    return _mapper.mapVideoAnalysisResponse(googleResponse);
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
