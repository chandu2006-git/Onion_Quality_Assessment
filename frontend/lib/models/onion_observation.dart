import 'package:flutter/material.dart';

import '../config/grades.dart';
import '../config/grading_rules.dart';
import '../theme/app_theme.dart';

/// Human verification state of a single onion bulb.
///
/// The AI observation is immutable. A confirmation stores which AI label the
/// inspector accepted; an override stores the inspector's own decision next to
/// the original observation, never in place of it.
enum VerificationOutcome {
  pending('pending', 'Pending'),
  confirmed('confirmed_ai', 'Confirmed'),
  overridden('overridden', 'Overridden');

  const VerificationOutcome(this.wireValue, this.label);

  /// Value accepted by the FastAPI report contract.
  final String wireValue;

  /// Short display label.
  final String label;

  static VerificationOutcome fromWire(String? value) {
    switch (value) {
      case 'confirmed_ai':
        return VerificationOutcome.confirmed;
      case 'overridden':
        return VerificationOutcome.overridden;
      default:
        return VerificationOutcome.pending;
    }
  }

  Color get colour {
    switch (this) {
      case VerificationOutcome.pending:
        return AppTheme.amber;
      case VerificationOutcome.confirmed:
        return AppTheme.secondaryGreen;
      case VerificationOutcome.overridden:
        return AppTheme.amberDark;
    }
  }

  IconData get icon {
    switch (this) {
      case VerificationOutcome.pending:
        return Icons.schedule;
      case VerificationOutcome.confirmed:
        return Icons.verified_outlined;
      case VerificationOutcome.overridden:
        return Icons.edit_outlined;
    }
  }
}

/// Inspector decision on the PER-BULB grade recommendation.
///
/// Separate from the health verification above: a bulb's health may be
/// confirmed while its grade is overridden (or the other way round). The AI
/// recommendation is never overwritten — an override records the inspector's
/// own grade next to it.
enum BulbGradeDecision {
  pending('pending', 'Pending'),
  confirmed('confirmed', 'Confirmed'),
  overridden('overridden', 'Overridden');

  const BulbGradeDecision(this.wireValue, this.label);

  /// Value accepted by the report contract.
  final String wireValue;

  /// Short display label.
  final String label;
}

/// Onion health label as reported by the classification model.
class OnionHealth {
  const OnionHealth._();

  static const String healthy = 'Healthy';
  static const String unhealthy = 'Unhealthy';

  static bool isHealthy(String value) => value.toLowerCase() == 'healthy';

  static Color colourFor(String value) =>
      isHealthy(value) ? AppTheme.healthy : AppTheme.unhealthy;
}

/// Bounding box in original image pixel coordinates.
@immutable
class BoundingBox {
  const BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final int x1;
  final int y1;
  final int x2;
  final int y2;

  double get width => (x2 - x1).toDouble();
  double get height => (y2 - y1).toDouble();

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
        x1: (json['x1'] as num).toInt(),
        y1: (json['y1'] as num).toInt(),
        x2: (json['x2'] as num).toInt(),
        y2: (json['y2'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
      };
}

/// One detected onion bulb: immutable AI observation plus a separate human
/// verification record.
class OnionObservation {
  OnionObservation({
    required this.id,
    required this.bbox,
    required this.detectionConfidence,
    required this.aiHealth,
    required this.healthConfidence,
    this.verification = VerificationOutcome.pending,
    this.humanDecision,
    this.verificationNote = '',
    BulbGradeAssessment? gradeAssessment,
    double relativeArea = 1.0,
    GradingRules rules = GradingRules.standard,
  }) : gradeAssessment = gradeAssessment ??
            rules.assess(
              BulbEvidence(
                health: aiHealth,
                healthConfidence: healthConfidence,
                detectionConfidence: detectionConfidence,
                relativeArea: relativeArea,
              ),
            );

  /// 1-based bulb number assigned by the detection stage.
  final int id;
  final BoundingBox bbox;
  final double detectionConfidence;

  /// AI observation — never overwritten by a human decision.
  final String aiHealth;

  /// Confidence of the health classification — never overwritten.
  final double healthConfidence;

  /// Standards-informed grade recommendation for THIS bulb, produced by the
  /// configurable rule engine (`config/grading_rules.dart`). Never overwritten
  /// by an inspector decision.
  final BulbGradeAssessment gradeAssessment;

  VerificationOutcome verification;

  /// Inspector decision when the AI observation was overridden.
  String? humanDecision;

  String verificationNote;

  /// Inspector decision on the grade recommendation.
  BulbGradeDecision gradeDecision = BulbGradeDecision.pending;

  /// Inspector's own grade when the recommendation was overridden.
  String? humanGrade;

  bool get isHealthyObservation => OnionHealth.isHealthy(aiHealth);
  bool get isReviewed => verification != VerificationOutcome.pending;

  /// True only when the inspector's recorded decision genuinely differs from
  /// the AI observation — never shown for confirmations or pending bulbs.
  bool get isAiHumanMismatch =>
      verification == VerificationOutcome.overridden &&
      humanDecision != null &&
      OnionHealth.isHealthy(humanDecision!) != isHealthyObservation;

  /// Lifecycle label for the bulb: pending → verified → verified override.
  String get finalStatusLabel {
    switch (verification) {
      case VerificationOutcome.confirmed:
        return 'VERIFIED';
      case VerificationOutcome.overridden:
        return 'VERIFIED — OVERRIDE';
      case VerificationOutcome.pending:
        return 'PENDING VERIFICATION';
    }
  }

