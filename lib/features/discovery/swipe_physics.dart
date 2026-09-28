import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/physics.dart';

import 'swipe_card_stack.dart' show SwipeDirection;

// Physics for touch-driven motion, after Apple's "Designing Fluid Interfaces"
// (WWDC 2018): springs described by damping ratio and response, momentum
// projection to decide where a flick is going, and rubber-banding at edges.

/// A spring from Apple's two designer-friendly parameters. [dampingRatio] 1.0
/// settles without overshoot; below 1.0 it overshoots. [response] is roughly
/// how quickly it gets there, in seconds (not a fixed duration).
SpringDescription appleSpring({
  required double dampingRatio,
  required double response,
}) {
  const mass = 1.0;
  final stiffness = math.pow(2 * math.pi / response, 2) * mass;
  final damping = 4 * math.pi * dampingRatio * mass / response;
  return SpringDescription(
    mass: mass,
    stiffness: stiffness.toDouble(),
    damping: damping,
  );
}

/// Settling after a flick: a little bounce, because momentum preceded it.
final springAfterFlick = appleSpring(dampingRatio: 0.8, response: 0.35);

/// Where a release at [velocity] (px/s) would carry the card, the way a
/// scroll view decelerates. 0.99 is Apple's "snappier" rate.
double projectMomentum(double velocity, {double decelerationRate = 0.99}) =>
    (velocity / 1000) * decelerationRate / (1 - decelerationRate);

/// Soft resistance past a boundary: the further past, the less it follows.
double rubberband(
  double overshoot,
  double dimension, [
  double constant = 0.55,
]) {
  if (dimension <= 0) return 0;
  final sign = overshoot.sign;
  final distance = overshoot.abs();
  return sign *
      (distance * dimension * constant) /
      (dimension + constant * distance);
}

/// How far the card must (be projected to) travel to commit.
const horizontalCommit = 0.33; // of the card width
const upCommit = 0.22; // of the card height

/// A release moving back toward the centre faster than this cancels the swipe,
/// whatever the position: the direction of the gesture shows the intent.
const reversalCancelsAt = 250.0; // px/s

/// Decides a release from where the card is and where its momentum projects
/// it, not from position alone.
SwipeDirection? decideSwipe(Offset offset, Offset velocity, Size size) {
  if (size.isEmpty) return null;
  final projected = Offset(
    offset.dx + projectMomentum(velocity.dx),
    offset.dy + projectMomentum(velocity.dy),
  );
  final horizontal = projected.dx.abs() >= -projected.dy;
  if (horizontal) {
    if (projected.dx > size.width * horizontalCommit &&
        velocity.dx > -reversalCancelsAt) {
      return SwipeDirection.right;
    }
    if (projected.dx < -size.width * horizontalCommit &&
        velocity.dx < reversalCancelsAt) {
      return SwipeDirection.left;
    }
    return null;
  }
  if (projected.dy < -size.height * upCommit &&
      velocity.dy < reversalCancelsAt) {
    return SwipeDirection.up;
  }
  return null;
}

/// How long a card leaving at [speed] px/s takes to cover [distance], so the
/// fly-off continues at the finger's speed instead of a fixed timing.
Duration flyOffDuration(double distance, double speed) {
  final pxPerSecond = math.max(speed, 1600.0);
  final ms = (distance / pxPerSecond * 1000).clamp(120.0, 320.0);
  return Duration(milliseconds: ms.round());
}
