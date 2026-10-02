import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/main.dart';

void main() {
  testWidgets('shows an honest pre-implementation notice', (tester) async {
    await tester.pumpWidget(const PartilhaApp());

    expect(find.text('Partilha'), findsOneWidget);
    expect(
      find.text('Under construction. No feature is implemented yet.'),
      findsOneWidget,
    );
  });

  testWidgets('does not present the generated counter demo', (tester) async {
    await tester.pumpWidget(const PartilhaApp());

    expect(find.text('0'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Flutter Demo Home Page'), findsNothing);
  });

  testWidgets('is not labelled as a debug build', (tester) async {
    await tester.pumpWidget(const PartilhaApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.title, 'Partilha');
  });
}
