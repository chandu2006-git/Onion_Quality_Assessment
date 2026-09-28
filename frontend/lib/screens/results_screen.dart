import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/grades.dart';
import '../config/grading_rules.dart';
import '../models/analysis_result.dart';
import '../models/inspection_session.dart';
import '../models/onion_observation.dart';
import '../providers/inspection_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../widgets/app_shell.dart';
import '../widgets/bulb_grade_table.dart';
import '../widgets/evidence_view.dart';
import '../widgets/feedback.dart';
import '../widgets/inspection_record_panel.dart';
import '../widgets/inspection_status_strip.dart';
import '../widgets/onion_detail_panel.dart';
import '../widgets/onion_verification_tile.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/status_widgets.dart';
import '../widgets/surfaces.dart';

/// Page 4 - inspection results and human verification of AI observations.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionProvider);
    final session = state.session;

    if (session == null || session.analysis == null) {
      return AppShell(
        child: ContentContainer(
          maxWidth: 880,
          child: EmptyState(
            message: 'No inspection result is available for this session.',
            icon: Icons.analytics_outlined,
            action: FilledButton(
              onPressed: () => context.go('/capture'),
              child: const Text('RETURN TO CAPTURE'),
            ),
          ),
        ),
      );
    }

    final analysis = session.analysis!;
    final observations = session.observations;
    final selectedId = state.selectedOnionId;

    return AppShell(
      child: SingleChildScrollView(
        child: ContentContainer(
          maxWidth: AppTheme.maxContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResultsHeader(
                session: session,
                total: analysis.totalOnions,
                healthy: analysis.healthyCount,
                unhealthy: analysis.unhealthyCount,
              ),
              const SizedBox(height: AppTheme.md),
              InspectionStatusStrip.forResults(
                verificationPending: session.pendingCount > 0,
                reportReady: state.reportNotice != null,
              ),
              const SizedBox(height: AppTheme.xl),
              InspectionRecordPanel(
                session: session,
                modelInfo: analysis.modelInfo,
              ),
              const SizedBox(height: AppTheme.xl),
              _SummaryCards(
                total: analysis.totalOnions,
                healthy: analysis.healthyCount,
                unhealthy: analysis.unhealthyCount,
                session: session,
              ),
              const SizedBox(height: AppTheme.xl),
              // BULB-WISE QUALITY ASSESSMENT — one record per detected bulb.
              BulbGradeTable(
                observations: observations,
                selectedId: selectedId,
                onSelect: ref.read(inspectionProvider.notifier).selectOnion,
                onConfirmGrade:
                    ref.read(inspectionProvider.notifier).confirmBulbGrade,
                onOverrideGrade:
                    ref.read(inspectionProvider.notifier).overrideBulbGrade,
                onClearGrade: ref
                    .read(inspectionProvider.notifier)
                    .clearBulbGradeDecision,
                onConfirmAll: ref
                    .read(inspectionProvider.notifier)
                    .confirmAllPendingGrades,
              ),
              const SizedBox(height: AppTheme.xl),
              // QUALITY GRADE DISTRIBUTION — computed from the bulb records.
              GradeDistributionPanel(
                title: 'Quality grade distribution',
                subtitle:
                    'Counts are computed from the bulb records above and update '
                    'the moment a single bulb is confirmed or overridden.',
                distribution: session.gradeDistribution,
                footnote: session.pendingGradeCount == 0
                    ? 'All ${session.totalCount} bulb(s) carry a recorded grade.'
                    : '${session.pendingGradeCount} of ${session.totalCount} '
                        'bulb(s) still await a grade decision.',
              ),
              const SizedBox(height: AppTheme.xl),
              _GradePanel(
                session: session,
                analysis: analysis,
                onConfirm: ref.read(inspectionProvider.notifier).confirmGrade,
                onOverride:
                    ref.read(inspectionProvider.notifier).overrideGradeWith,
                onClear:
                    ref.read(inspectionProvider.notifier).clearGradeDecision,
              ),
              const SizedBox(height: AppTheme.xl),
              _EvidenceSection(
                analysis: analysis,
                originalBytes: session.sampleBytes,
                selectedId: selectedId,
                onSelect: ref.read(inspectionProvider.notifier).selectOnion,
              ),
              const SizedBox(height: AppTheme.xl),
              OnionDetailPanel(
                observation: session.observationById(selectedId),
                sampleBytes: session.sampleBytes,
                isDemo: session.isDemo,
                onConfirmAi: () {
                  final id = selectedId;
                  if (id != null) {
                    ref.read(inspectionProvider.notifier).confirmAiObservation(id);
                  }
                },
                onOverride: () {
                  final id = selectedId;
                  if (id == null) return;
                  final observation = session.observationById(id);
                  if (observation == null) return;
                  ref.read(inspectionProvider.notifier).overrideObservation(
                        id,
                        observation.isHealthyObservation
                            ? OnionHealth.unhealthy
                            : OnionHealth.healthy,
                      );
                },
                onClearReview: () {
                  final id = selectedId;
                  if (id != null) {
                    ref.read(inspectionProvider.notifier).clearReview(id);
                  }
                },
              ),
              const SizedBox(height: AppTheme.xl),
              _VerificationSection(
                session: session,
                observations: observations,
                selectedId: selectedId,
                onSelect: ref.read(inspectionProvider.notifier).selectOnion,
                onConfirmAi:
                    ref.read(inspectionProvider.notifier).confirmAiObservation,
                onOverride:
                    ref.read(inspectionProvider.notifier).overrideObservation,
                onClear: ref.read(inspectionProvider.notifier).clearReview,
              ),
              const SizedBox(height: AppTheme.xl),
              // FINAL VERIFIED DISTRIBUTION — the grades the inspector recorded.
              GradeDistributionPanel(
                title: 'Final verified distribution',
                subtitle:
                    'Grades recorded by the inspector. Health verification: '
                    '${session.reviewedCount} of ${session.totalCount} bulb(s) '
                    'reviewed · AI–human mismatches: ${session.mismatchCount}.',
                distribution: session.gradeDistribution,
                footnote:
                    '${GradingWording.humanVerificationRequired} · '
                    '${GradingWording.lotManualDecision}',
              ),
              if (analysis.hasDetections) ...[
                const SizedBox(height: AppTheme.xl),
                _FinalizeSection(
                  session: session,
                  generating: state.generatingReport,
                  reportError: state.reportError,
                  reportNotice: state.reportNotice,
                  onGenerate:
                      ref.read(inspectionProvider.notifier).generateReport,
                  onConfirmAllGrades: ref
                      .read(inspectionProvider.notifier)
                      .confirmAllPendingGrades,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.session,
    required this.total,
    required this.healthy,
    required this.unhealthy,
  });

  final InspectionSession session;
  final int total;
  final int healthy;
  final int unhealthy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: 'Inspection results',
          subtitle: session.isDemo
              ? 'Fixed demonstration scenario — stored detection evidence '
                  'awaiting human verification; no AI inference ran for this '
                  'result.'
              : 'Every value below was produced by the AI pipeline and is '
                  'awaiting (or has received) human verification.',
        ),
        const SizedBox(height: AppTheme.s12),
        Wrap(
          spacing: AppTheme.s12,
          runSpacing: AppTheme.s8,
          children: [
            StatusChip(label: session.id, colour: AppTheme.primary),
            StatusChip(label: session.inspector, colour: AppTheme.secondaryGreen),
            StatusChip(label: session.location, colour: AppTheme.secondaryGreen),
            StatusChip(label: session.batchLot, colour: AppTheme.secondaryGreen),
            StatusChip(
              label: session.isDemo ? 'Demo mode' : 'AI inference active',
              colour: session.isDemo ? AppTheme.amberDark : AppTheme.healthy,
              icon: session.isDemo
                  ? Icons.dataset_outlined
                  : Icons.smart_toy_outlined,
            ),
            StatusChip(label: session.formattedTimestamp, colour: AppTheme.charcoal),
          ],
        ),
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.total,
    required this.healthy,
    required this.unhealthy,
    required this.session,
  });

  final int total;
  final int healthy;
  final int unhealthy;
  final InspectionSession session;

  @override
  Widget build(BuildContext context) {
    final denom = total == 0 ? 1 : total;
    final healthyPct = (healthy / denom * 100).toStringAsFixed(0);
    final unhealthyPct = (unhealthy / denom * 100).toStringAsFixed(0);
    return ResponsiveCardGrid(
      minCardWidth: 200,
      maxColumns: 4,
      children: [
        MetricCard(
          value: total.toString(),
          title: 'TOTAL ONIONS',
          description: 'Detected by YOLOv8n',
          icon: Icons.analytics,
          valueColour: AppTheme.primary,
        ),
        MetricCard(
          value: healthy.toString(),
          title: 'HEALTHY',
          description: '$healthyPct% of sample',
          icon: Icons.check_circle_outline,
          valueColour: AppTheme.healthy,
        ),
        MetricCard(
          value: unhealthy.toString(),
          title: 'UNHEALTHY',
          description: '$unhealthyPct% of sample',
          icon: Icons.error_outline,
          valueColour: AppTheme.unhealthy,
        ),
        MetricCard(
          value: '${session.reviewedCount}/${session.totalCount}',
          title: 'REVIEWED',
          description: 'Human verification required',
          icon: Icons.fact_check_outlined,
          valueColour: session.allReviewed ? AppTheme.secondaryGreen : AppTheme.amberDark,
        ),
      ],
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
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
  Widget build(BuildContext context) {
    return EvidenceView(
      analysis: analysis,
      originalBytes: originalBytes,
      selectedId: selectedId,
      onSelect: onSelect,
    );
  }
}


class _VerificationSection extends StatelessWidget {
  const _VerificationSection({
    required this.session,
    required this.observations,
    required this.selectedId,
    required this.onSelect,
    required this.onConfirmAi,
    required this.onOverride,
    required this.onClear,
  });

  final InspectionSession session;
  final List<OnionObservation> observations;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  final void Function(int id) onConfirmAi;
  final void Function(int id, String decision) onOverride;
  final void Function(int id) onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _VerificationHeader(),
        const SizedBox(height: AppTheme.md),
        if (observations.isEmpty)
          const EmptyState(
            message: 'No onion bulbs were detected in this image.',
            icon: Icons.sentiment_dissatisfied_outlined,
          )
        else
          _VerificationList(
            observations: observations,
            sampleBytes: session.sampleBytes,
            selectedId: selectedId,
            onSelect: onSelect,
            onConfirmAi: onConfirmAi,
            onOverride: onOverride,
            onClear: onClear,
          ),
        const SizedBox(height: AppTheme.md),
        _VerificationProgress(session: session),
      ],
    );
  }
}

