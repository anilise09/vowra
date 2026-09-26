import 'package:ember_app/data/discovery_interaction_repository.dart';
import 'package:ember_app/domain/demo_profile.dart';
import 'package:ember_app/domain/discovery_preferences.dart';
import 'package:ember_app/features/discovery/discovery_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

void main() {
  const near = DemoProfile(
    'Near',
    30,
    'Open to long-term',
    '2–5 km away',
    'A bio long enough to be shown here.',
    ['Books'],
    'assets/profiles/maya.png',
  );
  const far = DemoProfile(
    'Far',
    30,
    'Open to long-term',
    '20–50 km away',
    'A bio long enough to be shown here.',
    ['Books'],
    'assets/profiles/elena.png',
  );

  test('distance preference uses only the far edge of the band', () {
    expect(DiscoveryPreferences.bandUpperKm('5–10 km away'), 10);
    const upTo10 = DiscoveryPreferences(maxDistanceKm: 10);
    expect(
      upTo10.includes(
        age: 30,
        relationshipIntent: 'x',
        distanceBand: '5–10 km away',
      ),
      isTrue,
    );
    expect(
      upTo10.includes(
        age: 30,
        relationshipIntent: 'x',
        distanceBand: '10–20 km away',
      ),
      isFalse,
    );
    expect(upTo10.isDefault, isFalse);
  });

  test('undo brings back only the latest pass, never a like', () {
    final repository = MemoryDiscoveryInteractionRepository();
    repository.reject(near);
    repository.recordLike(
      far,
      createdAt: DateTime.utc(2026),
      mutualLike: false,
    );
    expect(repository.undoLastRejection(), near.assetPath);
    expect(repository.rejectedProfileAssets(), isEmpty);
    expect(repository.undoLastRejection(), isNull);
    expect(repository.likedProfiles().containsKey(far.assetPath), isTrue);

    repository.reject(near);
    repository.clearRejections();
    expect(repository.rejectedProfileAssets(), isEmpty);
  });

  testWidgets('undo puts the passed profile back on top', (tester) async {
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('undo-pass')));
    await tester.pumpAndSettle();
    expect(
      find.text('Maya, 29', findRichText: true),
      findsOneWidget,
      reason: 'nothing to undo yet',
    );

    await tester.flingFrom(const Offset(400, 320), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Maya, 29', findRichText: true), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('undo-pass')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('undo-pass')));
    await tester.pumpAndSettle();
    expect(find.text('Maya, 29', findRichText: true), findsOneWidget);
  });

  testWidgets('likes you is free and liking back creates a match', (
    tester,
  ) async {
    await enterDiscovery(tester);
    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();

    expect(find.text('Likes you'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    await tester.tap(find.byKey(const Key('likes-you-like-Maya')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('likes-you-row')), findsNothing);
    expect(find.text('New match'), findsOneWidget);
  });

  testWidgets('an empty deck offers preferences and passed profiles', (
    tester,
  ) async {
    Widget deck({required Set<String> passed}) => MaterialApp(
      home: Scaffold(
        body: DiscoveryDeck(
          profiles: const [near],
          preferences: const DiscoveryPreferences(),
          blockedProfileAssets: const {},
          likedProfiles: const {},
          rejectedProfileAssets: passed,
          reports: const {},
          likeEvents: const [],
          profileIndex: 0,
          onPreferencesChanged: (_) {},
          onSwipeAction: (_, _) {},
          onReport: (_) {},
          onBlockProfile: (_) {},
          onOpenSafety: () {},
          onShowPassedAgain: () {},
        ),
      ),
    );

    await tester.pumpWidget(deck(passed: {near.assetPath}));
    expect(find.text("You've seen everyone for now"), findsOneWidget);
    expect(find.byKey(const Key('end-open-preferences')), findsOneWidget);
    expect(find.byKey(const Key('end-show-passed')), findsOneWidget);
  });
}
