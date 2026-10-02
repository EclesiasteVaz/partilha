import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/theme/theme.dart';

/// WCAG 2.1 minimum contrast ratios.
///
/// §50 makes sufficient contrast a requirement, so it is asserted rather than
/// assumed. `4.5` is AA for normal text; `3.0` is the AA ceiling for large
/// text and for non-text UI such as borders and icons.
const double _aaBody = 4.5;
const double _aaNonText = 3.0;

void main() {
  group('contrast', () {
    test('matches the WCAG reference values', () {
      // The three anchors from the specification: black on white is the
      // maximum, identical colours collapse to 1, and mid-grey is ~7.4.
      expect(AppColors.contrast(Colors.black, Colors.white), closeTo(21, 0.1));
      expect(AppColors.contrast(Colors.grey, Colors.grey), closeTo(1, 0.01));
      expect(AppColors.contrast(Colors.white, Colors.black), closeTo(21, 0.1));
      expect(
        AppColors.contrast(const Color(0xFF777777), Colors.white),
        closeTo(4.48, 0.02),
      );
    });

    test('is symmetric', () {
      const Color a = Color(0xFF0F6E78);
      const Color b = Color(0xFF123456);
      expect(
        AppColors.contrast(a, b),
        closeTo(AppColors.contrast(b, a), 0.0001),
      );
    });
  });

  group('light palette', () {
    final AppColors colors = AppTheme.light.extension<AppColors>()!;

    void expectLegible(
      String name,
      Color fg,
      Color bg, {
      double min = _aaBody,
    }) {
      final double ratio = AppColors.contrast(fg, bg);
      expect(
        ratio,
        greaterThanOrEqualTo(min),
        reason:
            '$name on ${bg.toARGB32().toRadixString(16)} is $ratio:1, below '
            'the $min:1 target',
      );
    }

    test('body text is legible on the surface', () {
      expectLegible('onSurface', colors.onSurface, colors.surface);
      expectLegible('onSurfaceMuted', colors.onSurfaceMuted, colors.surface);
      expectLegible(
        'onSurfaceMuted',
        colors.onSurfaceMuted,
        colors.surfaceMuted,
      );
    });

    test('filled surfaces pick a readable foreground', () {
      expectLegible('onPrimary', colors.onPrimary, colors.primary);
      expectLegible('onSecondary', colors.onSecondary, colors.secondary);
      expectLegible('onDanger', colors.onDanger, colors.danger);
      expectLegible('onWarning', colors.onWarning, colors.warning);
      expectLegible('onSuccess', colors.onSuccess, colors.success);
      expectLegible('onInfo', colors.onInfo, colors.info);
    });

    test('the chosen foreground is genuinely the better one', () {
      // Guards against the foreground picker silently regressing to a fixed
      // colour that happens to pass today.
      expect(colors.onPrimary, AppColors.foregroundOn(colors.primary));
      expect(colors.onSuccess, AppColors.foregroundOn(colors.success));
    });

    test('borders and focus outlines are visible without colour', () {
      // §84 forbids relying on colour alone, so the strong outline has to be
      // perceivable against the surface it is drawn on.
      expect(
        AppColors.contrast(colors.outlineStrong, colors.surface),
        greaterThanOrEqualTo(_aaNonText),
      );
    });
  });

  group('dark palette', () {
    final AppColors colors = AppTheme.dark.extension<AppColors>()!;

    void expectLegible(
      String name,
      Color fg,
      Color bg, {
      double min = _aaBody,
    }) {
      final double ratio = AppColors.contrast(fg, bg);
      expect(
        ratio,
        greaterThanOrEqualTo(min),
        reason:
            'dark $name on ${bg.toARGB32().toRadixString(16)} is $ratio:1, '
            'below the $min:1 target',
      );
    }

    test('body text is legible on the surface', () {
      expectLegible('onSurface', colors.onSurface, colors.surface);
      expectLegible('onSurfaceMuted', colors.onSurfaceMuted, colors.surface);
      expectLegible(
        'onSurfaceMuted',
        colors.onSurfaceMuted,
        colors.surfaceMuted,
      );
    });

    test('filled surfaces pick a readable foreground', () {
      expectLegible('onPrimary', colors.onPrimary, colors.primary);
      expectLegible('onSecondary', colors.onSecondary, colors.secondary);
      expectLegible('onDanger', colors.onDanger, colors.danger);
      expectLegible('onWarning', colors.onWarning, colors.warning);
      expectLegible('onSuccess', colors.onSuccess, colors.success);
      expectLegible('onInfo', colors.onInfo, colors.info);
    });

    test('borders and focus outlines are visible without colour', () {
      expect(
        AppColors.contrast(colors.outlineStrong, colors.surface),
        greaterThanOrEqualTo(_aaNonText),
      );
    });
  });

  group('semantic colours', () {
    test('error and success are distinguishable from each other', () {
      // §84 forbids communicating state by colour alone; a red/green pair that
      // is also distinguishable by name is what the icon and text carry.
      final AppColors light = AppTheme.light.extension<AppColors>()!;
      expect(light.danger, isNot(light.success));
      expect(light.danger, isNot(light.warning));
    });

    test('the palettes differ in brightness', () {
      final AppColors light = AppTheme.light.extension<AppColors>()!;
      final AppColors dark = AppTheme.dark.extension<AppColors>()!;
      expect(
        AppColors.luminance(light.surface),
        greaterThan(AppColors.luminance(dark.surface)),
      );
    });
  });
}
