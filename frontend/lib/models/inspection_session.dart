import 'dart:convert';
import 'dart:typed_data';

import '../core/api_exception.dart';
import '../core/inspection_id.dart';
import 'analysis_result.dart';
import 'onion_observation.dart';

/// Everything recorded during one inspection session.
///
/// The session is held in application state only (no database is required) and
/// is written into the generated PDF report at finalisation time.
class InspectionSession {
  InspectionSession({
    required this.id,
    required this.inspector,
    required this.location,
    required this.batchLot,
    required this.notes,
    required this.startedAt,
  });

  final String id;
  final String inspector;
  final String location;
  final String batchLot;
  final String notes;
  final DateTime startedAt;

  /// The uploaded sample, kept for preview and for the report.
  Uint8List? sampleBytes;
  String? sampleFileName;
  int? sampleSizeBytes;

  AnalysisResult? analysis;

  List<OnionObservation> get observations =>
      analysis?.observations ?? const <OnionObservation>[];

  String get formattedTimestamp => formatInspectionTimestamp(startedAt);

  int get reviewedCount => observations.where((o) => o.isReviewed).length;
  int get totalCount => observations.length;
  bool get allReviewed => totalCount > 0 && reviewedCount == totalCount;

  int get pendingCount => observations
      .where((o) => o.verification == VerificationOutcome.pending)
      .length;
  int get confirmedCount => observations
      .where((o) => o.verification == VerificationOutcome.confirmed)
      .length;
  int get overriddenCount => observations
      .where((o) => o.verification == VerificationOutcome.overridden)
      .length;

  int get verifiedHealthyCount => observations
      .where((o) => o.recordedHealth == OnionHealth.healthy)
      .length;
  int get verifiedUnhealthyCount => observations
      .where((o) => o.recordedHealth == OnionHealth.unhealthy)
      .length;

  /// Base64 annotated evidence image (bounding boxes drawn by the backend).
  String? get annotatedImageBase64 {
    final bytes = analysis?.annotatedImage;
    if (bytes == null || bytes.isEmpty) return null;
    return base64Encode(bytes);
  }

  OnionObservation? observationById(int? id) {
    if (id == null) return null;
    for (final observation in observations) {
      if (observation.id == id) return observation;
    }
    return null;
  }

  /// Payload accepted by `POST /api/report`.
  ///
  /// Throws [ApiException] when the inspection is not fully reviewed: the report
  /// must never be produced from an unfinished verification.
  Map<String, dynamic> toReportPayload() {
    if (analysis == null) {
      throw const ApiException(
        ApiFailureKind.invalidRequest,
        'No analysis result is available for this inspection.',
      );
    }
    if (!allReviewed) {
      throw const ApiException(
        ApiFailureKind.invalidRequest,
        'Review all AI observations before finalizing the inspection.',
      );
    }
    return <String, dynamic>{
      'inspection_id': id,
      'timestamp': formattedTimestamp,
      'inspector': inspector,
      'location': location,
      'batch_lot': batchLot,
      'notes': notes.isEmpty ? null : notes,
      'ai_healthy': analysis!.healthyCount,
      'ai_unhealthy': analysis!.unhealthyCount,
      'verified_healthy': verifiedHealthyCount,
      'verified_unhealthy': verifiedUnhealthyCount,
      'detections': observations.map((o) => o.toDetectionJson()).toList(),
      'verifications': observations.map((o) => o.toVerificationJson()).toList(),
      'annotated_image': annotatedImageBase64,
    };
  }
}
