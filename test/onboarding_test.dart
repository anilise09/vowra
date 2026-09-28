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
      expect(find.text('Step 1 of 9'), findsOneWidget);
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

    // Gender is required; "Show me" starts at everyone.
    expect(find.byKey(const Key('onboarding-skip')), findsNothing);
    expect(nextEnabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('gender-nonbinary')));
    await tester.pump();
    expect(nextEnabled(tester), isTrue);
    await tapNext(tester);
    expect(find.text('Who would you like to meet?'), findsOneWidget);
    expect(nextEnabled(tester), isTrue);
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
    await answerGenderSteps(tester);
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
    await answerGenderSteps(tester);
    await tester.ensureVisible(find.byKey(const Key('intent-casual')));
    await tester.tap(find.byKey(const Key('intent-casual')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('interest-Music')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

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

    expect(find.text('PROTOTYPE PROFILE · NOT A REAL PERSON'), findsWidgets);
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

  testWidgets('gender and "show me" reach the profile editor', (tester) async {
    Future<void> pick(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
    }

    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '30');
    await tapNext(tester);
    await pick('gender-man');
    await pick('onboarding-show-gender');
    await tester.pump();
    await tapNext(tester);

    bool chosen(String key) =>
        tester
            .widget<Semantics>(
              find
                  .ancestor(
                    of: find.byKey(Key(key)),
                    matching: find.byType(Semantics),
                  )
                  .first,
            )
            .properties
            .selected ??
        false;
    expect(chosen('showme-everyone'), isTrue);
    await pick('showme-woman');
    await tester.pump();
    expect(chosen('showme-everyone'), isFalse);
    expect(chosen('showme-woman'), isTrue);
    await pick('showme-man');
    await pick('showme-nonbinary');
    await tester.pump();
    expect(chosen('showme-everyone'), isTrue, reason: 'all three = everyone');
    await pick('showme-woman');
    await pick('showme-man');
    await tapNext(tester);

    await tester.ensureVisible(find.byKey(const Key('intent-casual')));
    await tester.tap(find.byKey(const Key('intent-casual')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('interest-Music')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    await tapNext(tester);
    await dismissSwipeTutorial(tester);

    await tester.tap(find.byKey(const Key('profile-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Man'), findsOneWidget);
    FilterChip chip(String key) =>
        tester.widget<FilterChip>(find.byKey(Key(key)));
    expect(chip('profile-showme-woman').selected, isTrue);
    expect(chip('profile-showme-man').selected, isTrue);
    expect(chip('profile-showme-nonbinary').selected, isFalse);
    expect(chip('profile-showme-everyone').selected, isFalse);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('profile-show-gender')))
          .value,
      isTrue,
    );
  });

  testWidgets('headlines use the name; lifestyle is optional and counted', (
    tester,
  ) async {
    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tapNext(tester);
    expect(
      find.text('Nice to meet you, Alex. How old are you?'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('onboarding-age')), '30');
    await tapNext(tester);
    await answerGenderSteps(tester);
    await tester.ensureVisible(find.byKey(const Key('intent-casual')));
    await tester.tap(find.byKey(const Key('intent-casual')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('interest-Music')));
    await tester.pump();
    expect(find.text('Continue 1/5'), findsOneWidget);
    await tapNext(tester);

    expect(find.text('A few habits, Alex'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-skip')), findsOneWidget);
    expect(nextEnabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('lifestyle-drinking-Socially')));
    await tester.pump();
    expect(find.text('Continue 1/4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lifestyle-drinking-Rarely')));
    await tester.pump();
    expect(find.text('Continue 1/4'), findsOneWidget, reason: 'one per topic');
    await tester.tap(find.byKey(const Key('lifestyle-drinking-Rarely')));
    await tester.pump();
    expect(find.text('Continue 0/4'), findsOneWidget, reason: 'tap clears');
    expect(nextEnabled(tester), isFalse);
  });
}
