import 'package:flutter/material.dart';

import '../models/onion_observation.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import 'status_widgets.dart';
import 'surfaces.dart';
import 'verification_controls.dart';

/// Detail view for a single bulb, making the decision chain explicit:
/// AI observation → human verification → final recorded status.
class OnionDetailPanel extends StatelessWidget {
  const OnionDetailPanel({
    super.key,
    required this.observation,
    required this.onConfirmAi,
    required this.onOverride,
    required this.onClearReview,
  });

  final OnionObservation? observation;
  final VoidCallback onConfirmAi;
  final VoidCallback onOverride;
  final VoidCallback onClearReview;

  @override
  Widget build(BuildContext context) {
    final observation = this.observation;
    if (observation == null) {
      return PanelCard(
        label: 'Onion detail',
        child: const EmptyState(
          message: 'Select an onion bulb to review its AI observation and record '
              'your verification.',
          icon: Icons.touch_app_outlined,
          guidance: [
            'Tap a bounding box on the evidence image,',
            'or open an onion from the verification list.',
          ],
        ),
      );
    }

    final aiHealthy = observation.isHealthyObservation;
    final aiColour = OnionHealth.colourFor(observation.aiHealth);

    return PanelCard(
      label: 'Onion detail',
      trailing: StatusChip(
        label: observation.verification.label,
        colour: observation.verification.colour,
        icon: observation.verification.icon,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            observation.displayLabel,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: AppTheme.md),
          _Block(
            title: 'AI observation',
            accent: aiColour,
            surface: aiHealthy ? AppTheme.healthySurface : AppTheme.unhealthySurface,
            children: [
              Text(
                observation.aiHealth,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: aiColour,
                ),
              ),
              const SizedBox(height: AppTheme.s4),
              Text(
                'AI classification — subject to human verification.',
                style: AppTypo.meta.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              _ValueRow(
                label: 'Health confidence',
                value: formatPercent(observation.healthConfidence),
              ),
              const SizedBox(height: AppTheme.s4),
              Text(
                'Confidence associated with the Healthy/Unhealthy classification.',
                style: AppTypo.meta,
              ),
              const SizedBox(height: AppTheme.s12),
              _ValueRow(
                label: 'Detection confidence',
                value: formatPercent(observation.detectionConfidence),
              ),
              const SizedBox(height: AppTheme.s4),
              Text(
                'Confidence associated with locating the onion.',
                style: AppTypo.meta,
              ),
            ],
          ),
          const _FlowArrow(label: 'Human verification'),
          _Block(
            title: 'Human verification',
            accent: AppTheme.amberDark,
            surface: AppTheme.pendingSurface,
            children: [
              Text(
                'Review the AI observation before finalizing the inspection report.',
                style: AppTypo.body.copyWith(color: AppTheme.charcoal),
              ),
              const SizedBox(height: AppTheme.s12),
              VerificationControls(
                observation: observation,
                onConfirmAi: onConfirmAi,
                onOverride: onOverride,
                onClearReview: onClearReview,
              ),
            ],
          ),
          const _FlowArrow(label: 'Final recorded status'),
          _Block(
            title: 'Final recorded status',
            accent: AppTheme.primary,
            surface: AppTheme.lightGreen,
            children: [
              Text(
                observation.recordedHealth ?? 'Pending review',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: observation.isReviewed
                      ? AppTheme.primary
                      : AppTheme.amberDark,
                ),
              ),
              const SizedBox(height: AppTheme.s8),
              Text(
                observation.verification == VerificationOutcome.overridden
                    ? 'AI observation recorded as ${observation.aiHealth}; the inspector '
                        'recorded a different final status.'
                    : 'The AI observation is preserved in the report together with the '
                        'verification status.',
                style: AppTypo.meta,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.title,
    required this.accent,
    required this.surface,
    required this.children,
  });

  final String title;
  final Color accent;
  final Color surface;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppTypo.label.copyWith(color: accent)),
          const SizedBox(height: AppTheme.s8),
          ...children,
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.s8),
      child: Row(
        children: [
          const Icon(Icons.arrow_downward, size: 16, color: AppTheme.secondaryText),
          const SizedBox(width: AppTheme.s8),
          Text(
            label.toUpperCase(),
            style: AppTypo.label.copyWith(color: AppTheme.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTypo.meta)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.charcoal,
          ),
        ),
      ],
    );
  }
}
