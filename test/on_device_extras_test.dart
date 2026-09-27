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

  testWidgets('emoji panel, quick replies, and big emoji messages', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('action-like')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-send-message')));
    await tester.pumpAndSettle();
    await closeSafetyGuideIfShown(tester);

    await tester.tap(find.byKey(const Key('emoji-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emoji-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('emoji-😂')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-message')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('big-emoji')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('thread-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('big-emoji')), findsOneWidget);

    await tester.tap(find.text('Quick replies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hi! How is your week going?'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emoji-panel')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('message-composer')))
          .controller
          ?.text,
      'Hi! How is your week going?',
    );
  });

  testWidgets('notification choices are kept between visits', (tester) async {
    await enterDiscovery(tester);
    await openSettings(tester);
    final scroll = find
        .descendant(
          of: find.byKey(const Key('settings-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('notify-Messages')),
      200,
      scrollable: scroll,
    );
    expect(find.text('Nothing is sent yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notify-Messages')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('notify-Messages')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('notify-Messages')))
          .value,
      isFalse,
    );
  });

  testWidgets('travel mode shows a banner on Discover and turns off', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-travel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('travel-Toronto')));
    await tester.pumpAndSettle();
    expect(find.text('Travel mode: Toronto'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('travel-banner')), findsOneWidget);
    expect(find.textContaining('Browsing in Toronto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('travel-off')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('travel-banner')), findsNothing);
  });
}
