/// STANDARDS-INFORMED QUALITY GRADING ENGINE (per bulb + per lot).
///
/// The engine turns the evidence this system ACTUALLY measures into a
/// recommendation:
///
///   detected bulb  +  health classification  +  their confidences
///                    ↓  configurable rule set  ↓
///        GRADE A  /  GRADE B  /  URS  /  REQUIRES HUMAN REVIEW
///
/// Rules live here — never inside widgets — and every threshold is a named,
/// documented field of [GradingRules], so the rule set can be tuned (for
/// example after a calibration exercise) without touching the UI.
///
/// HONESTY CONSTRAINTS (non-negotiable):
///  * Only the health classification, its confidence, the detection confidence
///    and the detected box size are used. The models do NOT measure diameter,
///    firmness, moisture, internal rot, stem/root length or an exact defect
///    percentage, so the engine never claims them.
///  * When the evidence is too weak to grade a bulb, the outcome is
///    [QualityGrade.requiresReview] — REQUIRES HUMAN REVIEW — never an invented
///    certainty.
///  * GRADE A / GRADE B / URS are the product's operational categories. They are
///    informed by the documented onion quality references (AGMARK Extra
///    Class/Class I/Class II tolerances and the PSF procurement characteristics)
///    but this engine is NOT an official AGMARK/PSF certification engine, and
///    the report says so.
library;

import 'grades.dart';

/// One bulb's measured evidence.
class BulbEvidence {
  const BulbEvidence({
    required this.health,
    required this.healthConfidence,
    required this.detectionConfidence,
    this.relativeArea = 1.0,
  });

  /// `Healthy` or `Unhealthy`, as reported by the health model.
  final String health;

  /// Confidence of the health classification (0..1).
  final double healthConfidence;

  /// Detection confidence of the bounding box (0..1).
  final double detectionConfidence;

  /// Bulb box area relative to the image area (0..1). Used only as a weak
  /// "the bulb is large enough in frame to judge" signal.
  final double relativeArea;

  bool get isHealthy => health.toLowerCase() == 'healthy';
}

/// Auditable result of grading one bulb.
class BulbGradeAssessment {
  const BulbGradeAssessment({
    required this.grade,
    required this.observation,
    required this.reason,
    required this.evidenceUsed,
    required this.requiresHumanReview,
  });

  /// [QualityGrade.gradeA], [QualityGrade.gradeB], [QualityGrade.urs] or
  /// [QualityGrade.requiresReview].
  final String grade;

  /// Short visible-quality statement shown to the inspector.
  final String observation;

  /// Which rule fired and why (plain language, auditable).
  final String reason;

  /// The measured attributes this decision used — nothing else.
  final List<String> evidenceUsed;

  /// True when the engine refuses to grade the bulb automatically.
  final bool requiresHumanReview;

  String get gradeLabel => grade;

  bool get isGradeA => grade == QualityGrade.gradeA;
  bool get isGradeB => grade == QualityGrade.gradeB;
  bool get isUrs => grade == QualityGrade.urs;
}

/// Configurable thresholds of the per-bulb rule set.
///
/// Every value is documented so the recommendation is explainable to an
/// inspector or auditor.
class GradingRules {
  const GradingRules({
    this.highConfidenceThreshold = 0.85,
    this.moderateConfidenceThreshold = 0.60,
    this.strongUnhealthyThreshold = 0.80,
    this.strongDetectionConfidence = 0.60,
    this.minimumDetectionConfidence = 0.35,
    this.minimumRelativeArea = 0.0025,
  });

  /// Health confidence at or above which a Healthy bulb is recommended as
  /// GRADE A (its strongest visible-quality condition, as far as this system
  /// can observe).
  final double highConfidenceThreshold;

  /// Below this health confidence the classification is too weak to grade:
  /// the bulb is routed to REQUIRES HUMAN REVIEW.
  final double moderateConfidenceThreshold;

  /// Health confidence at or above which an Unhealthy bulb is treated as a
  /// strong deterioration indicator → URS.
  final double strongUnhealthyThreshold;

