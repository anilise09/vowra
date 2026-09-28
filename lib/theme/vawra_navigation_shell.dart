import 'dart:ui';

import 'package:flutter/material.dart';

/// A quiet, translucent home for the app's existing destinations.
/// The navigation bar stays a NavigationBar for semantics and large-text support.
class VawraNavigationShell extends StatelessWidget {
  const VawraNavigationShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            border: const Border(top: BorderSide(color: Color(0xFFEDE5E7))),
          ),
          child: child,
        ),
      ),
    ),
  );
}
