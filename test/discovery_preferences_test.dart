import 'package:ember_app/domain/discovery_preferences.dart';
import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    await tester.pumpWidget(const EmberApp());
    await tester.tap(find.byKey(const Key('adult-checkbox')));
    await tester.tap(find.byKey(const Key('rules-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('continue-button')));
    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();
    expect(find.text('Maya, 29'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discovery-preferences')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open to long-term').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-discovery-preferences')));
    await tester.pumpAndSettle();
    expect(find.text('Amina, 27'), findsOneWidget);
    expect(find.text('Edit preferences'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discovery-preferences')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset-discovery-preferences')));
    await tester.pumpAndSettle();
    expect(find.text('Maya, 29'), findsOneWidget);
  });
}
