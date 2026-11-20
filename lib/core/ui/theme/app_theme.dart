import 'package:cinema_app/core/ui/theme/app_colors.dart';
import 'package:cinema_app/core/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// The only theme of the app (light). There is no dark theme.
abstract final class AppTheme {
  static const double _buttonMinHeight = 44;

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
    );
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusS)),
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.m,
      vertical: AppSpacing.s,
    );
    const buttonMinSize = Size(64, _buttonMinHeight);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme(),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      inputDecorationTheme: const InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.m,
        ),
        border: _inputBorder,
        enabledBorder: _inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusM)),
        ),
      ),
    );
  }

  static const _inputRadius = BorderRadius.all(
    Radius.circular(AppSpacing.radiusS),
  );

  static const _inputBorder = OutlineInputBorder(
    borderRadius: _inputRadius,
    borderSide: BorderSide(color: AppColors.border),
  );

  static TextTheme _textTheme() {
    const primary = AppColors.textPrimary;
    const secondary = AppColors.textSecondary;
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontSize: 40,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      displaySmall: TextStyle(
        fontSize: 34,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: primary),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: primary),
      bodySmall: TextStyle(fontSize: 12, height: 1.35, color: secondary),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );
  }
}
