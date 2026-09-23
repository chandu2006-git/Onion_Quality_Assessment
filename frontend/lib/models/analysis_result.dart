import 'dart:convert';
import 'dart:typed_data';

import 'onion_observation.dart';

/// Result of a real inference run performed by the FastAPI backend.
///
/// Every value here comes from the API response: the onion count, the health
/// labels, the confidences and the annotated evidence image are never
/// synthesised on the client.
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
  });

  final int totalOnions;
  final int healthyCount;
  final int unhealthyCount;
  final List<OnionObservation> observations;

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
    final detections = (json['detections'] as List<dynamic>? ?? <dynamic>[])
        .map((entry) => OnionObservation.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);

    final encoded = json['annotated_image'] as String? ?? '';
    final imageWidth = (json['image_width'] as num?)?.toInt() ?? 0;
    final imageHeight = (json['image_height'] as num?)?.toInt() ?? 0;

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
    );
  }
}
