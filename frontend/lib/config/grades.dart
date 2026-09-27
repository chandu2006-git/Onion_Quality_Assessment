/// Quality grade labels used across ONION DETECT.
///
/// Exactly three labels are supported: GRADE A, GRADE B and URS
/// (Under Relaxed Specifications). They are AI-assisted recommendation
/// labels that always require human verification — ONION DETECT never
/// certifies official grades and never introduces additional grades.
class QualityGrade {
  const QualityGrade._();

  static const String gradeA = 'GRADE A';
  static const String gradeB = 'GRADE B';
  static const String urs = 'URS';

  /// The complete set of supported labels.
  static const List<String> all = <String>[gradeA, gradeB, urs];

  /// Expansion shown next to URS (never any other expansion).
  static String expansionOf(String grade) =>
      grade == urs ? 'Under Relaxed Specifications' : '';

  static bool isValid(String grade) => all.contains(grade);

  /// Deterministic recommendation heuristic applied to REAL AI results.
  ///
  /// - healthy ratio ≥ 0.85 → GRADE A
  /// - healthy ratio ≥ 0.50 → GRADE B
  /// - otherwise → URS
  ///
  /// Returns `null` when no bulbs were assessed. This is a transparent,
  /// human-verifiable recommendation — NOT an official certification rule.
  /// Fixed demo scenarios carry their own spec-defined recommendation.
  static String? recommend({required int healthy, required int unhealthy}) {
    final total = healthy + unhealthy;
    if (total <= 0) return null;
    final ratio = healthy / total;
    if (ratio >= 0.85) return gradeA;
    if (ratio >= 0.50) return gradeB;
    return urs;
  }
}
