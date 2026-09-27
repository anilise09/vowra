import 'package:ember_app/data/api/vawra_api.dart';
import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';
import 'support/fake_vawra_server.dart';

Future<void> _openSignIn(WidgetTester tester, FakeVawraServer server) async {
  final api = VawraApi(Uri.parse('http://vawra.test'), client: server.client);
  await tester.pumpWidget(VawraApp(api: api));
  await tester.pumpAndSettle();
  expect(find.text('Continue with email'), findsOneWidget);
  expect(find.textContaining('Prototype only'), findsNothing);
  for (final key in ['adult-checkbox', 'rules-checkbox']) {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
  }
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('continue-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('continue-button')));
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester, FakeVawraServer server) async {
  await _openSignIn(tester, server);
  await tester.enterText(
    find.byKey(const Key('sign-in-email')),
    'alex@example.test',
  );
  await tester.tap(find.byKey(const Key('send-code')));
  await tester.pumpAndSettle();
  expect(find.text('Check your email'), findsOneWidget);
  await tester.enterText(
    find.byKey(const Key('sign-in-code')),
    server.outbox.last,
  );
  await tester.tap(find.byKey(const Key('verify-code')));
  await tester.pumpAndSettle();
}

Future<void> _completeOnboarding(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
  await tapNext(tester);
  await tester.enterText(find.byKey(const Key('onboarding-age')), '28');
  await tapNext(tester);
  await tester.tap(find.byKey(const Key('intent-open_to_long_term')));
  await tester.pump();
  await tapNext(tester);
  await tester.tap(find.byKey(const Key('interest-Books')));
  await tester.pump();
  await tapNext(tester);
  await tester.tap(find.byKey(const Key('onboarding-skip')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('onboarding-skip')));
  await tester.pumpAndSettle();
  expect(find.textContaining('This prototype keeps'), findsNothing);
  expect(find.textContaining('saved to your Vawra account'), findsOneWidget);
  await tapNext(tester);
}

/// ServerHome polls on a timer, so settle with bounded pumps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a wrong code explains itself without revealing the account', (
    tester,
  ) async {
    final server = FakeVawraServer();
    await _openSignIn(tester, server);
    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'not-an-email',
    );
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    expect(find.textContaining('Enter an email address'), findsOneWidget);
    expect(server.requests, isEmpty);

    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'alex@example.test',
    );
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sign-in-code')),
      'proof-that-was-never-sent',
    );
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();
    expect(find.textContaining('That code didn\'t work'), findsOneWidget);
  });

  testWidgets('new account: profile, age check, then match and chat for real', (
    tester,
  ) async {
    final server = FakeVawraServer()
      ..addPerson('Maya', likesMe: true)
      ..addPerson('Elena');
    await _signIn(tester, server);

    // A new account creates its profile with the usual onboarding.
    expect(find.byKey(const Key('onboarding-name')), findsOneWidget);
    await _completeOnboarding(tester);
    expect(server.profile?['display_name'], 'Alex');
    expect(server.profile?.containsKey('age'), isFalse);

    // Dating stays closed until the age check passes.
    expect(find.byKey(const Key('age-check-again')), findsOneWidget);
    await tester.tap(find.byKey(const Key('age-check-again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('age-check-again')), findsOneWidget);
    server.verified = true;
    await tester.tap(find.byKey(const Key('age-check-again')));
    await _settle(tester);

    await dismissSwipeTutorial(tester);
    expect(find.text('Maya, 30', findRichText: true), findsOneWidget);
    expect(find.text('2 people to meet'), findsOneWidget);
    expect(find.textContaining('PROTOTYPE PROFILE'), findsNothing);

    await tester.tap(find.byKey(const Key('action-like')));
    await _settle(tester);
    expect(server.mySwipes[server.idOf('Maya')], 'like');
    expect(find.byKey(const Key('match-celebration')), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-send-message')));
    await _settle(tester);
    expect(find.text('Matched on Vawra'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('message-composer')),
      'Hi Maya!',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-message')));
    await _settle(tester);
    final matchId = server.matches.keys.single;
    expect(server.messages[matchId]?.single['text'], 'Hi Maya!');

    // The reply arrives with the next refresh.
    server.peerSays(matchId, 'Hello Alex, how is your week?');
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    expect(find.text('Hello Alex, how is your week?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('thread-back')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('chat-tab')));
    await _settle(tester);
    await closeSafetyGuideIfShown(tester);
    await _settle(tester);
    expect(find.byKey(const Key('conversation-Maya')), findsOneWidget);
  });

  testWidgets('a restart with a saved session goes straight back in', (
    tester,
  ) async {
    final server = FakeVawraServer()
      ..verified = true
      ..addPerson('Maya')
      ..profile = {
        'display_name': 'Alex',
        'relationship_intent': 'casual',
        'bio': '',
        'interests': <String>[],
        'show_distance_band': true,
        'call_ready_by_default': false,
        'public_age': 28,
      };
    final store = MemorySessionStore()
      ..saved = (
        refreshToken: 'refresh-token-00000000000',
        accountId: FakeVawraServer.me,
      );
    await tester.pumpWidget(
      VawraApp(
        api: VawraApi(
          Uri.parse('http://vawra.test'),
          client: server.client,
          store: store,
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Continue with email'), findsNothing);
    await dismissSwipeTutorial(tester);
    expect(find.text('Maya, 30', findRichText: true), findsOneWidget);
  });

  testWidgets('sign out ends the session and returns to the start', (
    tester,
  ) async {
    final server = FakeVawraServer()
      ..verified = true
      ..profile = {
        'display_name': 'Alex',
        'relationship_intent': 'casual',
        'bio': '',
        'interests': <String>[],
        'show_distance_band': true,
        'call_ready_by_default': false,
        'public_age': 28,
      };
    await _signIn(tester, server);
    await _settle(tester);
    await dismissSwipeTutorial(tester);
    await tester.tap(find.byKey(const Key('profile-tab')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('open-settings')));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('What Vawra keeps'), 200);
    expect(find.textContaining('What this prototype keeps'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-sign-out')),
      200,
    );
    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await _settle(tester);
    expect(server.requests.last.method, 'DELETE');
    expect(server.requests.last.url.path, '/v1/session');
    expect(find.text('Continue with email'), findsOneWidget);
  });

  group('account deletion', () {
    Map<String, dynamic> profile() => {
      'display_name': 'Alex',
      'relationship_intent': 'casual',
      'bio': '',
      'interests': <String>[],
      'show_distance_band': true,
      'call_ready_by_default': false,
      'public_age': 28,
    };

    Future<void> openDelete(WidgetTester tester) async {
      await dismissSwipeTutorial(tester);
      await tester.tap(find.byKey(const Key('profile-tab')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('open-settings')));
      await _settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-delete')),
        200,
      );
      await tester.tap(find.byKey(const Key('settings-delete')));
      await _settle(tester);
      expect(find.text('Delete your account?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await _settle(tester);
    }

    testWidgets('schedules it and shows the server date, signed out', (
      tester,
    ) async {
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile();
      await _signIn(tester, server);
      await _settle(tester);
      await openDelete(tester);
      expect(server.deletionAt, isNotNull);
      expect(
        find.text('Your account will be deleted on 4 October 2026'),
        findsOneWidget,
      );
      expect(find.textContaining('signed out on every device'), findsOneWidget);
      await tester.tap(find.byKey(const Key('deletion-done')));
      await _settle(tester);
      expect(find.text('Continue with email'), findsOneWidget);
    });

    testWidgets('an old sign-in confirms with a code first', (tester) async {
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile();
      await _signIn(tester, server);
      await _settle(tester);
      server.recentSignIn = false;
      await openDelete(tester);
      expect(server.deletionAt, isNull);
      expect(find.text("Confirm it's you"), findsOneWidget);
      expect(find.textContaining('To delete your account'), findsOneWidget);
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
      expect(server.deletionAt, isNotNull);
      expect(find.byKey(const Key('deletion-done')), findsOneWidget);
    });

    testWidgets('signing in before the date lets the person keep it', (
      tester,
    ) async {
      final server = FakeVawraServer()
        ..verified = true
        ..addPerson('Maya')
        ..profile = profile()
        ..deletionAt = DateTime.utc(2026, 10, 4, 12);
      await _signIn(tester, server);
      await _settle(tester);
      expect(
        find.text('Your account will be deleted on 4 October 2026'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('keep-account')));
      await _settle(tester);
      expect(server.deletionAt, isNull);
      await dismissSwipeTutorial(tester);
      expect(find.text('Maya, 30', findRichText: true), findsOneWidget);
    });
  });
}
