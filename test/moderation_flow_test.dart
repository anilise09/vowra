import 'package:ember_app/data/api/vawra_api.dart';
import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';
import 'support/fake_vawra_server.dart';

/// The server-connected app keeps a live link open: settle by time.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _signIn(WidgetTester tester, FakeVawraServer server) async {
  final api = VawraApi(Uri.parse('http://vawra.test'), client: server.client);
  await tester.pumpWidget(VawraApp(api: api));
  await _settle(tester);
  for (final key in ['adult-checkbox', 'rules-checkbox']) {
    await tester.ensureVisible(find.byKey(Key(key)));
    await _settle(tester);
    await tester.tap(find.byKey(Key(key)));
  }
  await tester.ensureVisible(find.byKey(const Key('continue-button')));
  await _settle(tester);
  await tester.tap(find.byKey(const Key('continue-button')));
  await _settle(tester);
  await tester.enterText(
    find.byKey(const Key('sign-in-email')),
    'alex@example.test',
  );
  await tester.tap(find.byKey(const Key('send-code')));
  await _settle(tester);
  await tester.enterText(
    find.byKey(const Key('sign-in-code')),
    server.outbox.last,
  );
  await tester.tap(find.byKey(const Key('verify-code')));
  await _settle(tester);
}

Map<String, dynamic> _profile() => {
  'display_name': 'Alex',
  'relationship_intent': 'casual',
  'bio': '',
  'interests': <String>['Books'],
  'show_distance_band': true,
  'call_ready_by_default': false,
  'public_age': 28,
};

Future<void> _openModeration(WidgetTester tester) async {
  await dismissSwipeTutorial(tester);
  await tester.tap(find.byKey(const Key('profile-tab')));
  await _settle(tester);
  await tester.tap(find.byKey(const Key('open-settings')));
  await _settle(tester);
  await tester.scrollUntilVisible(
    find.byKey(const Key('settings-moderation')),
    200,
  );
  await tester.ensureVisible(find.byKey(const Key('settings-moderation')));
  await _settle(tester);
  await tester.tap(find.byKey(const Key('settings-moderation')));
  await _settle(tester);
}

