import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

/// White card with a thin border — the primary surface of the product.
class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.child,
    this.label,
    this.padding = const EdgeInsets.all(AppTheme.s24),
    this.background = AppTheme.white,
    this.borderColour = AppTheme.border,
    this.trailing,
    this.onDark = false,
  });

  final Widget child;
  final String? label;
  final EdgeInsetsGeometry padding;
  final Color background;
  final Color borderColour;
  final Widget? trailing;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
        border: Border.all(color: borderColour),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    label!.toUpperCase(),
                    style: AppTypo.label.copyWith(
                      color: onDark ? AppTheme.lightGreen : AppTheme.secondaryText,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppTheme.s16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Uppercase section marker used to separate the major page regions.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.onDark = false,
  });

  final String title;
  final String? subtitle;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypo.label.copyWith(
            fontSize: 11.5,
            color: onDark ? AppTheme.lightGreen : AppTheme.secondaryGreen,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppTheme.s8),
          SizedBox(
            width: 720,
            child: Text(
              subtitle!,
              style: AppTypo.bodyMuted.copyWith(
                color: onDark ? AppTheme.lightGreen : AppTheme.secondaryText,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Large-number metric card (home page, results summary).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.value,
    required this.title,
    required this.description,
    this.valueColour = AppTheme.primary,
    this.icon,
    this.onDark = false,
  });

  final String value;
  final String title;
  final String description;
  final Color valueColour;
  final IconData? icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.s24),
      decoration: BoxDecoration(
        color: onDark ? AppTheme.white.withValues(alpha: 0.06) : AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
        border: Border.all(
          color: onDark ? AppTheme.lightGreen.withValues(alpha: 0.24) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: onDark ? AppTheme.lightGreen : AppTheme.secondaryGreen,
            ),
            const SizedBox(height: AppTheme.s16),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypo.number.copyWith(
                color: onDark ? AppTheme.white : valueColour,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.s8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: onDark ? AppTheme.white : AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: AppTheme.s8),
          Text(
            description,
            style: AppTypo.meta.copyWith(
              color: onDark ? AppTheme.lightGreen : AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small labelled value used inside detail panels.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColour = AppTheme.charcoal,
    this.hint,
  });

  final String label;
  final String value;
  final Color valueColour;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypo.label),
          const SizedBox(height: AppTheme.s4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColour,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: AppTheme.s4),
            Text(hint!, style: AppTypo.meta),
          ],
        ],
      ),
    );
  }
}
