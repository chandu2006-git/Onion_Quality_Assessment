import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/onion_observation.dart';
import '../theme/app_theme.dart';

/// Small cropped view of one detected bulb.
///
/// The thumbnail is rendered from the ORIGINAL sample image and the real YOLO
/// bounding box — nothing is fabricated on the client. Used in the
/// verification list and the onion detail panel.
class OnionCropThumb extends StatefulWidget {
  const OnionCropThumb({
    super.key,
    required this.imageBytes,
    required this.bbox,
    this.size = 56,
    this.borderColor,
  });

  /// Original uploaded sample (or any image in the same coordinates).
  final Uint8List? imageBytes;
  final BoundingBox bbox;
  final double size;
  final Color? borderColor;

  @override
  State<OnionCropThumb> createState() => _OnionCropThumbState();
}

class _OnionCropThumbState extends State<OnionCropThumb> {
  Future<ui.Image>? _decoded;

  @override
  void initState() {
    super.initState();
    _decoded = _decode();
  }

  @override
  void didUpdateWidget(covariant OnionCropThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) {
      _decoded = _decode();
    }
  }

  Future<ui.Image>? _decode() {
    final bytes = widget.imageBytes;
    if (bytes == null || bytes.isEmpty) return null;
    return ui.instantiateImageCodec(bytes).then((codec) async {
      final frame = await codec.getNextFrame();
      return frame.image;
    });
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.borderColor ?? AppTheme.border;
    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.offWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: borderColor),
      ),
      child: _decoded == null
          ? _placeholder()
          : FutureBuilder<ui.Image>(
              future: _decoded,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    !snapshot.hasData) {
                  if (snapshot.hasError) return _placeholder();
                  return const Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return CustomPaint(
                  size: Size.square(widget.size),
                  painter: _CropPainter(snapshot.data!, widget.bbox),
                );
              },
            ),
    );
  }

  Widget _placeholder() => Icon(
        Icons.crop_square,
        size: widget.size * 0.45,
        color: AppTheme.secondaryText,
      );
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.image, this.bbox);

  final ui.Image image;
  final BoundingBox bbox;

  @override
  void paint(Canvas canvas, Size size) {
    var x1 = bbox.x1.toDouble().clamp(0.0, image.width.toDouble());
    var y1 = bbox.y1.toDouble().clamp(0.0, image.height.toDouble());
    var x2 = bbox.x2.toDouble().clamp(0.0, image.width.toDouble());
    var y2 = bbox.y2.toDouble().clamp(0.0, image.height.toDouble());
    if (x2 - x1 < 1 || y2 - y1 < 1) {
      // Degenerate box: fall back to the whole image rather than failing.
      x1 = 0;
      y1 = 0;
      x2 = image.width.toDouble();
      y2 = image.height.toDouble();
    }
    final src = Rect.fromLTRB(x1, y1, x2, y2);
    // Cover-fit the detected box into the thumbnail frame.
    final scale = math.max(size.width / src.width, size.height / src.height);
    final dst = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: src.width * scale,
      height: src.height * scale,
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.bbox != bbox;
}
