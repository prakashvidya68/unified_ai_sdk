/// Enumerations used throughout the Unified AI SDK.
///
/// This file contains all enum definitions that represent core concepts
/// in the SDK, including message roles, task types, and provider types.
library;

/// Represents the role of a message in a chat conversation.
///
/// Used in [Message] objects to indicate who sent the message and how
/// it should be interpreted by the AI model.
enum Role {
  /// System messages provide instructions, context, or constraints
  /// to the AI model. These are typically used to set behavior or personality.
  system,

  /// User messages represent input from the end user.
  user,

  /// Assistant messages represent responses from the AI model.
  assistant,

  /// Function messages represent tool/function call results or definitions.
  /// Used in function calling scenarios where the model can invoke functions.
  function,
}

/// Represents the type of AI task or operation being performed.
///
/// Used to determine which provider capabilities are needed and how
/// requests should be routed through the SDK.
enum TaskType {
  /// Chat completion tasks - generating text responses to conversations.
  chat,

  /// Embedding tasks - converting text into vector representations.
  embedding,

  /// Image generation tasks - creating images from text prompts.
  imageGeneration,

  /// Text-to-speech tasks - converting text into audio.
  tts,

  /// Speech-to-text tasks - converting audio into text transcriptions.
  stt,
}

/// Represents the AI provider being used.
///
/// Used for provider registration, routing, and capability detection.
/// Providers can be registered and selected based on their capabilities.
enum ProviderType {
  /// OpenAI provider (GPT models, DALL-E, Whisper).
  openai,

  /// Anthropic provider (Claude models).
  anthropic,

  /// Google provider (Gemini, Vertex AI).
  google,

  /// Cohere provider (embedding models, command models).
  cohere,

  /// Stability AI provider (image generation).
  stability,

  /// Custom provider - for self-hosted or custom implementations.
  custom,
}

/// Represents the size/dimensions of an image to be generated.
///
/// Used in [ImageRequest] to specify the desired output dimensions.
/// The toString() method converts enum values to API-compatible format
/// (e.g., "256x256", "1024x1024").
enum ImageSize {
  /// 256x256 pixels - Small square image (suitable for thumbnails or icons).
  w256h256,

  /// 512x512 pixels - Medium square image (good balance of quality and size).
  w512h512,

  /// 1024x1024 pixels - Large square image (high quality, standard size).
  w1024h1024,

  /// 1024x1792 pixels - Portrait orientation (9:16 aspect ratio).
  w1024h1792,

  /// 1792x1024 pixels - Landscape orientation (16:9 aspect ratio).
  w1792h1024;

  /// Converts the enum value to the API-compatible string format.
  ///
  /// Returns a string in the format "WIDTHxHEIGHT" (e.g., "256x256", "1024x1792").
  /// This format is compatible with most image generation APIs.
  @override
  String toString() {
    switch (this) {
      case ImageSize.w256h256:
        return '256x256';
      case ImageSize.w512h512:
        return '512x512';
      case ImageSize.w1024h1024:
        return '1024x1024';
      case ImageSize.w1024h1792:
        return '1024x1792';
      case ImageSize.w1792h1024:
        return '1792x1024';
    }
  }
}
