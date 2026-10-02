import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography tokens.
///
/// §48 requires typography to be owned by the design system, so no widget
/// builds a `TextStyle` by hand. Every style here is derived from the active
/// [TextTheme], which means a single text-scale change or locale change
/// propagates without touching call sites.
///
/// Sizes are deliberately restrained. Partilha surfaces file names and device
/// names, so the display sizes are large enough for glanceability and small
/// enough that long names still fit (§49).
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.displayLarge,
    required this.displaySmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.mono,
  });

  /// Screen-scale heading. Used only for empty states and first-run.
  final TextStyle displayLarge;

  /// Section heading on a detail screen.
  final TextStyle displaySmall;

  /// Screen title in an app bar.
  final TextStyle titleLarge;

  /// Card or list-section title.
  final TextStyle titleMedium;

  /// List row title, typically a file or device name.
  final TextStyle titleSmall;

  /// Default reading text.
  final TextStyle bodyLarge;

  /// Default supporting text.
  final TextStyle bodyMedium;

  /// Legal and metadata text.
  final TextStyle bodySmall;

  /// Button text.
  final TextStyle labelLarge;

  /// Field label and badge text.
  final TextStyle labelMedium;

  /// Technical values such as an address or a token fingerprint.
  ///
  /// Monospace so digits align in a column and a mistyped character is visible.
  /// Used for diagnostics and never for anything the user must read fluently.
  final TextStyle mono;

  /// Builds the scale for [scheme].
  ///
  /// Sizes are declared here rather than read from [base]. `ThemeData.textTheme`
  /// resolves lazily and hands back `null` for every `fontSize` on Flutter
  /// 3.44, so deriving from it produces styles with no size at all, which then
  /// silently inherit whatever `DefaultTextStyle` happens to provide. Owning
  /// the numbers is what §48 asks for and is the only way the sizes are
  /// testable.
  ///
  /// The scale follows Material 3 proportions, pulled in slightly at the top so
  /// long device and file names fit without truncation (§49). [height] is
  /// applied so a style cannot collapse when the user enlarges text (§50).
  factory AppTextStyles.from(TextTheme base, ColorScheme scheme) {
    TextStyle style(
      TextStyle? seed, {
      required double size,
      double height = 1.43,
      FontWeight weight = FontWeight.w400,
      Color? color,
    }) => (seed ?? const TextStyle()).copyWith(
      fontSize: size,
      height: height,
      fontWeight: weight,
      color: color ?? scheme.onSurface,
    );

    return AppTextStyles(
      displayLarge: style(
        base.displayLarge,
        size: 34,
        height: 1.25,
        weight: FontWeight.w700,
      ),
      displaySmall: style(
        base.displaySmall,
        size: 28,
        height: 1.25,
        weight: FontWeight.w600,
      ),
      titleLarge: style(
        base.titleLarge,
        size: 22,
        height: 1.25,
        weight: FontWeight.w600,
      ),
      titleMedium: style(
        base.titleMedium,
        size: 18,
        height: 1.3,
        weight: FontWeight.w600,
      ),
      titleSmall: style(
        base.titleSmall,
        size: 16,
        height: 1.3,
        weight: FontWeight.w600,
      ),
      bodyLarge: style(base.bodyLarge, size: 16),
      bodyMedium: style(base.bodyMedium, size: 14),
      bodySmall: style(
        base.bodySmall,
        size: 12,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: style(base.labelLarge, size: 14, weight: FontWeight.w600),
      labelMedium: style(
        base.labelMedium,
        size: 12,
        weight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
      // Sized to match bodyMedium so a value in a list row lines up with the
      // label beside it, and explicit because a null size here would inherit
      // whatever the surrounding DefaultTextStyle happens to be.
      mono: const TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: <String>['Menlo', 'Courier New', 'monospace'],
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        fontSize: 14,
        height: 1.43,
      ).copyWith(color: scheme.onSurface),
    );
  }

  @override
  AppTextStyles copyWith({
    TextStyle? displayLarge,
    TextStyle? displaySmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? mono,
  }) => AppTextStyles(
    displayLarge: displayLarge ?? this.displayLarge,
    displaySmall: displaySmall ?? this.displaySmall,
    titleLarge: titleLarge ?? this.titleLarge,
    titleMedium: titleMedium ?? this.titleMedium,
    titleSmall: titleSmall ?? this.titleSmall,
    bodyLarge: bodyLarge ?? this.bodyLarge,
    bodyMedium: bodyMedium ?? this.bodyMedium,
    bodySmall: bodySmall ?? this.bodySmall,
    labelLarge: labelLarge ?? this.labelLarge,
    labelMedium: labelMedium ?? this.labelMedium,
    mono: mono ?? this.mono,
  );

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) return this;
    return AppTextStyles(
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      displaySmall: TextStyle.lerp(displaySmall, other.displaySmall, t)!,
      titleLarge: TextStyle.lerp(titleLarge, other.titleLarge, t)!,
      titleMedium: TextStyle.lerp(titleMedium, other.titleMedium, t)!,
      titleSmall: TextStyle.lerp(titleSmall, other.titleSmall, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      labelLarge: TextStyle.lerp(labelLarge, other.labelLarge, t)!,
      labelMedium: TextStyle.lerp(labelMedium, other.labelMedium, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
    );
  }
}

/// Shorthand for [AppTextStyles] from a [BuildContext].
///
/// Widgets read `context.textStyles.titleMedium` instead of repeating the
/// `Theme.of(context).extension<AppTextStyles>()!` lookup, which is verbose
/// enough that people bypass it and hard-code styles (§48).
extension AppTextStylesContext on BuildContext {
  AppTextStyles get textStyles => Theme.of(this).extension<AppTextStyles>()!;

  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
