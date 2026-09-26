import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

void main() {
  double stampOpacity(WidgetTester tester, String key) => tester
      .widget<Opacity>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  testWidgets('dragging shows the stamp; a short drag springs back', (
    tester,
  ) async {
    await enterDiscovery(tester);
    final card = find.byKey(const Key('swipe-front'));
    final gesture = await tester.startGesture(tester.getCenter(card));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(stampOpacity(tester, 'stamp-like'), greaterThan(0.3));
    expect(stampOpacity(tester, 'stamp-nope'), 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Maya, 29', findRichText: true), findsOneWidget);
    expect(stampOpacity(tester, 'stamp-like'), 0);
  });

  testWidgets('pass button flies the card off to the next profile', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('action-pass')));
    await tester.pumpAndSettle();
    expect(find.text('Maya, 29', findRichText: true), findsNothing);
    expect(find.text('Elena, 32', findRichText: true), findsOneWidget);
  });

  testWidgets('super likes are counted and run out after three', (
    tester,
  ) async {
    await enterDiscovery(tester);
    // Maya liked you first, so a Super Like matches straight away.
    await tester.tap(find.byKey(const Key('action-super-like')));
    await tester.pumpAndSettle();
    expect(find.text("It's a match!"), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
    await tester.tap(find.byKey(const Key('match-keep-swiping')));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.flingFrom(const Offset(400, 400), const Offset(0, -500), 1500);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('action-super-like')));
    await tester.pumpAndSettle();

    final before =
        find.text('Amina, 27', findRichText: true).evaluate().length +
        find.text('Sofia, 35', findRichText: true).evaluate().length;
    await tester.tap(find.byKey(const Key('action-super-like')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No Super Likes left today'), findsOneWidget);
    final after =
        find.text('Amina, 27', findRichText: true).evaluate().length +
        find.text('Sofia, 35', findRichText: true).evaluate().length;
    expect(after, before, reason: 'the card stays when none are left');
  });
}
