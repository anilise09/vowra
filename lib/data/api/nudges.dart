import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'vawra_api.dart';

/// "Something changed" for this account. It carries no content: the app
/// fetches what changed through the normal authenticated routes.
class Nudge {
  const Nudge(this.kind, {this.matchId});

  /// message, match or like. [catchUp] asks every screen to refresh.
  final String kind;
  final String? matchId;

  static const catchUp = Nudge('catch_up');

  bool get isCatchUp => kind == 'catch_up';

  @override
  bool operator ==(Object other) =>
      other is Nudge && other.kind == kind && other.matchId == matchId;

  @override
  int get hashCode => Object.hash(kind, matchId);

  @override
  String toString() => 'Nudge($kind, $matchId)';
}

/// Reads a Server-Sent Events byte stream, chunk by chunk.
class SseParser {
  final _buffer = StringBuffer();

  /// Returns the complete events in [chunk] as (event, data) pairs.
  List<(String, String)> add(String chunk) {
    _buffer.write(chunk.replaceAll('\r\n', '\n'));
    final text = _buffer.toString();
    final end = text.lastIndexOf('\n\n');
    if (end < 0) return const [];
    _buffer
      ..clear()
      ..write(text.substring(end + 2));
    final events = <(String, String)>[];
    for (final block in text.substring(0, end).split('\n\n')) {
      var event = 'message';
      final data = <String>[];
      for (final line in block.split('\n')) {
        if (line.isEmpty || line.startsWith(':')) continue;
        final colon = line.indexOf(':');
        final field = colon < 0 ? line : line.substring(0, colon);
        var value = colon < 0 ? '' : line.substring(colon + 1);
        if (value.startsWith(' ')) value = value.substring(1);
        if (field == 'event') event = value;
        if (field == 'data') data.add(value);
      }
      if (data.isNotEmpty) events.add((event, data.join('\n')));
    }
    return events;
  }
}

/// Exponential back-off with full jitter: a random wait between zero and
/// min(cap, base * 2^attempt), so many phones never reconnect in lockstep.
Duration backoffWithJitter(
  int attempt,
  Random random, {
  Duration base = const Duration(seconds: 1),
  Duration cap = const Duration(seconds: 60),
}) {
  final ceiling = min(
    cap.inMilliseconds,
    base.inMilliseconds * pow(2, min(attempt, 16)).toInt(),
  );
  return Duration(milliseconds: random.nextInt(ceiling + 1));
}

// The connection is a small state machine. Transitions are pure: given a
// state and an event they return the next state and the side effects to run,
// or report the event as invalid for that state. The driver runs the effects.

sealed class LinkState {
  const LinkState();
}

class LinkStopped extends LinkState {
  const LinkStopped();
}

class LinkConnecting extends LinkState {
  const LinkConnecting(this.attempt);
  final int attempt;
}

class LinkConnected extends LinkState {
  const LinkConnected();
}

class LinkWaitingToRetry extends LinkState {
  const LinkWaitingToRetry(this.attempt);
  final int attempt;
}

enum LinkEvent { start, stop, opened, dropped, retryDue }

enum LinkEffect { open, close, scheduleRetry, cancelRetry, catchUp }

class LinkTransition {
  const LinkTransition(
    this.state, [
    this.effects = const [],
    this.valid = true,
  ]);
  const LinkTransition.invalid(this.state) : effects = const [], valid = false;

  final LinkState state;
  final List<LinkEffect> effects;
  final bool valid;
}