class _VerificationHeader extends StatelessWidget {
  const _VerificationHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('HUMAN VERIFICATION', style: AppTypo.label),
        SizedBox(height: AppTheme.s4),
        Text(
          'Review the AI observations before finalizing the inspection report.',
          style: AppTypo.body,
        ),
      ],
    );
  }
}


class _VerificationList extends StatelessWidget {
  const _VerificationList({
    required this.observations,
    required this.sampleBytes,
    required this.selectedId,
    required this.onSelect,
    required this.onConfirmAi,
    required this.onOverride,
    required this.onClear,
  });

  final List<OnionObservation> observations;
  final Uint8List? sampleBytes;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  final void Function(int id) onConfirmAi;
  final void Function(int id, String decision) onOverride;
  final void Function(int id) onClear;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: observations.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.s12),
      itemBuilder: (_, index) {
        final observation = observations[index];
        return OnionVerificationTile(
          observation: observation,
          sampleBytes: sampleBytes,
          selected: observation.id == selectedId,
          onSelect: () => onSelect(observation.id),
          onConfirmAi: () => onConfirmAi(observation.id),
          onOverride: () => onOverride(
            observation.id,
            observation.isHealthyObservation
                ? OnionHealth.unhealthy
                : OnionHealth.healthy,
          ),
          onClearReview: () => onClear(observation.id),
        );
      },
    );
  }
}

