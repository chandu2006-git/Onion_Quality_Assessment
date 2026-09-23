import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../core/api_exception.dart';
import '../models/backend_status.dart';
import '../models/inspection_session.dart';
import '../providers/backend_status_provider.dart';
import '../providers/inspection_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../widgets/analysis_activity.dart';
import '../widgets/app_shell.dart';
import '../widgets/feedback.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/status_widgets.dart';
import '../widgets/surfaces.dart';
import '../widgets/upload_area.dart';

/// Page 3 — capture or upload the onion sample and run the inspection.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  String? _fileError;

  Future<void> _onFileSelected(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      ref.read(inspectionProvider.notifier).setSample(
            bytes: bytes,
            fileName: file.name,
            sizeBytes: bytes.length,
          );
      setState(() => _fileError = null);
    } on ApiException catch (error) {
      setState(() => _fileError = error.message);
    } catch (error) {
      setState(() => _fileError =
          'The selected file could not be processed. Please upload a valid JPG, PNG or WEBP image.');
    }
  }

  Future<void> _analyze() async {
    setState(() => _fileError = null);
    await ref.read(inspectionProvider.notifier).analyzeSample();
    if (!mounted) return;
    final state = ref.read(inspectionProvider);
    if (state.phase == AnalysisPhase.completed) {
      context.go('/results');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionProvider);
    final session = state.session;
    final backend = ref.watch(backendStatusProvider);

    if (session == null) {
      return AppShell(
        child: ContentContainer(
          maxWidth: 880,
          child: EmptyState(
            message: 'Create an inspection record before submitting a sample.',
            icon: Icons.assignment_outlined,
            action: FilledButton(
              onPressed: () => context.go('/start'),
              child: const Text('NEW INSPECTION →'),
            ),
          ),
        ),
      );
    }

    return AppShell(
      child: SingleChildScrollView(
        child: ContentContainer(
          maxWidth: AppTheme.maxContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CaptureHeader(session: session),
              const SizedBox(height: AppTheme.lg),
              backend.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (error, _) => InfoBanner(
                  title: 'Service status',
                  severity: BannerSeverity.error,
                  message: BackendStatus.unreachable().summary,
                  action: OutlinedButton(
                    onPressed: () => ref.invalidate(backendStatusProvider),
                    child: const Text('RECHECK SERVICE'),
                  ),
                ),
                data: (status) => _ServiceStatusBanner(status: status),
              ),
              const SizedBox(height: AppTheme.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1000;
                  final uploadColumn = _UploadColumn(
                    enabled: !state.analysisRunning,
                    onFileSelected: _onFileSelected,
                    onError: (message) => setState(() => _fileError = message),
                    session: session,
                    fileError: _fileError,
                  );
                  final actionColumn = _ActionColumn(
                    state: state,
                    canAnalyze: _canAnalyze(state, backend),
                    onAnalyze: _analyze,
                    onClear: () => ref.read(inspectionProvider.notifier).clearSample(),
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: uploadColumn),
                        const SizedBox(width: AppTheme.lg),
                        Expanded(flex: 4, child: actionColumn),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      uploadColumn,
                      const SizedBox(height: AppTheme.lg),
                      actionColumn,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canAnalyze(InspectionState state, AsyncValue<BackendStatus> backend) {
    if (state.session?.sampleBytes == null) return false;
    if (state.analysisRunning) return false;
    final status = backend.value;
    return status == null ? true : status.ready;
  }
}

class _UploadColumn extends StatelessWidget {
  const _UploadColumn({
    required this.enabled,
    required this.onFileSelected,
    required this.onError,
    required this.session,
    required this.fileError,
  });

  final bool enabled;
  final ValueChanged<XFile> onFileSelected;
  final ValueChanged<String> onError;
  final InspectionSession session;
  final String? fileError;

  @override
  Widget build(BuildContext context) {
    final bytes = session.sampleBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UploadArea(
          enabled: enabled,
          onFileSelected: onFileSelected,
          onError: onError,
        ),
        if (fileError != null) ...[
          const SizedBox(height: AppTheme.s12),
          InfoBanner(
            title: 'Sample could not be used',
            severity: BannerSeverity.error,
            message: fileError!,
          ),
        ],
        const SizedBox(height: AppTheme.md),
        if (bytes != null && bytes.isNotEmpty)
          _SamplePreview(session: session)
        else
          const EmptyState(
            message: 'Upload an onion sample to begin inspection.',
            icon: Icons.add_photo_alternate_outlined,
            guidance: [
              'Accepted formats: JPG, JPEG, PNG or WEBP.',
              'Use sufficient lighting and keep bulbs clearly visible.',
              'Minimize heavy overlap between bulbs.',
            ],
          ),
      ],
    );
  }
}

class _SamplePreview extends StatelessWidget {
  const _SamplePreview({required this.session});

  final InspectionSession session;

  @override
  Widget build(BuildContext context) {
    final bytes = session.sampleBytes;
    if (bytes == null || bytes.isEmpty) return const SizedBox.shrink();
    final sizeKb =
        ((session.sampleSizeBytes ?? bytes.length) / 1024).toStringAsFixed(0);
    return PanelCard(
      label: 'Image ready for inspection',
      borderColour: AppTheme.secondaryGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
          const SizedBox(height: AppTheme.s12),
          Text(
            '${session.sampleFileName ?? 'sample image'} · $sizeKb KB',
            style: AppTypo.meta,
          ),
        ],
      ),
    );
  }
}

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({
    required this.state,
    required this.canAnalyze,
    required this.onAnalyze,
    required this.onClear,
  });

  final InspectionState state;
  final bool canAnalyze;
  final VoidCallback onAnalyze;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final running = state.analysisRunning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          label: 'Inspection readiness',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KeyValueRow(
                label: 'Inspection ID',
                value: state.session?.id ?? '—',
              ),
              KeyValueRow(
                label: 'Inspector',
                value: state.session?.inspector ?? '—',
              ),
              const KeyValueRow(
                label: 'Image quality guidance',
                value: 'Clear, well-lit bulbs',
                hint:
                    'Use sufficient lighting. Keep onion bulbs clearly visible. Minimize heavy overlap between bulbs.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (canAnalyze && !running) ? onAnalyze : null,
            child: Text(running ? 'ANALYZING…' : 'ANALYZE SAMPLE →'),
          ),
        ),
        const SizedBox(height: AppTheme.s8),
        if (state.session?.sampleBytes != null)
          OutlinedButton(
            onPressed: running ? null : onClear,
            child: const Text('REMOVE SAMPLE'),
          ),
        if (running) ...[
          const SizedBox(height: AppTheme.md),
          AnalysisActivity(
            phase: state.phase,
            uploadProgress: state.uploadProgress,
          ),
        ],
        if (state.analysisError != null) ...[
          const SizedBox(height: AppTheme.md),
          InfoBanner(
            title: 'Inspection could not be completed',
            severity: BannerSeverity.error,
            message: state.analysisError!,
          ),
        ],
        const SizedBox(height: AppTheme.md),
        Text(
          'Upload limit ${AppConfig.maxUploadLabel} · ${AppConfig.acceptedFormatsLabel}.',
          style: AppTypo.meta,
        ),
      ],
    );
  }
}

