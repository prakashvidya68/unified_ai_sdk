/// Represents a detected object in a video.
class DetectedObject {
  /// The name/label of the detected object.
  final String name;

  /// Confidence score (0.0 to 1.0).
  final double confidence;

  /// Bounding box coordinates (if available).
  final Map<String, dynamic>? boundingBox;

  /// Timestamp in the video where this object appears (in seconds).
  final double? timestamp;

  /// Creates a new [DetectedObject] instance.
  /// [name], [confidence], [boundingBox], and [timestamp] are required.
  /// [boundingBox] and [timestamp] are optional.
  /// Example Usage:
  /// ```dart
  /// final detectedObject = DetectedObject(
  ///   name: 'Person',
  ///   confidence: 0.95,
  ///   boundingBox: {'x': 100, 'y': 100, 'width': 100, 'height': 100},
  ///   timestamp: 10.0,
  /// );
  const DetectedObject({
    required this.name,
    required this.confidence,
    this.boundingBox,
    this.timestamp,
  });

  /// Converts this [DetectedObject] to a JSON map.
  /// Example Usage:
  /// ```dart
  /// final json = detectedObject.toJson();
  /// print(json);
  /// ```
  /// Example Response:
  /// ```json
  /// {
  ///   "name": "Person",
  ///   "confidence": 0.95,
  ///   "bounding_box": {"x": 100, "y": 100, "width": 100, "height": 100},
  ///   "timestamp": 10.0
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'confidence': confidence,
      if (boundingBox != null) 'bounding_box': boundingBox,
      if (timestamp != null) 'timestamp': timestamp,
    };
  }

  /// Creates a new [DetectedObject] instance from a JSON map.
  /// Example Usage:
  /// ```dart
  /// final detectedObject = DetectedObject.fromJson(json);
  /// print(detectedObject);
  /// ```
  /// Example Response:
  /// created a new [DetectedObject] instance from a JSON map.
  /// Example Usage:
  /// ```dart
  /// final json = {
  ///   "name": "Person",
  ///   "confidence": 0.95,
  ///   "bounding_box": {"x": 100, "y": 100, "width": 100, "height": 100},
  ///   "timestamp": 10.0
  /// };
  /// final detectedObject = DetectedObject.fromJson(json);
  /// print(detectedObject);
  /// ```
  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      name: json['name'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: json['bounding_box'] as Map<String, dynamic>? ??
          json['boundingBox'] as Map<String, dynamic>?,
      timestamp: (json['timestamp'] as num?)?.toDouble(),
    );
  }
}

/// Represents a detected scene or segment in a video.
class DetectedScene {
  /// Description of the scene.
  final String description;

  /// Confidence score (0.0 to 1.0).
  final double confidence;

  /// Start time of the scene (in seconds).
  final double startTime;

  /// End time of the scene (in seconds).
  final double endTime;

  /// Creates a new [DetectedScene] instance.
  /// [description], [confidence], [startTime], and [endTime] are required.
  /// Example Usage:
  /// ```dart
  /// final detectedScene = DetectedScene(
  ///   description: 'A person is walking down the street',
  ///   confidence: 0.95,
  ///   startTime: 10.0,
  ///   endTime: 20.0,
  const DetectedScene({
    required this.description,
    required this.confidence,
    required this.startTime,
    required this.endTime,
  });

  /// Converts this [DetectedScene] to a JSON map.
  /// Example Usage:
  /// ```dart
  /// final json = detectedScene.toJson();
  /// print(json);
  /// ```
  /// Example Response:
  /// ```json
  /// {
  ///   "description": "A person is walking down the street",
  ///   "confidence": 0.95,
  ///   "start_time": 10.0,
  ///   "end_time": 20.0
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'confidence': confidence,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  /// Creates a new [DetectedScene] instance from a JSON map.
  /// Example Usage:
  /// ```dart
  /// final json = {
  ///   "description": "A person is walking down the street",
  ///   "confidence": 0.95,
  ///   "start_time": 10.0,
  ///   "end_time": 20.0
  /// };
  /// final detectedScene = DetectedScene.fromJson(json);
  /// print(detectedScene);
  /// ```
  factory DetectedScene.fromJson(Map<String, dynamic> json) {
    return DetectedScene(
      description: json['description'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      startTime: (json['start_time'] as num).toDouble(),
      endTime: (json['end_time'] as num).toDouble(),
    );
  }
}

/// Represents a detected action in a video.
class DetectedAction {
  /// The name/label of the detected action.
  final String name;

  /// Confidence score (0.0 to 1.0).
  final double confidence;

  /// Start time of the action (in seconds).
  final double? startTime;

