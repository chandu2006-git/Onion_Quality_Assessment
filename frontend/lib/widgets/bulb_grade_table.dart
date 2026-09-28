import 'package:flutter/material.dart';

import '../config/grades.dart';
import '../config/grading_rules.dart';
import '../models/onion_observation.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import 'status_widgets.dart';
import 'surfaces.dart';

/// Colour used for a grade label (consistent across every grading surface).
Color gradeColourFor(String grade) {
  if (grade == QualityGrade.gradeA) return AppTheme.healthy;
  if (grade == QualityGrade.gradeB) return AppTheme.amberDark;
  if (grade == QualityGrade.urs) return AppTheme.unhealthy;
  return AppTheme.secondaryText;
}

/// Grade picker used by the bulb table and the lot panel.
///
/// Only the three supported operational grades are ever offered, with the URS
/// expansion shown explicitly. Returns the chosen grade, or `null` if cancelled.
Future<String?> pickGrade(
  BuildContext context, {
  String? recommended,
  String title = 'Choose the final grade',
}) async {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recommended == null
                ? 'Your grade is recorded as the final grade for this record.'
                : 'Your grade is recorded next to the AI recommendation '
                    '($recommended) — the recommendation itself is never '
                    'overwritten.',
            style: AppTypo.meta,
          ),
          const SizedBox(height: AppTheme.s12),
          ...QualityGrade.all.map(
            (option) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                Icons.circle,
                size: 14,
                color: gradeColourFor(option),
              ),
              title: Text(
                option,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: option == QualityGrade.urs
                  ? const Text(
                      'Under Relaxed Specifications',
                      style: AppTypo.meta,
                    )
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(option),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('CANCEL'),
        ),
      ],
    ),
  );
}

/// BULB-WISE QUALITY ASSESSMENT.
///
/// One record per detected bulb: health, confidence, the visible-quality
/// observation produced by the grading engine, the AI grade recommendation, the
/// final (human) grade and the CONFIRM / OVERRIDE actions.
class BulbGradeTable extends StatelessWidget {
  const BulbGradeTable({
    super.key,
    required this.observations,
    required this.onSelect,
    required this.onConfirmGrade,
    required this.onOverrideGrade,
    required this.onClearGrade,
    required this.onConfirmAll,
    this.selectedId,
  });

  final List<OnionObservation> observations;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  final void Function(int id) onConfirmGrade;
  final void Function(int id, String grade) onOverrideGrade;
  final void Function(int id) onClearGrade;

  /// Accepts every remaining recommendation (convenience action).
  final VoidCallback onConfirmAll;

  int get _pendingCount =>
      observations.where((item) => !item.gradeDecided).length;

  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) {
      return const PanelCard(
        label: 'Bulb-wise quality assessment',
        child: EmptyState(
          message: 'No onion bulbs were detected in this image.',
          icon: Icons.sentiment_dissatisfied_outlined,
        ),
      );
    }
    return PanelCard(
      label: 'Bulb-wise quality assessment',
      trailing: StatusChip(
        label: _pendingCount == 0
            ? 'All ${observations.length} grades decided'
            : '${observations.length - _pendingCount} of ${observations.length} decided',
        colour: _pendingCount == 0 ? AppTheme.healthy : AppTheme.amberDark,
        icon: _pendingCount == 0
            ? Icons.how_to_reg_outlined
            : Icons.pending_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${GradingWording.standardsInformed} · '
            '${GradingWording.humanVerificationRequired}',
            style: AppTypo.label.copyWith(color: AppTheme.secondaryGreen),
          ),
          const SizedBox(height: AppTheme.s8),
          Text(GradingWording.measuredEvidenceOnly, style: AppTypo.meta),
          const SizedBox(height: AppTheme.md),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 960) {
                return BulbGradeGrid(
                  observations: observations,
                  selectedId: selectedId,
                  onSelect: onSelect,
                  onConfirmGrade: onConfirmGrade,
                  onOverrideGrade: onOverrideGrade,
                  onClearGrade: onClearGrade,
                );
              }
              return Column(
                children: [
                  for (final observation in observations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.s12),
                      child: BulbGradeCard(
                        observation: observation,
                        selected: observation.id == selectedId,
                        onSelect: onSelect,
                        onConfirmGrade: onConfirmGrade,
                        onOverrideGrade: onOverrideGrade,
                        onClearGrade: onClearGrade,
                      ),
                    ),
                ],
              );
            },
          ),
          if (_pendingCount > 0) ...[
            const SizedBox(height: AppTheme.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onConfirmAll,
                icon: const Icon(Icons.done_all, size: 16),
                label: Text('CONFIRM ALL RECOMMENDATIONS ($_pendingCount)'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact per-bulb grade actions shared by the table and the card layout.
class BulbGradeActions extends StatelessWidget {
  const BulbGradeActions({
    super.key,
    required this.observation,
    required this.onConfirmGrade,
    required this.onOverrideGrade,
    required this.onClearGrade,
  });

  final OnionObservation observation;
  final void Function(int id) onConfirmGrade;
  final void Function(int id, String grade) onOverrideGrade;
  final void Function(int id) onClearGrade;

  static ButtonStyle _compactFilled() => FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 34),
        textStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );

  static ButtonStyle _compactOutlined() => OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 34),
        textStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );

  Future<void> _chooseGrade(BuildContext context) async {
    final grade = await pickGrade(
      context,
      recommended: observation.recommendedGrade,
      title: '${observation.displayLabel} — final grade',
    );
    if (grade != null) onOverrideGrade(observation.id, grade);
  }

  @override
  Widget build(BuildContext context) {
    if (!observation.gradeDecided) {
      return Wrap(
        spacing: AppTheme.s8,
        runSpacing: AppTheme.s8,
        children: [
          FilledButton(
            onPressed: () => onConfirmGrade(observation.id),
            style: _compactFilled(),
            child: const Text('CONFIRM'),
          ),
          OutlinedButton(
            onPressed: () => _chooseGrade(context),
            style: _compactOutlined(),
            child: const Text('OVERRIDE'),
          ),
        ],
      );
    }
    final finalGrade = observation.finalGrade ?? '';
    return Wrap(
      spacing: AppTheme.s8,
      runSpacing: AppTheme.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(
          label: observation.gradeDecisionLabel,
          colour: observation.gradeDecision == BulbGradeDecision.overridden
              ? AppTheme.amberDark
              : AppTheme.healthy,
          icon: observation.gradeDecision == BulbGradeDecision.overridden
              ? Icons.compare_arrows
              : Icons.verified_outlined,
        ),
        StatusChip(label: finalGrade, colour: gradeColourFor(finalGrade)),
        OutlinedButton(
          onPressed: () => _chooseGrade(context),
          style: _compactOutlined(),
          child: const Text('CHANGE'),
        ),
        TextButton(
          onPressed: () => onClearGrade(observation.id),
          child: const Text('CLEAR', style: TextStyle(fontSize: 11.5)),
        ),
      ],
    );
  }
}