class _VerificationProgress extends StatelessWidget {
  const _VerificationProgress({required this.session});

  final InspectionSession session;

  @override
  Widget build(BuildContext context) {
    final total = session.totalCount;
    final reviewed = session.reviewedCount;
    final progress = total == 0 ? 0.0 : reviewed / total;
    final complete = total > 0 && reviewed == total;
    return PanelCard(
      label: 'Verification summary',
      borderColour: complete ? AppTheme.secondaryGreen : AppTheme.amber,
      trailing: StatusChip(
        label: complete ? 'Verified · 100%' : 'Verification pending',
        colour: complete ? AppTheme.healthy : AppTheme.amberDark,
        icon: complete ? Icons.verified_outlined : Icons.schedule,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppTheme.xl,
            runSpacing: AppTheme.md,
            children: [
              _Stat(value: '${session.totalCount}', label: 'Total inspected'),
              _Stat(
                value: '${session.confirmedCount}',
                label: 'AI confirmed',
                valueColour: AppTheme.secondaryGreen,
              ),
              _Stat(
                value: '${session.mismatchCount}',
                label: 'AI–Human mismatches',
                valueColour: session.mismatchCount > 0
                    ? AppTheme.amberDark
                    : AppTheme.secondaryText,
              ),
              _Stat(
                value: '$reviewed / $total',
                label: 'Human verified',
                valueColour: complete ? AppTheme.secondaryGreen : AppTheme.amberDark,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          Row(
            children: [
              Text('$reviewed of $total onions reviewed', style: AppTypo.body),
              const Spacer(),
              Text('${(progress * 100).toStringAsFixed(0)}%', style: AppTypo.body),
            ],
          ),
          const SizedBox(height: AppTheme.s8),
          ProgressLine(value: progress),
          const SizedBox(height: AppTheme.md),
          Wrap(
            spacing: AppTheme.s12,
            runSpacing: AppTheme.s8,
            children: [
              StatusChip(
                  label: 'Pending ${session.pendingCount}',
                  colour: AppTheme.amber),
              StatusChip(
                  label: 'Confirmed ${session.confirmedCount}',
                  colour: AppTheme.healthy),
              StatusChip(
                  label: 'Overridden ${session.overriddenCount}',
                  colour: AppTheme.amberDark),
              if (session.mismatchCount > 0)
                StatusChip(
                    label: 'AI–human mismatch ${session.mismatchCount}',
                    colour: AppTheme.amberDark,
                    icon: Icons.compare_arrows),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          Text(
            complete
                ? 'All bulbs reviewed. AI observations stay preserved next to '
                    'the human decisions in the report.'
                : 'Verification pending — the report cannot be generated until '
                    'every bulb has been reviewed. Progress reflects reviewed '
                    'bulbs only.',
            style: AppTypo.meta,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.valueColour = AppTheme.primary,
  });

  final String value;
  final String label;
  final Color valueColour;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: valueColour,
          ),
        ),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: AppTypo.label),
      ],
    );
  }
}


