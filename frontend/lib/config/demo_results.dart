import 'package:flutter/foundation.dart';

import '../models/onion_observation.dart';
import 'grades.dart';

/// One bulb of a FIXED demonstration scenario.
///
/// Data provenance (kept honest and explicit):
/// * [bbox] / [detectionConfidence] were captured by the real YOLOv8n model
///   on the final bundled photograph at curation time, so the stored geometry
///   genuinely matches the photo.
/// * [health] / [confidence] are the scenario values defined by the product
///   specification. At curation time the real classifier's opinion was verified
///   to agree with every stored label for these exact boxes.
///
/// This data is NEVER presented as live model output: every surface labels it
/// DEMO MODE / FIXED DEMO SCENARIO.
@immutable
class DemoOnion {
  const DemoOnion({
    required this.id,
    required this.health,
    required this.confidence,
    required this.bbox,
    required this.detectionConfidence,
  });

  /// 1-based bulb number shown in the UI.
  final int id;

  /// Fixed scenario label: `Healthy` or `Unhealthy`.
  final String health;

  /// Fixed scenario health confidence (0..1).
  final double confidence;

  /// Stored geometry in bundled-photo pixel coordinates.
  final BoundingBox bbox;

  /// Detection confidence measured by YOLOv8n on the bundled photo (0..1).
  final double detectionConfidence;
}

/// One complete, ready-to-open demonstration scenario.
@immutable
class DemoScenario {
  const DemoScenario({
    required this.id,
    required this.asset,
    required this.title,
    required this.teaser,
    required this.imageWidth,
    required this.imageHeight,
    required this.totalOnions,
    required this.healthyCount,
    required this.unhealthyCount,
    required this.recommendedGrade,
    required this.observations,
    required this.onions,
    this.recommended = false,
  });

  /// Two-digit scenario number shown on the selection card (`01`…`04`).
  final String id;

  /// Asset key registered in `pubspec.yaml` (`assets/demo/`).
  final String asset;
  final String title;

  /// Short card teaser — describes the scenario, never its result.
  final String teaser;

  final int imageWidth;
  final int imageHeight;
  final int totalOnions;
  final int healthyCount;
  final int unhealthyCount;

  /// Fixed spec recommendation: GRADE A, GRADE B or URS.
  final String recommendedGrade;

  /// Quality observations shown on the results page and in the PDF.
  final List<String> observations;

  final List<DemoOnion> onions;

  /// Highlighted as the best sample for a live walkthrough.
  final bool recommended;

  /// Fixed demo results always carry this flag (`isDemo = true`).
  bool get isDemo => true;
}

