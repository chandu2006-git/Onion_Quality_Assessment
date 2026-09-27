import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/onion_observation.dart';
import '../theme/app_theme.dart';

/// Annotated evidence image rendered locally for a FIXED demo scenario.
class DemoEvidence {
  const DemoEvidence({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Renders the annotated evidence image for a fixed demonstration scenario.
///
/// The stored scenario boxes are drawn onto the bundled demo photograph
/// entirely on the client — no service, model or network request is involved.
/// A visible `DEMO MODE` mark is painted into the image so it can never be
/// mistaken for live model output. Returns `null` if rendering fails, in
/// which case the UI falls back to the original photograph.
Future<DemoEvidence?> renderDemoEvidence({
  required Uint8List imageBytes,
  required List<OnionObservation> observations,
}) async {
  try {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());

    final strokeWidth = (image.width * 0.005).clamp(2.0, 6.0);
    final fontSize = (image.width * 0.032).clamp(14.0, 42.0);
    final radius = Radius.circular((image.width * 0.008).clamp(3.0, 10.0));

    for (final observation in observations) {
      final colour = OnionHealth.colourFor(observation.aiHealth);
      final rect = Rect.fromLTRB(
        observation.bbox.x1.clamp(0.0, image.width.toDouble()).toDouble(),
        observation.bbox.y1.clamp(0.0, image.height.toDouble()).toDouble(),
        observation.bbox.x2.clamp(0.0, image.width.toDouble()).toDouble(),
        observation.bbox.y2.clamp(0.0, image.height.toDouble()).toDouble(),
      );
      if (rect.width < 2 || rect.height < 2) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = colour,
      );

      final label = observation.displayLabel;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: AppTheme.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pill = Rect.fromLTWH(
        rect.left,
        (rect.top - painter.height - 4).clamp(0.0, image.height.toDouble()),
        painter.width + fontSize * 0.8,
        painter.height + fontSize * 0.4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pill, radius),
        Paint()..color = colour.withValues(alpha: 0.92),
      );
      painter.paint(
        canvas,
        Offset(pill.left + fontSize * 0.4, pill.top + fontSize * 0.2),
      );
    }

    // Honesty mark: the image is always visibly a demo artefact.
    final demoStyle = TextStyle(
      color: AppTheme.white,
      fontSize: (image.width * 0.030).clamp(14.0, 40.0),
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    );
    final demoPainter = TextPainter(
      text: TextSpan(text: 'DEMO MODE', style: demoStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final markPad = fontSize * 0.5;
    final markRect = Rect.fromLTWH(
      image.width * 0.02,
      image.height - demoPainter.height - markPad * 2,
      demoPainter.width + markPad * 2,
      demoPainter.height + markPad,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(markRect, radius),
      Paint()..color = AppTheme.charcoal.withValues(alpha: 0.78),
    );
    demoPainter.paint(canvas, Offset(markRect.left + markPad, markRect.top + markPad * 0.4));

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(image.width, image.height);
    final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) return null;
    return DemoEvidence(
      bytes: png.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
  } catch (_) {
    // Any decode/encode failure simply falls back to the original photo.
    return null;
  }
}