  /// Detection confidence required for a GRADE A recommendation (the bulb must
  /// be located confidently as well as classified confidently).
  final double strongDetectionConfidence;

  /// Below this detection confidence the bulb is not graded automatically.
  final double minimumDetectionConfidence;

  /// Minimum box area relative to the image; smaller boxes are too small in
  /// frame to judge visually.
  final double minimumRelativeArea;

  /// The production rule set.
  static const GradingRules standard = GradingRules();

  static String _pct(double value) => '${(value * 100).round()}%';

  /// Grade one bulb from its measured evidence.
  BulbGradeAssessment assess(BulbEvidence evidence) {
    final used = <String>[
      'health=${evidence.health}',
      'health_confidence=${_pct(evidence.healthConfidence)}',
      'detection_confidence=${_pct(evidence.detectionConfidence)}',
    ];

    // --- 1. Is there enough visual evidence to grade this bulb at all? -----
    if (evidence.detectionConfidence < minimumDetectionConfidence) {
      return BulbGradeAssessment(
        grade: QualityGrade.requiresReview,
        observation:
            'Detection confidence is low (${_pct(evidence.detectionConfidence)}); '
            'the bulb may be partially hidden or cut off.',
        reason:
            'Detection confidence below the ${_pct(minimumDetectionConfidence)} '
            'threshold, so the bulb cannot be graded reliably from this evidence.',
        evidenceUsed: used,
        requiresHumanReview: true,
      );
    }
    if (evidence.relativeArea < minimumRelativeArea) {
      return BulbGradeAssessment(
        grade: QualityGrade.requiresReview,
        observation:
            'The bulb occupies very little of the image '
            '(${(evidence.relativeArea * 100).toStringAsFixed(2)}% of the frame).',
        reason:
            'Bulb box smaller than the '
            '${(minimumRelativeArea * 100).toStringAsFixed(2)}% frame-area '
            'threshold, so it is too small in frame for a reliable visual call.',
        evidenceUsed: used,
        requiresHumanReview: true,
      );
    }
    if (evidence.healthConfidence < moderateConfidenceThreshold) {
      return BulbGradeAssessment(
        grade: QualityGrade.requiresReview,
        observation:
            'Health classification confidence is low '
            '(${_pct(evidence.healthConfidence)}).',
        reason:
            'Health confidence below the ${_pct(moderateConfidenceThreshold)} '
            'threshold, so the visible condition cannot be graded automatically.',
        evidenceUsed: used,
        requiresHumanReview: true,
      );
    }

    // --- 2. Healthy bulbs: strongest visible condition observed -----------
    if (evidence.isHealthy) {
      if (evidence.healthConfidence >= highConfidenceThreshold &&
          evidence.detectionConfidence >= strongDetectionConfidence) {
        return BulbGradeAssessment(
          grade: QualityGrade.gradeA,
          observation:
              'Healthy appearance with a high-confidence classification '
              '(${_pct(evidence.healthConfidence)}) and a confident detection '
              '(${_pct(evidence.detectionConfidence)}).',
          reason:
              'Healthy bulb with health confidence at or above '
              '${_pct(highConfidenceThreshold)} and detection confidence at or '
              'above ${_pct(strongDetectionConfidence)}: the strongest '
              'visible-quality condition this system measures.',
          evidenceUsed: used,
          requiresHumanReview: false,
        );
      }
      return BulbGradeAssessment(
        grade: QualityGrade.gradeB,
        observation:
            'Healthy appearance reported with moderate confidence '
            '(${_pct(evidence.healthConfidence)}); inspect the surface visually.',
        reason:
            'Healthy bulb whose confidence is below the '
            '${_pct(highConfidenceThreshold)} GRADE A threshold: acceptable '
            'visible quality with a human check recommended.',
        evidenceUsed: used,
        requiresHumanReview: false,
      );
    }

    // --- 3. Unhealthy bulbs: how strong is the deterioration signal? ------
    if (evidence.healthConfidence >= strongUnhealthyThreshold) {
      return BulbGradeAssessment(
        grade: QualityGrade.urs,
        observation:
            'Unhealthy appearance reported with strong confidence '
            '(${_pct(evidence.healthConfidence)}); a visible defect or '
            'deterioration indicator is present.',
        reason:
            'Unhealthy classification at or above the '
            '${_pct(strongUnhealthyThreshold)} strong-signal threshold: does not '
            'meet GRADE A / GRADE B visible-quality expectations.',
        evidenceUsed: used,
        requiresHumanReview: false,
      );
    }
    return BulbGradeAssessment(
      grade: QualityGrade.gradeB,
      observation:
          'Unhealthy appearance reported with limited confidence '
          '(${_pct(evidence.healthConfidence)}); a moderate, recoverable '
          'surface defect is possible.',
      reason:
          'Unhealthy classification below the '
          '${_pct(strongUnhealthyThreshold)} strong-signal threshold: moderate '
          'visible defect, sorting recommended.',
      evidenceUsed: used,
      requiresHumanReview: false,
    );
  }
}

