import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requires adult and community-rule consent', (tester) async {
    await tester.pumpWidget(const EmberApp());
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('continue-button')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('adult-checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('continue-button')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('rules-checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('continue-button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('enters discovery and opens safety center', (tester) async {
    await tester.pumpWidget(const EmberApp());
    await tester.tap(find.byKey(const Key('adult-checkbox')));
    await tester.tap(find.byKey(const Key('rules-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();
    expect(find.text('PROTOTYPE PROFILE · NOT A REAL PERSON'), findsOneWidget);
    expect(find.textContaining('Exact location'), findsOneWidget);
    await tester.tap(find.byTooltip('Safety center'));
    await tester.pumpAndSettle();
    expect(find.text('Calls require mutual readiness'), findsOneWidget);
    expect(
      find.text('A match can always decline. Calls are not recorded.'),
      findsOneWidget,
    );
  });
}
