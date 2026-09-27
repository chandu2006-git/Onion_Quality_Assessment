import 'dart:convert';
import 'dart:typed_data';

import '../core/api_exception.dart';
import '../core/inspection_id.dart';
import '../config/grades.dart';
import 'analysis_result.dart';
import 'onion_observation.dart';

/// Inspector decision on the grade recommendation.
///
/// The recommended grade is never overwritten: a confirmation records that
/// the inspector accepted it, an override records the inspector's own final
/// grade NEXT to the original recommendation.
enum GradeDecision {
  pending('pending', 'Pending'),
  confirmed('confirmed', 'Confirmed'),
  overridden('overridden', 'Overridden');

  const GradeDecision(this.wireValue, this.label);

  /// Value accepted by the report contract.
  final String wireValue;

  /// Short display label.
  final String label;
}

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

  // --------------------------------------------------------------------- //
  // Quality grade workflow: recommendation → human decision → final grade
  // --------------------------------------------------------------------- //

  /// AI-assisted (or fixed-demo) grade recommendation. Never overwritten.
  String? recommendedGrade;

  /// Inspector decision state of the grade recommendation.
  GradeDecision gradeDecision = GradeDecision.pending;

  /// Inspector's own grade when the recommendation was overridden.
  String? humanGrade;

  /// True when the current result is a FIXED demonstration scenario.
  bool get isDemo => analysis?.isDemo ?? false;

  /// Final grade shown after the inspector decides.
  /// `PENDING` until the recommendation is confirmed or overridden.
  String get finalGradeLabel {
    switch (gradeDecision) {
      case GradeDecision.confirmed:
        return recommendedGrade ?? 'PENDING';
      case GradeDecision.overridden:
        return humanGrade ?? recommendedGrade ?? 'PENDING';
      case GradeDecision.pending:
        return 'PENDING';
    }
  }

  bool get gradeDecided => gradeDecision != GradeDecision.pending;

  /// Accept the recommendation. The original value stays untouched.
  void confirmGrade() {
    if (recommendedGrade == null) return;
    gradeDecision = GradeDecision.confirmed;
    humanGrade = null;
  }

  /// Record an inspector grade that differs from the recommendation.
  void overrideGrade(String grade) {
    if (recommendedGrade == null || !QualityGrade.isValid(grade)) return;
    gradeDecision = GradeDecision.overridden;
    humanGrade = grade;
  }

  /// Return the grade decision to PENDING (recommendation preserved).
  void clearGradeDecision() {
    gradeDecision = GradeDecision.pending;
    humanGrade = null;
  }

  /// Clears any grade state (used when a new sample or analysis replaces the
  /// previous one).
  void resetGrade() {
    recommendedGrade = null;
    gradeDecision = GradeDecision.pending;
    humanGrade = null;
  }

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

  /// Bulbs where the inspector's decision genuinely differs from the AI
  /// observation (computed from the recorded decisions, never assumed).
  int get mismatchCount => observations.where((o) => o.isAiHumanMismatch).length;

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
      // Quality grade + demo transparency (optional for the backend; real
      // reports are never marked as demo and vice versa).
      'is_demo': analysis!.isDemo,
      'recommended_grade': recommendedGrade,
      'final_grade': finalGradeLabel,
      'grade_decision': gradeDecision.wireValue,
      'demo_scenario': analysis!.isDemo ? analysis!.scenarioTitle : null,
      'demo_observations': analysis!.isDemo ? analysis!.scenarioNotes : null,
    };
  }
}