  /// Recorded final status: the AI label when confirmed, the human decision when
  /// overridden. `null` while the bulb is still pending review.
  String? get recordedHealth {
    switch (verification) {
      case VerificationOutcome.confirmed:
        return aiHealth;
      case VerificationOutcome.overridden:
        return humanDecision;
      case VerificationOutcome.pending:
        return null;
    }
  }

  String get displayLabel => 'ONION #${id.toString().padLeft(2, '0')}';

  // --------------------------------------------------------------------- //
  // Per-bulb grade workflow: recommendation → human decision → final grade
  // --------------------------------------------------------------------- //

  /// AI-assisted grade recommendation for this bulb (never overwritten).
  String get recommendedGrade => gradeAssessment.grade;

  /// Visible-quality observation produced by the grading engine.
  String get qualityObservation => gradeAssessment.observation;

  /// Why the engine produced this recommendation (auditable rule trace).
  String get gradeReason => gradeAssessment.reason;

  /// True when the engine could not grade this bulb from the measured evidence.
  bool get gradeRequiresHumanReview => gradeAssessment.requiresHumanReview;

  bool get gradeDecided => gradeDecision != BulbGradeDecision.pending;

  /// Final grade: the recommendation when confirmed, the inspector's grade when
  /// overridden; `null` while the bulb still awaits a decision.
  String? get finalGrade {
    switch (gradeDecision) {
      case BulbGradeDecision.confirmed:
        return gradeAssessment.grade;
      case BulbGradeDecision.overridden:
        return humanGrade;
      case BulbGradeDecision.pending:
        return null;
    }
  }

  String get finalGradeLabel => finalGrade ?? 'PENDING';

  String get gradeDecisionLabel => gradeDecision.label;

  /// Accept the recommended grade for this bulb.
  void confirmGrade() {
    gradeDecision = BulbGradeDecision.confirmed;
    humanGrade = null;
  }

  /// Record an inspector grade for this bulb (recommendation preserved).
  void overrideGradeWith(String grade) {
    if (!QualityGrade.isValid(grade)) return;
    gradeDecision = BulbGradeDecision.overridden;
    humanGrade = grade;
  }

  /// Return the grade decision of this bulb to PENDING.
  void clearGradeDecision() {
    gradeDecision = BulbGradeDecision.pending;
    humanGrade = null;
  }

  /// Bulb box area as a share of the image area. Returns 1.0 when the frame
  /// size is unknown, so an unknown image size never triggers the engine's
  /// "too small in frame" rule.
  static double _relativeAreaFrom(
    Map<String, dynamic> json,
    int imageWidth,
    int imageHeight,
  ) {
    if (imageWidth <= 0 || imageHeight <= 0) return 1.0;
    final box = BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>);
    final frame = imageWidth * imageHeight;
    if (frame <= 0) return 1.0;
    return (box.width * box.height / frame).clamp(0.0, 1.0).toDouble();
  }

  /// Parse one detection from a real `/api/analyze` response.
  ///
  /// [imageWidth] / [imageHeight] let the grading engine judge whether the bulb
  /// is large enough in frame to be graded; they are optional so existing
  /// callers keep working.
  factory OnionObservation.fromJson(
    Map<String, dynamic> json, {
    int imageWidth = 0,
    int imageHeight = 0,
  }) =>
      OnionObservation(
        id: (json['id'] as num).toInt(),
        bbox: BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>),
        detectionConfidence: (json['detection_confidence'] as num).toDouble(),
        aiHealth: json['health'] as String,
        healthConfidence: (json['health_confidence'] as num).toDouble(),
        relativeArea: _relativeAreaFrom(json, imageWidth, imageHeight),
      );

  /// Detection payload for the report request (AI fields only).
  Map<String, dynamic> toDetectionJson() => <String, dynamic>{
        'id': id,
        'bbox': bbox.toJson(),
        'detection_confidence': detectionConfidence,
        'health': aiHealth,
        'health_confidence': healthConfidence,
      };

  /// Verification payload for the report request.
  ///
  /// Carries the per-bulb grade record as well: the AI recommendation, the
  /// visible-quality observation, the inspector's grade and the decision — the
  /// PDF renders the bulb-wise quality table from exactly these values.
  Map<String, dynamic> toVerificationJson() => <String, dynamic>{
        'id': id,
        'ai_health': aiHealth,
        'health_confidence': healthConfidence,
        'detection_confidence': detectionConfidence,
        'verification_status': verification.wireValue,
        'human_decision': humanDecision,
        'verification_note': verificationNote.isEmpty ? null : verificationNote,
        'quality_observation': qualityObservation,
        'recommended_grade': recommendedGrade,
        'human_grade': humanGrade,
        'final_grade': finalGrade,
        'grade_decision': gradeDecision.wireValue,
        'grade_reason': gradeReason,
      };

  /// Accept the AI observation.
  void confirmAi() {
    verification = VerificationOutcome.confirmed;
    humanDecision = null;
  }

  /// Record an inspector decision that differs from the AI observation.
  void overrideWith(String decision) {
    verification = VerificationOutcome.overridden;
    humanDecision = decision;
  }

  /// Return the bulb to the pending state.
  void clearReview() {
    verification = VerificationOutcome.pending;
    humanDecision = null;
    verificationNote = '';
  }
}
