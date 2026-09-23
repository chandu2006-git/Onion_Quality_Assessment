import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ONION DETECT wordmark.
///
/// A minimal onion glyph drawn with a painter (no image asset required), so the
/// mark is crisp in the header, in the footer and inside the PDF branding.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.onDark = false,
    this.compact = false,
  });

  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? AppTheme.white : AppTheme.primary;
    final accent = onDark ? AppTheme.lightGreen : AppTheme.secondaryGreen;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: compact ? 24 : 28,
          height: compact ? 24 : 28,
          child: CustomPaint(
            painter: _OnionGlyphPainter(colour: foreground, accent: accent),
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ONION DETECT',
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: foreground,
                height: 1.1,
              ),
            ),
            if (!compact)
              Text(
                'AI-ASSISTED INSPECTION',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: accent,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _OnionGlyphPainter extends CustomPainter {
  const _OnionGlyphPainter({required this.colour, required this.accent});

  final Color colour;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * 0.60);
    final radius = size.width * 0.36;
    final bodyPaint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(centre, radius, bodyPaint);

    final inner = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius * 0.62),
      -3.1,
      3.6,
      false,
      inner,
    );

    final stalkPaint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    final tip = Offset(size.width / 2, size.height * 0.10);
    canvas.drawLine(Offset(centre.dx, centre.dy - radius), tip, stalkPaint);
    canvas.drawLine(tip, Offset(size.width * 0.30, size.height * 0.26), stalkPaint);
    canvas.drawLine(tip, Offset(size.width * 0.70, size.height * 0.26), stalkPaint);
  }

  @override
  bool shouldRepaint(covariant _OnionGlyphPainter oldDelegate) =>
      oldDelegate.colour != colour || oldDelegate.accent != accent;
}
