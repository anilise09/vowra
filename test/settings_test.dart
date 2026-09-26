import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('profile-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
  }

  testWidgets('pausing is free, shows on Discover, and can be resumed', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await openSettings(tester);

    await tester.tap(find.byKey(const Key('settings-show-me')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Paused. New people will not see you'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paused-banner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('resume-profile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paused-banner')), findsNothing);
  });

  testWidgets('delete offers a pause once, then clears everything', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await openSettings(tester);

    await tester.tap(find.byKey(const Key('settings-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete your profile?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-pause-instead')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paused.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-delete')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('delete-pause-instead')),
      findsNothing,
      reason: 'already paused: no second pause offer',
    );
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('adult-checkbox')), findsOneWidget);
    expect(find.text('PROTOTYPE PROFILE · NOT A REAL PERSON'), findsNothing);
  });
}
