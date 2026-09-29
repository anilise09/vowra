import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/api/vawra_api.dart';
import 'call_media.dart';

enum CallPhase { ringingOut, ringingIn, connecting, live, ended }

/// One call from ringing to hang-up. The server passes the setup messages
/// between the two phones; the call itself goes through [media].
class CallController extends ChangeNotifier {
  CallController._({
    required this.api,
    required this.media,
    required this.peerName,
    required this.video,
    required this._phase,
    this.checkEvery = const Duration(seconds: 2),
    this.ringFor = const Duration(seconds: 45),
  });

  /// Rings [peerName] in [matchId].
  factory CallController.outgoing({
    required VawraApi api,
    required CallMedia media,
    required String matchId,
    required String peerName,
    required bool video,
    Duration checkEvery = const Duration(seconds: 2),
    Duration ringFor = const Duration(seconds: 45),
  }) {
    final controller = CallController._(
      api: api,
      media: media,
      peerName: peerName,
      video: video,
      phase: CallPhase.ringingOut,
      checkEvery: checkEvery,
      ringFor: ringFor,
    );
    unawaited(controller._dial(matchId));
    return controller;
  }

  /// A call ringing on this phone, waiting for [accept] or [decline].
  factory CallController.incoming({
    required VawraApi api,
    required CallMedia media,
    required ServerCall call,
    required String peerName,
    Duration checkEvery = const Duration(seconds: 2),
  }) {
    final controller = CallController._(
      api: api,
      media: media,
      peerName: peerName,
      video: call.video,
      phase: CallPhase.ringingIn,
      checkEvery: checkEvery,
    );
    controller._call = call;
    controller._startChecking();
    return controller;
  }

  final VawraApi api;
  final CallMedia media;
  final String peerName;
  final Duration checkEvery;
  final Duration ringFor;

  /// A video call; an audio call never opens the camera.
  final bool video;

  CallPhase _phase;
  CallPhase get phase => _phase;

  ServerCall? _call;
  String? get callId => _call?.callId;

  /// Why the call ended, in words for the person.
  String? endedBecause;

  bool muted = false;
  bool cameraOn = true;
  late bool speakerOn = video;

  /// Set while the connection is briefly lost.
  bool reconnecting = false;

  /// When the two phones connected; the screen counts from here.
  DateTime? connectedAt;

  int _cursor = 0;
  bool _checking = false;
  bool _checkAgain = false;
  Timer? _check;
  Timer? _ring;
  StreamSubscription<String>? _candidates;
  StreamSubscription<MediaLink>? _link;
  bool _mediaOpen = false;

  bool get ended => _phase == CallPhase.ended;

  Future<void> _dial(String matchId) async {
    try {
      _call = await api.startCall(matchId, video: video);
    } catch (e) {
      return _finish(_startError(e), tellServer: false);
    }
    if (ended) return _tellServerEnded();
    _ring = Timer(ringFor, () {
      if (_phase == CallPhase.ringingOut) hangUp(because: 'No answer');
    });
    if (!await _openMedia()) return;
    try {
      await api.sendSignal(_call!.callId, 'offer', await media.createOffer());
    } catch (_) {
      return _finish('The call could not connect');
    }
    _startChecking();
  }

  /// Answers, audio only when [withVideo] is false.
  Future<void> accept({bool withVideo = true}) async {
    if (_phase != CallPhase.ringingIn) return;
    _set(CallPhase.connecting);
    try {
      _call = await api.answerCall(_call!.callId);
    } catch (_) {
      return _finish('This call has ended', tellServer: false);
    }
    if (!withVideo) cameraOn = false;
    if (!await _openMedia(video: video && withVideo)) return;
    await _checkNow();
  }

  Future<void> decline() async {
    if (_phase != CallPhase.ringingIn) return;
    _finish('Declined', tellServer: false);
    await api.declineCall(_call!.callId).catchError((Object _) {});
  }

  Future<void> hangUp({String because = 'Call ended'}) async {
    if (ended) return;
    _finish(because);
  }

  /// A call nudge arrived: something changed for this call.
  void poke() => unawaited(_checkNow());

  Future<void> toggleMute() async {
    muted = !muted;
    notifyListeners();
    await media.setMuted(muted);
  }

  Future<void> toggleCamera() async {
    cameraOn = !cameraOn;
    notifyListeners();
    await media.setCameraOn(cameraOn);
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    notifyListeners();
    await media.setSpeaker(speakerOn);
  }

  Future<void> switchCamera() => media.switchCamera();

