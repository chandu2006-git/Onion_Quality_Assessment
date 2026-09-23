import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../models/backend_status.dart';
import '../providers/backend_status_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../widgets/app_shell.dart';
import '../widgets/feedback.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/status_widgets.dart';
import '../widgets/surfaces.dart';

/// Page 5 — product methodology, standards and technical information.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(backendStatusProvider);

    return AppShell(
      child: SingleChildScrollView(
        child: ContentContainer(
          maxWidth: AppTheme.maxContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Overview(),
              const SizedBox(height: AppTheme.xl),
              _Methodology(),
              const SizedBox(height: AppTheme.xl),
              _TechnicalInformation(statusAsync: statusAsync),
              const SizedBox(height: AppTheme.xl),
              _StandardsDisclaimer(),
              const SizedBox(height: AppTheme.xxl),
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'ABOUT ONION DETECT'),
        const SizedBox(height: AppTheme.s12),
        Text(
          AppConfig.tagline,
          style: AppTypo.body.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: AppTheme.md),
        Text(
          'ONION DETECT is an AI-assisted surface inspection tool for onion '
          'quality assessment. A real YOLOv8n detector locates individual bulbs, '
          'and a MobileNetV2 classifier assigns a Health / Unhealthy label to '
          'each bulb. Every AI observation is then presented for human '
          'verification before any evidence is recorded or reported.',
          style: AppTypo.body,
        ),
        const SizedBox(height: AppTheme.md),
        Text(
          'Workflow: ${AppConfig.workflowStatement}',
          style: AppTypo.meta.copyWith(color: AppTheme.secondaryGreen),
        ),
      ],
    );
  }
}

class _Methodology extends StatelessWidget {
  const _Methodology();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'METHODLOGY'),
        const SizedBox(height: AppTheme.s12),
        PanelCard(
          label: 'Inspection pipeline',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _PipelineStep(
                step: '1',
                title: 'Capture',
                description:
                    'The inspector uploads a JPG, PNG or WEBP sample image '
                    '(up to 10 MB).',
              ),
              SizedBox(height: AppTheme.s16),
              _PipelineStep(
                step: '2',
                title: 'Detection — YOLOv8n',
                description:
                    'A real YOLOv8n detector localises onion bulbs and returns '
                    'pixel-accurate bounding boxes. No objects are invented on '
                    'the client.',
              ),
              SizedBox(height: AppTheme.s16),
              _PipelineStep(
                step: '3',
                title: 'Classification — MobileNetV2',
                description:
                    'A real MobileNetV2 classifier assigns a Health / Unhealthy '
                    'label to each detected bulb with a confidence score.',
              ),
              SizedBox(height: AppTheme.s16),
              _PipelineStep(
                step: '4',
                title: 'Human verification',
                description:
                    'Every AI observation is presented for manual review. The '
                    'inspector may accept the AI label or override it. The '
                    'original AI observation is never overwritten.',
              ),
              SizedBox(height: AppTheme.s16),
              _PipelineStep(
                step: '5',
                title: 'Report generation',
                description:
                    'Once every bulb is reviewed, a PDF inspection report is '
                    'generated with annotated evidence and verification records.',
          ),
        ],
      ),
    ),
  ],
);
  }
}


class _PipelineStep extends StatelessWidget {
  const _PipelineStep({
    required this.step,
    required this.title,
    required this.description,
  });

  final String step;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(AppTheme.chipRadius),
          ),
          child: Center(
            child: Text(step, style: AppTypo.body.copyWith(
              color: AppTheme.white, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: AppTheme.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypo.label),
              const SizedBox(height: AppTheme.s4),
              Text(description, style: AppTypo.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _TechnicalInformation extends StatelessWidget {
  const _TechnicalInformation({required this.statusAsync});

  final AsyncValue<BackendStatus> statusAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'TECHNICAL INFORMATION'),
        const SizedBox(height: AppTheme.s12),
        PanelCard(
          label: 'Service status',
          child: statusAsync.when(
            data: (status) => _StatusContent(status: status),
            loading: () => const _StatusLoading(),
            error: (error, _) => _StatusError(message: error.toString()),
          ),
        ),
        const SizedBox(height: AppTheme.md),
        PanelCard(
          label: 'Models & inference',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              KeyValueRow(label: 'Detector', value: 'YOLOv8n'),
              KeyValueRow(label: 'Classifier', value: 'MobileNetV2'),
              KeyValueRow(
                label: 'Input',
                value: 'JPG, PNG, WEBP — up to 10 MB',
                hint: 'JPG, JPEG, PNG or WEBP',
              ),
              KeyValueRow(label: 'Output', value: 'Annotated evidence image + PDF report'),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusContent extends StatelessWidget {
  const _StatusContent({required this.status});

  final BackendStatus status;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (status.version.isNotEmpty) {
      rows.add(KeyValueRow(label: 'Version', value: status.version));
    }
    rows
      ..add(KeyValueRow(
          label: 'Detector model',
          value: status.detectorLoaded ? 'In memory' : 'Not in memory (loads on demand)'))
      ..add(KeyValueRow(
          label: 'Classifier model',
          value: status.classifierLoaded ? 'In memory' : 'Not in memory (loads on demand)'));

    if (status.detectorError != null) {
      rows.add(KeyValueRow(
          label: 'Detector error', value: status.detectorError!,
          valueColour: AppTheme.unhealthy));
    }
    if (status.classifierError != null) {
      rows.add(KeyValueRow(
          label: 'Classifier error', value: status.classifierError!,
          valueColour: AppTheme.unhealthy));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppTheme.s8,
          runSpacing: AppTheme.s8,
          children: [
            StatusChip(
              label: status.ready ? 'Ready' : status.status,
              colour: status.ready ? AppTheme.healthy : AppTheme.unhealthy,
              filled: true,
            ),
            if (status.detectorFilePresent && status.classifierFilePresent)
              StatusChip(
                label: 'Models present',
                colour: AppTheme.secondaryGreen,
                icon: Icons.check_circle_outline,
              ),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        ...rows,
        if (status.summary.isNotEmpty) ...[
          const SizedBox(height: AppTheme.md),
          Text(status.summary, style: AppTypo.body),
        ],
      ],
    );
  }
}

class _StatusLoading extends StatelessWidget {
  const _StatusLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: AppTheme.s12),
        Text('Checking service status…'),
      ],
    );
  }
}

class _StatusError extends StatelessWidget {
  const _StatusError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      title: 'Service unreachable',
      severity: BannerSeverity.error,
      message: 'Could not contact the inspection service. $message',
    );
  }
}

class _StandardsDisclaimer extends StatelessWidget {
  const _StandardsDisclaimer();

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      title: 'Important',
      severity: BannerSeverity.attention,
      message: 'AI-assisted inspection — human verification required.',
      details: [
        'The AI measures quality traits; a human inspector must verify every '
        'observation before it is recorded.',
        'This tool does not assign official AGMARK grades.',
        'It does not provide disease-specific diagnosis.',
        'It does not replace regulatory or expert inspection.',
      ],
    );
  }
}

