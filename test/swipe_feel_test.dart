import 'package:ember_app/features/discovery/swipe_card_stack.dart';
import 'package:ember_app/features/matches/match_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// How the card feels under the finger (apple-design: interruptible,
/// momentum-aware, haptic at the decision point, gentle with reduced motion).
void main() {
  late List<SwipeDirection> swiped;

  Future<void> pumpStack(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    swiped = [];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 560,
                child: SwipeCardStack(
                  frontId: 'a',
                  front: const ColoredBox(
                    key: Key('front'),
                    color: Colors.pink,
                  ),
                  onSwiped: swiped.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset cardCentre(WidgetTester tester) =>
      tester.getCenter(find.byKey(const Key('front')));

  testWidgets('catching the card mid-spring holds it where it was caught', (
    tester,
  ) async {
    await pumpStack(tester);
    final home = cardCentre(tester);
    await tester.drag(
      find.byKey(const Key('swipe-front')),
      const Offset(90, 0),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final inFlight = cardCentre(tester);
    expect(inFlight.dx, greaterThan(home.dx)); // still springing back

    final grab = await tester.startGesture(inFlight);
    await tester.pump(const Duration(milliseconds: 200));
    // Held: no jump, and the spring no longer pulls it home.
    expect((cardCentre(tester) - inFlight).distance, lessThan(2));
    await grab.up();
    await tester.pumpAndSettle();
    expect(swiped, isEmpty);
  });

  testWidgets('a quick flick from near the centre commits', (tester) async {
    await pumpStack(tester);
    await tester.fling(
      find.byKey(const Key('swipe-front')),
      const Offset(50, 0),
      1600,
    );
    await tester.pumpAndSettle();
    expect(swiped, [SwipeDirection.right]);
  });

  testWidgets('flicking back toward the centre cancels the swipe', (
    tester,
  ) async {
    await pumpStack(tester);
    final gesture = await tester.startGesture(cardCentre(tester));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(16, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Now 160 px right (past the line), then a fast move back.
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(swiped, isEmpty);
  });

  testWidgets('one haptic tick when crossing the line, not on every move', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    await pumpStack(tester);
    final gesture = await tester.startGesture(cardCentre(tester));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    await gesture.up();
    await tester.pumpAndSettle();
    // Committing adds the impact, on the same frame the card leaves.
    expect(haptics.last, 'HapticFeedbackType.lightImpact');
    expect(swiped, [SwipeDirection.right]);
  });

  testWidgets('with reduced motion the card fades instead of flying', (
    tester,
  ) async {
    await pumpStack(tester, reduceMotion: true);
    final home = cardCentre(tester);
    final state = tester.state<SwipeCardStackState>(
      find.byType(SwipeCardStack),
    );
    final done = state.swipe(SwipeDirection.left);
    await tester.pump(); // the fade's clock starts on this frame
    await tester.pump(const Duration(milliseconds: 80));
    expect(cardCentre(tester), home); // no travel
    final opacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const Key('front')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, lessThan(1));
    await tester.pumpAndSettle();
    await done;
    expect(swiped, [SwipeDirection.left]);
  });

  testWidgets('a match lands with one firm haptic', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => MatchCelebration.show(
              context,
              peerName: 'Maya',
              peerPhotoAsset: 'assets/profiles/maya.png',
              ownInitial: 'A',
              superLike: false,
              onMessage: () {},
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('match-celebration')), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.heavyImpact']);
  });
}
