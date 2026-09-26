import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/vawra_theme.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Offset _offset = Offset.zero;
  Animation<Offset>? _animation;
  SwipeDirection? _leaving;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final animation = _animation;
      if (animation != null) setState(() => _offset = animation.value);
    });
  }

  @override
  void didUpdateWidget(SwipeCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frontId != widget.frontId) {
      _controller.stop();
      _animation = null;
      _leaving = null;
      _offset = Offset.zero;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
    // A small lean first so a button press reads like a real swipe.
    final lean = switch (direction) {
      SwipeDirection.left => Offset(-_size.width * 0.08, 0),
      SwipeDirection.right => Offset(_size.width * 0.08, 0),
      SwipeDirection.up => Offset(0, -_size.height * 0.06),
    };
    await _animateTo(lean, const Duration(milliseconds: 110), Curves.easeOut);
    await _flyOff(direction);
  }

  Future<void> _animateTo(Offset target, Duration duration, Curve curve) {
    _animation = Tween(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: curve));
    _controller.duration = duration;
    return _controller.forward(from: 0);
  }

  Future<void> _flyOff(SwipeDirection direction) async {
    _leaving = direction;
    HapticFeedback.lightImpact();
    final width = _size.width;
    final height = _size.height;
    final target = switch (direction) {
      SwipeDirection.left => Offset(-width * 1.6, _offset.dy + height * 0.05),
      SwipeDirection.right => Offset(width * 1.6, _offset.dy + height * 0.05),
      SwipeDirection.up => Offset(_offset.dx, -height * 1.4),
    };
    await _animateTo(target, const Duration(milliseconds: 260), Curves.easeIn);
    if (mounted) widget.onSwiped(direction);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (busy) return;
    setState(() => _offset += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (busy) return;
    final velocity = details.velocity.pixelsPerSecond;
    final horizontal = _offset.dx.abs() >= _offset.dy.abs();
    SwipeDirection? direction;
    if (horizontal) {
      if (_offset.dx > _size.width * 0.28 ||
          (velocity.dx > 900 && _offset.dx > 0)) {
        direction = SwipeDirection.right;
      } else if (_offset.dx < -_size.width * 0.28 ||
          (velocity.dx < -900 && _offset.dx < 0)) {
        direction = SwipeDirection.left;
      }
    } else if (_offset.dy < -_size.height * 0.2 ||
        (velocity.dy < -900 && _offset.dy < 0)) {
      direction = SwipeDirection.up;
    }
    if (direction == SwipeDirection.up && !widget.canSwipeUp) {
      widget.onSwipeUpBlocked?.call();
      direction = null;
    }
    if (direction != null) {
      _flyOff(direction);
    } else {
      _animateTo(
        Offset.zero,
        const Duration(milliseconds: 420),
        Curves.elasticOut,
      );
    }
  }

  /// 0..1 progress toward a swipe decision, used for stamps and the back card.
  double get _progress {
    if (_size == Size.zero) return 0;
    final horizontal = (_offset.dx.abs() / (_size.width * 0.28));
    final vertical = (-_offset.dy / (_size.height * 0.2));
    return math.max(horizontal, vertical).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      final angle = (_offset.dx / math.max(_size.width, 1)) * 0.35;
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
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Transform.translate(
                offset: _offset,
                child: Transform.rotate(
                  angle: angle,
                  alignment: const Alignment(0, 1.4),
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
        ],
      );
    },
  );
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
