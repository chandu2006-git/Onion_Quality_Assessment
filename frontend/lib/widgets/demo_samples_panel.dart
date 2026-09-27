import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/demo_samples.dart';
import '../providers/inspection_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import 'responsive_layout.dart';
import 'status_widgets.dart';
import 'surfaces.dart';

/// One-click demo samples for the capture page.
///
/// Each card loads a bundled photograph into the EXISTING sample pipeline via
/// `setSample`, so the subsequent analysis runs through the real
/// `POST /api/analyze` endpoint (YOLOv8n → MobileNetV2) exactly like a user
/// upload. No result is precomputed or assumed.
class DemoSamplesPanel extends ConsumerWidget {
  const DemoSamplesPanel({super.key});

  Future<void> _load(BuildContext context, WidgetRef ref, DemoSample sample) async {
    final notifier = ref.read(inspectionProvider.notifier);
    try {
      final data = await rootBundle.load(sample.asset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      if (!context.mounted) return;
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
            '${sample.title} demo image loaded. Press ANALYZE SAMPLE to run '
                'the real AI pipeline on it.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('The demo image could not be loaded: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(
      inspectionProvider.select((state) => state.analysisRunning),
    );
    return PanelCard(
      label: 'Demo images',
      trailing: const StatusChip(
        label: 'Real images · real AI',
        colour: AppTheme.secondaryGreen,
        icon: Icons.smart_toy_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'One-click sample photographs for a live walkthrough. Selecting a '
                'demo loads it into the same inspection pipeline as an upload — '
                'the shown results always come from the running models.',
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
                  onTap: () => _load(context, ref, sample),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

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
