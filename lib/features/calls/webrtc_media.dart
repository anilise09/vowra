import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../data/api/vawra_api.dart';
import 'call_media.dart';

/// [CallMedia] on WebRTC. With a relay-only [IceSetup] every packet goes
/// through the relay, so neither phone learns the other's address. Nothing is
/// recorded: the streams go to the screen and the speaker only.
class WebRtcMedia implements CallMedia {
  RTCPeerConnection? _pc;
  MediaStream? _local;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _renderers = false;
  bool _hasVideo = false;
  final _candidates = StreamController<String>.broadcast();
  final _link = StreamController<MediaLink>.broadcast();

  /// Candidates that arrived before the other phone's description.
  final _early = <RTCIceCandidate>[];
  bool _remoteSet = false;

  @override
  Stream<String> get localCandidates => _candidates.stream;

  @override
  Stream<MediaLink> get link => _link.stream;

  @override
  Future<void> open({required bool video, required IceSetup ice}) async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _renderers = true;
    try {
      _local = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      });
    } catch (e) {
      final text = e.toString().toLowerCase();
      if (text.contains('permission') || text.contains('notallowed')) {
        throw const MediaPermissionDenied();
      }
      rethrow;
    }
    _hasVideo = video;
    _localRenderer.srcObject = _local;
    final pc = await createPeerConnection({
      'iceServers': ice.servers,
      'iceTransportPolicy': ice.relayOnly ? 'relay' : 'all',
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    for (final track in _local!.getTracks()) {
      await pc.addTrack(track, _local!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null || _candidates.isClosed) return;
      _candidates.add(jsonEncode(c.toMap()));
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
      }
    };
    pc.onConnectionState = (state) {
      if (_link.isClosed) return;
      final link = switch (state) {
        RTCPeerConnectionState.RTCPeerConnectionStateConnected =>
          MediaLink.connected,
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
          MediaLink.interrupted,
        RTCPeerConnectionState.RTCPeerConnectionStateFailed => MediaLink.failed,
        _ => MediaLink.connecting,
      };
      _link.add(link);
    };
  }

  RTCSessionDescription _description(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return RTCSessionDescription(map['sdp'] as String?, map['type'] as String?);
  }

  Future<void> _setRemote(String json) async {
    await _pc!.setRemoteDescription(_description(json));
    _remoteSet = true;
    for (final c in _early) {
      await _pc!.addCandidate(c);
    }
    _early.clear();
  }

  @override
  Future<String> createOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    return jsonEncode(offer.toMap());
  }

  @override
  Future<String> createAnswer(String offer) async {
    await _setRemote(offer);
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    return jsonEncode(answer.toMap());
  }

  @override
  Future<void> acceptAnswer(String answer) => _setRemote(answer);

  @override
  Future<void> addCandidate(String candidate) async {
    final map = jsonDecode(candidate) as Map<String, dynamic>;
    final c = RTCIceCandidate(
      map['candidate'] as String?,
      map['sdpMid'] as String?,
      map['sdpMLineIndex'] as int?,
    );
    if (_remoteSet) {
      await _pc!.addCandidate(c);
    } else {
      _early.add(c);
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
  }

  @override
  Future<void> setCameraOn(bool on) async {
    for (final t in _local?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = on;
    }
  }

  @override
  Future<void> switchCamera() async {
    final track = _local?.getVideoTracks().firstOrNull;
    if (track != null) await Helper.switchCamera(track);
  }

  @override
  Future<void> setSpeaker(bool on) => Helper.setSpeakerphoneOn(on);

  @override
  Widget? localView() => _hasVideo
      ? RTCVideoView(
          _localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        )
      : null;

  @override
  Widget? remoteView() => _hasVideo
      ? RTCVideoView(
          _remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        )
      : null;

  @override
  Future<void> close() async {
    for (final t in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
      await t.stop();
    }
    await _local?.dispose();
    _local = null;
    await _pc?.close();
    _pc = null;
    if (_renderers) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      await _localRenderer.dispose();
      await _remoteRenderer.dispose();
      _renderers = false;
    }
    await _candidates.close();
    await _link.close();
  }
}
