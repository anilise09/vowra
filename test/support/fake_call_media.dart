import 'dart:async';

import 'package:ember_app/data/api/vawra_api.dart';
import 'package:ember_app/features/calls/call_media.dart';
import 'package:flutter/widgets.dart';

/// A camera, microphone and connection that only record what was asked of
/// them. [candidate] and [connect] play the network's part.
class FakeCallMedia implements CallMedia {
  FakeCallMedia({this.denyPermission = false});

  final bool denyPermission;
  final log = <String>[];
  IceSetup? ice;
  bool? openedVideo;
  bool closed = false;
  bool muted = false;
  bool cameraOn = true;
  bool? speaker;
  final _candidates = StreamController<String>.broadcast();
  final _link = StreamController<MediaLink>.broadcast();

  void candidate(String c) => _candidates.add(c);
  void connect() => _link.add(MediaLink.connected);
  void drop() => _link.add(MediaLink.interrupted);
  void fail() => _link.add(MediaLink.failed);

  @override
  Future<void> open({required bool video, required IceSetup ice}) async {
    if (denyPermission) throw const MediaPermissionDenied();
    this.ice = ice;
    openedVideo = video;
    log.add('open ${video ? 'video' : 'audio'}');
  }

  @override
  Future<String> createOffer() async {
    log.add('offer');
    return 'offer-sdp';
  }

  @override
  Future<String> createAnswer(String offer) async {
    log.add('answer to $offer');
    return 'answer-sdp';
  }

  @override
  Future<void> acceptAnswer(String answer) async => log.add('accept $answer');

  @override
  Future<void> addCandidate(String candidate) async =>
      log.add('candidate $candidate');

  @override
  Stream<String> get localCandidates => _candidates.stream;

  @override
  Stream<MediaLink> get link => _link.stream;

  @override
  Future<void> setMuted(bool muted) async => this.muted = muted;

  @override
  Future<void> setCameraOn(bool on) async => cameraOn = on;

  @override
  Future<void> switchCamera() async => log.add('flip');

  @override
  Future<void> setSpeaker(bool on) async => speaker = on;

  @override
  Widget? localView() =>
      openedVideo == true ? const SizedBox(key: Key('local-video')) : null;

  @override
  Widget? remoteView() =>
      openedVideo == true ? const SizedBox(key: Key('remote-video')) : null;

  @override
  Future<void> close() async {
    closed = true;
    log.add('close');
  }
}
