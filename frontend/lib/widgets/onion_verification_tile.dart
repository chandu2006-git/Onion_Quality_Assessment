import 'package:flutter/material.dart';

import '../models/onion_observation.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import 'status_widgets.dart';
import 'verification_controls.dart';

/// One row of the verification list.
class OnionVerificationTile extends StatelessWidget {
  const OnionVerificationTile({
    super.key,
    required this.observation,
    required this.selected,
    required this.onSelect,
    required this.onConfirmAi,
    required this.onOverride,
    required this.onClearReview,
  });

  final OnionObservation observation;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onConfirmAi;
  final VoidCallback onOverride;
  final VoidCallback onClearReview;

  @override
  Widget build(BuildContext context) {
    final aiHealthy = observation.isHealthyObservation;
    final outcome = observation.verification;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.s12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: selected ? AppTheme.amber : AppTheme.border,
          width: selected ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  observation.displayLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              StatusChip(
                label: outcome.label,
                colour: outcome.colour,
                icon: outcome.icon,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s8),
          Row(
            children: [
              const Expanded(child: Text('AI OBSERVATION', style: AppTypo.label)),
              StatusChip(
                label: observation.aiHealth,
                colour: OnionHealth.colourFor(observation.aiHealth),
                icon: aiHealthy ? Icons.check_circle_outline : Icons.error_outline,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s8),
          Row(
            children: [
              Expanded(
                child: _Confidence(
                  label: 'Health confidence',
                  value: observation.healthConfidence,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: _Confidence(
                  label: 'Detection confidence',
                  value: observation.detectionConfidence,
                ),
              ),
              IconButton(
                onPressed: onSelect,
                tooltip: 'Show details for ${observation.displayLabel}',
                icon: const Icon(Icons.chevron_right),
                color: AppTheme.secondaryText,
              ),
            ],
          ),
          const Divider(height: AppTheme.lg, color: AppTheme.border),
          const Text('HUMAN VERIFICATION', style: AppTypo.label),
          const SizedBox(height: AppTheme.s8),
          VerificationControls(
            observation: observation,
            onConfirmAi: onConfirmAi,
            onOverride: onOverride,
            onClearReview: onClearReview,
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _Confidence extends StatelessWidget {
  const _Confidence({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypo.meta),
        const SizedBox(height: 2),
        Text(
          formatPercent(value),
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
