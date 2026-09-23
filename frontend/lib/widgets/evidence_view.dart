import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../models/onion_observation.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import 'status_widgets.dart';
import 'surfaces.dart';

/// Visual centrepiece of the results page.
///
/// The image shown is the annotated evidence image produced by the backend from
/// real YOLO detections; bounding boxes are never drawn or guessed on the
/// client. A transparent hit overlay maps the detection coordinates onto the
/// image so each bulb can be selected for review.
class EvidenceView extends StatefulWidget {
  const EvidenceView({
    super.key,
    required this.analysis,
    required this.originalBytes,
    required this.selectedId,
    required this.onSelect,
  });

  final AnalysisResult analysis;
  final Uint8List? originalBytes;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  @override
  State<EvidenceView> createState() => _EvidenceViewState();
}

class _EvidenceViewState extends State<EvidenceView> {
  bool _showAnnotated = true;

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;
    if (analysis.annotatedImage.isEmpty) {
      return const EmptyState(
        message: 'No evidence image was returned for this inspection.',
        icon: Icons.image_not_supported_outlined,
      );
    }

    final showAnnotated = _showAnnotated || widget.originalBytes == null;
    final bytes = showAnnotated ? analysis.annotatedImage : widget.originalBytes!;

    return PanelCard(
      label: 'Evidence image',
      trailing: widget.originalBytes == null
          ? null
          : SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Annotated')),
                ButtonSegment(value: false, label: Text('Original')),
              ],
              selected: {showAnnotated},
              showSelectedIcon: false,
              style: const ButtonStyle(
                textStyle: WidgetStatePropertyAll(
                  TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                visualDensity: VisualDensity.compact,
              ),
              onSelectionChanged: (selection) =>
                  setState(() => _showAnnotated = selection.first),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            showAnnotated
                ? 'Bounding boxes, bulb numbers and health state are produced by the '
                    'detection stage of the inspection pipeline.'
                : 'Original uploaded sample without AI annotations.',
            style: AppTypo.meta,
          ),
          const SizedBox(height: AppTheme.md),
          const _Legend(),
          const SizedBox(height: AppTheme.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: ColoredBox(
              color: AppTheme.charcoal,
              child: AspectRatio(
                aspectRatio: analysis.annotatedAspectRatio,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    return InteractiveViewer(
                      maxScale: 4,
                      minScale: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            bytes,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.medium,
                          ),
                          if (showAnnotated)
                            ..._buildHitAreas(analysis, width, height),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.s12),
          Row(
            children: [
              const Icon(Icons.zoom_in, size: 15, color: AppTheme.secondaryText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pinch or scroll to zoom. Select a bulb — on the image or in the '
                  'list — to review its observation.',
                  style: AppTypo.meta,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHitAreas(AnalysisResult analysis, double width, double height) {
    final imageWidth = analysis.imageWidth.toDouble();
    final imageHeight = analysis.imageHeight.toDouble();
    if (imageWidth <= 0 || imageHeight <= 0) return const [];

    return analysis.observations.map((observation) {
      final scaleX = width / imageWidth;
      final scaleY = height / imageHeight;
      final selected = observation.id == widget.selectedId;
      final colour =
          selected ? AppTheme.amber : OnionHealth.colourFor(observation.aiHealth);
      return Positioned(
        left: observation.bbox.x1 * scaleX,
        top: observation.bbox.y1 * scaleY,
        width: observation.bbox.width * scaleX,
        height: observation.bbox.height * scaleY,
        child: Tooltip(
          message: '${observation.displayLabel} · AI ${observation.aiHealth} '
              '${(observation.healthConfidence * 100).toStringAsFixed(1)}%',
          child: Semantics(
            button: true,
            label: '${observation.displayLabel}, AI observation '
                '${observation.aiHealth}, select for review',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSelect(observation.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: selected ? colour.withValues(alpha: 0.16) : Colors.transparent,
                  border: Border.all(
                    color: colour.withValues(alpha: selected ? 1 : 0.55),
                    width: selected ? 3 : 1.6,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(growable: false);
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.md,
      runSpacing: AppTheme.s8,
      children: const [
        StatusChip(
          label: 'Healthy',
          colour: AppTheme.healthy,
          icon: Icons.check_circle_outline,
        ),
        StatusChip(
          label: 'Unhealthy',
          colour: AppTheme.unhealthy,
          icon: Icons.error_outline,
        ),
        StatusChip(
          label: 'Selected',
          colour: AppTheme.amber,
          icon: Icons.center_focus_strong,
        ),
      ],
    );
  }
}

