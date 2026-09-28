import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

void main() {
  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('profile-tab')));
    await tester.pumpAndSettle();
  }

  testWidgets('preview shows the card as others see it', (tester) async {
    await enterDiscovery(tester);
    await openProfile(tester);

    expect(
      find.textContaining('Prototype data stays in memory'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('preview-card')));
    await tester.pumpAndSettle();
    expect(find.text('How others see you'), findsOneWidget);
    expect(find.text('Alex, 28', findRichText: true), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('preview-scroll')),
        matching: find.text('Open to long-term'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('close-preview')));
    await tester.pumpAndSettle();
    expect(find.text('How others see you'), findsNothing);
  });

  testWidgets('profile strength counts optional pieces live', (tester) async {
    await enterDiscovery(tester);
    await openProfile(tester);

    expect(find.text('0 of 4'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('profile-bio')),
      'Weekend hikes, secondhand bookshops, and slow breakfasts.',
    );
    await tester.pump();
    expect(find.text('1 of 4'), findsOneWidget);
  });

  testWidgets('lifestyle answers from sign-up appear in the editor', (
    tester,
  ) async {
    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Sam');
    await tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '31');
    await tapNext(tester);
    await answerGenderSteps(tester);
    await tester.tap(find.byKey(const Key('intent-long_term')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('interest-Travel')));
    await tester.pump();
    await tapNext(tester);
    await tester.ensureVisible(
      find.byKey(const Key('lifestyle-exercise-Daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lifestyle-exercise-Daily')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    await tapNext(tester);

    await openProfile(tester);
    expect(find.text('1 of 4'), findsOneWidget);
    final daily = find.byKey(const Key('lifestyle-exercise-Daily'));
    await tester.scrollUntilVisible(
      daily,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.widget<ChoiceChip>(daily).selected, isTrue);
  });

  testWidgets('photos card is honest about upload and offers tips', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await openProfile(tester);
    await tester.ensureVisible(find.byKey(const Key('photo-tips')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Photo upload is coming'), findsOneWidget);
    await tester.tap(find.byKey(const Key('photo-tips')));
    await tester.pumpAndSettle();
    expect(find.text('Works well'), findsOneWidget);
    expect(find.text('Your face, clearly'), findsOneWidget);
  });

  testWidgets('a prompt can be added and shows on the preview', (tester) async {
    await enterDiscovery(tester);
    await openProfile(tester);
    final scroll = find
        .descendant(
          of: find.byKey(const Key('profile-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-prompt')),
      200,
      scrollable: scroll,
    );
    await tester.tap(find.byKey(const Key('add-prompt')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask me about…'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('prompt-answer')),
      'The best bakery in town',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('prompt-save')));
    await tester.pumpAndSettle();
    expect(find.text('The best bakery in town'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('preview-card')),
      -200,
      scrollable: scroll,
    );
    await tester.tap(find.byKey(const Key('preview-card')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.descendant(
        of: find.byKey(const Key('preview-scroll')),
        matching: find.text('The best bakery in town'),
      ),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('preview-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  });
}
