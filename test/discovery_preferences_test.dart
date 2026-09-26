import 'package:ember_app/domain/discovery_preferences.dart';
import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> enterDiscovery(WidgetTester tester) async {
    await tester.pumpWidget(const VawraApp());
    await tester.tap(find.byKey(const Key('adult-checkbox')));
    await tester.tap(find.byKey(const Key('rules-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('continue-button')));
    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();
  }

  test('age limits and relationship intent are both respected', () {
    const preferences = DiscoveryPreferences(
      minAge: 30,
      maxAge: 35,
      intent: 'Open to long-term',
    );
    expect(
      preferences.includes(age: 30, relationshipIntent: 'Open to long-term'),
      isTrue,
    );
    expect(
      preferences.includes(age: 35, relationshipIntent: 'Open to long-term'),
      isTrue,
    );
    expect(
      preferences.includes(age: 29, relationshipIntent: 'Open to long-term'),
      isFalse,
    );
    expect(
      preferences.includes(age: 36, relationshipIntent: 'Open to long-term'),
      isFalse,
    );
    expect(
      preferences.includes(
        age: 32,
        relationshipIntent: 'Long-term relationship',
      ),
      isFalse,
    );
    expect(preferences.isDefault, isFalse);
    expect(const DiscoveryPreferences().isDefault, isTrue);
  });

  testWidgets('discovery preferences filter and reset synthetic cards', (
    tester,
  ) async {
    await enterDiscovery(tester);
    expect(find.text('Maya, 29'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discovery-preferences')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open to long-term').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-discovery-preferences')));
    await tester.pumpAndSettle();
    expect(find.text('Amina, 27'), findsOneWidget);
    expect(find.byTooltip('Edit preferences'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discovery-preferences')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset-discovery-preferences')));
    await tester.pumpAndSettle();
    expect(find.text('Maya, 29'), findsOneWidget);
  });

  testWidgets('discovery report needs a reason and stays local', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('discovery-safety-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report privately'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('submit-discovery-report')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('discovery-report-reason')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scam or suspicious request').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('submit-discovery-report')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('submit-discovery-report')));
    await tester.pumpAndSettle();

    expect(
      find.text('Report recorded: Scam or suspicious request'),
      findsOneWidget,
    );
    expect(find.textContaining('No review team is connected'), findsWidgets);
  });

  testWidgets('blocking a discovery profile removes it from the local deck', (
    tester,
  ) async {
    await enterDiscovery(tester);
    expect(find.text('Maya, 29'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discovery-safety-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-discovery-block')));
    await tester.pumpAndSettle();

    expect(find.text('Maya, 29'), findsNothing);
    expect(find.text('Elena, 32'), findsOneWidget);
    expect(find.textContaining('prototype profiles'), findsOneWidget);
  });

  testWidgets('swipe up opens details without liking; right likes', (
    tester,
  ) async {
    await enterDiscovery(tester);
    expect(find.text('Maya, 29'), findsOneWidget);

    await tester.dragFrom(const Offset(200, 500), const Offset(0, -160));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('close-profile-details')), findsOneWidget);
    expect(find.text('Maya, 29'), findsNWidgets(2));
    expect(find.textContaining('Mutual like with Maya'), findsNothing);
    await tester.tap(find.byKey(const Key('close-profile-details')));
    await tester.pumpAndSettle();

    await tester.flingFrom(const Offset(160, 320), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Maya, 29'), findsNothing);
    expect(find.text('Elena, 32'), findsOneWidget);
    expect(find.textContaining('Mutual like with Maya'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Local activity'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Local activity'), findsOneWidget);
    expect(
      find.textContaining('Notification preview for Maya'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Mutual like with Maya can connect'),
      findsOneWidget,
    );
  });

  testWidgets('mutual like creates a free messaging match', (tester) async {
    await enterDiscovery(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Chats'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No chat yet'), findsOneWidget);

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.flingFrom(const Offset(160, 320), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Chats'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Hi! What is your ideal Sunday?'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('message-composer')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('message-composer')), findsOneWidget);
  });

  testWidgets('premium direct intro is an unavailable honest preview', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await tester.tap(find.byTooltip('Safety center'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('direct-intro-preview')),
      180,
      scrollable: find.byType(Scrollable).last,
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('direct-intro-preview')),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('No message is sent'), findsOneWidget);
    expect(
      find.textContaining('Mutual matches can always message for free'),
      findsOneWidget,
    );
  });

  testWidgets('swipe left passes while swipe right likes', (tester) async {
    await enterDiscovery(tester);

    await tester.flingFrom(const Offset(160, 320), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Elena, 32'), findsOneWidget);
    expect(find.textContaining('prototype profiles'), findsOneWidget);

    await tester.flingFrom(const Offset(400, 320), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Elena, 32'), findsNothing);
    expect(find.text('Amina, 27'), findsOneWidget);
    expect(find.textContaining('prototype profiles'), findsOneWidget);
  });
}
