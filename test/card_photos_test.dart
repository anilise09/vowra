import 'package:ember_app/domain/demo_profile.dart';
import 'package:ember_app/domain/discovery_preferences.dart';
import 'package:ember_app/features/discovery/discovery_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const maya = DemoProfile(
    'Maya',
    29,
    'Long-term relationship',
    '2–5 km away',
    'A bio long enough to be shown here.',
    ['Books'],
    'assets/profiles/maya.webp',
  );

  Widget deck(Map<String, List<String>> extra) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 900,
        child: DiscoveryDeck(
          profiles: const [maya],
          preferences: const DiscoveryPreferences(),
          blockedProfileAssets: const {},
          likedProfiles: const {},
          rejectedProfileAssets: const {},
          reports: const {},
          likeEvents: const [],
          profileIndex: 0,
          onPreferencesChanged: (_) {},
          onSwipeAction: (_, _) {},
          onReport: (_) {},
          onBlockProfile: (_) {},
          onOpenSafety: () {},
          extraPhotos: extra,
        ),
      ),
    ),
  );

  testWidgets('several photos show segments and flip on tap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      deck({
        'assets/profiles/maya.webp': ['assets/profiles/elena.webp'],
      }),
    );
    expect(find.byKey(const Key('photo-segments')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('photo 1 of 2')), findsOneWidget);

    final tap = find.byKey(const Key('card-photo-tap'));
    final box = tester.getRect(tap);
    await tester.tapAt(Offset(box.right - 30, box.center.dy));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('photo 2 of 2')), findsOneWidget);

    await tester.tapAt(Offset(box.left + 30, box.center.dy));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('photo 1 of 2')), findsOneWidget);
  });

  testWidgets('a single photo shows no segment bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(deck(const {}));
    expect(find.byKey(const Key('photo-segments')), findsNothing);
    expect(find.byKey(const Key('card-photo-tap')), findsNothing);
  });
}
