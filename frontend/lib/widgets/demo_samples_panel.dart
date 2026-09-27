import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/demo_results.dart';
import '../config/demo_samples.dart';
import '../providers/inspection_provider.dart';
import '../services/demo_evidence.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import 'responsive_layout.dart';
import 'status_widgets.dart';
import 'surfaces.dart';

/// Demo samples for the capture page — two clearly separated paths.
///
/// * **Fixed demonstration scenarios (primary).** Selecting one NEVER calls
///   `/api/analyze`: the result opens instantly from the bundled dataset, so
///   the walkthrough keeps working even when the backend is offline, cold
///   starting, or the models are not resident in memory.
/// * **Real-AI quick check (secondary).** The original bundled photographs
///   are loaded into the EXISTING sample pipeline (`setSample` →
///   `POST /api/analyze`), exactly like a user upload.
class DemoSamplesPanel extends ConsumerStatefulWidget {
  const DemoSamplesPanel({super.key});

  @override
  ConsumerState<DemoSamplesPanel> createState() => _DemoSamplesPanelState();
}

class _DemoSamplesPanelState extends ConsumerState<DemoSamplesPanel> {
  String? _busyId;

  /// Opens a fixed scenario instantly — no service, model or network call.
  Future<void> _openScenario(DemoScenario scenario) async {
    if (_busyId != null) return;
    setState(() => _busyId = scenario.id);
    try {
      final data = await rootBundle.load(scenario.asset);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final observations = buildDemoObservations(scenario);
      final evidence = await renderDemoEvidence(
        imageBytes: bytes,
        observations: observations,
      );
      if (!mounted) return;
      ref.read(inspectionProvider.notifier).applyDemoResult(
            scenario: scenario,
            imageBytes: bytes,
            fileName: scenario.asset.split('/').last,
            evidence: evidence,
          );
      if (!mounted) return;
      context.go('/results');
    } catch (_) {
      // Never surface technical details — only a friendly, actionable message.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'The demonstration sample could not be opened. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Loads a bundled photograph into the EXISTING real-AI sample pipeline.
  Future<void> _loadRealSample(DemoSample sample) async {
    final notifier = ref.read(inspectionProvider.notifier);
    try {
      final data = await rootBundle.load(sample.asset);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      if (!mounted) return;
      notifier.setSample(
        bytes: bytes,
        fileName: sample.asset.split('/').last,
        sizeBytes: bytes.length,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          content: Text(
            '${sample.title} image loaded. Press ANALYZE SAMPLE to run '
                'the real AI pipeline on it.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('The image could not be loaded. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(
      inspectionProvider.select((state) => state.analysisRunning),
    );
    return PanelCard(
      label: 'Demo samples',
      trailing: const StatusChip(
        label: 'Demo mode · instant · works offline',
        colour: AppTheme.amberDark,
        icon: Icons.auto_awesome_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Four prepared demonstration scenarios with fixed results. '
                'Selecting one opens the prepared inspection immediately — no '
                'service, no model loading — so the walkthrough never stops. '
                'Real uploads always run through the live AI pipeline.',
            style: AppTypo.meta,
          ),
          const SizedBox(height: AppTheme.md),
          ResponsiveCardGrid(
            minCardWidth: 210,
            maxColumns: 4,
            children: [
              for (final scenario in kDemoScenarios)
                _ScenarioCard(
                  scenario: scenario,
                  busy: _busyId != null,
                  opening: _busyId == scenario.id,
                  onTap: () => _openScenario(scenario),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          const Divider(height: AppTheme.lg, color: AppTheme.border),
          const Text(
            'REAL AI QUICK CHECK — BUNDLED PHOTOS THROUGH POST /API/ANALYZE '
                '(SERVICE REQUIRED)',
            style: AppTypo.label,
          ),
          const SizedBox(height: AppTheme.s8),
          const Text(
            'Optional: analyse the photographs below with the live YOLOv8n + '
                'MobileNetV2 pipeline, exactly like a user upload. This path '
                'requires the inspection service to be reachable.',
            style: AppTypo.meta,
          ),
          const SizedBox(height: AppTheme.md),
          ResponsiveCardGrid(
            minCardWidth: 210,
            maxColumns: 3,
            children: [
              for (final sample in kDemoSamples)
                _DemoSampleCard(
                  sample: sample,
                  enabled: !running,
                  onTap: () => _loadRealSample(sample),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Selection card for one FIXED demonstration scenario.
///
/// Deliberately reveals only the scenario (number, title, teaser) — never the
/// result — so the judge discovers the outcome on the results page.
class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.busy,
    required this.opening,
    required this.onTap,
  });

  final DemoScenario scenario;
  final bool busy;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = scenario.recommended;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: AnimatedOpacity(
        opacity: busy && !opening ? 0.55 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: highlighted ? AppTheme.secondaryGreen : AppTheme.border,
              width: highlighted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.charcoal.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      scenario.asset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.lightGreen,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppTheme.secondaryGreen,
                        ),
                      ),
                    ),
                    if (highlighted)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: StatusChip(
                          label: 'Recommended',
                          colour: AppTheme.secondaryGreen,
                          filled: true,
                          icon: Icons.star_outline,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          scenario.id,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.amberDark,
                          ),
                        ),
                        const SizedBox(width: AppTheme.s8),
                        const StatusChip(
                          label: 'Fixed demo scenario',
                          colour: AppTheme.secondaryText,
                          icon: Icons.dataset_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.s8),
                    Text(
                      scenario.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.s4),
                    Text(scenario.teaser, style: AppTypo.meta),
                    const SizedBox(height: AppTheme.s12),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: busy
                              ? AppTheme.secondaryText
                              : AppTheme.secondaryGreen,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          opening ? 'OPENING…' : 'OPEN DEMO →',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: busy
                                ? AppTheme.secondaryText
                                : AppTheme.secondaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card for the secondary REAL-AI quick check (bundled photo → live pipeline).
class _DemoSampleCard extends StatelessWidget {
  const _DemoSampleCard({
    required this.sample,
    required this.enabled,
    required this.onTap,
  });

  final DemoSample sample;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = sample.recommended;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.55,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: highlighted ? AppTheme.secondaryGreen : AppTheme.border,
              width: highlighted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.charcoal.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      sample.asset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.lightGreen,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppTheme.secondaryGreen,
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: StatusChip(
                        label: 'Real AI',
                        colour: AppTheme.healthy,
                        filled: true,
                        icon: Icons.smart_toy_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sample.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.s4),
                    Text(sample.description, style: AppTypo.meta),
                    const SizedBox(height: AppTheme.s12),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: enabled
                              ? AppTheme.secondaryGreen
                              : AppTheme.secondaryText,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          enabled ? 'LOAD SAMPLE' : 'ANALYSIS RUNNING…',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: enabled
                                ? AppTheme.secondaryGreen
                                : AppTheme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

