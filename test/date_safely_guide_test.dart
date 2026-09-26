import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

void main() {
  Future<void> openChats(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Chats'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first visit to Chats shows the guide once; shield reopens it', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await openChats(tester);

    expect(find.text('Date safely'), findsOneWidget);
    expect(find.text('Kindness first'), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-next')));
    await tester.pumpAndSettle();
    expect(find.text('Money talk is a red flag'), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-next')));
    await tester.pumpAndSettle();
    expect(find.text('Block and report are free'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-next')));
    await tester.pumpAndSettle();
    expect(find.text('Date safely'), findsNothing);

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await openChats(tester);
    expect(find.text('Date safely'), findsNothing);
    expect(find.text('No chats yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chats-safety')));
    await tester.pumpAndSettle();
    expect(find.text('Date safely'), findsOneWidget);
  });

  testWidgets('profile details end with free Block and Report actions', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await tester.ensureVisible(find.byKey(const Key('open-profile-details')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-profile-details')));
    await tester.pumpAndSettle();

    final details = find
        .descendant(
          of: find.byKey(const Key('profile-details-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Looking for'),
      200,
      scrollable: details,
    );
    expect(find.text('Looking for'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('details-report')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('profile-details-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Block Maya'), findsOneWidget);
    expect(find.text('Report Maya'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('never told'),
      120,
      scrollable: details,
    );
    expect(find.textContaining('never told'), findsOneWidget);
  });
}
