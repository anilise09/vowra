import 'dart:math';

import 'package:ember_app/data/api/nudges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('connection state machine', () {
    LinkTransition go(LinkState s, LinkEvent e) => nextLink(s, e);

    test('start opens; opened connects and catches up', () {
      final started = go(const LinkStopped(), LinkEvent.start);
      expect(started.state, isA<LinkConnecting>());
      expect((started.state as LinkConnecting).attempt, 0);
      expect(started.effects, [LinkEffect.open]);

      final opened = go(started.state, LinkEvent.opened);
      expect(opened.state, isA<LinkConnected>());
      expect(opened.effects, [LinkEffect.catchUp]);
    });

    test('failed attempts count up; a dropped live connection starts at 0', () {
      final failed = go(const LinkConnecting(2), LinkEvent.dropped);
      expect((failed.state as LinkWaitingToRetry).attempt, 3);
      expect(failed.effects, [LinkEffect.scheduleRetry]);

      final dropped = go(const LinkConnected(), LinkEvent.dropped);
      expect((dropped.state as LinkWaitingToRetry).attempt, 0);

      final retry = go(const LinkWaitingToRetry(3), LinkEvent.retryDue);
      expect((retry.state as LinkConnecting).attempt, 3);
      expect(retry.effects, [LinkEffect.open]);
    });

    test('stop always ends in Stopped with the right clean-up', () {
      expect(go(const LinkConnecting(0), LinkEvent.stop).effects, [
        LinkEffect.close,
      ]);
      expect(go(const LinkConnected(), LinkEvent.stop).effects, [
        LinkEffect.close,
      ]);
      expect(go(const LinkWaitingToRetry(1), LinkEvent.stop).effects, [
        LinkEffect.cancelRetry,
      ]);
      for (final s in const [
        LinkStopped(),
        LinkConnecting(0),
        LinkConnected(),
        LinkWaitingToRetry(1),
      ]) {
        expect(go(s, LinkEvent.stop).state, isA<LinkStopped>());
      }
    });

    test('events that make no sense are reported, not acted on', () {
      for (final (s, e) in const [
        (LinkStopped(), LinkEvent.opened),
        (LinkStopped(), LinkEvent.dropped),
        (LinkStopped(), LinkEvent.retryDue),
        (LinkConnected(), LinkEvent.opened),
        (LinkConnected(), LinkEvent.retryDue),
        (LinkWaitingToRetry(0), LinkEvent.opened),
      ]) {
        final t = go(s, e);
        expect(t.valid, isFalse, reason: '$s + $e');
        expect(t.effects, isEmpty);
      }
      // Start while already running is a harmless no-op.
      final again = go(const LinkConnected(), LinkEvent.start);
      expect(again.valid, isTrue);
      expect(again.effects, isEmpty);
    });
  });

  test('back-off grows exponentially with full jitter, capped', () {
    final random = Random(7);
    for (var attempt = 0; attempt < 12; attempt++) {
      final ceiling = min(60000, 1000 * pow(2, attempt).toInt());
      var maxSeen = 0;
      for (var i = 0; i < 400; i++) {
        final ms = backoffWithJitter(attempt, random).inMilliseconds;
        expect(ms, inInclusiveRange(0, ceiling));
        maxSeen = max(maxSeen, ms);
      }
      // Spread across the whole range, not bunched at one value.
      expect(maxSeen, greaterThan(ceiling * 0.8), reason: 'attempt $attempt');
    }
    expect(backoffWithJitter(1000, random).inMilliseconds, lessThan(60001));
  });

  group('SSE parser', () {
    test('reads events split across chunks, skipping comments', () {
      final parser = SseParser();
      expect(parser.add(': connected\n\nevent: nud'), isEmpty);
      expect(parser.add('ge\ndata: {"kind":"like"}\n'), isEmpty);
      expect(parser.add('\n: ping\n\n'), [('nudge', '{"kind":"like"}')]);
    });

    test('handles CRLF, several events in one chunk and multi-line data', () {
      final parser = SseParser();
      expect(
        parser.add('event: nudge\r\ndata: a\r\n\r\ndata: b\ndata: c\n\n'),
        [('nudge', 'a'), ('message', 'b\nc')],
      );
    });
  });
}
