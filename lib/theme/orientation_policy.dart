import 'package:flutter/services.dart';

/// Phones stay upright: a swipe card in a 390-pixel-tall landscape phone is
/// cramped, and dating apps are held one-handed. Tablets and open foldables
/// (shortest side 600 or more) turn freely. Re-applied when a foldable opens
/// or closes, because its shortest side changes.
List<DeviceOrientation> orientationsFor(Size logicalSize) =>
    logicalSize.shortestSide >= 600
    ? const []
    : const [DeviceOrientation.portraitUp];

List<DeviceOrientation>? _applied;

void applyOrientationPolicy(Size logicalSize) {
  final wanted = orientationsFor(logicalSize);
  if (_applied != null && _listEquals(_applied!, wanted)) return;
  _applied = wanted;
  SystemChrome.setPreferredOrientations(wanted);
}

bool _listEquals(List<DeviceOrientation> a, List<DeviceOrientation> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);
