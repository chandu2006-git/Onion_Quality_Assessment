import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

/// Severity of an inline banner.
enum BannerSeverity { info, attention, success, error }

/// Inline message block. Status is never communicated by colour alone: every
/// banner carries an icon and explicit text.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.title,
    this.severity = BannerSeverity.info,
    this.action,
    this.details,
  });

  final String message;
  final String? title;
  final BannerSeverity severity;
  final Widget? action;
  final List<String>? details;

  Color get _accent {
    switch (severity) {
      case BannerSeverity.info:
        return AppTheme.secondaryGreen;
      case BannerSeverity.attention:
        return AppTheme.amberDark;
      case BannerSeverity.success:
        return AppTheme.healthy;
      case BannerSeverity.error:
        return AppTheme.unhealthy;
    }
  }

  Color get _surface {
    switch (severity) {
      case BannerSeverity.info:
        return AppTheme.lightGreen;
      case BannerSeverity.attention:
        return AppTheme.pendingSurface;
      case BannerSeverity.success:
        return AppTheme.healthySurface;
      case BannerSeverity.error:
        return AppTheme.unhealthySurface;
    }
  }

  IconData get _icon {
    switch (severity) {
      case BannerSeverity.info:
        return Icons.info_outline;
      case BannerSeverity.attention:
        return Icons.warning_amber_rounded;
      case BannerSeverity.success:
        return Icons.check_circle_outline;
      case BannerSeverity.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.s16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: _accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 20, color: _accent),
          const SizedBox(width: AppTheme.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!.toUpperCase(), style: AppTypo.label.copyWith(color: _accent)),
                  const SizedBox(height: AppTheme.s4),
                ],
                Text(message, style: AppTypo.body.copyWith(fontSize: 14)),
                if (details != null && details!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.s8),
                  ...details!.map(
                    (detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $detail', style: AppTypo.meta),
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppTheme.s12),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
