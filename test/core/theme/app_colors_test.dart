import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/theme/theme.dart';

/// WCAG 2.1 minimum contrast ratios.
///
/// §50 makes sufficient contrast a requirement, so it is asserted rather than
/// assumed. 4.5 is AA for normal text; 3.0 is the AA ceiling for large text
/// and for non-text UI such as borders and icons.
const double _aaBody = 4.5;
const double _aaNonText = 3.0;

/// Minimum luminance separation between semantic states.
///
/// A greyscale or colour-blind user reads state by lightness when hue is gone.
/// Requiring a 1.35x luminance ratio means the three states stay separable
/// without relying on colour at all, which is what §84 asks for.
const double _minLuminanceRatio = 1.35;

void main() {
  group('contrast maths', () {
    test('matches the WCAG reference values', () {
      // Black on white is the specification maximum; identical colours collapse
      // to 1; mid-grey is ~4.48 against white.
      expect(AppColors.contrast(Colors.black, Colors.white), closeTo(21, 0.1));
      expect(AppColors.contrast(Colors.grey, Colors.grey), closeTo(1, 0.01));
      expect(AppColors.contrast(Colors.white, Colors.black), closeTo(21, 0.1));
      expect(
        AppColors.contrast(const Color(0xFF777777), Colors.white),
        closeTo(4.48, 0.02),
      );
    });

    test('is symmetric', () {
      const Color a = Color(0xFF22D3EE);
      const Color b = Color(0xFFFF2D95);
      expect(
        AppColors.contrast(a, b),
        closeTo(AppColors.contrast(b, a), 0.0001),
      );
    });
  });

  /// Shared assertions for one palette.
  void verifyPalette(String label, AppColors colors) {
    group(label, () {
      void expectLegible(String name, Color fg, Color bg) {
        final double ratio = AppColors.contrast(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(_aaBody),
          reason:
              '$label $name on #${bg.toARGB32().toRadixString(16)} is '
              '$ratio:1, below the $_aaBody:1 target',
        );
      }

      test('body text is legible on both surfaces', () {
        expectLegible('onSurface', colors.onSurface, colors.surface);
        expectLegible('onSurfaceMuted', colors.onSurfaceMuted, colors.surface);
        expectLegible(
          'onSurfaceMuted',
          colors.onSurfaceMuted,
          colors.surfaceMuted,
        );
      });

      test('every brand and semantic colour is legible as text', () {
        // These are used for links, inline status and icon glyphs, so each has
        // to clear the body-text ratio against the surface, not just 3:1.
        expectLegible('primary', colors.primary, colors.surface);
        expectLegible('primary', colors.primary, colors.surfaceMuted);
        expectLegible('secondary', colors.secondary, colors.surface);
        expectLegible('success', colors.success, colors.surface);
        expectLegible('warning', colors.warning, colors.surface);
        expectLegible('danger', colors.danger, colors.surface);
      });

      test('every filled surface picks a readable foreground', () {
        expectLegible('onPrimary', colors.onPrimary, colors.primary);
        expectLegible('onSecondary', colors.onSecondary, colors.secondary);
        expectLegible('onSuccess', colors.onSuccess, colors.success);
        expectLegible('onWarning', colors.onWarning, colors.warning);
        expectLegible('onDanger', colors.onDanger, colors.danger);
      });

      test('the control outline is perceivable without colour', () {
        // §84: a boundary that only exists as a hue change is invisible to a
        // greyscale or low-contrast user.
        expect(
          AppColors.contrast(colors.outlineStrong, colors.surface),
          greaterThanOrEqualTo(_aaNonText),
          reason: '$label outlineStrong must be visible as a boundary',
        );
      });

      test('semantic states are separable without hue', () {
        // The reason the neon trio is spread across the luminance range
        // instead of all being maximally bright.
        final Map<String, Color> states = <String, Color>{
          'success': colors.success,
          'warning': colors.warning,
          'danger': colors.danger,
        };

        final List<String> names = states.keys.toList()..sort();
        for (int i = 0; i < names.length; i++) {
          for (int j = i + 1; j < names.length; j++) {
            final double a = AppColors.luminance(states[names[i]]!);
            final double b = AppColors.luminance(states[names[j]]!);
            final double ratio = a > b ? a / b : b / a;
            expect(
              ratio,
              greaterThanOrEqualTo(_minLuminanceRatio),
              reason:
                  '$label ${names[i]} and ${names[j]} differ in luminance by '
                  'only ${ratio.toStringAsFixed(2)}x, so they look like the '
                  'same grey',
            );
          }
        }
      });

      test('the glow clears the non-text ratio', () {
        // A palette invariant, not a UI guarantee: no widget consumes glow yet,
        // so this only guarantees that the token is usable as a visible
        // accent by the first screen that needs one. It says nothing about a
        // specific element.
        expect(
          AppColors.contrast(colors.glow, colors.surface),
          greaterThanOrEqualTo(_aaNonText),
          reason: '$label glow must be visible against its own surface',
        );
      });

      test('surfaces are distinct from each other', () {
        expect(colors.surface, isNot(colors.surfaceMuted));
      });
    });
  }

  verifyPalette('dark', AppColors.neonDark);
  verifyPalette('light', AppColors.neonLight);

  group('dark-first ordering', () {
    test('the app boots in dark mode', () {
      expect(AppTheme.mode, ThemeMode.dark);
    });

    test('the dark palette is the brand', () {
      // Asserted so a future edit that promotes light to primary is deliberate.
      expect(AppColors.forBrightness(Brightness.dark), AppColors.neonDark);
      expect(AppColors.forBrightness(Brightness.light), AppColors.neonLight);
    });

    test('dark is darker than light', () {
      expect(
        AppColors.luminance(AppColors.neonDark.surface),
        lessThan(AppColors.luminance(AppColors.neonLight.surface)),
      );
    });

    test('the brand hue is shared across both palettes', () {
      // Same family, different luminosity. Neon against white fails contrast,
      // so the hue is preserved and the lightness is not. This is what keeps
      // the light palette reading as Partilha rather than as a generic scheme.
      // HSLColor.hue is in degrees and wraps at 360, so compare the shortest
      // angular distance rather than a plain subtraction.
      double hueDelta(Color a, Color b) {
        final double d =
            (HSLColor.fromColor(a).hue - HSLColor.fromColor(b).hue).abs() % 360;
        return d > 180 ? 360 - d : d;
      }

      expect(
        hueDelta(AppColors.neonLight.primary, AppColors.neonDark.primary),
        lessThan(8),
      );
      expect(
        hueDelta(AppColors.neonLight.secondary, AppColors.neonDark.secondary),
        lessThan(8),
      );
    });

    test('light is the desaturated counterpart, not the neon one', () {
      double lightness(Color color) => HSLColor.fromColor(color).lightness;

      // Neon needs a near-black field. Proving the light primary really is
      // darker than the dark one guards against someone "simplifying" the two
      // palettes into one value and breaking contrast in light mode.
      expect(
        lightness(AppColors.neonLight.primary),
        lessThan(lightness(AppColors.neonDark.primary)),
      );
    });
  });

  group('ColorScheme stays in sync with AppColors', () {
    test('dark overlays the brand values onto the scheme', () {
      final ColorScheme scheme = AppTheme.dark.colorScheme;
      expect(scheme.primary, AppColors.neonDark.primary);
      expect(scheme.onPrimary, AppColors.neonDark.onPrimary);
      expect(scheme.secondary, AppColors.neonDark.secondary);
      expect(scheme.surface, AppColors.neonDark.surface);
      expect(scheme.onSurface, AppColors.neonDark.onSurface);
      expect(scheme.error, AppColors.neonDark.danger);
      expect(scheme.onError, AppColors.neonDark.onDanger);
    });

    test('light overlays the brand values onto the scheme', () {
      final ColorScheme scheme = AppTheme.light.colorScheme;
      expect(scheme.primary, AppColors.neonLight.primary);
      expect(scheme.onPrimary, AppColors.neonLight.onPrimary);
      expect(scheme.error, AppColors.neonLight.danger);
    });

    test('the surface a Material component reads is the palette surface', () {
      // The usual way a design system loses control of its own palette: a
      // component styled from colorScheme drifts from context.colors.
      for (final AppColors colors in <AppColors>[
        AppColors.neonDark,
        AppColors.neonLight,
      ]) {
        final ThemeData theme = colors == AppColors.neonDark
            ? AppTheme.dark
            : AppTheme.light;
        expect(theme.scaffoldBackgroundColor, colors.surface);
        expect(theme.extension<AppColors>(), colors);
      }
    });
  });

  group('theme extension plumbing', () {
    test('lerp returns the endpoints exactly', () {
      expect(
        AppColors.neonDark.lerp(AppColors.neonLight, 0).primary,
        AppColors.neonDark.primary,
      );
      expect(
        AppColors.neonDark.lerp(AppColors.neonLight, 1).primary,
        AppColors.neonLight.primary,
      );
    });

    test('lerp tolerates a missing extension', () {
      // Happens mid theme-animation before a widget's theme has picked up the
      // new extension set; must not throw.
      expect(AppColors.neonDark.lerp(null, 0.5), same(AppColors.neonDark));
    });

    test('lerp switches palettes at the halfway point', () {
      // Deliberate: see AppColors.lerp. Interpolating these two palettes was
      // measured at 1.05:1 for body text at the midpoint.
      expect(
        AppColors.neonDark.lerp(AppColors.neonLight, 0.49),
        same(AppColors.neonDark),
      );
      expect(
        AppColors.neonDark.lerp(AppColors.neonLight, 0.5),
        same(AppColors.neonLight),
      );
    });

    test('every step of the interpolation stays legible', () {
      // Sweeps the whole range rather than sampling the midpoint. This is the
      // assertion that keeps AppColors.lerp from regressing into a naive lerp:
      // if someone reintroduces Color.lerp, some step here goes unreadable.
      for (int i = 0; i <= 20; i++) {
        final double t = i / 20;
        final AppColors frame = AppColors.neonDark.lerp(AppColors.neonLight, t);
        final String at = 'at t=$t';

        expect(
          AppColors.contrast(frame.onSurface, frame.surface),
          greaterThanOrEqualTo(_aaBody),
          reason: 'onSurface is not legible $at',
        );
        expect(
          AppColors.contrast(frame.onSurfaceMuted, frame.surfaceMuted),
          greaterThanOrEqualTo(_aaBody),
          reason: 'onSurfaceMuted is not legible $at',
        );
        // The accents double as text, so they are held to the text ratio too.
        for (final MapEntry<String, Color> entry in <String, Color>{
          'primary': frame.primary,
          'secondary': frame.secondary,
          'success': frame.success,
          'warning': frame.warning,
          'danger': frame.danger,
        }.entries) {
          expect(
            AppColors.contrast(entry.value, frame.surface),
            greaterThanOrEqualTo(_aaBody),
            reason: '${entry.key} is not legible on the surface $at',
          );
          expect(
            AppColors.contrast(frame.onSurface, frame.surface),
            greaterThanOrEqualTo(_aaBody),
            reason: 'body text is not legible $at',
          );
        }
        // Filled pairs stay readable too.
        expect(
          AppColors.contrast(frame.onPrimary, frame.primary),
          greaterThanOrEqualTo(_aaBody),
          reason: 'onPrimary $at',
        );
        expect(
          AppColors.contrast(frame.onDanger, frame.danger),
          greaterThanOrEqualTo(_aaBody),
          reason: 'onDanger $at',
        );
        expect(
          AppColors.contrast(frame.onSuccess, frame.success),
          greaterThanOrEqualTo(_aaBody),
          reason: 'onSuccess $at',
        );
        expect(
          AppColors.contrast(frame.onWarning, frame.warning),
          greaterThanOrEqualTo(_aaBody),
          reason: 'onWarning $at',
        );
        expect(
          AppColors.contrast(frame.onSecondary, frame.secondary),
          greaterThanOrEqualTo(_aaBody),
          reason: 'onSecondary $at',
        );
      }
    });
  });
}
