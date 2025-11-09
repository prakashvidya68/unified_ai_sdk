import '../models/base_enums.dart';
import '../models/requests/chat_request.dart';
import '../models/requests/embedding_request.dart';
import '../models/requests/image_request.dart';
import 'intent.dart';

/// Detects the intent of user requests to determine which AI operation to perform.
///
/// The [IntentDetector] analyzes request content to automatically determine
/// whether a user wants to:
/// - Generate text/chat responses
/// - Generate images
/// - Generate embeddings
/// - Perform other operations (TTS, STT, etc.)
///
/// **Design Pattern:** Strategy Pattern with keyword-based detection
///
/// **Example usage:**
/// ```dart
/// final detector = IntentDetector();
///
/// // Detect intent from chat request
/// final chatRequest = ChatRequest(
///   messages: [
///     Message(role: Role.user, content: 'Draw a picture of a cat'),
///   ],
/// );
/// final intent = detector.detect(chatRequest);
/// // Returns: Intent.imageGeneration(confidence: 0.9)
///
/// // Detect intent from explicit request types
/// final imageRequest = ImageRequest(prompt: 'A sunset');
/// final intent2 = detector.detect(imageRequest);
/// // Returns: Intent.imageGeneration(confidence: 1.0)
/// ```
class IntentDetector {
  /// Keywords that indicate image generation intent.
  ///
  /// These keywords are matched against user messages to detect
  /// when a user wants to generate an image.
  static const List<String> _imageGenerationKeywords = [
    'draw',
    'generate image',
    'create image',
    'create art',
    'make a picture',
    'make an image',
    'generate a picture',
    'generate an image',
    'create a picture',
    'create an image',
    'draw me',
    'show me an image',
    'show me a picture',
    'paint',
    'illustrate',
    'sketch',
    'design',
    'visualize',
    'render',
    'image of',
    'picture of',
    'photo of',
    'logo',
    'icon',
    'graphic',
    'artwork',
    'portrait',
    'landscape',
    'diagram',
    'chart',
    'infographic',
  ];

  /// Keywords that indicate embedding intent.
  ///
  /// These keywords are matched against user messages to detect
  /// when a user wants to generate embeddings.
  static const List<String> _embeddingKeywords = [
    'embed',
    'embedding',
    'vector',
    'vectorize',
    'convert to vector',
    'get embedding',
    'generate embedding',
    'create embedding',
    'semantic search',
    'similarity',
    'find similar',
    'match',
    'compare',
  ];

  /// Keywords that indicate text-to-speech intent.
  ///
  /// These keywords are matched against user messages to detect
  /// when a user wants to convert text to speech.
  static const List<String> _ttsKeywords = [
    'speak',
    'say',
    'read aloud',
    'read this aloud',
    'read it aloud',
    'text to speech',
    'tts',
    'narrate',
    'pronounce',
  ];

  /// Keywords that indicate speech-to-text intent.
  ///
  /// These keywords are matched against user messages to detect
  /// when a user wants to convert speech to text.
  static const List<String> _sttKeywords = [
    'transcribe',
    'transcription',
    'speech to text',
    'stt',
    'voice to text',
    'audio to text',
    'convert audio',
    'listen',
  ];

  /// Creates a new [IntentDetector] instance.
  ///
  /// The detector uses keyword-based matching to determine intent.
  /// Future versions may support ML-based detection for higher accuracy.
  IntentDetector();

