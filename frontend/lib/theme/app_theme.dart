import 'package:flutter/material.dart';

/// Brand colour system. Restrained, agricultural, industrial.
class AppTheme {
  const AppTheme._();

  static const Color primary = Color(0xFF12372A);
  static const Color primaryDark = Color(0xFF0C2A1F);
  static const Color secondaryGreen = Color(0xFF2E6B4A);
  static const Color lightGreen = Color(0xFFE7F0EA);
  static const Color offWhite = Color(0xFFF7F5EF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color charcoal = Color(0xFF202622);
  static const Color secondaryText = Color(0xFF66716A);
  static const Color border = Color(0xFFD9E1DB);
  static const Color amber = Color(0xFFD39B35);
  static const Color amberDark = Color(0xFF9A6B14);

  /// Restrained status colours (never neon).
  static const Color healthy = Color(0xFF2E6B4A);
  static const Color unhealthy = Color(0xFFB03A3A);
  static const Color healthySurface = Color(0xFFE7F0EA);
  static const Color unhealthySurface = Color(0xFFF7E9E7);
  static const Color pendingSurface = Color(0xFFFBF2E0);

  /// 8px-based spacing scale.
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
  static const double s64 = 64;
  static const double s80 = 80;

  // --- Spacing aliases used across screens/widgets ----------------------
  // Canonical tokens above stay the source of truth; these short names keep
  // the existing screen code readable.
  static const double sm = s8;
  static const double md = s16;
  static const double lg = s24;
  static const double xl = s32;
  static const double xxl = s48;

  /// Horizontal padding of the main content container on small screens.
  static const double gutter = 20;

  /// Maximum width of the centred content column on very wide displays.
  static const double maxContentWidth = 1280;

  static const double cardRadius = 14;
  static const double panelRadius = 16;
  static const double buttonRadius = 10;
  static const double inputRadius = 10;
  static const double chipRadius = 6;
}