  Future<bool> _openMedia({bool? video}) async {
    final ice = _call?.ice;
    if (ice == null) {
      _finish('Calls are not available right now');
      return false;
    }
    try {
      await media.open(video: video ?? this.video, ice: ice);
      _mediaOpen = true;
    } on MediaPermissionDenied {
      _finish(
        video ?? this.video
            ? 'Vawra needs the camera and microphone for a video call. You can allow them in your phone\'s settings.'
            : 'Vawra needs the microphone for a call. You can allow it in your phone\'s settings.',
      );
      return false;
    } catch (_) {
      _finish('The call could not connect');
      return false;
    }
    if (ended) {
      await media.close();
      return false;
    }
    // Video calls start on the speaker, audio calls at the ear.
    speakerOn = this.video;
    await media.setSpeaker(speakerOn);
    _candidates = media.localCandidates.listen((c) {
      final id = _call?.callId;
      if (id != null && !ended) {
        api.sendSignal(id, 'candidate', c).catchError((Object _) {});
      }
    });
    _link = media.link.listen(_onLink);
    notifyListeners();
    return true;
  }

  void _onLink(MediaLink link) {
    if (ended) return;
    switch (link) {
      case MediaLink.connected:
        reconnecting = false;
        connectedAt ??= DateTime.now();
        _set(CallPhase.live);
      case MediaLink.interrupted:
        reconnecting = true;
        notifyListeners();
      case MediaLink.failed:
        hangUp(because: 'The connection was lost');
      case MediaLink.connecting:
        break;
    }
  }

  void _startChecking() {
    _check?.cancel();
    _check = Timer.periodic(checkEvery, (_) => _checkNow());
  }

  /// Reads the call's state and, once media is open, the other phone's
  /// setup messages in order. Never runs twice at once.
  Future<void> _checkNow() async {
    final id = _call?.callId;
    if (id == null || ended) return;
    if (_checking) {
      _checkAgain = true;
      return;
    }
    _checking = true;
    try {
      do {
        _checkAgain = false;
        await _checkOnce(id);
      } while (_checkAgain && !ended);
    } finally {
      _checking = false;
    }
  }

  Future<void> _checkOnce(String id) async {
    try {
      if (!_mediaOpen) {
        // Still ringing here: only whether the caller gave up.
        final call = await api.call(id);
        if (!call.live) _finish(_endedWords(call.state), tellServer: false);
        return;
      }
      final result = await api.signals(id, after: _cursor);
      for (final signal in result.signals) {
        if (ended) return;
        _cursor = signal.seq;
        switch (signal.type) {
          case 'offer':
            await api.sendSignal(
              id,
              'answer',
              await media.createAnswer(signal.data),
            );
          case 'answer':
            await media.acceptAnswer(signal.data);
            if (_phase == CallPhase.ringingOut) _set(CallPhase.connecting);
          case 'candidate':
            await media.addCandidate(signal.data);
        }
      }
      if (result.state == 'active' && _phase == CallPhase.ringingOut) {
        _set(CallPhase.connecting);
      }
      if (result.state != 'ringing' && result.state != 'active') {
        _finish(_endedWords(result.state), tellServer: false);
      }
    } on ApiException catch (e) {
      if (e.status == 404 || e.code == 'conversation_closed') {
        _finish('Call ended', tellServer: false);
      }
    } catch (_) {
      // Offline for a moment; the next check tries again.
    }
  }

  String _endedWords(String state) => switch (state) {
    'declined' => '$peerName can\'t talk right now',
    'missed' => 'No answer',
    'cancelled' => _phase == CallPhase.ringingIn ? 'Missed call' : 'Call ended',
    _ => 'Call ended',
  };

  String _startError(Object e) => switch (e) {
    ApiException(code: 'busy') => '$peerName is on another call',
    ApiException(code: 'not_ready') =>
      'You both need to turn on "Open to a call" first',
    ApiException(code: 'call_limit') =>
      'You\'ve started a lot of calls. Try again later.',
    ApiException(code: 'calls_unavailable') =>
      'Calls are not available right now',
    ApiException(code: 'conversation_closed') => 'This conversation has closed',
    _ => 'The call could not start. Check your connection.',
  };

  void _set(CallPhase phase) {
    if (ended || _phase == phase) return;
    _phase = phase;
    notifyListeners();
  }

  void _finish(String because, {bool tellServer = true, bool notify = true}) {
    if (ended) return;
    endedBecause = because;
    _phase = CallPhase.ended;
    _check?.cancel();
    _ring?.cancel();
    unawaited(_candidates?.cancel());
    unawaited(_link?.cancel());
    if (_mediaOpen) unawaited(media.close());
    _mediaOpen = false;
    if (tellServer) unawaited(_tellServerEnded());
    if (notify) notifyListeners();
  }

  Future<void> _tellServerEnded() async {
    final id = _call?.callId;
    if (id != null) await api.endCall(id).catchError((Object _) {});
  }

  @override
  void dispose() {
    _finish('Call ended', notify: false);
    super.dispose();
  }
}