  /// Detects the intent from a request object.
  ///
  /// Analyzes the request to determine what operation the user wants to perform.
  /// For explicit request types (ImageRequest, EmbeddingRequest), the intent
  /// is immediately clear. For ChatRequest, the detector analyzes message content
  /// to infer intent.
  ///
  /// **Parameters:**
  /// - [request]: The request object to analyze. Can be [ChatRequest],
  ///   [ImageRequest], [EmbeddingRequest], or other request types.
  ///
  /// **Returns:**
  /// An [Intent] object describing the detected intent with confidence score.
  ///
  /// **Throws:**
  /// - [ArgumentError] if the request type is not supported
  ///
  /// **Example:**
  /// ```dart
  /// final detector = IntentDetector();
  ///
  /// // Explicit image request
  /// final imageRequest = ImageRequest(prompt: 'A cat');
  /// final intent = detector.detect(imageRequest);
  /// // Returns: Intent.imageGeneration(confidence: 1.0)
  ///
  /// // Chat request with image intent
  /// final chatRequest = ChatRequest(
  ///   messages: [
  ///     Message(role: Role.user, content: 'Draw a picture of a cat'),
  ///   ],
  /// );
  /// final intent2 = detector.detect(chatRequest);
  /// // Returns: Intent.imageGeneration(confidence: 0.9)
  /// ```
  Intent detect(dynamic request) {
    // Handle explicit request types (intent is clear from type)
    if (request is ImageRequest) {
      return Intent.imageGeneration(
        confidence: 1.0,
        metadata: {
          'detection_method': 'explicit_request_type',
          'prompt': request.prompt,
        },
      );
    }

    if (request is EmbeddingRequest) {
      return Intent.embedding(
        confidence: 1.0,
        metadata: {
          'detection_method': 'explicit_request_type',
          'input_count': request.inputs.length,
        },
      );
    }

    // Handle ChatRequest - need to analyze message content
    if (request is ChatRequest) {
      return _detectFromChatRequest(request);
    }

    // Unknown request type
    throw ArgumentError(
      'Unsupported request type: ${request.runtimeType}. '
      'Supported types: ChatRequest, ImageRequest, EmbeddingRequest',
    );
  }

  /// Detects intent from a chat request by analyzing message content.
  ///
  /// Analyzes the user messages to determine if they're asking for:
  /// - Image generation (e.g., "draw a cat")
  /// - Embedding generation (e.g., "get embedding for this text")
  /// - TTS (e.g., "read this aloud")
  /// - STT (e.g., "transcribe this audio")
  /// - Default: Chat/text generation
  ///
  /// **Parameters:**
  /// - [request]: The chat request to analyze
  ///
  /// **Returns:**
  /// An [Intent] with confidence score based on keyword matching
  Intent _detectFromChatRequest(ChatRequest request) {
    // Extract all user message content
    final userMessages = request.messages
        .where((msg) => msg.role == Role.user)
        .map((msg) => msg.content.toLowerCase())
        .toList();

    if (userMessages.isEmpty) {
      // No user messages - default to chat
      return Intent.chat(confidence: 0.5);
    }

    // Combine all user messages for analysis
    final combinedText = userMessages.join(' ').toLowerCase();

    // Check for image generation keywords
    final imageScore = _calculateKeywordScore(
      combinedText,
      _imageGenerationKeywords,
    );
    if (imageScore > 0.3) {
      return Intent.imageGeneration(
        confidence: _normalizeConfidence(imageScore),
        metadata: {
          'detection_method': 'keyword_matching',
          'matched_keywords': _findMatchedKeywords(
            combinedText,
            _imageGenerationKeywords,
          ),
        },
      );
    }

    // Check for embedding keywords
    final embeddingScore = _calculateKeywordScore(
      combinedText,
      _embeddingKeywords,
    );
    if (embeddingScore > 0.3) {
      return Intent.embedding(
        confidence: _normalizeConfidence(embeddingScore),
        metadata: {
          'detection_method': 'keyword_matching',
          'matched_keywords': _findMatchedKeywords(
            combinedText,
            _embeddingKeywords,
          ),
        },
      );
    }

    // Check for STT keywords first (before TTS, as "speech to text" might match TTS)
    final sttScore = _calculateKeywordScore(combinedText, _sttKeywords);
    if (sttScore > 0.3) {
      return Intent.stt(
        confidence: _normalizeConfidence(sttScore),
        metadata: {
          'detection_method': 'keyword_matching',
          'matched_keywords': _findMatchedKeywords(combinedText, _sttKeywords),
        },
      );
    }

    // Check for TTS keywords (after STT to avoid conflicts)
    final ttsScore = _calculateKeywordScore(combinedText, _ttsKeywords);
    if (ttsScore > 0.3) {
      return Intent.tts(
        confidence: _normalizeConfidence(ttsScore),
        metadata: {
          'detection_method': 'keyword_matching',
          'matched_keywords': _findMatchedKeywords(combinedText, _ttsKeywords),
        },
      );
    }

    // Default to chat/text generation
    return Intent.chat(
      confidence: 0.8, // High confidence for default case
      metadata: {
        'detection_method': 'default',
        'reason': 'No specific intent keywords detected',
      },
    );
  }