class _CaptureHeader extends StatelessWidget {
  const _CaptureHeader({required this.session});

  final dynamic session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'Capture onion sample'),
        const SizedBox(height: AppTheme.s12),
        const Text(
          'Submit a clear image containing one or more onion bulbs for '
          'AI-assisted inspection.',
          style: AppTypo.body,
        ),
        const SizedBox(height: AppTheme.md),
        Wrap(
          spacing: AppTheme.s8,
          runSpacing: AppTheme.s8,
          children: [
            StatusChip(
              label: session.id.toString(),
              colour: AppTheme.primary,
              icon: Icons.assignment_outlined,
            ),
            StatusChip(
              label: session.inspector.toString(),
              colour: AppTheme.secondaryGreen,
              icon: Icons.person_outline,
            ),
            StatusChip(
              label: session.batchLot.toString(),
              colour: AppTheme.secondaryGreen,
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

/// Reports the live readiness of the FastAPI service and the trained models.
class _ServiceStatusBanner extends StatelessWidget {
  const _ServiceStatusBanner({required this.status});

  final BackendStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.ready) {
      return const InfoBanner(
        title: 'Inspection service online',
        severity: BannerSeverity.success,
        message: 'Detection model and health classification model reported as ready '
            'by the backend. Models load on demand for each analysis.',
      );
    }
    return InfoBanner(
      title: status.reachable ? 'Model configuration required' : 'Service unavailable',
      severity: BannerSeverity.error,
      message: status.summary,
      details: const [
        'Inference cannot run until the service reports ready (model files installed, no load failures).',
        'No placeholder or substitute results are produced by this application.',
      ],
    );
  }
}