LinkTransition nextLink(LinkState state, LinkEvent event) =>
    switch ((state, event)) {
      (LinkStopped(), LinkEvent.start) => const LinkTransition(
        LinkConnecting(0),
        [LinkEffect.open],
      ),
      (LinkStopped(), LinkEvent.stop) => LinkTransition(state),
      (LinkStopped(), _) => LinkTransition.invalid(state),
      (_, LinkEvent.start) => LinkTransition(state),
      (LinkConnecting(), LinkEvent.opened) => const LinkTransition(
        LinkConnected(),
        [LinkEffect.catchUp],
      ),
      (LinkConnecting(:final attempt), LinkEvent.dropped) => LinkTransition(
        LinkWaitingToRetry(attempt + 1),
        const [LinkEffect.scheduleRetry],
      ),
      (LinkConnecting(), LinkEvent.stop) => const LinkTransition(
        LinkStopped(),
        [LinkEffect.close],
      ),
      // A connection that was up starts counting from zero again.
      (LinkConnected(), LinkEvent.dropped) => const LinkTransition(
        LinkWaitingToRetry(0),
        [LinkEffect.scheduleRetry],
      ),
      (LinkConnected(), LinkEvent.stop) => const LinkTransition(LinkStopped(), [
        LinkEffect.close,
      ]),
      (LinkWaitingToRetry(:final attempt), LinkEvent.retryDue) =>
        LinkTransition(LinkConnecting(attempt), const [LinkEffect.open]),
      (LinkWaitingToRetry(), LinkEvent.stop) => const LinkTransition(
        LinkStopped(),
        [LinkEffect.cancelRetry],
      ),
      _ => LinkTransition.invalid(state),
    };

/// Keeps one nudge stream open while [start]ed, reconnecting with back-off.
/// Every nudge, and a catch-up after each (re)connect, goes to [onNudge].
class NudgeLink {
  NudgeLink(
    this.api, {
    required this.onNudge,
    Random? random,
    this.retryBase = const Duration(seconds: 1),
    this.retryCap = const Duration(seconds: 60),
  }) : _random = random ?? Random();

  final VawraApi api;
  final void Function(Nudge nudge) onNudge;
  final Duration retryBase;
  final Duration retryCap;
  final Random _random;

  LinkState _state = const LinkStopped();
  LinkState get state => _state;
  bool get connected => _state is LinkConnected;

  StreamSubscription<String>? _subscription;
  Timer? _retry;

  /// Bumped on every open or close so late callbacks from an old stream are
  /// ignored.
  int _generation = 0;

  void start() => _handle(LinkEvent.start);
  void stop() => _handle(LinkEvent.stop);

  void _handle(LinkEvent event) {
    final previous = _state;
    final transition = nextLink(previous, event);
    if (!transition.valid) return;
    _state = transition.state;
    for (final effect in transition.effects) {
      switch (effect) {
        case LinkEffect.open:
          _open();
        case LinkEffect.close:
          _close();
        case LinkEffect.scheduleRetry:
          _close();
          final attempt = (_state as LinkWaitingToRetry).attempt;
          _retry = Timer(
            backoffWithJitter(attempt, _random, base: retryBase, cap: retryCap),
            () => _handle(LinkEvent.retryDue),
          );
        case LinkEffect.cancelRetry:
          _retry?.cancel();
          _retry = null;
        case LinkEffect.catchUp:
          onNudge(Nudge.catchUp);
      }
    }
  }

  Future<void> _open() async {
    final generation = ++_generation;
    try {
      final lines = await api.openEvents();
      if (generation != _generation) {
        // Stopped while connecting.
        unawaited(lines.listen(null).cancel());
        return;
      }
      final parser = SseParser();
      _subscription = lines.listen(
        (chunk) {
          for (final (event, data) in parser.add(chunk)) {
            if (event != 'nudge') continue;
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              onNudge(
                Nudge(
                  json['kind'] as String,
                  matchId: json['match_id'] as String?,
                ),
              );
            } catch (_) {
              // A malformed nudge is dropped; the safety refresh covers it.
            }
          }
        },
        onDone: () {
          if (generation == _generation) _handle(LinkEvent.dropped);
        },
        onError: (Object _) {
          if (generation == _generation) _handle(LinkEvent.dropped);
        },
        cancelOnError: true,
      );
      _handle(LinkEvent.opened);
    } catch (_) {
      if (generation == _generation) _handle(LinkEvent.dropped);
    }
  }

  void _close() {
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void dispose() {
    stop();
    _retry?.cancel();
  }
}
