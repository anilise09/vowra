// Opt-in check against a real local backend (see backend/README.md):
//   VAWRA_LIVE_API=http://127.0.0.1:8797 VAWRA_OUTBOX=backend/.data/outbox.log \
//   VAWRA_LIVE_A=alex.test@vawra.test VAWRA_LIVE_B=maya.test@vawra.test \
//   flutter test test/live/nudge_live_test.dart
// Both accounts must exist, be age-verified locally and already be matched.
import 'dart:async';
import 'dart:io';

import 'package:ember_app/data/api/nudges.dart';
import 'package:ember_app/data/api/vawra_api.dart';
import 'package:flutter_test/flutter_test.dart';

final _env = Platform.environment;

Future<VawraApi> _signIn(String email) async {
  final api = VawraApi(Uri.parse(_env['VAWRA_LIVE_API']!));
  await api.requestSignIn(email);
  final line = File(_env['VAWRA_OUTBOX']!)
      .readAsLinesSync()
      .lastWhere((l) => l.split(' ')[2] == email);
  await api.exchange(line.split(' ')[3]);
  return api;
}

void main() {
  test(
    'a message on the real server reaches the other app as a nudge',
    () async {
      final a = await _signIn(_env['VAWRA_LIVE_A']!);
      final b = await _signIn(_env['VAWRA_LIVE_B']!);
      final match = (await b.matches()).firstWhere(
        (m) => m.peerAccountId == a.accountId,
      );

      final received = <Nudge>[];
      final gotMessage = Completer<Duration>();
      final clock = Stopwatch();
      final link = NudgeLink(
        a,
        onNudge: (n) {
          received.add(n);
          if (n.kind == 'message' && !gotMessage.isCompleted) {
            gotMessage.complete(clock.elapsed);
          }
        },
      )..start();

      // Connected: the link sends its catch-up first.
      while (!link.connected) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      clock.start();
      await b.send(match.matchId, 'Live nudge check ${DateTime.now()}');
      final after = await gotMessage.future.timeout(const Duration(seconds: 5));
      link.dispose();

      expect(received.first, Nudge.catchUp);
      expect(received.last, Nudge('message', matchId: match.matchId));
      // ignore: avoid_print
      print('nudge arrived ${after.inMilliseconds} ms after sending');
    },
    skip: _env['VAWRA_LIVE_API'] == null ? 'needs VAWRA_LIVE_API' : false,
  );
}
