import 'package:flutter/material.dart';

import 'app_text_styles.dart';
import 'app_theme.dart';

/// Material 3 theme assembled from the ONION DETECT design tokens.
class AppThemeData {
  const AppThemeData._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTheme.primary,
        primary: AppTheme.primary,
        secondary: AppTheme.secondaryGreen,
        surface: AppTheme.white,
        error: AppTheme.unhealthy,
      ),
      scaffoldBackgroundColor: AppTheme.offWhite,
      dividerColor: AppTheme.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppTheme.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          side: const BorderSide(color: AppTheme.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _primaryButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: const BorderSide(color: AppTheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            letterSpacing: 1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.secondaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      inputDecorationTheme: _inputTheme,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppTheme.primary,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.charcoal,
        contentTextStyle: TextStyle(color: AppTheme.white, fontWeight: FontWeight.w500),
      ),
      hoverColor: AppTheme.lightGreen,
      focusColor: AppTheme.lightGreen,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(textTheme: AppTextStyles.applyTo(base.textTheme));
  }

  static final ButtonStyle _primaryButtonStyle = FilledButton.styleFrom(
    backgroundColor: AppTheme.primary,
    foregroundColor: AppTheme.white,
    disabledBackgroundColor: AppTheme.border,
    disabledForegroundColor: AppTheme.secondaryText,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
    ),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      letterSpacing: 1.1,
    ),
  );

  static final InputDecorationTheme _inputTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppTheme.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      borderSide: const BorderSide(color: AppTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      borderSide: const BorderSide(color: AppTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: const TextStyle(color: AppTheme.secondaryText, fontWeight: FontWeight.w500),
    floatingLabelStyle: const TextStyle(
      color: AppTheme.primary,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
  );
}

/// Shared text styles resolved against the brand colours.
class AppTypo {
  const AppTypo._();

  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppTheme.secondaryText,
  );

  static const TextStyle labelOnDark = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppTheme.lightGreen,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.65,
    color: AppTheme.charcoal,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppTheme.secondaryText,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppTheme.secondaryText,
  );

  static const TextStyle number = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.1,
    color: AppTheme.primary,
  );
}
