import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Accepts the welcome gate and opens profile setup.
Future<void> startOnboarding(WidgetTester tester) async {
  await tester.pumpWidget(const VawraApp());
  await tester.tap(find.byKey(const Key('adult-checkbox')));
  await tester.tap(find.byKey(const Key('rules-checkbox')));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('continue-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('continue-button')));
  await tester.pumpAndSettle();
}

Future<void> tapNext(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.byKey(const Key('onboarding-next')));
  await tester.pumpAndSettle();
}

/// Completes the required onboarding steps, skipping the optional bio.
Future<void> enterDiscovery(WidgetTester tester) async {
  await startOnboarding(tester);
  await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
  await tapNext(tester);
  await tester.enterText(find.byKey(const Key('onboarding-age')), '28');
  await tapNext(tester);
  await tester.tap(find.byKey(const Key('intent-open_to_long_term')));
  await tester.pump();
  await tapNext(tester);
  await tester.tap(find.byKey(const Key('interest-Books')));
  await tester.pump();
  await tapNext(tester);
  // Lifestyle and intro are optional.
  await tester.tap(find.byKey(const Key('onboarding-skip')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('onboarding-skip')));
  await tester.pumpAndSettle();
  await tapNext(tester);
}

/// The first visit to Chats shows the date-safely guide; close it if open.
Future<void> closeSafetyGuideIfShown(WidgetTester tester) async {
  final close = find.byKey(const Key('safety-guide-close'));
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close);
    await tester.pumpAndSettle();
  }
}