class _FinalizeSection extends StatelessWidget {
  const _FinalizeSection({
    required this.session,
    required this.generating,
    required this.reportError,
    required this.reportNotice,
    required this.onGenerate,
    required this.onConfirmAllGrades,
  });

  final InspectionSession session;
  final bool generating;
  final String? reportError;
  final String? reportNotice;
  final Future<void> Function() onGenerate;

  /// Accepts every remaining grade recommendation (unblocks the report).
  final VoidCallback onConfirmAllGrades;

  @override
  Widget build(BuildContext context) {
    // The report is only generated once every bulb has both a health
    // verification and a recorded grade decision, so the PDF can always print
    // the complete bulb-wise quality table.
    final canGenerate = session.allReviewed &&
        session.allGradesDecided &&
        !generating &&
        reportError == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reportNotice != null) ...[
          InfoBanner(
            title: 'Report ready',
            severity: BannerSeverity.success,
            message: reportNotice!,
          ),
          const SizedBox(height: AppTheme.md),
        ],
        if (reportError != null) ...[
          InfoBanner(
            title: 'Report could not be generated',
            severity: BannerSeverity.error,
            message: reportError!,
          ),
          const SizedBox(height: AppTheme.md),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canGenerate ? onGenerate : null,
            icon: generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(generating
                ? 'GENERATING REPORT…'
                : 'CONFIRM INSPECTION & GENERATE REPORT'),
          ),
        ),
        const SizedBox(height: AppTheme.s8),
        Text(
          session.allGradesDecided && session.allReviewed
              ? 'All ${session.totalCount} bulb(s) are reviewed and graded. The '
                  'report records the AI recommendation, the final grade and the '
                  'human decision for every bulb.'
              : 'All ${session.totalCount} bulb(s) must be reviewed and graded '
                  'before the report can be generated.',
          style: AppTypo.meta,
        ),
        if (!session.allGradesDecided) ...[
          const SizedBox(height: AppTheme.md),
          InfoBanner(
            title: 'Grade decision required',
            severity: BannerSeverity.attention,
            message:
                '${session.pendingGradeCount} bulb(s) still need a grade '
                'decision. Confirm the recommendations or override them, then '
                'generate the report.',
            action: FilledButton.icon(
              onPressed: onConfirmAllGrades,
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('CONFIRM ALL RECOMMENDATIONS'),
            ),
          ),
        ],
      ],
    );
  }
}

