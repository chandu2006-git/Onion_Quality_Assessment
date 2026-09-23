
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Typography hierarchy: technical, authoritative, generous letter spacing on
/// uppercase labels.
class AppTextStyles {
  const AppTextStyles._();

  static const TextStyle display = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.08,
  );

  static const TextStyle pageHeading = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle cardHeading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.65,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static const TextStyle metric = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static const TextStyle metricSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static TextTheme applyTo(TextTheme base) => base.copyWith(
        displayLarge: display.copyWith(color: AppTheme.primary),
        displayMedium: pageHeading.copyWith(color: AppTheme.primary),
        headlineMedium: pageHeading.copyWith(color: AppTheme.primary),
        headlineSmall: sectionHeading.copyWith(color: AppTheme.primary),
        titleLarge: sectionHeading.copyWith(color: AppTheme.charcoal),
        titleMedium: cardHeading.copyWith(color: AppTheme.charcoal),
        bodyLarge: body.copyWith(color: AppTheme.charcoal),
        bodyMedium: bodySmall.copyWith(color: AppTheme.secondaryText),
        labelLarge: label.copyWith(color: AppTheme.secondaryText),
      );
}
