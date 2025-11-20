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
import '../../models/responses/chat_stream_event.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/responses/transcription_response.dart';
import '../../models/responses/video_analysis_response.dart';
import '../../models/responses/video_response.dart';
import '../../error/error_mapper.dart';
import '../../network/http_client_wrapper.dart';
import '../base/ai_provider.dart';
import '../base/model_fetcher.dart';
import '../base/provider_mapper.dart';
import '../base/rate_limiter_factory.dart';
import 'openai_mapper.dart';
import 'openai_models.dart';

/// OpenAI provider implementation for the Unified AI SDK.
///
/// This provider integrates with OpenAI's API to provide:
/// - Chat completions (GPT-5.1, GPT-5, GPT-4.1, GPT-4o, etc.)
/// - Text embeddings (text-embedding-3-large, text-embedding-3-small, text-embedding-ada-002)
/// - Image generation (GPT Image 1, GPT Image 1 Mini)
/// - Video generation (Sora-2 Pro, Sora-2)
/// - Video analysis (GPT-5, GPT-4o Vision)
/// - Text-to-speech (GPT-4o Mini TTS)
/// - Speech-to-text (GPT-4o Transcribe, GPT-4o Mini Transcribe)
/// - Streaming support for chat completions
///
/// **Example usage:**
/// ```dart
/// final config = ProviderConfig(
///   id: 'openai',
///   auth: ApiKeyAuth(apiKey: 'sk-...'),
///   settings: {
///     'defaultModel': 'gpt-5', // or 'gpt-4o' for latest GPT-4
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

  /// Underlying HTTP client for multipart requests.
  late final http.Client _httpClient;

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
  ///
  /// **Latest Models (2025):**
  /// - GPT-5.1 series: Latest generation with configurable reasoning effort
  /// - GPT-5 series: Intelligent reasoning models for coding and agentic tasks
  /// - GPT-4.1: Smartest non-reasoning model
  /// - GPT-4o series: Multimodal models with vision capabilities
  /// - GPT Image 1: State-of-the-art image generation
  /// - Sora 2: Latest video generation with synced audio
  /// - GPT Realtime/Audio: Real-time audio models
  static const List<String> _fallbackModels = [
    // Latest GPT-5.1 series (2025)
    'gpt-5.1',
    'gpt-5.1-codex',
    // GPT-5 series
    'gpt-5-pro',
    'gpt-5',
    'gpt-5-mini',
    'gpt-5-nano',
    'gpt-5-codex',
    'gpt-5-chat-latest',
    // GPT-4.1 series
    'gpt-4.1',
    // GPT-4o series (latest GPT-4 models)
    'gpt-4o-2024-11-20',
    'gpt-4o-2024-08-06',
    'gpt-4o',
    'gpt-4o-mini',
    'chatgpt-4o-latest',
    // Open-weight models
    'gpt-oss-120b',
    'gpt-oss-20b',
    // Embedding models
    'text-embedding-3-large',
    'text-embedding-3-small',
    'text-embedding-ada-002',
    // Image generation models
    'gpt-image-1',
    'gpt-image-1-mini',
    // Video generation models
    'sora-2-pro',
    'sora-2',
    // Audio models - GPT-4o based
    'gpt-4o-mini-tts',
    'gpt-4o-transcribe',
    'gpt-4o-mini-transcribe',
    // Real-time audio models
    'gpt-realtime',
    'gpt-realtime-mini',
    'gpt-audio',
    'gpt-audio-mini',
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
      supportsVideoGeneration: true,
      supportsVideoAnalysis: true,
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
    // Chat/text models - GPT series
    if (lowerId.startsWith('gpt-') || lowerId.startsWith('chatgpt-')) {
      // Exclude image, audio, and video models
      if (lowerId.contains('image') ||
          lowerId.contains('audio') ||
          lowerId.contains('realtime') ||
          lowerId.contains('transcribe') ||
          lowerId.contains('tts')) {
        // These are handled below
      } else {
        return 'text';
      }
    }
    // Embedding models
    if (lowerId.contains('embedding')) return 'embedding';
    // Image generation models
    if (lowerId.startsWith('gpt-image-') || lowerId.startsWith('dall-e')) {
      return 'image';
    }
    // Audio models - TTS
    if (lowerId.contains('tts') || lowerId.startsWith('tts-')) {
      return 'tts';
    }
    // Audio models - STT/Transcribe
    if (lowerId.contains('transcribe') || lowerId.startsWith('whisper-')) {
      return 'stt';
    }
    // Real-time audio models
    if (lowerId.contains('realtime') || lowerId.contains('audio')) {
      return 'text'; // Real-time models are text-based with audio I/O
    }
    // Video generation models
    if (lowerId.startsWith('sora-')) return 'video';
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

    // Include known model prefixes and patterns
    final lowerId = modelId.toLowerCase();
    return lowerId.startsWith('gpt-') ||
        lowerId.startsWith('chatgpt-') ||
        lowerId.startsWith('text-embedding-') ||
        lowerId.startsWith('gpt-image-') ||
        lowerId.startsWith('dall-e-') ||
        lowerId.contains('tts') ||
        lowerId.contains('transcribe') ||
        lowerId.startsWith('whisper-') ||
        lowerId.contains('realtime') ||
        lowerId.contains('audio') ||
        lowerId.startsWith('sora-') ||
        lowerId.startsWith('gpt-oss-');
  }

  @override
  Future<ChatResponse> chat(ChatRequest request) async {
    // Validate that chat is supported
    validateCapability('chat');

    // Map SDK request to OpenAI Responses API format
    // Note: mapResponseRequest is specific to OpenAIMapper, not part of ProviderMapper interface
    final openAIMapper = _mapper as OpenAIMapper;
    final openAIRequest = openAIMapper.mapResponseRequest(
      request,
      defaultModel: _defaultModel,
    );

    // Make HTTP POST request to responses endpoint
    final response = await _http.post(
      '$_baseUrl/responses',
      body: jsonEncode(openAIRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final openAIResponse = OpenAIResponseResponse.fromJson(responseJson);

    // Map OpenAI response to SDK format
    return _mapper.mapChatResponse(openAIResponse);
  }

  @override
  Stream<ChatStreamEvent> chatStream(ChatRequest request) async* {
    // Validate that streaming is supported
    validateCapability('streaming');

    // Map SDK request to OpenAI Responses API format
    // Note: mapResponseRequest is specific to OpenAIMapper, not part of ProviderMapper interface
    final openAIMapper = _mapper as OpenAIMapper;
    final openAIRequest = openAIMapper.mapResponseRequest(
      request,
      defaultModel: _defaultModel,
    );

    // Create streaming request with stream: true
    final requestJson = openAIRequest.toJson();
    final streamRequestJson = <String, dynamic>{
      ...requestJson,
      'stream': true,
    };

    try {
      // Make streaming HTTP POST request to responses endpoint
      final byteStream = _http.postStream(
        '$_baseUrl/responses', // Assuming this is the correct (non-standard) endpoint for your use case
        body: streamRequestJson,
      );

      // Parse SSE (Server-Sent Events) format
      String buffer = '';
      Map<String, dynamic>? finalMetadata;

      await for (final chunk in byteStream) {
        // Convert bytes to string and append to buffer
        // Ensure correct handling of potentially malformed UTF-8 from chunk boundaries
        buffer += utf8.decode(chunk, allowMalformed: true);

        // Process complete lines (ending with \n)
        final lines = buffer.split('\n');
        // Keep the last incomplete line in buffer
        buffer = lines.removeLast();

        for (final line in lines) {
          // Skip empty lines
          if (line.trim().isEmpty) continue;

          // SSE format: lines starting with "data: "
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();

            // FIX 1: The API you are streaming from likely does not use the OpenAI "[DONE]" marker.
            // The end-of-stream event is likely marked by a specific type or the stream closing.
            // We will rely on the stream closing or a final event type.

            // Parse JSON chunk
            try {
              final chunkJson = jsonDecode(data) as Map<String, dynamic>;

              // Extract the event type to differentiate chunks
              final eventType = chunkJson['type'] as String?;

              // --- FIX 2: Correctly extract the delta content based on the stream structure ---
              // The Anthropic/Claude style uses a 'delta' or 'part' field directly.

              String? contentDelta;

              if (eventType == 'response.output_text.delta' &&
                  chunkJson['delta'] is String) {
                // Directly extract text delta from the 'delta' field if it's a string
                contentDelta = chunkJson['delta'] as String;
              } else if (eventType == 'response.output_text.delta' &&
                  chunkJson['delta'] is Map) {
                // If 'delta' is an object (common for more structured data)
                contentDelta = (chunkJson['delta']
                    as Map<String, dynamic>)['text'] as String?;
              } else if (eventType == 'response.content_part.added') {
                // Check if this is a content part added event which might contain the text chunk
                final part = chunkJson['part'] as Map<String, dynamic>?;
                contentDelta = part?['text'] as String?;
              }
              // --- End of Fix 2 ---

              // --- FIX 3: Capture metadata from final completion event (e.g., 'response.end' or similar) ---
              if (eventType == 'response.end' || eventType == 'completion') {
                // This is where you would typically capture the full metadata/usage from the final event
                finalMetadata = chunkJson['meta'] as Map<String, dynamic>?;
                // Since this is a final event, we yield the done event here and return
                yield ChatStreamEvent(
                  delta: null,
                  done: true,
                  metadata: finalMetadata,
                );
                return;
              }
              // --- End of Fix 3 ---

              // Yield event with content delta
              if (contentDelta != null && contentDelta.isNotEmpty) {
                yield ChatStreamEvent(
                  delta: contentDelta,
                  done: false,
                );
              }
            } on FormatException {
              // Skip invalid JSON chunks
              continue;
            }
          }
        }
      }

      // Always yield final event, especially if the stream closed without a dedicated 'response.end' event
      yield ChatStreamEvent(
        delta: null,
        done: true,
        metadata: finalMetadata,
      );
    } catch (e) {
      // Map HTTP/network errors to appropriate exception types
      // Assuming ErrorMapper and id are defined in your context
      if (e is Exception) {
        // throw ErrorMapper.mapException(e, id); // Use this if you have the ErrorMapper
        rethrow;
      }
      rethrow;
    }
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    // Validate that embedding is supported
    validateCapability('embed');

    // Map SDK request to OpenAI format
    final openAIRequest = _mapper.mapEmbeddingRequest(
      request,
      defaultModel: _defaultModel,
    );

    // Make HTTP POST request to embeddings endpoint
    final response = await _http.post(
      '$_baseUrl/embeddings',
      body: jsonEncode(openAIRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final openAIResponse = OpenAIEmbeddingResponse.fromJson(responseJson);

    // Map OpenAI response to SDK format
    return _mapper.mapEmbeddingResponse(openAIResponse);
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    // Validate that image generation is supported
    validateCapability('image');

    // Map SDK request to OpenAI format
    final openAIRequest = _mapper.mapImageRequest(
      request,
      defaultModel: _defaultModel,
    );

    // Make HTTP POST request to images/generations endpoint
    final response = await _http.post(
      '$_baseUrl/images/generations',
      body: jsonEncode(openAIRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final openAIResponse = OpenAIImageResponse.fromJson(responseJson);

    // Map OpenAI response to SDK format
    // Note: We need to pass the model from the request to the mapper
    // Since OpenAI doesn't return the model in the response
    final imageResponse = _mapper.mapImageResponse(openAIResponse);

    // Update the model in the response to match the request
    final model = openAIRequest.model as String? ?? 'gpt-image-1';
    return imageResponse.copyWith(
      model: model,
    );
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    // Validate that TTS is supported
    validateCapability('tts');

    // Map SDK request to OpenAI format
    final openaiRequest = _mapper.mapTtsRequest(
      request,
      defaultModel: _defaultModel,
    ) as OpenAITtsRequest;

    // Make HTTP POST request to audio/speech endpoint
    final response = await _http.post(
      '$_baseUrl/audio/speech',
      body: jsonEncode(openaiRequest.toJson()),
      headers: {
        'Accept': 'audio/*', // Accept any audio format
      },
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Get audio bytes from response
    final audioBytes = response.bodyBytes;

    // Map OpenAI response to SDK format
    return _mapper.mapTtsResponse(response, audioBytes, request);
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    // Validate that STT is supported
    validateCapability('stt');

    // Map SDK request to OpenAI format
    final openaiRequest = _mapper.mapSttRequest(
      request,
      defaultModel: _defaultModel,
    ) as OpenAISttRequest;

    // OpenAI STT requires multipart/form-data
    // We need to use the underlying http client directly for multipart
    final multipartRequest = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/audio/transcriptions'),
    );

    // Add authentication headers
    final authHeaders = _http.defaultHeaders;
    multipartRequest.headers.addAll(authHeaders);

    // Add form fields
    final formFields = openaiRequest.toFormFields();
    multipartRequest.fields.addAll(
      formFields.map((key, value) => MapEntry(key, value.toString())),
    );

    // Add audio file
    multipartRequest.files.add(
      http.MultipartFile.fromBytes(
        'file',
        openaiRequest.audio,
        filename: 'audio.mp3', // Default filename, could be improved
      ),
    );

    // Send the request using the underlying client
    final streamedResponse = await _httpClient.send(multipartRequest);
    final response = await http.Response.fromStream(streamedResponse);

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response based on response_format
    final responseFormat = openaiRequest.responseFormat ?? 'json';
    dynamic parsedResponse;

    if (responseFormat == 'json' || responseFormat == 'verbose_json') {
      // JSON response
      parsedResponse = jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // Plain text response (text, srt, vtt)
      parsedResponse = response.body;
    }

    // Map OpenAI response to SDK format
    return _mapper.mapSttResponse(parsedResponse, request);
  }

  @override
  Future<VideoResponse> generateVideo(VideoRequest request) async {
    // Validate that video generation is supported
    validateCapability('video');

    // Map SDK request to OpenAI format
    final openaiRequest = _mapper.mapVideoRequest(
      request,
      defaultModel: _defaultModel,
    ) as OpenAIVideoRequest;

    // Step 1: Create video generation job
    // OpenAI video generation requires multipart/form-data
    // We need to use the underlying http client directly for multipart
    final multipartRequest = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/videos'),
    );

    // Add authentication headers
    final authHeaders = _http.defaultHeaders;
    multipartRequest.headers.addAll(authHeaders);

    // Add form fields
    final formFields = openaiRequest.toFormFields();
    multipartRequest.fields.addAll(
      formFields.map((key, value) => MapEntry(key, value.toString())),
    );

    // Send the request using the underlying client
    final streamedResponse = await _httpClient.send(multipartRequest);
    final response = await http.Response.fromStream(streamedResponse);

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON - this is a video job, not the actual video
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final videoJob = OpenAIVideoJob.fromJson(responseJson);

    // Check if job failed immediately
    if (videoJob.isFailed) {
      throw ClientError(
        message:
            'Video generation failed: ${videoJob.error ?? "Unknown error"}',
        code: 'VIDEO_GENERATION_FAILED',
        provider: id,
      );
    }

    // Step 2: Poll for completion (if not already completed)
    OpenAIVideoJob completedJob = videoJob;
    if (!videoJob.isCompleted) {
      completedJob = await _pollVideoJob(videoJob.id);
    }

    // Step 3: Retrieve the actual video content
    final videoContent = await _getVideoContent(completedJob.id);

    // Step 4: Map to SDK format
    // Cast to OpenAIMapper to access the new method
    final openAIMapper = _mapper as OpenAIMapper;
    return openAIMapper.mapVideoResponseFromContent(
      completedJob,
      videoContent,
      request,
    );
  }

  /// Polls a video job until it completes or fails.
  ///
  /// Polls the video job status endpoint until the job is completed or failed.
  /// Uses exponential backoff between polls.
  Future<OpenAIVideoJob> _pollVideoJob(String videoId) async {
    const maxAttempts = 60; // Maximum number of polling attempts
    const initialDelay = Duration(seconds: 2);
    const maxDelay = Duration(seconds: 30);

    Duration delay = initialDelay;
    int attempts = 0;

    while (attempts < maxAttempts) {
      // Wait before polling (except first attempt)
      if (attempts > 0) {
        await Future<void>.delayed(delay);
        // Exponential backoff with max cap
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 1.5).round().clamp(
                initialDelay.inMilliseconds,
                maxDelay.inMilliseconds,
              ),
        );
      }

      // Check job status
      final response = await _http.get('$_baseUrl/videos/$videoId');

      if (response.statusCode != 200) {
        throw ErrorMapper.mapHttpError(response, id);
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final job = OpenAIVideoJob.fromJson(responseJson);

      if (job.isCompleted) {
        return job;
      }

      if (job.isFailed) {
        throw ClientError(
          message: 'Video generation failed: ${job.error ?? "Unknown error"}',
          code: 'VIDEO_GENERATION_FAILED',
          provider: id,
        );
      }

      attempts++;
    }

    // Timeout after max attempts
    throw ClientError(
      message: 'Video generation timed out after $maxAttempts polling attempts',
      code: 'VIDEO_GENERATION_TIMEOUT',
      provider: id,
    );
  }

  /// Retrieves the actual video content for a completed video job.
  ///
  /// Makes a GET request to `/v1/videos/{id}/content` to download the video file.
  Future<List<int>> _getVideoContent(String videoId) async {
    final response = await _http.get(
      '$_baseUrl/videos/$videoId/content',
      headers: {
        'Accept': 'video/*',
      },
    );

    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    return response.bodyBytes;
  }

  @override
  Future<VideoAnalysisResponse> analyzeVideo(
      VideoAnalysisRequest request) async {
    // Validate that video analysis is supported
    validateCapability('videoAnalysis');

    // Map SDK request to OpenAI format
    final openaiRequest = _mapper.mapVideoAnalysisRequest(
      request,
      defaultModel: _defaultModel,
    ) as OpenAIVideoAnalysisRequest;

    // Make HTTP POST request to chat/completions endpoint (GPT-4o Vision)
    final response = await _http.post(
      '$_baseUrl/chat/completions',
      body: jsonEncode(openaiRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final openaiResponse = OpenAIVideoAnalysisResponse.fromJson(responseJson);

    // Map OpenAI response to SDK format
    return _mapper.mapVideoAnalysisResponse(openaiResponse);
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
