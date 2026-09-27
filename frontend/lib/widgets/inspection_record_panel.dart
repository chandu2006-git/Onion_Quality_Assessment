import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/inspection_session.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import 'status_widgets.dart';
import 'surfaces.dart';

/// Evidence-style summary of WHO inspected WHAT, WHERE and WITH WHICH MODELS.
///
/// Keeps user-entered metadata (inspector, batch, location) visually separate
/// from the AI section, and carries the `AI INFERENCE ACTIVE` and — for
/// illustrative locations — `PILOT DEMO` transparency chips.
class InspectionRecordPanel extends StatelessWidget {
  const InspectionRecordPanel({
    super.key,
    required this.session,
    this.modelInfo = const <String, String>{},
  });

  final InspectionSession session;

  /// Detector / classifier description reported by the analysis response.
  final Map<String, String> modelInfo;

  @override
  Widget build(BuildContext context) {
    final illustrative = AppConfig.isIllustrativeLocation(session.location);
    final detector = modelInfo['detector'] ?? 'YOLOv8n';
    final classifier = modelInfo['classifier'] ?? 'MobileNetV2';

    return PanelCard(
      label: 'Inspection record',
      trailing: Wrap(
        spacing: AppTheme.s8,
        runSpacing: AppTheme.s8,
        children: [
          const StatusChip(
            label: 'AI inference active',
            colour: AppTheme.healthy,
            icon: Icons.smart_toy_outlined,
          ),
          if (illustrative)
            const StatusChip(
              label: 'Pilot demo',
              colour: AppTheme.amberDark,
              icon: Icons.science_outlined,
            ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 640;
          final columnWidth =
              narrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 2;
          final rows = <List<(String, String)>>[
            [
              ('Inspection ID', session.id),
              ('Date & time', session.formattedTimestamp),
            ],
            [
              ('Inspector', session.inspector),
              ('Batch / Lot', session.batchLot),
            ],
            [
              (
                'Inspection location',
                '${session.location}${illustrative ? '  (Illustrative / Pilot Context)' : ''}',
              ),
              ('Sample file', session.sampleFileName ?? '—'),
            ],
            [
              ('Detection model', detector),
              ('Health classification model', classifier),
            ],
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.s12),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: AppTheme.s8,
                    children: [
                      for (final (label, value) in row)
                        SizedBox(
                          width: columnWidth,
                          child: _RecordValue(label: label, value: value),
                        ),
                    ],
                  ),
                ),
              const Divider(height: AppTheme.md, color: AppTheme.border),
              const Text(
                'AI measurements are recorded separately from human '
                    'verification; the final decision belongs to the inspector.',
                style: AppTypo.meta,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordValue extends StatelessWidget {
  const _RecordValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypo.label),
        const SizedBox(height: AppTheme.s4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.charcoal,
          ),
        ),
      ],
    );
  }
}