import 'package:flutter/material.dart';

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
  });

  /// 1-based bulb number assigned by the detection stage.
  final int id;
  final BoundingBox bbox;
  final double detectionConfidence;

  /// AI observation — never overwritten by a human decision.
  final String aiHealth;

  /// Confidence of the health classification — never overwritten.
  final double healthConfidence;

  VerificationOutcome verification;

  /// Inspector decision when the AI observation was overridden.
  String? humanDecision;

  String verificationNote;

  bool get isHealthyObservation => OnionHealth.isHealthy(aiHealth);
  bool get isReviewed => verification != VerificationOutcome.pending;

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

  factory OnionObservation.fromJson(Map<String, dynamic> json) => OnionObservation(
        id: (json['id'] as num).toInt(),
        bbox: BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>),
        detectionConfidence: (json['detection_confidence'] as num).toDouble(),
        aiHealth: json['health'] as String,
        healthConfidence: (json['health_confidence'] as num).toDouble(),
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
  Map<String, dynamic> toVerificationJson() => <String, dynamic>{
        'id': id,
        'ai_health': aiHealth,
        'health_confidence': healthConfidence,
        'detection_confidence': detectionConfidence,
        'verification_status': verification.wireValue,
        'human_decision': humanDecision,
        'verification_note': verificationNote.isEmpty ? null : verificationNote,
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
