import 'package:flutter/material.dart';

import 'orientation_policy.dart';
import 'vawra_theme.dart';

/// On tablets and open foldables the app keeps a readable column, centred,
/// instead of stretching lines and cards across the screen (Apple's readable
/// content width). Screens are told the column's size, so sheets and dialogs
/// size themselves to it. Phones are untouched.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child});

  static const maxWidth = 720.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    applyOrientationPolicy(media.size);
    if (media.size.width <= maxWidth) return child;
    return ColoredBox(
      color: VawraColors.canvas,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
