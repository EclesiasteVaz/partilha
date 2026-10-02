import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brand and semantic colour tokens.
///
/// `AGENTS.md` §46 requires the design system to own colour. This type is the
/// single source of truth: [AppTheme] builds its [ColorScheme] *from* these
/// values rather than the other way round, so a Material component that reads
/// `colorScheme.primary` and a widget that reads `context.colors.primary` can
/// never disagree.
///
/// ## Dark first
///
/// The product is dark-first: [neonDark] is the brand and [neonLight] exists
/// for users whose system demands a light surface. That ordering is why the
/// bright palette is named `neonDark` rather than treating light as the default
/// with a dark variant.
///
/// ## Why the light palette is not neon
///
/// Neon is emissive: it only reads as neon against a near-black field. Against
/// white, the same cyan drops to 2.4:1 and the magenta to 3.0:1, both below the
/// 4.5:1 floor for body text. So light mode uses deeper, desaturated
/// equivalents of the same hues. The brand hue is preserved; the luminosity is
/// not. This is a deliberate consequence of §50, not an oversight.
///
/// ## Why the semantic colours are ordered by luminance
///
/// Saturated neon colours all sit near the top of the luminance range, so a
/// naive neon trio is indistinguishable in greyscale: an early draft had
/// success at L=0.79 and warning at L=0.48 but the two read as the same grey,
/// and green/yellow is exactly the pair deuteranopia collapses.
///
/// The three states are therefore spread across the luminance range
/// (dark theme 0.79 / 0.48 / 0.28; light theme 0.14 / 0.07 / 0.04) so they
/// remain separable without hue. `app_colors_test.dart` asserts that ordering,
/// and the theme pairs every state with an icon and a text label so colour is
/// never the only signal either (§84).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.onSurface,
    required this.surfaceMuted,
    required this.onSurfaceMuted,
    required this.outline,
    required this.outlineStrong,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.glow,
  });

  /// Default background.
  final Color surface;

  /// Default body text on [surface].
  final Color onSurface;

  /// Deemphasised background for cards and wells.
  final Color surfaceMuted;

  /// Secondary text on [surface] and [surfaceMuted].
  final Color onSurfaceMuted;

  /// Hairline dividers.
  ///
  /// Exempt from the 3:1 non-text target: a divider is decorative structure,
  /// not a control boundary. [outlineStrong] is the one that has to be
  /// perceivable.
  final Color outline;

  /// Borders, focus rings and control outlines. Must reach 3:1 on [surface].
  final Color outlineStrong;

  /// Brand colour. Primary actions, links, active state.
  final Color primary;

  /// Content drawn on [primary].
  final Color onPrimary;

  /// Brand accent. Secondary emphasis and highlights.
  final Color secondary;

  /// Content drawn on [secondary].
  final Color onSecondary;

  /// Completed operations.
  final Color success;

  /// Content drawn on [success].
  final Color onSuccess;

  /// Recoverable problems.
  final Color warning;

  /// Content drawn on [warning].
  final Color onWarning;

  /// Destructive actions and errors.
  final Color danger;

  /// Content drawn on [danger].
  final Color onDanger;

  /// Halo colour for the neon accent.
  ///
  /// Used for focus rings and elevation shadows. Never the only carrier of
  /// meaning: a glow that is the only difference between two states fails
  /// §84, and it is invisible to a user who turned off animations or to a
  /// screen with low contrast.
  final Color glow;

  /// The dark brand palette.
  ///
  /// Surfaces are near-black with a blue-violet cast rather than pure black:
  /// pure black against saturated neon reads harsh, and OLED smear on a dark
  /// scroll is visible on scroll-up.
  static const AppColors neonDark = AppColors(
    surface: Color(0xFF0B0B12),
    onSurface: Color(0xFFF0F0F5),
    surfaceMuted: Color(0xFF16161F),
    onSurfaceMuted: Color(0xFFA0A0B0),
    outline: Color(0xFF2A2A38),
    outlineStrong: Color(0xFF6B6B85),
    primary: Color(0xFF22D3EE),
    onPrimary: Color(0xFF04141A),
    secondary: Color(0xFFFF2D95),
    onSecondary: Color(0xFF1A0411),
    success: Color(0xFF7CFFB2),
    onSuccess: Color(0xFF032014),
    warning: Color(0xFFFFA300),
    onWarning: Color(0xFF1F1400),
    danger: Color(0xFFFF4D6D),
    onDanger: Color(0xFF26040C),
    glow: Color(0xFF4DE8FF),
  );

  /// The light palette.
  ///
  /// Deeper, desaturated equivalents of the brand hues. See the class comment
  /// for why this is not simply the neon palette inverted.
  static const AppColors neonLight = AppColors(
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF12121A),
    surfaceMuted: Color(0xFFF4F5F8),
    onSurfaceMuted: Color(0xFF55556A),
    outline: Color(0xFFDCDEE6),
    outlineStrong: Color(0xFF8A8CA0),
    primary: Color(0xFF0E7490),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFB0106A),
    onSecondary: Color(0xFFFFFFFF),
    success: Color(0xFF12794F),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFF6B3F00),
    onWarning: Color(0xFFFFFFFF),
    danger: Color(0xFF7A0A24),
    onDanger: Color(0xFFFFFFFF),
    glow: Color(0xFF0E7490),
  );

  /// Seed handed to Material's tonal palette.
  ///
  /// Only used to keep `ColorScheme` internally coherent (its error colours,
  /// containers and inverse pairs). The values this class actually exposes are
  /// assigned explicitly, so the seed does not decide the brand colour.
  static Color get seed => neonDark.primary;

  /// Overlays these tokens onto a Material [ColorScheme].
  ///
  /// Material components read `colorScheme`, not `AppColors`. Without this the
  /// two would drift the moment a component is styled from the scheme, which is
  /// the usual way a design system silently loses control of its own palette.
  ColorScheme applyTo(ColorScheme base) => base.copyWith(
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: surfaceMuted,
    onPrimaryContainer: onSurface,
    secondary: secondary,
    onSecondary: onSecondary,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceMuted,
    onSurfaceVariant: onSurfaceMuted,
    outline: outlineStrong,
    outlineVariant: outline,
    error: danger,
    onError: onDanger,
    inverseSurface: onSurface,
    onInverseSurface: surface,
  );

  /// The palette for [brightness].
  static AppColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? neonDark : neonLight;

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
    Color? surface,
    Color? onSurface,
    Color? surfaceMuted,
    Color? onSurfaceMuted,
    Color? outline,
    Color? outlineStrong,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
    Color? glow,
  }) => AppColors(
    surface: surface ?? this.surface,
    onSurface: onSurface ?? this.onSurface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
    outline: outline ?? this.outline,
    outlineStrong: outlineStrong ?? this.outlineStrong,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    secondary: secondary ?? this.secondary,
    onSecondary: onSecondary ?? this.onSecondary,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    glow: glow ?? this.glow,
  );

  /// Switches between two palettes at the halfway point instead of
  /// interpolating between them.
  ///
  /// The two palettes are not two settings of one design. The dark palette is
  /// neon on a near-black field; the light palette is deep teal on white. They
  /// have different lightness, different contrast behaviour and different
  /// semantic colour luminances. Interpolating between them yields intermediate
  /// colours that belong to neither design.
  ///
  /// That is not only an aesthetic objection, it is a measurable failure. With
  /// a per-channel lerp, the midpoint of the animation put `onSurface` at
  /// 1.05:1 against the interpolated surface, and `primary` at 1.24:1, because
  /// a near-white foreground, a near-black foreground and a near-black surface
  /// all converge on mid-grey. Text would be invisible for the duration of
  /// every theme animation.
  ///
  /// Selecting the closer palette keeps every token at its designed contrast
  /// for the whole transition. `app_colors_test.dart` sweeps the interpolation
  /// and asserts legibility at each step, so this cannot silently regress into
  /// a naive lerp.
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}