void main() {
  group('suspended', () {
    FakeVawraServer suspended({String? appealState}) => FakeVawraServer()
      ..verified = true
      ..profile = _profile()
      ..suspension = {'since': '2026-09-28T12:00:00.000Z', 'reason': 'scam'}
      ..appealState = appealState;

    testWidgets('says why, and takes one appeal', (tester) async {
      final server = suspended();
      await _signIn(tester, server);
      expect(find.byKey(const Key('suspended-title')), findsOneWidget);
      expect(
        find.textContaining('“Scam or suspicious request”'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('discovery-card-gesture')), findsNothing);

      await tester.tap(find.byKey(const Key('appeal-send')));
      await _settle(tester);
      expect(server.appeals, isEmpty, reason: 'an empty appeal is not sent');
      expect(find.textContaining('Write a few words'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('appeal-message')),
        'That was my brother on my phone.',
      );
      await tester.tap(find.byKey(const Key('appeal-send')));
      await _settle(tester);
      expect(server.appeals, ['That was my brother on my phone.']);
      expect(find.byKey(const Key('appeal-pending')), findsOneWidget);
      expect(find.byKey(const Key('appeal-send')), findsNothing);
      // Their data and the exits stay open.
      for (final key in [
        'suspended-export',
        'suspended-delete',
        'suspended-sign-out',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }
    });

    testWidgets('an upheld appeal can be explained once more', (tester) async {
      await _signIn(tester, suspended(appealState: 'upheld'));
      expect(find.textContaining('the suspension stays'), findsOneWidget);
      expect(find.byKey(const Key('appeal-send')), findsOneWidget);
    });

    testWidgets('an open appeal shows as waiting', (tester) async {
      await _signIn(tester, suspended(appealState: 'open'));
      expect(find.byKey(const Key('appeal-pending')), findsOneWidget);
      expect(find.byKey(const Key('appeal-message')), findsNothing);
    });
  });

  group('moderation', () {
    FakeVawraServer withQueue() => FakeVawraServer()
      ..verified = true
      ..profile = _profile()
      ..moderator = true
      ..modReports.add({
        'report_id': 'r1',
        'reason': 'scam',
        'reported_at': '2026-09-28T10:00:00.000Z',
        'account_id': 'ben',
        'display_name': 'Ben',
        'bio': 'Crypto coach',
        'prompts': <Object>[],
        'status': 'active',
        'message': {
          'text': 'Send me money now',
          'sent_at': '2026-09-28T09:59:00.000Z',
        },
        'reports_against': 2,
        'reporter_report_count': 1,
      })
      ..modAppeals.addAll([
        {
          'appeal_id': 'a1',
          'message': 'That was not me.',
          'created_at': '2026-09-28T11:00:00.000Z',
          'account_id': 'cy',
          'display_name': 'Cy',
          'suspended_at': '2026-09-27T11:00:00.000Z',
          'suspension_reason': 'harassment',
          'suspended_by_you': true,
        },
        {
          'appeal_id': 'a2',
          'message': 'I have changed.',
          'created_at': '2026-09-28T12:00:00.000Z',
          'account_id': 'dee',
          'display_name': 'Dee',
          'suspended_at': '2026-09-26T11:00:00.000Z',
          'suspension_reason': 'other',
          'suspended_by_you': false,
        },
      ]);

    testWidgets('members have no Moderation row', (tester) async {
      final server = FakeVawraServer()
        ..verified = true
        ..profile = _profile();
      await _signIn(tester, server);
      await dismissSwipeTutorial(tester);
      await tester.tap(find.byKey(const Key('profile-tab')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('open-settings')));
      await _settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-sign-out')),
        200,
      );
      expect(find.byKey(const Key('settings-moderation')), findsNothing);
    });

    testWidgets('a report shows its evidence; suspending is confirmed', (
      tester,
    ) async {
      final server = withQueue();
      await _signIn(tester, server);
      await _openModeration(tester);
      expect(find.text('Reports (1)'), findsOneWidget);
      expect(
        find.text('Reported message: “Send me money now”'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('mod-suspend-r1')));
      await _settle(tester);
      expect(find.text('Suspend Ben?'), findsOneWidget);
      expect(server.decisions, isEmpty, reason: 'nothing until confirmed');
      await tester.enterText(
        find.byKey(const Key('mod-note')),
        'Asked for money',
      );
      await tester.tap(find.byKey(const Key('mod-confirm')));
      await _settle(tester);
      expect(server.decisions, ['reports:r1:suspended']);
      expect(find.text('No reports waiting.'), findsOneWidget);
    });

    testWidgets('first use: an authenticator is set up, then the queue opens', (
      tester,
    ) async {
      final server = withQueue()..modSecondFactor = 'none';
      await _signIn(tester, server);
      await _openModeration(tester);
      expect(find.byKey(const Key('mod-gate-setup')), findsOneWidget);
      expect(find.textContaining('Send me money'), findsNothing);
      // No queue tabs with unknown counts while the code is asked for.
      expect(find.textContaining('Reports ('), findsNothing);
      await tester.tap(find.byKey(const Key('mod-2fa-start')));
      await _settle(tester);
      // The key is shown in groups of four, to type into an authenticator.
      expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('mod-2fa-code')), '000000');
      await _settle(tester);
      expect(find.textContaining('That code didn\'t work'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('mod-2fa-code')),
        FakeVawraServer.modCode,
      );
      await _settle(tester);
      expect(find.byKey(const Key('mod-gate-setup')), findsNothing);
      expect(find.text('Reports (1)'), findsOneWidget);
      expect(server.modCodesTried, ['000000', FakeVawraServer.modCode]);
    });

    testWidgets(
      'after half an hour a code reopens moderation, even mid-decision',
      (tester) async {
        final server = withQueue()..modSecondFactor = 'enabled';
        await _signIn(tester, server);
        await _openModeration(tester);
        expect(find.byKey(const Key('mod-gate-verify')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('mod-2fa-code')),
          FakeVawraServer.modCode,
        );
        await _settle(tester);
        expect(find.text('Reports (1)'), findsOneWidget);

        // The half hour runs out while a decision is being made.
        server.modSecondFactor = 'enabled';
        await tester.tap(find.byKey(const Key('mod-suspend-r1')));
        await _settle(tester);
        await tester.tap(find.byKey(const Key('mod-confirm')));
        await _settle(tester);
        expect(server.decisions, isEmpty);
        expect(find.byKey(const Key('mod-gate-verify')), findsOneWidget);
        // Straight to the code: no error message on the way.
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('an old sign-in confirms with a code, then comes back', (
      tester,
    ) async {
      final server = withQueue();
      await _signIn(tester, server);
      server.recentSignIn = false;
      await _openModeration(tester);
      await tester.tap(find.byKey(const Key('mod-dismiss-r1')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('mod-confirm')));
      await _settle(tester);
      expect(
        find.textContaining('To make a moderation decision'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('sign-in-email')),
        'alex@example.test',
      );
      await tester.tap(find.byKey(const Key('send-code')));
      await _settle(tester);
      await tester.enterText(
        find.byKey(const Key('sign-in-code')),
        server.outbox.last,
      );
      await tester.tap(find.byKey(const Key('verify-code')));
      await _settle(tester);
      expect(server.decisions, ['reports:r1:dismissed']);
      expect(find.text('Moderation'), findsOneWidget);
      expect(find.text('No reports waiting.'), findsOneWidget);
    });

    testWidgets('you cannot decide an appeal for a suspension you made', (
      tester,
    ) async {
      final server = withQueue();
      await _signIn(tester, server);
      await _openModeration(tester);
      await tester.tap(find.text('Appeals (2)'));
      await _settle(tester);
      expect(find.byKey(const Key('mod-not-yours')), findsOneWidget);
      final mine = tester.widget<FilledButton>(
        find.byKey(const Key('mod-overturn-a1')),
      );
      expect(mine.onPressed, isNull);
      await tester.ensureVisible(find.byKey(const Key('mod-overturn-a2')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('mod-overturn-a2')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('mod-confirm')));
      await _settle(tester);
      expect(server.decisions, ['appeals:a2:overturned']);
    });
  });
}
