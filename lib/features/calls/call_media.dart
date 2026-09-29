import 'package:flutter/widgets.dart';

import '../../data/api/vawra_api.dart';

/// Whether the two phones can hear and see each other.
enum MediaLink { connecting, connected, interrupted, failed }

/// The camera or microphone was refused; the call cannot go ahead.
class MediaPermissionDenied implements Exception {
  const MediaPermissionDenied();
}

/// The part of a call that touches the camera, the microphone and the
/// network. Everything else (ringing, the setup messages, hanging up) lives in
/// [CallController], so it can be tested without a camera.
abstract interface class CallMedia {
  /// Opens the microphone, and the camera for [video]; this is when the
  /// phone asks for permission. Throws [MediaPermissionDenied] when refused.
  Future<void> open({required bool video, required IceSetup ice});

  /// The caller's opening description of the call, to send to the other phone.
  Future<String> createOffer();

  /// The callee's reply to [offer].
  Future<String> createAnswer(String offer);

  Future<void> acceptAnswer(String answer);

  Future<void> addCandidate(String candidate);

  /// Ways this phone can be reached, to send to the other phone as found.
  Stream<String> get localCandidates;

  Stream<MediaLink> get link;

  Future<void> setMuted(bool muted);
  Future<void> setCameraOn(bool on);
  Future<void> switchCamera();
  Future<void> setSpeaker(bool on);

  /// Your camera and theirs; null before the camera opens or in an audio call.
  Widget? localView();
  Widget? remoteView();

  /// Stops the camera and microphone and closes the connection.
  Future<void> close();
}