/// Distribution of FINAL (human-decided) bulb grades.
///
/// Counts are always recomputed from the bulb records, so the summary changes
/// the moment an inspector confirms or overrides a single bulb.
class LotGradeDistribution {
  const LotGradeDistribution({
    this.gradeA = 0,
    this.gradeB = 0,
    this.urs = 0,
    this.requiresReview = 0,
    this.undecided = 0,
  });

  final int gradeA;
  final int gradeB;
  final int urs;

  /// Bulbs the engine could not grade automatically and no human decided yet.
  final int requiresReview;

  /// Reviewed bulbs without a recorded grade decision.
  final int undecided;

  int get total => gradeA + gradeB + urs + requiresReview + undecided;

  /// Bulbs with a recorded grade (Grade A + Grade B + URS).
  int get decided => gradeA + gradeB + urs;

  /// Bulbs still awaiting a grade decision.
  int get pending => requiresReview + undecided;

  double shareOf(int count) => decided == 0 ? 0 : count / decided;

  /// Build the distribution from the bulbs' FINAL grade labels
  /// (`null` while no grade decision has been recorded).
  factory LotGradeDistribution.fromGrades(Iterable<String?> grades) {
    var a = 0, b = 0, urs = 0, review = 0, undecided = 0;
    for (final grade in grades) {
      if (grade == QualityGrade.gradeA) {
        a++;
      } else if (grade == QualityGrade.gradeB) {
        b++;
      } else if (grade == QualityGrade.urs) {
        urs++;
      } else if (grade == QualityGrade.requiresReview) {
        review++;
      } else {
        undecided++;
      }
    }
    return LotGradeDistribution(
      gradeA: a,
      gradeB: b,
      urs: urs,
      requiresReview: review,
      undecided: undecided,
    );
  }

  /// Ordered (label, count) pairs for tables and charts.
  List<(String, int)> get entries => <(String, int)>[
        (QualityGrade.gradeA, gradeA),
        (QualityGrade.gradeB, gradeB),
        (QualityGrade.urs, urs),
        (QualityGrade.requiresReview, requiresReview),
      ];
}

/// Lot-level recommendation plus the rule that produced it.
class LotGradeRecommendation {
  const LotGradeRecommendation({
    required this.status,
    required this.rule,
    required this.pendingHumanVerification,
    required this.requiresManualDecision,
  });

  final String status;

  /// Plain-language explanation of the aggregation rule that fired.
  final String rule;

  /// True while bulbs are still awaiting a grade decision.
  final bool pendingHumanVerification;

  /// True when no lot grade is claimed and the inspector must decide.
  final bool requiresManualDecision;
}

/// Configurable lot-level aggregation policy.
///
/// There is no validated official lot-grading formula behind this product, so
/// the policy is explicit, conservative and printed on the report:
///
///  * GRADE A — Grade A share ≥ [gradeAShare] of graded bulbs AND no URS bulb;
///  * GRADE B — (Grade A + Grade B) share ≥ [gradeBShare] of graded bulbs;
///  * URS — otherwise;
///  * PENDING HUMAN VERIFICATION — while any bulb awaits a decision, or when no
///    bulb has been graded at all (no lot grade is invented).
class LotGradingPolicy {
  const LotGradingPolicy({this.gradeAShare = 0.85, this.gradeBShare = 0.50});

