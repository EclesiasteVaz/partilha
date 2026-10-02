import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brand and semantic colour tokens.
///
/// Names describe intent, not hue, so a widget never has to know whether
/// "danger" is red today. That is the point of owning the palette (`AGENTS.md`
/// §46): a colour change happens here and nowhere else.
///
/// Values are placeholders chosen to be legible and calm for a local file
/// transfer tool. They are accessibility-verified by
/// `test/core/theme/app_colors_test.dart`, which fails the build if any
/// foreground/background pair drops below its WCAG target. Replacing the hue is
/// a local edit; the test is the contract that keeps it honest.
///
/// The primary seed is a teal-leaning blue. A saturated blue is the most
/// common default and reads as generic system chrome; teal separates Partilha
/// from stock Android and macOS surfaces without becoming a brand statement.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.surface,
    required this.onSurface,
    required this.surfaceMuted,
    required this.onSurfaceMuted,
    required this.outline,
    required this.outlineStrong,
    required this.danger,
    required this.onDanger,
    required this.warning,
    required this.onWarning,
    required this.success,
    required this.onSuccess,
    required this.info,
    required this.onInfo,
  });

  /// Brand colour for primary actions.
  final Color primary;

  /// Content drawn on [primary]. Must reach 4.5:1 against it.
  final Color onPrimary;

  /// Accent for secondary emphasis.
  final Color secondary;

  /// Content drawn on [secondary].
  final Color onSecondary;

  /// Default background.
  final Color surface;

  /// Default body text on [surface].
  final Color onSurface;

  /// Deemphasised background for cards and wells.
  final Color surfaceMuted;

  /// Secondary text on [surface] and [surfaceMuted].
  final Color onSurfaceMuted;

  /// Hairline borders and dividers.
  final Color outline;

  /// Borders that must be perceivable without relying on colour alone.
  final Color outlineStrong;

  /// Destructive actions and errors.
  final Color danger;

  /// Content drawn on [danger].
  final Color onDanger;

  /// Recoverable problems.
  final Color warning;

  /// Content drawn on [warning].
  final Color onWarning;

  /// Completed operations.
  final Color success;

  /// Content drawn on [success].
  final Color onSuccess;

  /// Neutral informational state.
  final Color info;

  /// Content drawn on [info].
  final Color onInfo;

  /// Light palette, derived from a single seed.
  static AppColors light(ColorScheme scheme) => AppColors(
    primary: scheme.primary,
    onPrimary: foregroundOn(scheme.primary),
    secondary: scheme.secondary,
    onSecondary: foregroundOn(scheme.secondary),
    surface: scheme.surface,
    onSurface: scheme.onSurface,
    surfaceMuted: scheme.surfaceContainerHighest,
    onSurfaceMuted: scheme.onSurfaceVariant,
    outline: scheme.outlineVariant,
    outlineStrong: scheme.outline,
    danger: scheme.error,
    onDanger: scheme.onError,
    warning: _warningLight,
    onWarning: foregroundOn(_warningLight),
    success: _successLight,
    onSuccess: foregroundOn(_successLight),
    info: scheme.primaryContainer,
    onInfo: scheme.onPrimaryContainer,
  );

  /// Dark palette, derived from the same seed.
  static AppColors dark(ColorScheme scheme) => AppColors(
    primary: scheme.primary,
    onPrimary: scheme.onPrimary,
    secondary: scheme.secondary,
    onSecondary: scheme.onSecondary,
    surface: scheme.surface,
    onSurface: scheme.onSurface,
    surfaceMuted: scheme.surfaceContainerHighest,
    onSurfaceMuted: scheme.onSurfaceVariant,
    outline: scheme.outlineVariant,
    outlineStrong: scheme.outline,
    danger: scheme.error,
    onDanger: scheme.onError,
    warning: _warningDark,
    onWarning: foregroundOn(_warningDark),
    success: _successDark,
    onSuccess: foregroundOn(_successDark),
    info: scheme.primaryContainer,
    onInfo: scheme.onPrimaryContainer,
  );

  /// Seed for both palettes.
  ///
  /// One seed keeps light and dark visually related instead of drifting into
  /// two unrelated colour schemes.
  static const Color seed = Color(0xFF0F6E78);

  /// Warning and success are fixed per brightness instead of taken from the
  /// generated [ColorScheme].
  ///
  /// Material's tonal palette does emit `tertiary` and `errorContainer`, but
  /// relying on whichever container the algorithm happened to pick makes the
  /// contrast target untestable. These are pinned so
  /// `app_colors_test.dart` can assert a hard ratio.
  static const Color _warningLight = Color(0xFF8A5A00);
  static const Color _warningDark = Color(0xFFFFB95C);
  static const Color _successLight = Color(0xFF1B6B33);
  static const Color _successDark = Color(0xFF6FDD8B);

  /// Near-black content colour, used when white is the wrong foreground.
  static const Color _ink = Color(0xFF11181C);

  /// Picks the foreground with the higher contrast against [background].
  ///
  /// Computing the foreground instead of hard-coding white is what stops a
  /// future palette change from silently producing unreadable buttons.
  static Color foregroundOn(Color background) =>
      contrast(background, Colors.white) >= contrast(background, _ink)
      ? Colors.white
      : _ink;

  /// Relative luminance per WCAG 2.1.
  static double luminance(Color color) {
    double channel(double component) => component <= 0.03928
        ? component / 12.92
        : math.pow((component + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// WCAG contrast ratio between two colours, from 1.0 to 21.0.
  static double contrast(Color a, Color b) {
    final double la = luminance(a);
    final double lb = luminance(b);
    final double lighter = la > lb ? la : lb;
    final double darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  @override
  AppColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? surface,
    Color? onSurface,
    Color? surfaceMuted,
    Color? onSurfaceMuted,
    Color? outline,
    Color? outlineStrong,
    Color? danger,
    Color? onDanger,
    Color? warning,
    Color? onWarning,
    Color? success,
    Color? onSuccess,
    Color? info,
    Color? onInfo,
  }) => AppColors(
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    secondary: secondary ?? this.secondary,
    onSecondary: onSecondary ?? this.onSecondary,
    surface: surface ?? this.surface,
    onSurface: onSurface ?? this.onSurface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
    outline: outline ?? this.outline,
    outlineStrong: outlineStrong ?? this.outlineStrong,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    info: info ?? this.info,
    onInfo: onInfo ?? this.onInfo,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
    );
  }
}