/// QUALITY GRADE RECOMMENDATION — the prominent grading workflow component.
///
/// Shows the AI-assisted (or fixed-scenario) recommendation NEXT TO the final
/// grade and lets the inspector CONFIRM or OVERRIDE it. The recommendation is
/// never overwritten: an override records the inspector's own grade beside the
/// original recommendation. ONION DETECT never certifies official grades.
class _GradePanel extends StatelessWidget {
  const _GradePanel({
    required this.session,
    required this.analysis,
    required this.onConfirm,
    required this.onOverride,
    required this.onClear,
  });

  final InspectionSession session;
  final AnalysisResult analysis;
  final VoidCallback onConfirm;
  final ValueChanged<String> onOverride;
  final VoidCallback onClear;

  static Color _gradeColour(String grade) {
    if (grade == QualityGrade.gradeA) return AppTheme.healthy;
    if (grade == QualityGrade.gradeB) return AppTheme.amberDark;
    if (grade == QualityGrade.urs) return AppTheme.unhealthy;
    return AppTheme.charcoal;
  }

  /// Picker dialog for the inspector's own grade (only the three supported
  /// labels are ever offered).
  Future<void> _pickOverride(BuildContext context) async {
    final grade = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose the final grade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your grade is recorded next to the AI recommendation — the '
              'recommendation itself is never overwritten.',
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
                  color: _gradeColour(option),
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
    if (grade != null) onOverride(grade);
  }

