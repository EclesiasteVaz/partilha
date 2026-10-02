import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'tokens.dart';

/// Builds the app's light and dark themes.
///
/// §46 requires the design system to centralise colour, typography, spacing,
/// radii and elevation. Spacing and radii are constants in `tokens.dart`
/// because they do not change with brightness; colour and typography are
/// [ThemeExtension]s because both do, and a widget must be able to read them
/// from the ambient theme rather than knowing which brightness is active.
abstract final class AppTheme {
  /// Seed for both palettes. See [AppColors.seed].
  static Color get seed => AppColors.seed;

  /// Light theme.
  ///
  /// `final`, not a getter. Building a theme runs `ColorScheme.fromSeed` and
  /// rebuilds the text scale, so a getter would repeat that work on every
  /// access, including the incidental reads in tests and rebuilds. The theme is
  /// immutable once built, so it is computed exactly once.
  static final ThemeData light = _build(Brightness.light);

  /// Dark theme. See [light] for why this is `final`.
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final ThemeData base = ThemeData(colorScheme: scheme);

    final AppColors colors = brightness == Brightness.light
        ? AppColors.light(scheme)
        : AppColors.dark(scheme);

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        colors,
        AppTextStyles.from(base.textTheme, scheme),
      ],
      scaffoldBackgroundColor: colors.surface,
      dividerTheme: DividerThemeData(color: colors.outline, space: 1),
      // §50 requires text scaling to work. Material's default caps scaling on
      // large display text, which stops a user who needs 200% text from
      // getting it. Letting every style scale keeps the UI usable.
      textTheme: _scaledTextTheme(base.textTheme, scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTextStyles.from(base.textTheme, scheme).titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.sm)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          side: BorderSide(color: colors.outlineStrong),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.sm)),
          ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.sm)),
        ),
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
        contentTextStyle: AppTextStyles.from(
          base.textTheme,
          scheme,
        ).bodyMedium.copyWith(color: colors.surface),
      ),
    );
  }

  /// Applies the same sizes as [AppTextStyles.from] to the ambient
  /// [TextTheme], so Material components that read `textTheme` match the
  /// project's own styles instead of drifting.
  static TextTheme _scaledTextTheme(TextTheme base, ColorScheme scheme) {
    final AppTextStyles styles = AppTextStyles.from(base, scheme);
    return base.copyWith(
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
}