  /// End time of the action (in seconds).
  final double? endTime;

  /// Creates a new [DetectedAction] instance.
  /// [name], [confidence], [startTime], and [endTime] are required.
  /// [startTime] and [endTime] are optional.
  /// Example Usage:
  /// ```dart
  /// final detectedAction = DetectedAction(
  ///   name: 'Walking',
  ///   confidence: 0.95,
  const DetectedAction({
    required this.name,
    required this.confidence,
    this.startTime,
    this.endTime,
  });

  /// Converts this [DetectedAction] to a JSON map.
  /// Example Usage:
  /// ```dart
  /// final json = detectedAction.toJson();
  /// print(json);
  /// ```
  /// Example Response:
  /// ```json
  /// {
  ///   "name": "Walking",
  ///   "confidence": 0.95,
  ///   "start_time": 10.0,
  ///   "end_time": 20.0
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'confidence': confidence,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
    };
  }

  /// Creates a new [DetectedAction] instance from a JSON map.
  /// Example Usage:
  /// ```dart
  /// final json = {
  ///   "name": "Walking",
  ///   "confidence": 0.95,
  ///   "start_time": 10.0,
  ///   "end_time": 20.0
  /// };
  /// final detectedAction = DetectedAction.fromJson(json);
  /// print(detectedAction);
  /// ```
  factory DetectedAction.fromJson(Map<String, dynamic> json) {
    return DetectedAction(
      name: json['name'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      startTime: (json['start_time'] as num?)?.toDouble(),
      endTime: (json['end_time'] as num?)?.toDouble(),
    );
  }
}

/// Represents extracted text from a video.
class ExtractedText {
  /// The extracted text content.
  final String text;

  /// Confidence score (0.0 to 1.0).
  final double confidence;

  /// Bounding box coordinates (if available).
  final Map<String, dynamic>? boundingBox;

  /// Timestamp in the video where this text appears (in seconds).
  final double? timestamp;

  /// Creates a new [ExtractedText] instance.
  /// [text], [confidence], [boundingBox], and [timestamp] are required.
  /// [boundingBox] and [timestamp] are optional.
  /// Example Usage:
  /// ```dart
  /// final extractedText = ExtractedText(
  ///   text: 'Hello, world!',
  ///   confidence: 0.95,
  const ExtractedText({
    required this.text,
    required this.confidence,
    this.boundingBox,
    this.timestamp,
  });

  /// Converts this [ExtractedText] to a JSON map.
  /// Example Usage:
  /// ```dart
  /// final json = extractedText.toJson();
  /// print(json);
  /// ```
  /// Example Response:
  /// ```json
  /// {
  ///   "text": "Hello, world!",
  ///   "confidence": 0.95,
  ///   "bounding_box": {"x": 100, "y": 100, "width": 100, "height": 100},
  ///   "timestamp": 10.0
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'confidence': confidence,
      if (boundingBox != null) 'bounding_box': boundingBox,
      if (timestamp != null) 'timestamp': timestamp,
    };
  }

  /// Creates a new [ExtractedText] instance from a JSON map.
  /// Example Usage:
  /// ```dart
  /// final json = {
  ///   "text": "Hello, world!",
  ///   "confidence": 0.95,
  ///   "bounding_box": {"x": 100, "y": 100, "width": 100, "height": 100},
  ///   "timestamp": 10.0
  /// };
  /// final extractedText = ExtractedText.fromJson(json);
  /// print(extractedText);
  /// ```
  factory ExtractedText.fromJson(Map<String, dynamic> json) {
    return ExtractedText(
      text: json['text'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: json['bounding_box'] as Map<String, dynamic>? ??
          json['boundingBox'] as Map<String, dynamic>?,
      timestamp: (json['timestamp'] as num?)?.toDouble(),
    );
  }
}

/// Represents a complete video analysis response from an AI provider.
///
/// This is the primary response type returned by [analyzeVideo()] operations.
/// It contains detected objects, scenes, actions, text, and other insights
/// extracted from the analyzed video.
///
/// **Example usage:**
/// ```dart
/// final response = await ai.analyzeVideo(request: videoAnalysisRequest);
/// print('Detected objects: ${response.objects.length}');
/// print('Scenes: ${response.scenes.length}');
/// ```
class VideoAnalysisResponse {
  /// List of detected objects in the video.
  final List<DetectedObject> objects;

  /// List of detected scenes/segments in the video.
  final List<DetectedScene> scenes;

  /// List of detected actions in the video.
  final List<DetectedAction> actions;

  /// List of extracted text from the video.
  final List<ExtractedText> text;

  /// List of descriptive labels for the video.
  final List<String> labels;

