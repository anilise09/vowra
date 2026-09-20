import 'package:ember_app/domain/match_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const active = MatchConnection(matchId: 'synthetic-1', peerName: 'Maya');

  test('call request requires active match and mutual readiness', () {
    expect(active.canRequestCall, isFalse);
    final mine = active.setCurrentUserCallReady(true);
    expect(mine.canRequestCall, isFalse);
    expect(mine.setPeerCallReady(true).canRequestCall, isTrue);
  });

  test('block is terminal for messaging, readiness, and calls', () {
    final blocked = active
        .setCurrentUserCallReady(true)
        .setPeerCallReady(true)
        .block();
    expect(blocked.status, ConnectionStatus.blocked);
    expect(blocked.canMessage, isFalse);
    expect(blocked.canRequestCall, isFalse);
    expect(blocked.setCurrentUserCallReady(true), same(blocked));
  });

  test('unmatch closes contact while report preserves evidence state', () {
    final reported = active.report();
    expect(reported.reported, isTrue);
    expect(reported.canMessage, isTrue);
    final unmatched = reported.unmatch();
    expect(unmatched.reported, isTrue);
    expect(unmatched.canMessage, isFalse);
    expect(unmatched.canRequestCall, isFalse);
  });
}
