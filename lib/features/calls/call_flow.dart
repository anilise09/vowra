import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/nudges.dart';
import '../../domain/safety_report.dart';
import 'call_controller.dart';
import 'call_media.dart';
import 'call_screen.dart';
import 'webrtc_media.dart';

/// Makes the camera, microphone and connection for a call; tests replace it.
CallMedia Function() newCallMedia = WebRtcMedia.new;

/// The call on screen now, if any; there is at most one.
abstract final class ActiveCall {
  static CallController? current;

  /// A call is on screen and has not ended.
  static bool get busy => !(current?.ended ?? true);
}

/// Shows [controller]'s call full screen until it ends, feeding it the call
/// nudges, then hangs up if needed and releases the camera and microphone.
Future<void> showCallScreen(
  BuildContext context, {
  required CallController controller,
  Stream<Nudge>? nudges,
  ImageProvider? peerPhoto,
  Future<void> Function(ReportReason reason)? onReport,
  VoidCallback? onBlock,
}) async {
  ActiveCall.current = controller;
  final sub = nudges?.listen((nudge) {
    if (nudge.isCatchUp ||
        (nudge.kind == 'call' && nudge.callId == controller.callId)) {
      controller.poke();
    }
  });
  try {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CallScreen(
          controller: controller,
          peerPhoto: peerPhoto,
          onReport: onReport,
          onBlock: onBlock,
        ),
      ),
    );
  } finally {
    await sub?.cancel();
    if (!controller.ended) await controller.hangUp();
    if (ActiveCall.current == controller) ActiveCall.current = null;
    controller.dispose();
  }
}
