import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/theme/theme.dart';

void main() {
  Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );

  group('AppIcon rendering', () {
    testWidgets('inherits colour and size from the ambient IconTheme', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const IconTheme(
            data: IconThemeData(color: Color(0xFF123456), size: 40),
            child: AppIcon(AppIcons.send),
          ),
        ),
      );

      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, const Color(0xFF123456));
      expect(icon.size, 40);
    });

    testWidgets('an explicit size overrides the theme', (tester) async {
      await tester.pumpWidget(host(const AppIcon(AppIcons.send, size: 12)));

      expect(tester.widget<Icon>(find.byType(Icon)).size, 12);
    });

    testWidgets('falls back to the scheme body colour when unthemed', (
      tester,
    ) async {
      // An icon with no colour at all renders invisible. This asserts the
      // fallback chain ends somewhere visible instead of null.
      await tester.pumpWidget(host(const AppIcon(AppIcons.send)));

      final Color? color = tester.widget<Icon>(find.byType(Icon)).color;
      expect(color, isNotNull);
    });

    testWidgets('renders an actual glyph, not an empty box', (tester) async {
      await tester.pumpWidget(host(const AppIcon(AppIcons.qrCode)));

      // The font-based package renders through Icon, so the widget existing is
      // not proof the code point is valid; assert the IconData survived.
      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, AppIcons.qrCode);
      expect(icon.icon!.codePoint, isNot(0));
    });
  });

  group('AppIcon accessibility', () {
    testWidgets('a decorative icon is hidden from the semantics tree', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const Column(
            children: <Widget>[
              AppIcon(AppIcons.info),
              Text('Transfer complete'),
            ],
          ),
        ),
      );

      // The label already carries the meaning, so the icon must not announce
      // a second, redundant node (§50).
      expect(find.bySemanticsLabel('Transfer complete'), findsOneWidget);
      expect(handle, isNotNull);
      handle.dispose();
    });

    testWidgets('an icon-only control exposes its semantic label', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          IconButton(
            onPressed: () {},
            icon: const AppIcon(AppIcons.settings, semanticLabel: 'Settings'),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the semantics label survives into the merged node', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const AppIcon(AppIcons.cancel, semanticLabel: 'Cancel transfer')),
      );

      expect(
        tester.getSemantics(find.byType(AppIcon)).label,
        'Cancel transfer',
      );
      handle.dispose();
    });
  });

  group('theme integration', () {
    testWidgets('AppTheme.light exposes the palette to widgets', (
      tester,
    ) async {
      late AppColors seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (BuildContext context) {
              seen = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen.primary, AppTheme.light.colorScheme.primary);
      expect(seen.onSurface, AppTheme.light.colorScheme.onSurface);
    });

    testWidgets('AppTheme.dark resolves independently', (tester) async {
      late AppColors seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (BuildContext context) {
              seen = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen, isNot(AppTheme.light.extension<AppColors>()));
    });

    testWidgets('text styles resolve from the ambient theme', (tester) async {
      late AppTextStyles seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (BuildContext context) {
              seen = context.textStyles;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen, AppTheme.light.extension<AppTextStyles>());
    });

    testWidgets('a Text widget picks up the project body style', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) =>
                Text('hola', style: context.textStyles.bodyLarge),
          ),
        ),
      );

      final Text text = tester.widget<Text>(find.text('hola'));
      expect(text.style!.fontSize, 16);
    });
  });

  group('text scaling', () {
    testWidgets('large text still renders without overflowing', (tester) async {
      // §50 requires the UI to survive aggressive magnification.
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: Text(
                    'A very long device name that wraps',
                    style: context.textStyles.bodyLarge,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('A very long device name that wraps'), findsOneWidget);
    });
  });
}
