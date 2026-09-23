import 'package:flutter/material.dart';

import '../models/onion_observation.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

/// Percentages are shown rounded to one decimal place; raw probability values
/// stay internal.
String formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';

/// Verification controls for one bulb.
///
/// The inspector either confirms the AI observation or records the opposite
/// decision. Both actions are explicit, and the AI observation is preserved.
class VerificationControls extends StatelessWidget {
  const VerificationControls({
    super.key,
    required this.observation,
    required this.onConfirmAi,
    required this.onOverride,
    required this.onClearReview,
    this.dense = false,
  });

  final OnionObservation observation;
  final VoidCallback onConfirmAi;
  final VoidCallback onOverride;
  final VoidCallback onClearReview;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final aiHealthy = observation.isHealthyObservation;
    final confirmLabel = aiHealthy ? 'CONFIRM HEALTHY' : 'CONFIRM UNHEALTHY';
    final overrideLabel = aiHealthy ? 'MARK UNHEALTHY' : 'MARK HEALTHY';
    final confirmed = observation.verification == VerificationOutcome.confirmed;
    final overridden = observation.verification == VerificationOutcome.overridden;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: confirmed ? null : onConfirmAi,
                style: FilledButton.styleFrom(
                  backgroundColor: confirmed ? AppTheme.healthy : AppTheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: dense ? 14 : 16,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 0.9,
                  ),
                ),
                child: Text(confirmed ? 'CONFIRMED' : confirmLabel),
              ),
            ),
            const SizedBox(width: AppTheme.s8),
            Expanded(
              child: OutlinedButton(
                onPressed: overridden ? null : onOverride,
                style: OutlinedButton.styleFrom(
                  foregroundColor: overridden ? AppTheme.unhealthy : AppTheme.charcoal,
                  side: BorderSide(
                    color: overridden ? AppTheme.unhealthy : AppTheme.border,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: dense ? 14 : 16,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 0.9,
                  ),
                ),
                child: Text(overridden ? 'OVERRIDDEN' : overrideLabel),
              ),
            ),
          ],
        ),
        if (observation.isReviewed) ...[
          const SizedBox(height: AppTheme.s8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recorded status: ${observation.recordedHealth}',
                  style: AppTypo.meta.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.charcoal,
                  ),
                ),
              ),
              TextButton(onPressed: onClearReview, child: const Text('Clear review')),
            ],
          ),
        ],
      ],
    );
  }
}