  /// Content moderation results (if requested).
  ///
  /// Contains information about potentially inappropriate content.
  final Map<String, dynamic>? moderation;

  /// The model identifier used for this analysis.
  ///
  /// Examples: "video-intelligence", "rekognition-video"
  final String model;

  /// The provider that generated this response.
  ///
  /// Examples: "google", "amazon"
  final String provider;

  /// Timestamp when this response was created.
  final DateTime timestamp;

  /// Optional metadata associated with this response.
  ///
  /// Can contain provider-specific fields, request IDs, or custom metadata.
  final Map<String, dynamic>? metadata;

  /// Creates a new [VideoAnalysisResponse] instance.
  VideoAnalysisResponse({
    this.objects = const [],
    this.scenes = const [],
    this.actions = const [],
    this.text = const [],
    this.labels = const [],
    this.moderation,
    required this.model,
    required this.provider,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Converts this [VideoAnalysisResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'objects': objects.map((o) => o.toJson()).toList(),
      'scenes': scenes.map((s) => s.toJson()).toList(),
      'actions': actions.map((a) => a.toJson()).toList(),
      'text': text.map((t) => t.toJson()).toList(),
      'labels': labels,
      if (moderation != null) 'moderation': moderation,
      'model': model,
      'provider': provider,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Creates a [VideoAnalysisResponse] instance from a JSON map.
  factory VideoAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return VideoAnalysisResponse(
      objects: json['objects'] != null
          ? (json['objects'] as List)
              .map((o) => DetectedObject.fromJson(o as Map<String, dynamic>))
              .toList()
          : [],
      scenes: json['scenes'] != null
          ? (json['scenes'] as List)
              .map((s) => DetectedScene.fromJson(s as Map<String, dynamic>))
              .toList()
          : [],
      actions: json['actions'] != null
          ? (json['actions'] as List)
              .map((a) => DetectedAction.fromJson(a as Map<String, dynamic>))
              .toList()
          : [],
      text: json['text'] != null
          ? (json['text'] as List)
              .map((t) => ExtractedText.fromJson(t as Map<String, dynamic>))
              .toList()
          : [],
      labels: json['labels'] != null
          ? (json['labels'] as List).map((l) => l.toString()).toList()
          : [],
      moderation: json['moderation'] as Map<String, dynamic>?,
      model: json['model'] as String,
      provider: json['provider'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoAnalysisResponse &&
        _listEquals(other.objects, objects) &&
        _listEquals(other.scenes, scenes) &&
        _listEquals(other.actions, actions) &&
        _listEquals(other.text, text) &&
        _listEquals(other.labels, labels) &&
        _mapEquals(other.moderation, moderation) &&
        other.model == model &&
        other.provider == provider &&
        other.timestamp.millisecondsSinceEpoch ==
            timestamp.millisecondsSinceEpoch &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    int objectsHash = 0;
    for (final obj in objects) {
      objectsHash = Object.hash(objectsHash, obj);
    }
    int scenesHash = 0;
    for (final scene in scenes) {
      scenesHash = Object.hash(scenesHash, scene);
    }
    int actionsHash = 0;
    for (final action in actions) {
      actionsHash = Object.hash(actionsHash, action);
    }
    int textHash = 0;
    for (final t in text) {
      textHash = Object.hash(textHash, t);
    }
    int labelsHash = 0;
    for (final label in labels) {
      labelsHash = Object.hash(labelsHash, label);
    }
    return Object.hash(
      objectsHash,
      scenesHash,
      actionsHash,
      textHash,
      labelsHash,
      moderation,
      model,
      provider,
      timestamp.millisecondsSinceEpoch,
      metadata,
    );
  }

  /// Helper method to compare lists for equality.
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Helper method to compare maps for equality.
  bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  /// Creates a copy of this [VideoAnalysisResponse] with the given fields replaced.
  VideoAnalysisResponse copyWith({
    List<DetectedObject>? objects,
    List<DetectedScene>? scenes,
    List<DetectedAction>? actions,
    List<ExtractedText>? text,
    List<String>? labels,
    Map<String, dynamic>? moderation,
    String? model,
    String? provider,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return VideoAnalysisResponse(
      objects: objects ?? this.objects,
      scenes: scenes ?? this.scenes,
      actions: actions ?? this.actions,
      text: text ?? this.text,
      labels: labels ?? this.labels,
      moderation: moderation ?? this.moderation,
      model: model ?? this.model,
      provider: provider ?? this.provider,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'VideoAnalysisResponse(objects: ${objects.length}, scenes: ${scenes.length}, actions: ${actions.length}, text: ${text.length}, labels: ${labels.length}, model: $model, provider: $provider)';
  }
}