/// The four prepared demonstration scenarios.
///
/// Selecting one NEVER calls `/api/analyze`: the result opens instantly from
/// this dataset, works with the backend completely offline, and always starts
/// with human verification in the PENDING state.
const List<DemoScenario> kDemoScenarios = <DemoScenario>[
  DemoScenario(
    id: '01',
    asset: 'assets/demo/demo_1.jpg',
    title: 'Mixed Surface Condition',
    teaser: 'Clustered onions with mixed surface condition.',
    imageWidth: 576,
    imageHeight: 768,
    totalOnions: 7,
    healthyCount: 5,
    unhealthyCount: 2,
    recommendedGrade: QualityGrade.gradeB,
    observations: <String>[
      'Clustered onion arrangement',
      'Visible surface variation',
      'Dark surface blemishes on some bulbs',
      'Moderate visible quality variation',
    ],
    onions: <DemoOnion>[
      DemoOnion(
        id: 1,
        health: OnionHealth.healthy,
        confidence: 0.96,
        bbox: BoundingBox(x1: 48, y1: 284, x2: 163, y2: 421),
        detectionConfidence: 0.7813,
      ),
      DemoOnion(
        id: 2,
        health: OnionHealth.healthy,
        confidence: 0.94,
        bbox: BoundingBox(x1: 244, y1: 162, x2: 367, y2: 308),
        detectionConfidence: 0.8353,
      ),
      DemoOnion(
        id: 3,
        health: OnionHealth.unhealthy,
        confidence: 0.91,
        bbox: BoundingBox(x1: 75, y1: 149, x2: 255, y2: 308),
        detectionConfidence: 0.6544,
      ),
      DemoOnion(
        id: 4,
        health: OnionHealth.healthy,
        confidence: 0.95,
        bbox: BoundingBox(x1: 286, y1: 282, x2: 456, y2: 443),
        detectionConfidence: 0.8673,
      ),
      DemoOnion(
        id: 5,
        health: OnionHealth.healthy,
        confidence: 0.93,
        bbox: BoundingBox(x1: 250, y1: 469, x2: 431, y2: 659),
        detectionConfidence: 0.5878,
      ),
      DemoOnion(
        id: 6,
        health: OnionHealth.unhealthy,
        confidence: 0.89,
        bbox: BoundingBox(x1: 136, y1: 269, x2: 293, y2: 451),
        detectionConfidence: 0.739,
      ),
      DemoOnion(
        id: 7,
        health: OnionHealth.healthy,
        confidence: 0.97,
        bbox: BoundingBox(x1: 402, y1: 365, x2: 576, y2: 557),
        detectionConfidence: 0.7629,
      ),
    ],
  ),
  DemoScenario(
    id: '02',
    asset: 'assets/demo/demo_2.jpg',
    title: 'High Variation Batch',
    teaser: 'Multiple onions with strong appearance variation.',
    imageWidth: 1024,
    imageHeight: 768,
    totalOnions: 8,
    healthyCount: 4,
    unhealthyCount: 4,
    recommendedGrade: QualityGrade.urs,
    observations: <String>[
      'Multiple onions',
      'Strong appearance variation',
      'Visible surface marks',
      'Outer-skin irregularities',
    ],
    onions: <DemoOnion>[
      DemoOnion(
        id: 1,
        health: OnionHealth.unhealthy,
        confidence: 0.88,
        bbox: BoundingBox(x1: 450, y1: 37, x2: 647, y2: 270),
        detectionConfidence: 0.8773,
      ),
      DemoOnion(
        id: 2,
        health: OnionHealth.healthy,
        confidence: 0.94,
        bbox: BoundingBox(x1: 236, y1: 25, x2: 447, y2: 235),
        detectionConfidence: 0.8596,
      ),
      DemoOnion(
        id: 3,
        health: OnionHealth.unhealthy,
        confidence: 0.91,
        bbox: BoundingBox(x1: 219, y1: 212, x2: 433, y2: 471),
        detectionConfidence: 0.8102,
      ),
      DemoOnion(
        id: 4,
        health: OnionHealth.healthy,
        confidence: 0.92,
        bbox: BoundingBox(x1: 912, y1: 0, x2: 1023, y2: 262),
        detectionConfidence: 0.5473,
      ),
      DemoOnion(
        id: 5,
        health: OnionHealth.unhealthy,
        confidence: 0.87,
        bbox: BoundingBox(x1: 488, y1: 257, x2: 717, y2: 475),
        detectionConfidence: 0.8109,
      ),
      DemoOnion(
        id: 6,
        health: OnionHealth.healthy,
        confidence: 0.95,
        bbox: BoundingBox(x1: 101, y1: 549, x2: 402, y2: 767),
        detectionConfidence: 0.7803,
      ),
      DemoOnion(
        id: 7,
        health: OnionHealth.unhealthy,
        confidence: 0.90,
        bbox: BoundingBox(x1: 338, y1: 406, x2: 542, y2: 633),
        detectionConfidence: 0.6502,
      ),
      DemoOnion(
        id: 8,
        health: OnionHealth.healthy,
        confidence: 0.93,
        bbox: BoundingBox(x1: 723, y1: 513, x2: 866, y2: 716),
        detectionConfidence: 0.5159,
      ),
    ],
    recommended: true,
  ),
  DemoScenario(
    id: '03',
    asset: 'assets/demo/demo_3.jpg',
    title: 'Relatively Clean Batch',
    teaser: 'Relatively uniform appearance with few visible defects.',
    imageWidth: 1024,
    imageHeight: 768,
    totalOnions: 7,
    healthyCount: 6,
    unhealthyCount: 1,
    recommendedGrade: QualityGrade.gradeA,
    observations: <String>[
      'Relatively uniform appearance',
      'Limited visible surface defects',
      'Stronger visible quality condition',
    ],
    onions: <DemoOnion>[
      DemoOnion(
        id: 1,
        health: OnionHealth.healthy,
        confidence: 0.98,
        bbox: BoundingBox(x1: 365, y1: 24, x2: 570, y2: 295),
        detectionConfidence: 0.4755,
      ),
      DemoOnion(
        id: 2,
        health: OnionHealth.healthy,
        confidence: 0.97,
        bbox: BoundingBox(x1: 363, y1: 25, x2: 692, y2: 318),
        detectionConfidence: 0.426,
      ),
      DemoOnion(
        id: 3,
        health: OnionHealth.healthy,
        confidence: 0.96,
        bbox: BoundingBox(x1: 458, y1: 30, x2: 702, y2: 318),
        detectionConfidence: 0.6538,
      ),
      DemoOnion(
        id: 4,
        health: OnionHealth.unhealthy,
        confidence: 0.86,
        bbox: BoundingBox(x1: 468, y1: 256, x2: 623, y2: 522),
        detectionConfidence: 0.3229,
      ),
      DemoOnion(
        id: 5,
        health: OnionHealth.healthy,
        confidence: 0.97,
        bbox: BoundingBox(x1: 250, y1: 170, x2: 497, y2: 417),
        detectionConfidence: 0.8674,
      ),
      DemoOnion(
        id: 6,
        health: OnionHealth.healthy,
        confidence: 0.98,
        bbox: BoundingBox(x1: 299, y1: 384, x2: 487, y2: 633),
        detectionConfidence: 0.5676,
      ),
      DemoOnion(
        id: 7,
        health: OnionHealth.healthy,
        confidence: 0.96,
        bbox: BoundingBox(x1: 622, y1: 319, x2: 840, y2: 527),
        detectionConfidence: 0.6711,
      ),
    ],
  ),
  DemoScenario(
    id: '04',
    asset: 'assets/demo/demo_4.jpg',
    title: 'Visible Defect Variation',
    teaser: 'Visible surface defects across a varied batch.',
    imageWidth: 1024,
    imageHeight: 768,
    totalOnions: 7,
    healthyCount: 3,
    unhealthyCount: 4,
    recommendedGrade: QualityGrade.gradeB,
    observations: <String>[
      'Multiple visible surface defects',
      'Strong appearance variation',
      'Useful scenario for human verification',
    ],
    onions: <DemoOnion>[
      DemoOnion(
        id: 1,
        health: OnionHealth.healthy,
        confidence: 0.95,
        bbox: BoundingBox(x1: 578, y1: 102, x2: 801, y2: 430),
        detectionConfidence: 0.7881,
      ),
      DemoOnion(
        id: 2,
        health: OnionHealth.unhealthy,
        confidence: 0.90,
        bbox: BoundingBox(x1: 421, y1: 73, x2: 579, y2: 269),
        detectionConfidence: 0.8292,
      ),
      DemoOnion(
        id: 3,
        health: OnionHealth.unhealthy,
        confidence: 0.92,
        bbox: BoundingBox(x1: 579, y1: 198, x2: 797, y2: 430),
        detectionConfidence: 0.823,
      ),
      DemoOnion(
        id: 4,
        health: OnionHealth.healthy,
        confidence: 0.94,
        bbox: BoundingBox(x1: 616, y1: 100, x2: 806, y2: 313),
        detectionConfidence: 0.5796,
      ),
      DemoOnion(
        id: 5,
        health: OnionHealth.unhealthy,
        confidence: 0.89,
        bbox: BoundingBox(x1: 332, y1: 262, x2: 611, y2: 569),
        detectionConfidence: 0.8234,
      ),
      DemoOnion(
        id: 6,
        health: OnionHealth.healthy,
        confidence: 0.96,
        bbox: BoundingBox(x1: 415, y1: 540, x2: 682, y2: 767),
        detectionConfidence: 0.7915,
      ),
      DemoOnion(
        id: 7,
        health: OnionHealth.unhealthy,
        confidence: 0.91,
        bbox: BoundingBox(x1: 660, y1: 369, x2: 914, y2: 631),
        detectionConfidence: 0.7915,
      ),
    ],
  ),
];

/// Builds the observation list for a scenario — every bulb starts in the
/// PENDING human-verification state (nothing is auto-verified).
List<OnionObservation> buildDemoObservations(DemoScenario scenario) =>
    <OnionObservation>[
      for (final onion in scenario.onions)
        OnionObservation(
          id: onion.id,
          bbox: onion.bbox,
          detectionConfidence: onion.detectionConfidence,
          aiHealth: onion.health,
          healthConfidence: onion.confidence,
        ),
    ];
