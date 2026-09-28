import 'dart:convert';
import 'dart:typed_data';

import 'onion_observation.dart';

/// Result of one inspection run.
///
/// Real results are produced by the FastAPI backend (YOLOv8n → MobileNetV2);
/// fixed demonstration results are built locally from the bundled demo dataset
/// with `isDemo: true`. Every value shown to the user comes from one of those
/// two sources — nothing is synthesised in between.
class AnalysisResult {
  AnalysisResult({
    required this.totalOnions,
    required this.healthyCount,
    required this.unhealthyCount,
    required this.observations,
    required this.imageWidth,
    required this.imageHeight,
    required this.annotatedImageWidth,
    required this.annotatedImageHeight,
    required this.annotatedImage,
    required this.modelInfo,
    this.isDemo = false,
    this.scenarioId = '',
    this.scenarioTitle = '',
    this.scenarioNotes = const <String>[],
  });

  final int totalOnions;
  final int healthyCount;
  final int unhealthyCount;
  final List<OnionObservation> observations;

  /// True only for FIXED demonstration scenarios opened from the bundled
  /// dataset. Real backend responses never set it, so real AI data and demo
  /// data can never be mixed.
  final bool isDemo;

  /// Demo scenario metadata (`''` for real AI results).
  final String scenarioId;
  final String scenarioTitle;
  final List<String> scenarioNotes;

  /// Original uploaded image dimensions (bounding boxes use these coordinates).
  final int imageWidth;
  final int imageHeight;

  /// Dimensions of the annotated evidence image returned by the backend.
  final int annotatedImageWidth;
  final int annotatedImageHeight;

  /// Annotated evidence image (bounding boxes drawn by the backend).
  final Uint8List annotatedImage;

  /// Detector / classifier description reported by the backend.
  final Map<String, String> modelInfo;

  bool get hasDetections => observations.isNotEmpty;

  double get annotatedAspectRatio {
    final width = annotatedImageWidth > 0 ? annotatedImageWidth : imageWidth;
    final height = annotatedImageHeight > 0 ? annotatedImageHeight : imageHeight;
    if (width <= 0 || height <= 0) return 4 / 3;
    return width / height;
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final imageWidth = (json['image_width'] as num?)?.toInt() ?? 0;
    final imageHeight = (json['image_height'] as num?)?.toInt() ?? 0;
    // Frame size is passed in so the grading engine can judge whether each bulb
    // is large enough in frame to be graded from the measured evidence.
    final detections = (json['detections'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (entry) => OnionObservation.fromJson(
            entry as Map<String, dynamic>,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
          ),
        )
        .toList(growable: false);

    final encoded = json['annotated_image'] as String? ?? '';

    return AnalysisResult(
      totalOnions: (json['total_onions'] as num?)?.toInt() ?? detections.length,
      healthyCount: (json['healthy'] as num?)?.toInt() ??
          detections.where((d) => d.isHealthyObservation).length,
      unhealthyCount: (json['unhealthy'] as num?)?.toInt() ??
          detections.where((d) => !d.isHealthyObservation).length,
      observations: detections,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      annotatedImageWidth: (json['annotated_width'] as num?)?.toInt() ?? imageWidth,
      annotatedImageHeight: (json['annotated_height'] as num?)?.toInt() ?? imageHeight,
      annotatedImage: encoded.isEmpty ? Uint8List(0) : base64Decode(encoded),
      modelInfo: (json['model_info'] as Map<String, dynamic>? ?? <String, dynamic>{})
          .map((key, value) => MapEntry(key, value.toString())),
      // Real backend responses never flag demo mode; only the fixed demo
      // dataset builds results with `isDemo: true`.
      isDemo: json['is_demo'] as bool? ?? false,
      scenarioId: json['scenario_id'] as String? ?? '',
      scenarioTitle: json['scenario_title'] as String? ?? '',
      scenarioNotes: (json['scenario_notes'] as List<dynamic>? ?? <dynamic>[])
          .map((note) => note.toString())
          .toList(growable: false),
    );
  }
}
