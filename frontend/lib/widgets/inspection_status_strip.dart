import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'status_widgets.dart';

/// Lifecycle state of one workflow step.
enum StatusStepState { done, active, upcoming }

/// One labelled step of the inspection status strip.
class StatusStep {
  const StatusStep(this.label, this.state, {this.icon});

  final String label;
  final StatusStepState state;
  final IconData? icon;
}

/// Compact horizontal status strip: `READY → ANALYZING → …`.
///
/// Status is communicated by text + icon (never colour alone); completed steps
/// read `done`, the current step `active`, future steps `upcoming`.
class InspectionStatusStrip extends StatelessWidget {
  const InspectionStatusStrip({super.key, required this.steps});

  final List<StatusStep> steps;

  /// Strip for the capture page.
  factory InspectionStatusStrip.forCapture({required bool analysing}) =>
      InspectionStatusStrip(
        steps: [
          StatusStep(
            'Ready',
            analysing ? StatusStepState.done : StatusStepState.active,
            icon: Icons.check_circle_outline,
          ),
          StatusStep(
            'Analysing',
            analysing ? StatusStepState.active : StatusStepState.upcoming,
            icon: Icons.smart_toy_outlined,
          ),
          const StatusStep(
            'AI analysis complete',
            StatusStepState.upcoming,
            icon: Icons.fact_check_outlined,
          ),
        ],
      );

  /// Strip for the results page, from analysis completion to a ready report.
  factory InspectionStatusStrip.forResults({
    required bool verificationPending,
    required bool reportReady,
  }) =>
      InspectionStatusStrip(
        steps: [
          const StatusStep(
            'AI analysis complete',
            StatusStepState.done,
            icon: Icons.fact_check_outlined,
          ),
          StatusStep(
            'Verification pending',
            verificationPending ? StatusStepState.active : StatusStepState.done,
            icon: verificationPending
                ? Icons.schedule
                : Icons.verified_outlined,
          ),
          StatusStep(
            'Verified',
            verificationPending
                ? StatusStepState.upcoming
                : StatusStepState.done,
            icon: Icons.verified_outlined,
          ),
          StatusStep(
            'Report ready',
            reportReady
                ? StatusStepState.done
                : (verificationPending
                    ? StatusStepState.upcoming
                    : StatusStepState.active),
            icon: Icons.picture_as_pdf_outlined,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.s8,
      runSpacing: AppTheme.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final step in steps)
          StatusChip(
            label: step.label,
            colour: _colourFor(step.state),
            icon: step.icon ??
                (step.state == StatusStepState.done
                    ? Icons.check_circle_outline
                    : null),
            filled: step.state == StatusStepState.active,
          ),
      ],
    );
  }

  Color _colourFor(StatusStepState state) {
    switch (state) {
      case StatusStepState.done:
        return AppTheme.secondaryGreen;
      case StatusStepState.active:
        return AppTheme.amberDark;
      case StatusStepState.upcoming:
        return AppTheme.secondaryText;
    }
  }
}
