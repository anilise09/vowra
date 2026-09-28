import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../theme/vawra_theme.dart';
import 'swipe_physics.dart';

enum SwipeDirection { left, right, up }

/// A two-card stack: the front card follows the finger, tilts, shows a stamp
/// for the direction it is heading, and flies off or springs back on release.
/// The card behind grows into place as the front card leaves.
class SwipeCardStack extends StatefulWidget {
  const SwipeCardStack({
    super.key,
    required this.frontId,
    required this.front,
    this.back,
    required this.onSwiped,
    this.canSwipeUp = true,
    this.onSwipeUpBlocked,
  });

  /// Identifies the front card; a new id resets the drag state.
  final String frontId;
  final Widget front;
  final Widget? back;

  /// Called once the fly-off animation has finished.
  final ValueChanged<SwipeDirection> onSwiped;

  /// False when no Super Likes are left: an upward swipe springs back.
  final bool canSwipeUp;
  final VoidCallback? onSwipeUpBlocked;

  @override
  State<SwipeCardStack> createState() => SwipeCardStackState();
}

class SwipeCardStackState extends State<SwipeCardStack>
    with TickerProviderStateMixin {
  // X and Y are separate springs: a single spring on the 2D distance would
  // desync when the two axes move at different speeds.
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _y = AnimationController.unbounded(
    vsync: this,
  );

  /// Reduced motion only: the card fades instead of flying.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  SwipeDirection? _leaving;
  Size _size = Size.zero;

  /// Where the card was grabbed: the lower half tilts the other way, like a
  /// real card held low.
  double _tiltSign = 1;

  /// Past the commit line during the drag (for the haptic tick).
  bool _armed = false;

  Offset get _offset => Offset(_x.value, _y.value);

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didUpdateWidget(SwipeCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frontId != widget.frontId) {
      _x
        ..stop()
        ..value = 0;
      _y
        ..stop()
        ..value = 0;
      _fade.value = 0;
      _leaving = null;
      _armed = false;
      _tiltSign = 1;
    }
  }

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    _fade.dispose();
    super.dispose();
  }

  bool get busy => _leaving != null;

  /// Swipes the front card programmatically, as the action buttons do.
  Future<void> swipe(SwipeDirection direction) async {
    if (busy) return;
    if (direction == SwipeDirection.up && !widget.canSwipeUp) {
      widget.onSwipeUpBlocked?.call();
      return;
    }
    if (!_reduceMotion) {
      // A small lean first so a button press reads like a real swipe.
      final lean = switch (direction) {
        SwipeDirection.left => Offset(-_size.width * 0.08, 0),
        SwipeDirection.right => Offset(_size.width * 0.08, 0),
        SwipeDirection.up => Offset(0, -_size.height * 0.06),
      };
      const d = Duration(milliseconds: 110);
      await Future.wait([
        _x.animateTo(lean.dx, duration: d, curve: Curves.easeOut),
        _y.animateTo(lean.dy, duration: d, curve: Curves.easeOut),
      ]);
    }
    await _flyOff(direction, Offset.zero);
  }

  /// Leaves at the finger's speed (at least a brisk throw), in its direction.
  Future<void> _flyOff(SwipeDirection direction, Offset velocity) async {
    _leaving = direction;
    HapticFeedback.lightImpact();
    if (_reduceMotion) {
      await _fade.forward(from: 0);
      if (mounted) widget.onSwiped(direction);
      return;
    }
    final width = _size.width;
    final height = _size.height;
    final target = switch (direction) {
      SwipeDirection.left => Offset(-width * 1.6, _offset.dy + height * 0.05),
      SwipeDirection.right => Offset(width * 1.6, _offset.dy + height * 0.05),
      SwipeDirection.up => Offset(_offset.dx, -height * 1.4),
    };
    final distance = (target - _offset).distance;
    final duration = flyOffDuration(distance, velocity.distance);
    // A thrown card keeps its speed (linear); a button press accelerates away.
    final curve = velocity == Offset.zero ? Curves.easeIn : Curves.linear;
    await Future.wait([
      _x.animateTo(target.dx, duration: duration, curve: curve),
      _y.animateTo(target.dy, duration: duration, curve: curve),
    ]);
    if (mounted) widget.onSwiped(direction);
  }

  /// Catching the card mid-motion stops it where it is, under the finger:
  /// the new gesture starts from the on-screen position, never a jump.
  void _onPanDown(DragDownDetails details) {
    if (busy) return;
    _x.stop();
    _y.stop();
    _tiltSign = details.localPosition.dy > _size.height / 2 ? -1 : 1;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (busy) return;
    _x.value += details.delta.dx;
    _y.value += details.delta.dy;
    final armed = decideSwipe(_offset, Offset.zero, _size) != null;
    if (armed != _armed) {
      _armed = armed;
      // Tick when crossing the line, so the finger feels the decision point.
      if (armed) HapticFeedback.selectionClick();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (busy) return;
    _armed = false;
    final velocity = details.velocity.pixelsPerSecond;
    // Decide from the drawn position (rubber-banded downwards).
    final shown = _shownOffset;
    var direction = decideSwipe(shown, velocity, _size);
    if (direction == SwipeDirection.up && !widget.canSwipeUp) {
      widget.onSwipeUpBlocked?.call();
      direction = null;
    }
    if (direction != null) {
      _y.value = shown.dy;
      _flyOff(direction, velocity);
      return;
    }
    _y.value = shown.dy;
    if (_reduceMotion) {
      _x.value = 0;
      _y.value = 0;
      return;
    }
    // Back home on a spring that starts at the release speed: no seam between
    // dragging and animating, and a little bounce because momentum preceded it.
    _x.animateWith(
      SpringSimulation(springAfterFlick, _x.value, 0, velocity.dx),
    );
    _y.animateWith(
      SpringSimulation(springAfterFlick, _y.value, 0, velocity.dy),
    );
  }

  /// Down is not a direction: past the resting point the card resists.
  Offset get _shownOffset {
    final raw = _offset;
    if (raw.dy <= 0 || busy) return raw;
    return Offset(raw.dx, rubberband(raw.dy, _size.height));
  }

  /// 0..1 progress toward a swipe decision, used for stamps and the back card.
  double get _progress {
    if (_size == Size.zero) return 0;
    final horizontal = (_offset.dx.abs() / (_size.width * 0.28));
    final vertical = (-_offset.dy / (_size.height * 0.2));
    return math.max(horizontal, vertical).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_x, _y, _fade]),
    builder: (context, _) => LayoutBuilder(builder: _layout),
  );

  Widget _layout(BuildContext context, BoxConstraints constraints) {
    _size = constraints.biggest;
    final shown = _shownOffset;
    final angle = (shown.dx / math.max(_size.width, 1)) * 0.35 * _tiltSign;
    final likeOpacity = (_offset.dx / (_size.width * 0.25)).clamp(0.0, 1.0);
    final nopeOpacity = (-_offset.dx / (_size.width * 0.25)).clamp(0.0, 1.0);
    final superOpacity = _offset.dx.abs() > -_offset.dy
        ? 0.0
        : (-_offset.dy / (_size.height * 0.16)).clamp(0.0, 1.0);
    final backScale = 0.93 + 0.07 * _progress;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.back != null)
          Positioned.fill(
            child: Transform.scale(
              scale: backScale,
              child: IgnorePointer(child: widget.back),
            ),
          ),
        Positioned.fill(
          child: GestureDetector(
            key: const Key('swipe-front'),
            behavior: HitTestBehavior.translucent,
            onPanDown: _onPanDown,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Opacity(
              opacity: 1 - _fade.value,
              child: Transform.translate(
                offset: shown,
                child: Transform.rotate(
                  angle: angle,
                  alignment: Alignment(0, 1.4 * _tiltSign),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.front,
                      Positioned(
                        top: 70,
                        left: 26,
                        child: _Stamp(
                          key: const Key('stamp-like'),
                          label: 'LIKE',
                          color: VawraColors.coral,
                          angle: -0.28,
                          opacity: likeOpacity,
                        ),
                      ),
                      Positioned(
                        top: 70,
                        right: 26,
                        child: _Stamp(
                          key: const Key('stamp-nope'),
                          label: 'NOPE',
                          color: const Color(0xFFB9AEB6),
                          angle: 0.28,
                          opacity: nopeOpacity,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 150,
                        child: Center(
                          child: _Stamp(
                            key: const Key('stamp-super'),
                            label: 'SUPER LIKE',
                            color: VawraColors.superLike,
                            angle: -0.12,
                            opacity: superOpacity,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    super.key,
    required this.label,
    required this.color,
    required this.angle,
    required this.opacity,
  });

  final String label;
  final Color color;
  final double angle;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    ),
  );
}