  /// Calculates a score based on keyword matches in the text.
  ///
  /// Returns a score between 0.0 and 1.0 based on:
  /// - Number of keywords matched
  /// - Position of keywords (earlier = higher score)
  /// - Exact vs. partial matches
  ///
  /// **Parameters:**
  /// - [text]: The text to analyze (should be lowercase)
  /// - [keywords]: List of keywords to search for
  ///
  /// **Returns:**
  /// A score between 0.0 and 1.0
  double _calculateKeywordScore(String text, List<String> keywords) {
    if (text.isEmpty || keywords.isEmpty) return 0.0;

    int matches = 0;
    double positionBonus = 0.0;
    final textLength = text.length;

    for (final keyword in keywords) {
      final lowerKeyword = keyword.toLowerCase();
      // Try exact match first
      int index = text.indexOf(lowerKeyword);

      // If no exact match, try word boundary matching for multi-word keywords
      if (index == -1 && lowerKeyword.contains(' ')) {
        // Split keyword and check if all words appear in order
        final words = lowerKeyword.split(' ');
        bool allWordsFound = true;
        int firstWordIndex = -1;
        int lastWordIndex = -1;

        for (int i = 0; i < words.length; i++) {
          final wordIndex = text.indexOf(words[i]);
          if (wordIndex == -1) {
            allWordsFound = false;
            break;
          }
          if (i == 0) firstWordIndex = wordIndex;
          lastWordIndex = wordIndex;
        }

        // If all words found and they're reasonably close, consider it a match
        if (allWordsFound &&
            firstWordIndex != -1 &&
            (lastWordIndex - firstWordIndex) < 50) {
          index = firstWordIndex;
        }
      }

      if (index != -1) {
        matches++;
        // Position bonus: keywords earlier in text get higher weight
        // Normalize by text length
        positionBonus += (1.0 - (index / textLength)) * 0.3;
      }
    }

    if (matches == 0) return 0.0;

    // Base score: any match gives at least 0.4, multiple matches increase it
    // This ensures that even a single keyword match is detected
    final baseScore = (0.4 + (matches - 1) * 0.2).clamp(0.4, 1.0);

    // Combine base score with position bonus
    final totalScore = (baseScore * 0.7 + positionBonus).clamp(0.0, 1.0);

    return totalScore;
  }

  /// Finds which keywords were matched in the text.
  ///
  /// **Parameters:**
  /// - [text]: The text to search (should be lowercase)
  /// - [keywords]: List of keywords to search for
  ///
  /// **Returns:**
  /// List of matched keywords
  List<String> _findMatchedKeywords(String text, List<String> keywords) {
    final matched = <String>[];
    for (final keyword in keywords) {
      if (text.contains(keyword.toLowerCase())) {
        matched.add(keyword);
      }
    }
    return matched;
  }

  /// Normalizes a confidence score to a reasonable range.
  ///
  /// Ensures confidence is between 0.5 and 1.0 for detected intents,
  /// with higher scores for stronger matches.
  ///
  /// **Parameters:**
  /// - [score]: Raw keyword match score (0.0 to 1.0)
  ///
  /// **Returns:**
  /// Normalized confidence score (0.5 to 1.0)
  double _normalizeConfidence(double score) {
    // Map [0.3, 1.0] to [0.5, 1.0]
    // This ensures detected intents have at least 0.5 confidence
    if (score <= 0.3) return 0.5;
    if (score >= 1.0) return 1.0;

    // Linear interpolation: (score - 0.3) / (1.0 - 0.3) * (1.0 - 0.5) + 0.5
    return ((score - 0.3) / 0.7 * 0.5 + 0.5).clamp(0.5, 1.0);
  }
}
