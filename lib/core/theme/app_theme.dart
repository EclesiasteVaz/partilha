import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'tokens.dart';

/// Builds the app's themes.
///
/// ## Dark first
///
/// The product is dark-first, so [dark] is the canonical theme and the one the
/// app starts in. [light] is a derived, restrained counterpart for users whose
/// system requires a light surface; see [AppColors] for why it is not simply
/// the neon palette inverted.
///
/// Both are `final`, not getters. Building a theme runs `ColorScheme.fromSeed`
/// and rebuilds the text scale, so a getter would repeat that work on every
/// access, including incidental reads in tests and rebuilds.
abstract final class AppTheme {
  /// The brand palette. Dark is the design target.
  static final ThemeData dark = _build(AppColors.neonDark, Brightness.dark);

  /// Light counterpart. Not the primary design.
  static final ThemeData light = _build(AppColors.neonLight, Brightness.light);

  /// The mode the app boots with.
  ///
  /// Dark, matching the design focus. Switching to [ThemeMode.system] is the
  /// one-line change if the project later decides to follow the platform; the
  /// light palette already passes the same contrast gates.
  static const ThemeMode mode = ThemeMode.dark;

  static ThemeData _build(AppColors colors, Brightness brightness) {
    // Material's tonal palette supplies the container and inverse pairs that
    // AppColors does not name. The brand values are then overlaid so a
    // component reading colorScheme agrees with one reading context.colors.
    final ColorScheme scheme = colors.applyTo(
      ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: brightness),
    );

    final ThemeData base = ThemeData(colorScheme: scheme);
    final AppTextStyles styles = AppTextStyles.from(base.textTheme, scheme);
    const BorderRadius buttonShape = BorderRadius.all(
      Radius.circular(AppRadii.sm),
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[colors, styles],
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      dividerTheme: DividerThemeData(color: colors.outline, space: 1),
      textTheme: _scaledTextTheme(base.textTheme, styles),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: styles.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          shape: const RoundedRectangleBorder(borderRadius: buttonShape),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          side: BorderSide(color: colors.outlineStrong),
          shape: const RoundedRectangleBorder(borderRadius: buttonShape),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSizes.minTouchTarget),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: AppSpacing.sm,
        shape: RoundedRectangleBorder(borderRadius: buttonShape),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceMuted,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.onSurface,
        contentTextStyle: styles.bodyMedium.copyWith(color: colors.surface),
      ),
      // Keyboard focus is the one place a neon design can go too far: a glow
      // alone disappears for a user who cannot perceive the hue, and for anyone
      // the focus indicator disappears. So the ring is a solid outline in
      // outlineStrong, and the glow only reinforces it. §50, §84.
      focusColor: colors.primary.withValues(alpha: 0.16),
      hoverColor: colors.primary.withValues(alpha: 0.08),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  /// Applies the same sizes as [AppTextStyles] to the ambient [TextTheme], so
  /// Material components that read `textTheme` match the project's own styles
  /// instead of drifting apart from them.
  static TextTheme _scaledTextTheme(TextTheme base, AppTextStyles styles) =>
      base.copyWith(
        displayLarge: styles.displayLarge,
        displayMedium: styles.displayLarge,
        displaySmall: styles.displaySmall,
        headlineLarge: styles.displaySmall,
        headlineMedium: styles.titleLarge,
        headlineSmall: styles.titleLarge,
        titleLarge: styles.titleLarge,
        titleMedium: styles.titleMedium,
        titleSmall: styles.titleSmall,
        bodyLarge: styles.bodyLarge,
        bodyMedium: styles.bodyMedium,
        bodySmall: styles.bodySmall,
        labelLarge: styles.labelLarge,
        labelMedium: styles.labelMedium,
      );
}
