import 'dart:ui';

import 'package:ember_app/features/discovery/swipe_card_stack.dart';
import 'package:ember_app/features/discovery/swipe_physics.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const card = Size(360, 560);

  group('momentum decides the swipe', () {
    test('a slow drag past the line commits; a short one springs back', () {
      expect(
        decideSwipe(const Offset(140, 0), Offset.zero, card),
        SwipeDirection.right,
      );
      expect(decideSwipe(const Offset(80, 0), Offset.zero, card), isNull);
    });

    test('a quick flick from near the centre commits by momentum', () {
      // 40 px out, but moving right at 1500 px/s: projected ~190 px.
      expect(
        decideSwipe(const Offset(40, 0), const Offset(1500, 0), card),
        SwipeDirection.right,
      );
      expect(
        decideSwipe(const Offset(-30, 0), const Offset(-1600, 0), card),
        SwipeDirection.left,
      );
    });

    test('flicking back toward the centre cancels, even past the line', () {
      expect(
        decideSwipe(const Offset(150, 0), const Offset(-900, 0), card),
        isNull,
      );
    });

    test('up needs to head up; downward never commits', () {
      expect(
        decideSwipe(const Offset(0, -60), const Offset(0, -1400), card),
        SwipeDirection.up,
      );
      expect(decideSwipe(const Offset(0, 200), Offset.zero, card), isNull);
    });
  });

  test('momentum projection follows the exponential-decay form', () {
    expect(projectMomentum(1000), closeTo(99, 0.01));
    expect(projectMomentum(-1000), closeTo(-99, 0.01));
    expect(projectMomentum(1000, decelerationRate: 0.998), closeTo(499, 0.01));
  });

  test('rubber-banding resists more the further it goes', () {
    final a = rubberband(100, 560);
    final b = rubberband(300, 560);
    expect(a, lessThan(100));
    expect(b, lessThan(300));
    // Diminishing returns: each extra pixel moves the card less.
    expect((b - a) / 200, lessThan(a / 100));
    expect(rubberband(-100, 560), -a);
  });

  test('springs: damping 1.0 never overshoots, 0.8 does a little', () {
    double peak(SpringDescription spring) {
      final sim = SpringSimulation(spring, 100, 0, 0);
      var lowest = 100.0;
      for (var t = 0.0; t < 2; t += 0.005) {
        lowest = lowest < sim.x(t) ? lowest : sim.x(t);
      }
      return lowest;
    }

    expect(
      peak(appleSpring(dampingRatio: 1, response: 0.35)),
      greaterThanOrEqualTo(-0.01),
    );
    final bounce = peak(appleSpring(dampingRatio: 0.8, response: 0.35));
    expect(bounce, lessThan(0));
    expect(bounce, greaterThan(-5)); // a small overshoot, not a wobble
  });

  test('fly-off keeps the finger speed within sensible bounds', () {
    expect(flyOffDuration(600, 3000), const Duration(milliseconds: 200));
    expect(flyOffDuration(600, 200), const Duration(milliseconds: 320));
    expect(flyOffDuration(100, 9000), const Duration(milliseconds: 120));
  });
}
