import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/analysis_result.dart';
import '../models/inspection_session.dart';
import '../models/onion_observation.dart';
import '../providers/inspection_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../widgets/app_shell.dart';
import '../widgets/evidence_view.dart';
import '../widgets/feedback.dart';
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
              const SizedBox(height: AppTheme.xl),
              _SummaryCards(
                total: analysis.totalOnions,
                healthy: analysis.healthyCount,
                unhealthy: analysis.unhealthyCount,
                session: session,
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
              if (analysis.hasDetections) ...[
                const SizedBox(height: AppTheme.xl),
                _FinalizeSection(
                  session: session,
                  generating: state.generatingReport,
                  reportError: state.reportError,
                  reportNotice: state.reportNotice,
                  onGenerate:
                      ref.read(inspectionProvider.notifier).generateReport,
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
        const SectionHeading(title: 'INSPECTION RESULTS'),
        const SizedBox(height: AppTheme.s12),
        Wrap(
          spacing: AppTheme.s12,
          runSpacing: AppTheme.s8,
          children: [
            StatusChip(label: session.id, colour: AppTheme.primary),
            StatusChip(label: session.inspector, colour: AppTheme.secondaryGreen),
            StatusChip(label: session.location, colour: AppTheme.secondaryGreen),
            StatusChip(label: session.batchLot, colour: AppTheme.secondaryGreen),
            StatusChip(label: session.formattedTimestamp, colour: AppTheme.charcoal),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        const Text('AI ANALYSIS COMPLETE', style: AppTypo.label),
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
    required this.selectedId,
    required this.onSelect,
    required this.onConfirmAi,
    required this.onOverride,
    required this.onClear,
  });

  final List<OnionObservation> observations;
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
    return PanelCard(
      label: 'Verification progress',
      borderColour: AppTheme.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$reviewed of $total onions reviewed',
                  style: AppTypo.body),
              const Spacer(),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: AppTypo.body),
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
            ],
          ),
        ],
      ),
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
  });

  final InspectionSession session;
  final bool generating;
  final String? reportError;
  final String? reportNotice;
  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    final canGenerate =
        session.allReviewed && !generating && reportError == null;
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
          'All ${session.totalCount} onions must be reviewed before the '
          'report can be generated.',
          style: AppTypo.meta,
        ),
      ],
    );
  }
}