  /// Minimum Grade A share of graded bulbs for a lot-level GRADE A.
  final double gradeAShare;

  /// Minimum (Grade A + Grade B) share of graded bulbs for a lot-level GRADE B.
  final double gradeBShare;

  static const LotGradingPolicy standard = LotGradingPolicy();

  /// The rule, printed verbatim next to the recommendation.
  String get ruleText =>
      'Lot policy: GRADE A when at least ${(gradeAShare * 100).round()}% of the '
      'graded bulbs are GRADE A and no bulb is URS; GRADE B when GRADE A and '
      'GRADE B together cover at least ${(gradeBShare * 100).round()}% of the '
      'graded bulbs; otherwise URS. Pending until every bulb has a grade.';

  LotGradeRecommendation recommend(LotGradeDistribution distribution) {
    if (distribution.decided == 0) {
      return const LotGradeRecommendation(
        status: QualityGrade.requiresReview,
        rule: 'No bulb grade has been recorded yet, so no lot grade is claimed.',
        pendingHumanVerification: true,
        requiresManualDecision: true,
      );
    }
    if (distribution.pending > 0) {
      return LotGradeRecommendation(
        status: QualityGrade.requiresReview,
        rule: '${distribution.pending} of ${distribution.total} bulb(s) still '
            'await a grade decision. The lot summary updates as each bulb is '
            'decided.',
        pendingHumanVerification: true,
        requiresManualDecision: false,
      );
    }
    final aShare = distribution.shareOf(distribution.gradeA);
    final abShare = distribution.shareOf(
      distribution.gradeA + distribution.gradeB,
    );
    if (aShare >= gradeAShare && distribution.urs == 0) {
      return LotGradeRecommendation(
        status: QualityGrade.gradeA,
        rule: 'GRADE A share is ${(aShare * 100).round()}% of the graded bulbs '
            'and no bulb is URS.',
        pendingHumanVerification: false,
        requiresManualDecision: false,
      );
    }
    if (abShare >= gradeBShare) {
      return LotGradeRecommendation(
        status: QualityGrade.gradeB,
        rule: 'GRADE A + GRADE B cover ${(abShare * 100).round()}% of the graded '
            'bulbs.',
        pendingHumanVerification: false,
        requiresManualDecision: false,
      );
    }
    return LotGradeRecommendation(
      status: QualityGrade.urs,
      rule: 'GRADE A + GRADE B cover only ${(abShare * 100).round()}% of the '
          'graded bulbs, so the lot does not meet GRADE A / GRADE B '
          'expectations under this project policy.',
      pendingHumanVerification: false,
      requiresManualDecision: false,
    );
  }
}

/// Product wording used by every grading surface (single source of truth).
class GradingWording {
  const GradingWording._();

  static const String title = 'AI-assisted quality grade recommendation';
  static const String standardsInformed =
      'STANDARDS-INFORMED QUALITY RECOMMENDATION';
  static const String humanVerificationRequired =
      'FINAL GRADE SUBJECT TO HUMAN VERIFICATION';
  static const String lotManualDecision =
      'HUMAN REVIEW REQUIRED FOR FINAL LOT DECISION';
  static const String noOfficialCertification =
      'GRADE A / GRADE B / URS are project operational categories. This is not an '
      'official AGMARK or PSF certification and not a regulatory decision.';
  static const String measuredEvidenceOnly =
      'The engine uses only the evidence this system measures: the detected bulb, '
      'the health classification and their confidences. Diameter, firmness, '
      'moisture, internal rot, stem or root length and exact defect percentages '
      'are NOT measured and are never claimed.';

  /// Reference context only — the product's own categories stay A / B / URS.
  static const List<String> referenceContext = <String>[
    'AGMARK onion reference: Extra Class, Class I, Class II (reference context only).',
    'PSF onion procurement norms: procurement characteristics and Grade-A defect limits (reference context only).',
  ];
}
