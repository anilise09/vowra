import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

void main() {
  bool nextEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.byKey(const Key('onboarding-next')))
          .onPressed !=
      null;

  testWidgets(
    'welcome leads into one-question setup, not straight to discovery',
    (tester) async {
      await startOnboarding(tester);

      expect(find.text('What should matches call you?'), findsOneWidget);
      expect(find.text('Step 1 of 6'), findsOneWidget);
      expect(find.text('PROTOTYPE PROFILE · NOT A REAL PERSON'), findsNothing);
    },
  );

  testWidgets('required steps cannot be skipped or left blank', (tester) async {
    await startOnboarding(tester);

    expect(find.byKey(const Key('onboarding-skip')), findsNothing);
    expect(nextEnabled(tester), isFalse);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'A');
    await tester.pump();
    expect(nextEnabled(tester), isFalse);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tester.pump();
    expect(nextEnabled(tester), isTrue);
    await tapNext(tester);

    expect(find.byKey(const Key('onboarding-skip')), findsNothing);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '28');
    await tapNext(tester);

    expect(find.byKey(const Key('onboarding-skip')), findsNothing);
    expect(nextEnabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('intent-long_term')));
    await tester.pump();
    expect(nextEnabled(tester), isTrue);
    await tapNext(tester);

    expect(find.byKey(const Key('onboarding-skip')), findsNothing);
    expect(nextEnabled(tester), isFalse);
  });

  testWidgets('an under-18 age blocks setup', (tester) async {
    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tapNext(tester);

    await tester.enterText(find.byKey(const Key('onboarding-age')), '17');
    await tester.pump();
    expect(find.text('Vawra is only for adults 18+.'), findsOneWidget);
    expect(nextEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const Key('onboarding-age')), '1a8');
    await tester.pump();
    expect(find.text('18'), findsOneWidget, reason: 'digits only');
    expect(nextEnabled(tester), isTrue);
  });

  testWidgets('interests are capped at five', (tester) async {
    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '30');
    await tapNext(tester);
    await tester.ensureVisible(find.byKey(const Key('intent-casual')));
    await tester.tap(find.byKey(const Key('intent-casual')));
    await tester.pump();
    await tapNext(tester);

    for (final interest in ['Arts', 'Books', 'Cooking', 'Fitness', 'Music']) {
      await tester.tap(find.byKey(Key('interest-$interest')));
      await tester.pump();
    }
    expect(find.text('5 of 5 chosen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('interest-Travel')));
    await tester.pump();
    expect(find.text('5 of 5 chosen'), findsOneWidget);
  });

  testWidgets('back keeps earlier answers', (tester) async {
    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();

    expect(find.text('What should matches call you?'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('a short bio must be finished or skipped', (tester) async {
    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '30');
    await tapNext(tester);
    await tester.ensureVisible(find.byKey(const Key('intent-casual')));
    await tester.tap(find.byKey(const Key('intent-casual')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('interest-Music')));
    await tester.pump();
    await tapNext(tester);

    expect(nextEnabled(tester), isTrue, reason: 'an empty bio is allowed');
    await tester.enterText(find.byKey(const Key('onboarding-bio')), 'Hi');
    await tester.pump();
    expect(nextEnabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(find.text('Your privacy, your call'), findsOneWidget);
    expect(find.text('Start discovering'), findsOneWidget);
  });

  testWidgets('answers carry into discovery and the profile tab', (
    tester,
  ) async {
    await enterDiscovery(tester);

    expect(find.text('PROTOTYPE PROFILE · NOT A REAL PERSON'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-tab')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('profile-name')))
          .controller
          ?.text,
      'Alex',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('profile-age')))
          .controller
          ?.text,
      '28',
    );
  });
}
