import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

void main() {
  testWidgets('explore hubs open their own deck and go back', (tester) async {
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('explore-tab')));
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Bookworms'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hub-books')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hub-back')), findsOneWidget);
    expect(find.text('Bookworms'), findsOneWidget);
    expect(find.byKey(const Key('swipe-front')), findsOneWidget);

    await tester.tap(find.byKey(const Key('hub-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hub-books')), findsOneWidget);
  });

  testWidgets('chat list, reactions, and the are-you-sure nudge', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('action-like')));
    await tester.pumpAndSettle();
    // "Send a message" on the match screen opens the conversation directly.
    await tester.tap(find.byKey(const Key('match-send-message')));
    await tester.pumpAndSettle();
    await closeSafetyGuideIfShown(tester);
    expect(find.byKey(const Key('message-composer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bubble-seed-peer')));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.byKey(const Key('bubble-seed-peer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reaction-heart')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('message-composer')),
      'you are stupid',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-message')));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('are-you-sure-edit')));
    await tester.pumpAndSettle();
    expect(
      find.text('you are stupid'),
      findsOneWidget,
      reason: 'still in the box',
    );

    await tester.enterText(
      find.byKey(const Key('message-composer')),
      'Your Sunday sounds lovely',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-message')));
    await tester.pumpAndSettle();
    expect(find.text('Your Sunday sounds lovely'), findsOneWidget);

    await tester.tap(find.byKey(const Key('thread-back')));
    await tester.pumpAndSettle();
    expect(find.text('New matches'), findsOneWidget);
    expect(find.textContaining('You: Your Sunday'), findsOneWidget);
  });
}
