import 'package:flutter/foundation.dart';

/// One bundled, one-click demo sample for the capture page.
///
/// Selecting a demo loads the bundled photograph into the EXISTING sample
/// pipeline (`setSample` → `analyzeSample` → `POST /api/analyze`), so the
/// analysis always runs through the real YOLOv8n + MobileNetV2 models. Nothing
/// about the expected output is stored or assumed here — only the asset path
/// and human-readable description.
@immutable
class DemoSample {
  const DemoSample({
    required this.asset,
    required this.title,
    required this.description,
    this.recommended = false,
  });

  /// Asset key registered in `pubspec.yaml` (`assets/demo/`).
  final String asset;
  final String title;
  final String description;

  /// Highlighted as the best sample for a live walkthrough.
  final bool recommended;
}

/// The three demo samples offered on the capture page.
const List<DemoSample> kDemoSamples = <DemoSample>[
  DemoSample(
    asset: 'assets/demo/demo_single_onion.jpg',
    title: 'Single Onion',
    description: 'Healthy sample — one bulb on a neutral background.',
  ),
  DemoSample(
    asset: 'assets/demo/demo_multiple_onions.jpg',
    title: 'Multiple Onions',
    description: 'Batch inspection sample — a full basket of bulbs.',
    recommended: true,
  ),
  DemoSample(
    asset: 'assets/demo/demo_quality_variation.jpg',
    title: 'Quality Variation',
    description: 'Mixed-condition sample with visibly varied bulb surfaces.',
  ),
];