/// Wide-screen presentation: a proper bulb-wise table.
class BulbGradeGrid extends StatelessWidget {
  const BulbGradeGrid({
    super.key,
    required this.observations,
    required this.onSelect,
    required this.onConfirmGrade,
    required this.onOverrideGrade,
    required this.onClearGrade,
    this.selectedId,
  });

  final List<OnionObservation> observations;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  final void Function(int id) onConfirmGrade;
  final void Function(int id, String grade) onOverrideGrade;
  final void Function(int id) onClearGrade;

  static const List<String> headers = <String>[
    'BULB',
    'HEALTH',
    'CONF.',
    'QUALITY OBSERVATION',
    'AI GRADE',
    'FINAL GRADE',
    'DECISION / ACTIONS',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const <int, TableColumnWidth>{
          0: FlexColumnWidth(0.8),
          1: FlexColumnWidth(1.0),
          2: FlexColumnWidth(0.7),
          3: FlexColumnWidth(3.0),
          4: FlexColumnWidth(1.1),
          5: FlexColumnWidth(1.1),
          6: FlexColumnWidth(2.6),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(color: AppTheme.border, width: 0.6),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: <TableRow>[
          TableRow(
            decoration: const BoxDecoration(color: AppTheme.offWhite),
            children: <Widget>[
              for (final header in headers) _HeaderCell(label: header),
            ],
          ),
          for (final observation in observations)
            TableRow(
              decoration: BoxDecoration(
                color: observation.id == selectedId
                    ? AppTheme.lightGreen
                    : AppTheme.white,
              ),
              children: <Widget>[
                _BodyCell(
                  child: InkWell(
                    onTap: () => onSelect(observation.id),
                    child: Text(
                      '#${observation.id.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                _BodyCell(
                  child: Text(
                    observation.aiHealth,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: OnionHealth.colourFor(observation.aiHealth),
                    ),
                  ),
                ),
                _BodyCell(
                  child: Text(
                    '${(observation.healthConfidence * 100).round()}%',
                    style: AppTypo.meta,
                  ),
                ),
                _BodyCell(
                  child:
                      Text(observation.qualityObservation, style: AppTypo.meta),
                ),
                _BodyCell(
                  child: GradeCell(
                    grade: observation.recommendedGrade,
                    requiresReview: observation.gradeRequiresHumanReview,
                  ),
                ),
                _BodyCell(child: FinalGradeCell(observation: observation)),
                _BodyCell(
                  child: BulbGradeActions(
                    observation: observation,
                    onConfirmGrade: onConfirmGrade,
                    onOverrideGrade: onOverrideGrade,
                    onClearGrade: onClearGrade,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.s12,
        vertical: AppTheme.s8,
      ),
      child: Text(label, style: AppTypo.label),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.s12,
        vertical: AppTheme.s8,
      ),
      child: child,
    );
  }
}

/// AI grade cell: the recommendation plus an explicit review note when the
/// engine could not grade the bulb from the measured evidence.
class GradeCell extends StatelessWidget {
  const GradeCell({
    super.key,
    required this.grade,
    required this.requiresReview,
  });

  final String grade;
  final bool requiresReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          grade,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: gradeColourFor(grade),
          ),
        ),
        if (requiresReview) ...[
          const SizedBox(height: 2),
          Text(
            'Evidence insufficient — inspector decides.',
            style: AppTypo.meta,
          ),
        ],
      ],
    );
  }
}

