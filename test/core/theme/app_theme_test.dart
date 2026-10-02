import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/theme/theme.dart';

void main() {
  group('spacing', () {
    test('steps increase monotonically', () {
      final List<double> scale = <double>[
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ];
      for (int i = 1; i < scale.length; i++) {
        expect(
          scale[i],
          greaterThan(scale[i - 1]),
          reason: 'spacing step ${i - 1} -> $i must grow',
        );
      }
    });

    test('page padding grows with width for §49 responsiveness', () {
      final double phone = AppSpacing.pageHorizontal(400);
      final double tablet = AppSpacing.pageHorizontal(800);
      final double desktop = AppSpacing.pageHorizontal(1400);

      expect(phone, lessThan(tablet));
      expect(tablet, lessThan(desktop));
      // A phone must still leave a usable content area.
      expect(phone, lessThanOrEqualTo(AppSpacing.md));
    });

    test('page padding is stable inside each breakpoint', () {
      expect(AppSpacing.pageHorizontal(320), AppSpacing.pageHorizontal(599));
      expect(AppSpacing.pageHorizontal(600), AppSpacing.pageHorizontal(999));
      expect(AppSpacing.pageHorizontal(1000), AppSpacing.pageHorizontal(2000));
    });
  });

  group('sizes', () {
    test('the minimum touch target meets the platform guideline', () {
      // §50 requires appropriate touch targets; 48dp is the Material minimum
      // and the Android accessibility guideline.
      expect(AppSizes.minTouchTarget, greaterThanOrEqualTo(48));
    });
  });

  group('AppTheme', () {
    test(
      'exposes the colour and typography extensions in both brightnesses',
      () {
        for (final ThemeData theme in <ThemeData>[
          AppTheme.light,
          AppTheme.dark,
        ]) {
          expect(theme.extension<AppColors>(), isNotNull);
          expect(theme.extension<AppTextStyles>(), isNotNull);
        }
      },
    );

    test('light and dark use different surfaces', () {
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        isNot(AppTheme.dark.scaffoldBackgroundColor),
      );
    });

    test('button themes meet the minimum touch target', () {
      Size? resolve(ButtonStyle? style) =>
          style?.minimumSize?.resolve(<WidgetState>{});

      final List<Size?> sizes = <Size?>[
        resolve(AppTheme.light.filledButtonTheme.style),
        resolve(AppTheme.light.outlinedButtonTheme.style),
        resolve(AppTheme.light.textButtonTheme.style),
        resolve(AppTheme.light.iconButtonTheme.style),
      ];

      for (final Size? size in sizes) {
        expect(size, isNotNull);
        expect(size!.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });

    test('the scaffold uses the palette surface, not a stock colour', () {
      final AppColors colors = AppTheme.light.extension<AppColors>()!;
      expect(AppTheme.light.scaffoldBackgroundColor, colors.surface);
    });
  });

  group('AppTextStyles', () {
    final AppTextStyles styles = AppTheme.light.extension<AppTextStyles>()!;

    test('each family decreases monotonically', () {
      // Order is asserted within a family, not across the whole scale.
      // Material 3 deliberately puts labelLarge (14) above bodySmall (12):
      // a button label is meant to be more prominent than metadata. Treating
      // the entire list as one descending ramp would force a wrong scale.
      void expectDescending(String family, List<TextStyle> scale) {
        for (int i = 1; i < scale.length; i++) {
          expect(
            scale[i].fontSize,
            lessThanOrEqualTo(scale[i - 1].fontSize!),
            reason: '$family ${i - 1} -> $i must not grow',
          );
        }
      }

      expectDescending('display', <TextStyle>[
        styles.displayLarge,
        styles.displaySmall,
        styles.titleLarge,
        styles.titleMedium,
        styles.titleSmall,
      ]);
      expectDescending('body', <TextStyle>[
        styles.bodyLarge,
        styles.bodyMedium,
        styles.bodySmall,
      ]);
      expectDescending('label', <TextStyle>[
        styles.labelLarge,
        styles.labelMedium,
      ]);
    });

    test('weight separates headings from body, size separates headings', () {
      // Every heading shares w600, so hierarchy inside the heading family
      // comes from size. Weight's job is to lift all headings above body copy.
      // FontWeight does not implement Comparable, so compare by index.
      expect(
        styles.titleSmall.fontWeight!.value,
        greaterThan(styles.bodyMedium.fontWeight!.value),
      );
      expect(
        styles.displayLarge.fontWeight!.value,
        greaterThan(styles.titleLarge.fontWeight!.value),
      );
      // Within the heading family only the size may vary.
      expect(styles.titleLarge.fontWeight, styles.titleSmall.fontWeight);
      expect(styles.titleMedium.fontWeight, styles.titleSmall.fontWeight);
    });

    test('mono matches bodyMedium so a value aligns with its label', () {
      expect(styles.mono.fontSize, styles.bodyMedium.fontSize);
    });

    test('no style has a null fontSize', () {
      // Regression guard. `ThemeData.textTheme` resolves lazily and reports
      // null for every fontSize on Flutter 3.44, so a factory that derived
      // sizes from it produced styles with no size at all and silently fell
      // back to whatever DefaultTextStyle provided. Every style must now carry
      // an explicit size, which is what makes the scale testable.
      for (final MapEntry<String, TextStyle> entry in <String, TextStyle>{
        'displayLarge': styles.displayLarge,
        'displaySmall': styles.displaySmall,
        'titleLarge': styles.titleLarge,
        'titleMedium': styles.titleMedium,
        'titleSmall': styles.titleSmall,
        'bodyLarge': styles.bodyLarge,
        'bodyMedium': styles.bodyMedium,
        'bodySmall': styles.bodySmall,
        'labelLarge': styles.labelLarge,
        'labelMedium': styles.labelMedium,
        'mono': styles.mono,
      }.entries) {
        expect(
          entry.value.fontSize,
          isNotNull,
          reason: 'AppTextStyles.${entry.key} has a null fontSize',
        );
        expect(entry.value.height, isNotNull);
      }
    });

    test('no body style is smaller than the accessibility floor', () {
      // §50: text must stay readable. 12sp is the practical floor; anything
      // below it fails for users who need magnification.
      for (final TextStyle style in <TextStyle>[
        styles.bodyLarge,
        styles.bodyMedium,
        styles.bodySmall,
        styles.labelLarge,
        styles.labelMedium,
      ]) {
        expect(style.fontSize, greaterThanOrEqualTo(12));
      }
    });

    test('the mono style uses tabular figures so digits align', () {
      // Diagnostics list addresses and sizes in columns; without tabular
      // figures the numbers jitter.
      expect(
        styles.mono.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(styles.mono.fontFamily, 'monospace');
    });

    test('the mono style has a fallback so it renders on every platform', () {
      // 'monospace' is not a real family on macOS or Windows; without a
      // fallback the glyphs fall back inconsistently across platforms.
      expect(styles.mono.fontFamilyFallback, isNotEmpty);
    });

    test('bodySmall is measurably less prominent than bodyLarge', () {
      // De-emphasis is asserted as a contrast measurement, not just a
      // different colour value, so it stays true if the palette is retuned.
      final AppColors colors = AppTheme.light.extension<AppColors>()!;
      final double prominent = AppColors.contrast(
        styles.bodyLarge.color!,
        colors.surface,
      );
      final double quiet = AppColors.contrast(
        styles.bodySmall.color!,
        colors.surface,
      );
      expect(quiet, lessThan(prominent));
      // But still readable: §50 applies to metadata too.
      expect(quiet, greaterThanOrEqualTo(4.5));
    });
  });

  group('ThemeExtension', () {
    test('lerp returns the endpoints when t is 0 or 1', () {
      final AppColors light = AppTheme.light.extension<AppColors>()!;
      final AppColors dark = AppTheme.dark.extension<AppColors>()!;

      expect(light.lerp(dark, 0).primary, light.primary);
      expect(light.lerp(dark, 1).primary, dark.primary);
    });

    test('lerp ignores a foreign extension instead of throwing', () {
      final AppColors light = AppTheme.light.extension<AppColors>()!;
      // This happens during theme animation when a widget's theme has not yet
      // picked up the new extension set.
      expect(light.lerp(null, 0.5), same(light));
    });

    test('lerp interpolates between the two palettes', () {
      final AppColors light = AppTheme.light.extension<AppColors>()!;
      final AppColors dark = AppTheme.dark.extension<AppColors>()!;
      final AppColors mid = light.lerp(dark, 0.5);
      expect(mid.surface, isNot(light.surface));
      expect(mid.surface, isNot(dark.surface));
    });

    test('copyWith overrides only what is passed', () {
      final AppColors light = AppTheme.light.extension<AppColors>()!;
      final AppColors changed = light.copyWith(danger: Colors.purple);
      expect(changed.danger, Colors.purple);
      expect(changed.primary, light.primary);
      expect(changed.success, light.success);
    });
  });

  group('AppIcons', () {
    test('every icon resolves to a real glyph in the pinned package', () {
      // A wrong constant would render as a blank box, which is invisible in
      // review and obvious to users. IconData with codePoint 0 is the null
      // glyph.
      final List<MapEntry<String, IconData>> icons =
          <MapEntry<String, IconData>>[
            const MapEntry<String, IconData>('send', AppIcons.send),
            const MapEntry<String, IconData>('receive', AppIcons.receive),
            const MapEntry<String, IconData>('share', AppIcons.share),
            const MapEntry<String, IconData>('cancel', AppIcons.cancel),
            const MapEntry<String, IconData>('retry', AppIcons.retry),
            const MapEntry<String, IconData>('completed', AppIcons.completed),
            const MapEntry<String, IconData>('file', AppIcons.file),
            const MapEntry<String, IconData>('folder', AppIcons.folder),
            const MapEntry<String, IconData>('add', AppIcons.add),
            const MapEntry<String, IconData>('remove', AppIcons.remove),
            const MapEntry<String, IconData>('device', AppIcons.device),
            const MapEntry<String, IconData>('computer', AppIcons.computer),
            const MapEntry<String, IconData>('laptop', AppIcons.laptop),
            const MapEntry<String, IconData>('qrCode', AppIcons.qrCode),
            const MapEntry<String, IconData>('scan', AppIcons.scan),
            const MapEntry<String, IconData>('bluetooth', AppIcons.bluetooth),
            const MapEntry<String, IconData>('error', AppIcons.error),
            const MapEntry<String, IconData>('warning', AppIcons.warning),
            const MapEntry<String, IconData>('info', AppIcons.info),
            const MapEntry<String, IconData>('settings', AppIcons.settings),
            const MapEntry<String, IconData>('menu', AppIcons.menu),
            const MapEntry<String, IconData>('back', AppIcons.back),
            const MapEntry<String, IconData>('queued', AppIcons.queued),
          ];

      for (final MapEntry<String, IconData> entry in icons) {
        expect(
          entry.value.codePoint,
          isNot(0),
          reason: 'AppIcons.${entry.key} resolved to the null glyph',
        );
        expect(
          entry.value.fontFamily,
          'HgiStrokeRounded',
          reason: 'AppIcons.${entry.key} uses a different font family',
        );
      }
    });

    test('every icon is distinct', () {
      // Two names pointing at the same glyph is a copy-paste bug that no
      // reviewer would catch from the constant list alone.
      final Map<int, String> seen = <int, String>{};
      const Map<String, IconData> icons = <String, IconData>{
        'send': AppIcons.send,
        'receive': AppIcons.receive,
        'share': AppIcons.share,
        'cancel': AppIcons.cancel,
        'retry': AppIcons.retry,
        'completed': AppIcons.completed,
        'file': AppIcons.file,
        'folder': AppIcons.folder,
        'add': AppIcons.add,
        'remove': AppIcons.remove,
        'device': AppIcons.device,
        'computer': AppIcons.computer,
        'laptop': AppIcons.laptop,
        'qrCode': AppIcons.qrCode,
        'scan': AppIcons.scan,
        'bluetooth': AppIcons.bluetooth,
        'error': AppIcons.error,
        'info': AppIcons.info,
        'settings': AppIcons.settings,
        'menu': AppIcons.menu,
        'back': AppIcons.back,
        'queued': AppIcons.queued,
      };

      icons.forEach((String name, IconData icon) {
        final String? previous = seen[icon.codePoint];
        expect(
          previous,
          isNull,
          reason: 'AppIcons.$name duplicates AppIcons.$previous',
        );
        seen[icon.codePoint] = name;
      });
    });
  });
}