  @override
  Widget build(BuildContext context) {
    final recommended = session.recommendedGrade;
    final finalGrade = session.finalGradeLabel;
    final decision = session.gradeDecision;
    final isDemo = session.isDemo;
    final reviewed = session.reviewedCount;
    final total = session.totalCount;

    return PanelCard(
      label: 'Quality grade recommendation',
      borderColour:
          session.gradeDecided ? AppTheme.secondaryGreen : AppTheme.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Demo vs real provenance badges + grade decision state.
          Wrap(
            spacing: AppTheme.s8,
            runSpacing: AppTheme.s8,
            children: [
              StatusChip(
                label: isDemo ? 'Demo mode' : 'AI inference active',
                colour: isDemo ? AppTheme.amberDark : AppTheme.healthy,
                filled: true,
                icon: isDemo
                    ? Icons.dataset_outlined
                    : Icons.smart_toy_outlined,
              ),
              if (isDemo && analysis.scenarioId.isNotEmpty)
                StatusChip(
                  label:
                      'Scenario ${analysis.scenarioId} · ${analysis.scenarioTitle}',
                  colour: AppTheme.secondaryGreen,
                  icon: Icons.photo_outlined,
                ),
              StatusChip(
                label: 'Decision: ${decision.label}',
                colour: session.gradeDecided
                    ? AppTheme.healthy
                    : AppTheme.amberDark,
                icon: session.gradeDecided
                    ? Icons.how_to_reg_outlined
                    : Icons.pending_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),

          // Recommendation and final grade side by side — never merged.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GradeBox(
                  caption: 'AI RECOMMENDATION',
                  grade: recommended ?? '—',
                  colour: recommended == null
                      ? AppTheme.secondaryText
                      : _gradeColour(recommended),
                  note: recommended == null
                      ? 'No recommendation available.'
                      : isDemo
                          ? 'Fixed scenario recommendation.'
                          : 'Heuristic: healthy ≥ 85% = A · ≥ 50% = B.',
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: _GradeBox(
                  caption: 'FINAL GRADE (HUMAN)',
                  grade: finalGrade,
                  colour: finalGrade == 'PENDING'
                      ? AppTheme.amberDark
                      : _gradeColour(finalGrade),
                  note: decision == GradeDecision.pending
                      ? 'Awaiting inspector confirmation.'
                      : decision == GradeDecision.confirmed
                          ? 'Inspector confirmed the recommendation.'
                          : 'Inspector overrode to ${session.humanGrade ?? finalGrade}.',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),

          // RECOMMENDED LOT STATUS — configurable, explicitly explained policy.
          Builder(
            builder: (context) {
              final recommendation = session.lotGradeRecommendation;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.s12),
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RECOMMENDED LOT STATUS', style: AppTypo.label),
                    const SizedBox(height: AppTheme.s4),
                    Row(
                      children: [
                        StatusChip(
                          label: recommendation.status,
                          colour: gradeColourFor(recommendation.status),
                          icon: recommendation.pendingHumanVerification
                              ? Icons.pending_outlined
                              : Icons.insights_outlined,
                        ),
                        if (recommendation.pendingHumanVerification) ...[
                          const SizedBox(width: AppTheme.s8),
                          Flexible(
                            child: Text(
                              GradingWording.lotManualDecision,
                              style: AppTypo.label
                                  .copyWith(color: AppTheme.amberDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTheme.s8),
                    Text(recommendation.rule, style: AppTypo.meta),
                    const SizedBox(height: AppTheme.s4),
                    Text(
                      LotGradingPolicy.standard.ruleText,
                      style: AppTypo.meta.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: AppTheme.s4),
                    Text(
                      GradingWording.noOfficialCertification,
                      style: AppTypo.meta,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppTheme.md),

          // Honest provenance of the result above.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.s12),
            decoration: BoxDecoration(
              color: isDemo ? AppTheme.pendingSurface : AppTheme.lightGreen,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(
                color: isDemo ? AppTheme.amber : AppTheme.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDemo ? 'FIXED DEMONSTRATION SCENARIO' : 'REAL AI INFERENCE',
                  style: AppTypo.label.copyWith(
                    color:
                        isDemo ? AppTheme.amberDark : AppTheme.secondaryGreen,
                  ),
                ),
                const SizedBox(height: AppTheme.s4),
                Text(
                  isDemo
                      ? 'No AI inference was executed for this result. '
                          'Detection boxes and confidences were measured by '
                          'the real YOLOv8n model once on the bundled '
                          'photograph; health labels are fixed scenario values.'
                      : 'Produced by the real AI pipeline (YOLOv8n detection '
                          '· MobileNetV2 health classification). The grade is '
                          'an AI-assisted recommendation, never an official '
                          'certification.',
                  style: AppTypo.meta,
                ),
                if (isDemo && analysis.scenarioNotes.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.s4),
                  Text(
                    analysis.scenarioNotes.join(' '),
                    style: AppTypo.meta.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppTheme.secondaryGreen,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.md),

          // Verification summary.
          Text(
            'HUMAN VERIFICATION: $reviewed of $total bulbs reviewed',
            style: AppTypo.label,
          ),
          const SizedBox(height: AppTheme.s4),
          ProgressLine(value: total == 0 ? 0 : reviewed / total),
          const SizedBox(height: AppTheme.md),

          // Confirm / override / clear actions.
          Wrap(
            spacing: AppTheme.s8,
            runSpacing: AppTheme.s8,
            children: [
              FilledButton.icon(
                onPressed: (recommended != null && !session.gradeDecided)
                    ? onConfirm
                    : null,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('CONFIRM RECOMMENDATION'),
              ),
              OutlinedButton.icon(
                onPressed:
                    recommended == null ? null : () => _pickOverride(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('OVERRIDE'),
              ),
              if (session.gradeDecided)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('CLEAR DECISION'),
                ),
            ],
          ),
          if (!session.gradeDecided) ...[
            const SizedBox(height: AppTheme.s8),
            const Text(
              'Confirm or override the recommendation — the generated report '
              'records the recommendation, the final grade and the decision.',
              style: AppTypo.meta,
            ),
          ],
        ],
      ),
    );
  }
}

/// One large grade display box (recommendation or final grade).
class _GradeBox extends StatelessWidget {
  const _GradeBox({
    required this.caption,
    required this.grade,
    required this.colour,
    required this.note,
  });

  final String caption;
  final String grade;
  final Color colour;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.s16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: AppTypo.label),
          const SizedBox(height: AppTheme.s4),
          Text(
            grade,
            style: AppTypo.number.copyWith(color: colour, fontSize: 26),
          ),
          if (grade == QualityGrade.urs) ...[
            const SizedBox(height: 2),
            const Text('Under Relaxed Specifications', style: AppTypo.meta),
          ],
          const SizedBox(height: AppTheme.s4),
          Text(note, style: AppTypo.meta),
        ],
      ),
    );
  }
}