/// Final (human) grade cell. `PENDING` until the inspector decides.
class FinalGradeCell extends StatelessWidget {
  const FinalGradeCell({super.key, required this.observation});

  final OnionObservation observation;

  @override
  Widget build(BuildContext context) {
    if (!observation.gradeDecided) {
      return Text(
        'PENDING',
        style: AppTypo.meta.copyWith(
          color: AppTheme.amberDark,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final finalGrade = observation.finalGrade ?? '—';
    return Text(
      finalGrade,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
        color: gradeColourFor(finalGrade),
      ),
    );
  }
}

/// Narrow-screen presentation: one card per bulb.
class BulbGradeCard extends StatelessWidget {
  const BulbGradeCard({
    super.key,
    required this.observation,
    required this.selected,
    required this.onSelect,
    required this.onConfirmGrade,
    required this.onOverrideGrade,
    required this.onClearGrade,
  });

  final OnionObservation observation;
  final bool selected;
  final ValueChanged<int?> onSelect;
  final void Function(int id) onConfirmGrade;
  final void Function(int id, String grade) onOverrideGrade;
  final void Function(int id) onClearGrade;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelect(observation.id),
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.s16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lightGreen : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(
            color: selected ? AppTheme.secondaryGreen : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  observation.displayLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.s8),
                StatusChip(
                  label: observation.aiHealth,
                  colour: OnionHealth.colourFor(observation.aiHealth),
                ),
                const Spacer(),
                StatusChip(
                  label:
                      '${(observation.healthConfidence * 100).round()}% conf.',
                  colour: AppTheme.secondaryText,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.s8),
            Text(observation.qualityObservation, style: AppTypo.meta),
            const SizedBox(height: AppTheme.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI GRADE', style: AppTypo.label),
                      GradeCell(
                        grade: observation.recommendedGrade,
                        requiresReview: observation.gradeRequiresHumanReview,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FINAL GRADE (HUMAN)', style: AppTypo.label),
                      FinalGradeCell(observation: observation),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.s12),
            BulbGradeActions(
              observation: observation,
              onConfirmGrade: onConfirmGrade,
              onOverrideGrade: onOverrideGrade,
              onClearGrade: onClearGrade,
            ),
          ],
        ),
      ),
    );
  }
}

/// QUALITY GRADE DISTRIBUTION / FINAL VERIFIED DISTRIBUTION.
///
/// Every count is derived from the bulb records through [distribution], so the
/// panel changes the moment an inspector confirms or overrides a bulb.
class GradeDistributionPanel extends StatelessWidget {
  const GradeDistributionPanel({
    super.key,
    required this.title,
    required this.distribution,
    this.subtitle,
    this.footnote,
  });

  final String title;
  final LotGradeDistribution distribution;
  final String? subtitle;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null) ...[
            Text(subtitle!, style: AppTypo.meta),
            const SizedBox(height: AppTheme.md),
          ],
          for (final (label, count) in distribution.entries)
            DistributionRow(
              label: label,
              count: count,
              share: distribution.shareOf(count),
            ),
          if (distribution.pending > 0)
            DistributionRow(
              label: 'AWAITING GRADE DECISION',
              count: distribution.pending,
              share: 0,
              note: distribution.requiresReview > 0
                  ? '${distribution.requiresReview} bulb(s) need human review '
                      '(evidence insufficient for an automatic grade).'
                  : null,
            ),
          const Divider(height: AppTheme.lg, color: AppTheme.border),
          Row(
            children: [
              Text('TOTAL', style: AppTypo.label),
              const Spacer(),
              Text(
                '${distribution.total} bulb(s)',
                style: AppTypo.label.copyWith(color: AppTheme.primary),
              ),
            ],
          ),
          if (footnote != null) ...[
            const SizedBox(height: AppTheme.s8),
            Text(footnote!, style: AppTypo.meta),
          ],
        ],
      ),
    );
  }
}

/// One distribution row: label, count, share and a share bar.
class DistributionRow extends StatelessWidget {
  const DistributionRow({
    super.key,
    required this.label,
    required this.count,
    required this.share,
    this.note,
  });

  final String label;
  final int count;
  final double share;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colour = gradeColourFor(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTheme.s8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ).copyWith(color: colour),
                ),
              ),
              Text('$count bulb(s)', style: AppTypo.meta),
              const SizedBox(width: AppTheme.s12),
              Text(
                '${(share * 100).round()}%',
                style: AppTypo.meta.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ProgressLine(value: share, height: 6),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: AppTypo.meta),
          ],
        ],
      ),
    );
  }
}
