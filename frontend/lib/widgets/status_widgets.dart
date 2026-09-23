import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

/// Status pill: icon + wording + colour (never colour alone).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.colour,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color colour;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? colour : colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.chipRadius),
        border: Border.all(color: colour.withValues(alpha: filled ? 1 : 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: filled ? AppTheme.white : colour),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: filled ? AppTheme.white : colour,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state with a short explanation and optional guidance list.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.guidance,
    this.action,
  });

  final String message;
  final IconData icon;
  final List<String>? guidance;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.s32),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.s16),
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 26, color: AppTheme.secondaryGreen),
          ),
          const SizedBox(height: AppTheme.s16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypo.body.copyWith(fontSize: 15),
          ),
          if (guidance != null && guidance!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.s16),
            Column(
              children: guidance!
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(item, style: AppTypo.meta),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppTheme.s24),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Horizontal progress line used by the verification counter.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value, this.height = 8});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: AppTheme.border,
        color: AppTheme.primary,
      ),
    );
  }
}
