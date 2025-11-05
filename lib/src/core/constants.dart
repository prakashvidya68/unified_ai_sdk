/// Core constants used throughout the Unified AI SDK.
///
/// This file contains default values, SDK version information, and other
/// constants that are used across the SDK for consistency and maintainability.
library;

/// The current version of the Unified AI SDK.
///
/// This version matches the package version in pubspec.yaml and is used
/// for telemetry, logging, and API compatibility checks.
const String sdkVersion = '1.0.0';

/// Default maximum number of tokens to generate in a response.
///
/// Used when [maxTokens] is not explicitly specified in a request.
/// This value balances response length with API costs and latency.
const int defaultMaxTokens = 1000;

/// Default temperature value for text generation.
///
/// Temperature controls randomness in model outputs:
/// - Lower values (0.0-0.3): More focused and deterministic
/// - Medium values (0.4-0.7): Balanced creativity and coherence
/// - Higher values (0.8-1.0): More creative and diverse
///
/// Used when [temperature] is not explicitly specified in a request.
const double defaultTemperature = 0.7;

/// Default time-to-live (TTL) for cached responses.
///
/// Determines how long cached responses remain valid before expiring.
/// Cached responses help reduce API costs and improve response times for
/// repeated or similar requests.
const Duration defaultCacheTTL = Duration(hours: 1);
