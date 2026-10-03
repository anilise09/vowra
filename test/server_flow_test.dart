import 'package:ember_app/data/api/vawra_api.dart';
import 'package:ember_app/data/area_locator.dart';
import 'package:ember_app/data/area_prefs.dart';
import 'package:ember_app/domain/location_grid.dart';
import 'package:ember_app/features/calls/call_flow.dart';
import 'package:ember_app/features/shared/profile_image.dart';
import 'package:ember_app/main.dart';
import 'package:ember_app/server/photos_editor.dart';
import 'package:ember_app/server/server_flow.dart'
    show describeExportError, isSafeOutsideLink, openOutsideLink;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';
import 'support/fake_call_media.dart';
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
  await answerGenderSteps(tester);
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
/// Stands in for the phone's location: records whether it was allowed to ask.
class _FakeArea implements AreaLocator {
  _FakeArea(this.fix);

  AreaFix fix;
  final asks = <bool>[];

  @override
  Future<AreaFix> locate({required bool ask}) async {
    asks.add(ask);
    return fix;
  }

  @override
  Future<void> openSettings() async {}
}

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
    await tester.enterText(find.byKey(const Key('sign-in-code')), '000000');
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();
    expect(find.textContaining('That code didn\'t work'), findsOneWidget);
  });

  testWidgets('the sixth digit signs in: no extra tap, numbers only', (
    tester,
  ) async {
    final server = FakeVawraServer();
    await _openSignIn(tester, server);
    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'alex@example.test',
    );
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('sign-in-code'));
    // Letters and extra digits never get in.
    await tester.enterText(field, 'ab12');
    expect(tester.widget<TextField>(field).controller!.text, '12');
    final exchangesBefore = server.requests
        .where((r) => r.url.path == '/v1/auth/exchange')
        .length;
    await tester.enterText(field, '${server.outbox.last}9');
    await tester.pumpAndSettle();
    expect(
      server.requests.where((r) => r.url.path == '/v1/auth/exchange').length,
      exchangesBefore + 1,
    );
    expect(find.byKey(const Key('onboarding-name')), findsOneWidget);
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

    // A send that fails keeps what was typed, ready to try again.
    server.refuseNextMessage = true;
    await tester.enterText(find.byKey(const Key('message-composer')), 'Are you around?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-message')));
    await _settle(tester);
    expect(server.messages[matchId], hasLength(1));
    expect(
      tester.widget<TextField>(find.byKey(const Key('message-composer'))).controller!.text,
      'Are you around?',
    );
    // The error notice fades, then a retry sends it.
    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('send-message')));
    await _settle(tester);
    expect(server.messages[matchId]?.last['text'], 'Are you around?');
    expect(
      tester.widget<TextField>(find.byKey(const Key('message-composer'))).controller!.text,
      isEmpty,
    );

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

  group('the age check', () {
    final opened = <Uri>[];
    setUp(() {
      opened.clear();
      openOutsideLink = (url) async {
        opened.add(url);
        return true;
      };
    });

    void background(WidgetTester tester) {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    void resume(WidgetTester tester) {
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    testWidgets('opens the service, and Vawra opens on coming back', (
      tester,
    ) async {
      final server = FakeVawraServer()..addPerson('Maya');
      await _signIn(tester, server);
      await _completeOnboarding(tester);
      await tester.tap(find.byKey(const Key('age-check-start')));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(server.ageCheckUrl!)]);
      expect(server.ageChecksStarted, 1);
      expect(find.text('I\'ve finished'), findsOneWidget);

      // Back from the browser before the outcome: nothing changes, quietly.
      background(tester);
      resume(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('age-check-start')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // The outcome arrives while away: coming back opens Vawra.
      background(tester);
      server.verified = true;
      resume(tester);
      await _settle(tester);
      await dismissSwipeTutorial(tester);
      expect(find.text('1 person to meet'), findsOneWidget);
    });

    test('only HTTPS pages leave the app; HTTP only in development', () {
      bool safe(String url, {bool release = true}) =>
          isSafeOutsideLink(Uri.parse(url), release: release);
      expect(safe('https://checks.example.test/start?ref=r1'), isTrue);
      expect(safe('http://127.0.0.1:8798/start?ref=r1'), isFalse);
      expect(safe('http://127.0.0.1:8798/start?ref=r1', release: false), isTrue);
      for (final other in [
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///data/data/com.projectember.ember_app/shared_prefs/x.xml',
        'javascript:alert(1)',
        'tel:+15555550100',
        'https:no-host',
      ]) {
        expect(safe(other, release: false), isFalse, reason: other);
      }
    });

    testWidgets('an unsafe link from the server is never opened', (
      tester,
    ) async {
      final server = FakeVawraServer()
        ..ageCheckUrl = 'intent://check#Intent;scheme=evil;end';
      await _signIn(tester, server);
      await _completeOnboarding(tester);
      await tester.tap(find.byKey(const Key('age-check-start')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.text('Couldn\'t open the age check. Try again.'), findsOneWidget);
    });

    testWidgets('says so when the service is not connected', (tester) async {
      final server = FakeVawraServer()..ageCheckUrl = null;
      await _signIn(tester, server);
      await _completeOnboarding(tester);
      expect(find.byKey(const Key('age-check-unavailable')), findsNothing);
      await tester.tap(find.byKey(const Key('age-check-start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('age-check-unavailable')), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('a check under review waits; a failed one offers deletion', (
      tester,
    ) async {
      final server = FakeVawraServer()..unverifiedAgeState = 'pending_review';
      await _signIn(tester, server);
      await _completeOnboarding(tester);
      expect(find.text('Your age check is being reviewed'), findsOneWidget);
      expect(find.byKey(const Key('age-check-start')), findsNothing);

      server.unverifiedAgeState = 'rejected';
      await tester.tap(find.byKey(const Key('age-check-again')));
      await tester.pumpAndSettle();
      expect(find.text('Vawra is for adults only'), findsOneWidget);
      expect(find.byKey(const Key('age-check-again')), findsNothing);
      await tester.tap(find.byKey(const Key('age-delete')));
      await tester.pumpAndSettle();
      expect(server.deletionAt, isNotNull);
    });
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
    expect(find.textContaining('Prototype data stays in memory'), findsNothing);
    expect(
      find.textContaining('saved to your account when you tap Save'),
      findsOneWidget,
    );
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

  testWidgets('cards say why you might click; details list every reason', (
    tester,
  ) async {
    final server = FakeVawraServer()
      ..verified = true
      ..addPerson(
        'Maya',
        reasons: [
          {'kind': 'goal', 'text': 'Both want something long-term'},
          {'kind': 'interests', 'text': 'You both like Books'},
          {'kind': 'habit', 'text': 'Both dog people'},
          {'kind': 'looks', 'text': 'Never shown'},
        ],
      )
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
    // The card shows the shared interest; the goal already has its own line.
    expect(
      find.descendant(
        of: find.byKey(const Key('card-reason')),
        matching: find.text('You both like Books'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('open-profile-details')));
    await _settle(tester);
    final details = find.byKey(const Key('detail-reasons'));
    await tester.scrollUntilVisible(
      details,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('profile-details-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(details, findsOneWidget);
    for (final text in [
      'Both want something long-term',
      'You both like Books',
      'Both dog people',
    ]) {
      expect(
        find.descendant(of: details, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(find.text('Never shown'), findsNothing);
    expect(
      find.textContaining('never ranks people by popularity'),
      findsOneWidget,
    );
  });

  group('conversations', () {
    Future<String> matchedWithMaya(
      WidgetTester tester,
      FakeVawraServer server,
    ) async {
      server
        ..verified = true
        ..addPerson('Maya', likesMe: true)
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
      await tester.tap(find.byKey(const Key('action-like')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('match-keep-swiping')));
      await _settle(tester);
      return server.matches.keys.single;
    }

    Future<void> openChats(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('chat-tab')));
      await _settle(tester);
      await closeSafetyGuideIfShown(tester);
      await _settle(tester);
    }

    testWidgets('unread counts, then "Your turn" once read', (tester) async {
      final server = FakeVawraServer();
      final matchId = await matchedWithMaya(tester, server);
      server
        ..peerSays(matchId, 'Hi Alex!')
        ..peerSays(matchId, 'Free this weekend?');
      await _settle(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('chats-unread')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      await openChats(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('unread-Maya')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('conversation-Maya')));
      await _settle(tester);
      expect(server.myRead[matchId], 2);
      await tester.tap(find.byKey(const Key('thread-back')));
      await _settle(tester);
      expect(find.byKey(const Key('unread-Maya')), findsNothing);
      expect(find.byKey(const Key('your-turn-Maya')), findsOneWidget);
    });

    testWidgets('a risky message carries a warning with a one-tap report', (
      tester,
    ) async {
      final server = FakeVawraServer();
      final matchId = await matchedWithMaya(tester, server);
      server
        ..peerSays(matchId, 'Hi Alex!')
        ..peerSays(matchId, 'Can you send me a gift card?', hints: ['money']);
      await _settle(tester);
      await openChats(tester);
      await tester.tap(find.byKey(const Key('conversation-Maya')));
      await _settle(tester);
      final risky = server.messages[matchId]!.last['id'] as String;
      final calm = server.messages[matchId]!.first['id'] as String;
      expect(find.byKey(Key('safety-hint-$risky')), findsOneWidget);
      expect(find.byKey(Key('safety-hint-$calm')), findsNothing);
      expect(find.textContaining('Never send money'), findsOneWidget);

      await tester.tap(find.byKey(Key('hint-report-$risky')));
      await _settle(tester);
      expect(find.text('Include this message'), findsOneWidget);
      expect(find.textContaining('moderators'), findsWidgets);
      expect(find.textContaining('Prototype only'), findsNothing);
      await tester.tap(find.byKey(const Key('submit-report')));
      await _settle(tester);
      expect(server.reports.single, {
        'account_id': server.idOf('Maya'),
        'reason': 'scam',
        'message_id': risky,
      });
    });

    /// Alex and Maya are matched with Maya's chat open; [media] stands in for
    /// the camera, microphone and connection.
    Future<String> inChatWithMaya(
      WidgetTester tester,
      FakeVawraServer server,
      FakeCallMedia media, {
      bool mayaReady = true,
    }) async {
      final original = newCallMedia;
      addTearDown(() => newCallMedia = original);
      newCallMedia = () => media;
      final matchId = await matchedWithMaya(tester, server);
      if (mayaReady) server.callReadyByThem.add(matchId);
      await openChats(tester);
      await tester.tap(find.byKey(const Key('new-match-Maya')));
      await _settle(tester);
      return matchId;
    }

    IconButton callButton(WidgetTester tester, String key) =>
        tester.widget<IconButton>(find.byKey(Key(key)));

    /// Long enough for a call to react, shorter than the ended screen stays.
    Future<void> brief(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    String callStatus(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('call-status'))).data!;

    testWidgets('a video call: both opt in, it rings, connects and ends', (
      tester,
    ) async {
      final server = FakeVawraServer();
      final media = FakeCallMedia();
      final matchId = await inChatWithMaya(
        tester,
        server,
        media,
        mayaReady: false,
      );

      // Nobody can call until both people say yes.
      expect(callButton(tester, 'request-video-call').onPressed, isNull);
      await tester.tap(find.byKey(const Key('call-ready-switch')));
      await _settle(tester);
      expect(server.callReadyByMe, {matchId});
      expect(callButton(tester, 'request-voice-call').onPressed, isNull);
      server
        ..callReadyByThem.add(matchId)
        ..nudge('match', matchId: matchId);
      await _settle(tester);
      expect(callButton(tester, 'request-voice-call').onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('request-video-call')));
      await _settle(tester);
      expect(find.byKey(const Key('call-screen')), findsOneWidget);
      expect(callStatus(tester), 'Calling…');
      // The camera opens only now, and only through the relay.
      expect(media.log, ['open video', 'offer']);
      expect(media.ice!.relayOnly, isTrue);
      expect(server.sentSignals['call1'], [
        {'type': 'offer', 'data': 'offer-sdp'},
      ]);
      media.candidate('c1');
      await _settle(tester);
      expect(server.sentSignals['call1']!.last, {
        'type': 'candidate',
        'data': 'c1',
      });

      // Maya answers.
      server.calls['call1']!['state'] = 'active';
      server
        ..peerSignal('call1', 'answer', 'answer-sdp')
        ..peerSignal('call1', 'candidate', 'm1');
      await _settle(tester);
      expect(
        media.log,
        containsAllInOrder(['accept answer-sdp', 'candidate m1']),
      );
      expect(callStatus(tester), 'Connecting…');
      media.connect();
      await _settle(tester);
      expect(callStatus(tester), startsWith('0:0'));
      expect(find.byKey(const Key('remote-video')), findsOneWidget);
      expect(find.byKey(const Key('call-video-scrim')), findsOneWidget);
      expect(find.byKey(const Key('local-video')), findsOneWidget);

      await tester.tap(find.byKey(const Key('call-mute')));
      await tester.tap(find.byKey(const Key('call-camera')));
      await _settle(tester);
      expect(media.muted, isTrue);
      expect(media.cameraOn, isFalse);
      expect(find.byKey(const Key('local-video')), findsNothing);

      await tester.tap(find.byKey(const Key('call-hang-up')));
      await _settle(tester);
      expect(server.calls['call1']!['state'], 'ended');
      expect(media.closed, isTrue);
      await _settle(tester);
      expect(find.byKey(const Key('call-screen')), findsNothing);
    });

    testWidgets('a ring nobody answers, and a connection that drops', (
      tester,
    ) async {
      final server = FakeVawraServer();
      var media = FakeCallMedia();
      await inChatWithMaya(tester, server, media);
      newCallMedia = () => media;
      await tester.tap(find.byKey(const Key('call-ready-switch')));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('request-voice-call')));
      await _settle(tester);
      expect(media.openedVideo, isFalse);
      expect(media.speaker, isFalse); // a voice call starts at the ear
      await tester.pump(const Duration(seconds: 40));
      expect(callStatus(tester), 'Calling…');
      await tester.pump(const Duration(seconds: 4));
      await brief(tester);
      expect(callStatus(tester), 'No answer');
      expect(server.calls['call1']!['state'], 'cancelled');
      await _settle(tester);

      media = FakeCallMedia();
      await tester.tap(find.byKey(const Key('request-video-call')));
      await _settle(tester);
      server.calls['call2']!['state'] = 'active';
      server.peerSignal('call2', 'answer', 'answer-sdp');
      await _settle(tester);
      media.connect();
      await brief(tester);
      media.drop();
      await brief(tester);
      expect(callStatus(tester), 'Reconnecting…');
      media.fail();
      await brief(tester);
      expect(callStatus(tester), 'The connection was lost');
      expect(server.calls['call2']!['state'], 'ended');
      expect(media.closed, isTrue);
      await _settle(tester);
    });

    testWidgets('an incoming call rings on screen; answered without video', (
      tester,
    ) async {
      final server = FakeVawraServer();
      final media = FakeCallMedia();
      final matchId = await inChatWithMaya(tester, server, media);
      final callId = server.peerRings(matchId);
      await _settle(tester);
      expect(find.byKey(const Key('call-screen')), findsOneWidget);
      expect(callStatus(tester), 'Incoming video call');
      // Nothing is opened while it only rings.
      expect(media.log, isEmpty);

      await tester.tap(find.byKey(const Key('call-accept-audio')));
      await _settle(tester);
      expect(server.calls[callId]!['state'], 'active');
      expect(media.openedVideo, isFalse);
      server.peerSignal(callId, 'offer', 'offer-sdp');
      await _settle(tester);
      expect(media.log, contains('answer to offer-sdp'));
      expect(server.sentSignals[callId], [
        {'type': 'answer', 'data': 'answer-sdp'},
      ]);

      server.peerCallState(callId, 'ended');
      await brief(tester);
      expect(media.closed, isTrue);
      expect(find.text('Call ended'), findsOneWidget);
      await _settle(tester);
      expect(find.byKey(const Key('call-screen')), findsNothing);
    });

    testWidgets('declining, and a caller who gives up', (tester) async {
      final server = FakeVawraServer();
      final media = FakeCallMedia();
      final matchId = await inChatWithMaya(tester, server, media);
      var callId = server.peerRings(matchId, video: false);
      await _settle(tester);
      expect(callStatus(tester), 'Incoming voice call');
      expect(find.byKey(const Key('call-accept-audio')), findsNothing);
      await tester.tap(find.byKey(const Key('call-decline')));
      await _settle(tester);
      expect(server.calls[callId]!['state'], 'declined');
      await _settle(tester);
      expect(find.byKey(const Key('call-screen')), findsNothing);

      callId = server.peerRings(matchId);
      await _settle(tester);
      expect(callStatus(tester), 'Incoming video call');
      server.peerCallState(callId, 'cancelled');
      await brief(tester);
      expect(find.text('Missed call'), findsOneWidget);
      expect(media.log, isEmpty);
    });

    testWidgets('a refused camera ends the call with a way forward', (
      tester,
    ) async {
      final server = FakeVawraServer();
      final matchId = await inChatWithMaya(
        tester,
        server,
        FakeCallMedia(denyPermission: true),
      );
      await tester.tap(find.byKey(const Key('call-ready-switch')));
      await _settle(tester);
      expect(server.callReadyByMe, {matchId});
      await tester.tap(find.byKey(const Key('request-video-call')));
      await brief(tester);
      expect(callStatus(tester), contains('needs the camera and microphone'));
      expect(server.calls['call1']!['state'], 'cancelled');
    });

    testWidgets('block from inside a call ends it and closes the chat', (
      tester,
    ) async {
      final server = FakeVawraServer();
      final media = FakeCallMedia();
      final matchId = await inChatWithMaya(tester, server, media);
      final callId = server.peerRings(matchId);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('call-accept')));
      await _settle(tester);
      expect(media.openedVideo, isTrue);
      await tester.tap(find.byKey(const Key('call-safety-menu')));
      await _settle(tester);
      await tester.tap(find.text('End call and block'));
      await _settle(tester);
      expect(server.calls[callId]!['state'], 'ended');
      expect(server.blocked, isNotEmpty);
      expect(media.closed, isTrue);
    });

    testWidgets('report from inside a call', (tester) async {
      final server = FakeVawraServer();
      final matchId = await inChatWithMaya(tester, server, FakeCallMedia());
      server.peerRings(matchId);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('call-safety-menu')));
      await _settle(tester);
      await tester.tap(find.text('Report'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('call-report-harassment')));
      await _settle(tester);
      expect(server.reports.last['reason'], 'harassment');
      expect(find.byKey(const Key('call-reported')), findsOneWidget);
    });

    testWidgets('calls stay hidden while the server cannot relay them', (
      tester,
    ) async {
      final server = FakeVawraServer()..callsAvailable = false;
      await inChatWithMaya(tester, server, FakeCallMedia());
      expect(find.byKey(const Key('request-video-call')), findsNothing);
      expect(find.byKey(const Key('request-voice-call')), findsNothing);
      expect(find.byKey(const Key('call-ready-switch')), findsNothing);
    });

    testWidgets('photos in chat: allowed per match, blurred until tapped', (
      tester,
    ) async {
      final original = pickPhoto;
      addTearDown(() => pickPhoto = original);
      pickPhoto = () async =>
          PickedPhoto(Uint8List.fromList(FakeVawraServer.pixel), 'image/png');
      final server = FakeVawraServer();
      final matchId = await matchedWithMaya(tester, server);
      server.peerSays(matchId, '', photo: 'm9');
      await _settle(tester);
      await openChats(tester);
      await tester.tap(find.byKey(const Key('conversation-Maya')));
      await _settle(tester);

      // Allow photos from Maya.
      expect(server.photosAllowedByMe, isEmpty);
      await tester.tap(find.byKey(const Key('photo-consent-switch')));
      await _settle(tester);
      expect(server.photosAllowedByMe, {matchId});

      // Her photo arrives blurred; tapping shows it, then it can be reported.
      final photoId = server.messages[matchId]!.last['id'] as String;
      expect(find.text('Photo \u00b7 Tap to see'), findsOneWidget);
      expect(find.byKey(Key('photo-report-$photoId')), findsNothing);
      await tester.tap(find.byKey(Key('photo-message-$photoId')));
      await _settle(tester);
      expect(find.text('Photo \u00b7 Tap to see'), findsNothing);
      expect(find.byKey(Key('photo-report-$photoId')), findsOneWidget);

      // Sending: refused kindly until Maya allows photos from Alex.
      await tester.tap(find.byKey(const Key('send-photo')));
      await _settle(tester);
      expect(find.textContaining('hasn\'t turned on photos'), findsOneWidget);
      expect(server.chatPhotoUploads, isEmpty);
    });

    testWidgets('sending a photo once the other person allows them', (
      tester,
    ) async {
      final original = pickPhoto;
      addTearDown(() => pickPhoto = original);
      pickPhoto = () async =>
          PickedPhoto(Uint8List.fromList(FakeVawraServer.pixel), 'image/png');
      final server = FakeVawraServer();
      final matchId = await matchedWithMaya(tester, server);
      server.photosAllowedByThem.add(matchId);
      await openChats(tester);
      await tester.tap(find.byKey(const Key('new-match-Maya')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('send-photo')));
      await _settle(tester);
      expect(server.chatPhotoUploads, [matchId]);
      expect(find.textContaining('once approved'), findsOneWidget);
    });

    testWidgets('Seen and typing appear only when both share', (tester) async {
      final server = FakeVawraServer();
      final matchId = await matchedWithMaya(tester, server);
      await openChats(tester);
      await tester.tap(find.byKey(const Key('new-match-Maya')));
      await _settle(tester);

      Future<void> send(String text) async {
        await tester.enterText(find.byKey(const Key('message-composer')), text);
        await tester.pump();
        await tester.tap(find.byKey(const Key('send-message')));
        await _settle(tester);
      }

      // Not shared: typing is never sent, Seen never shown.
      await send('First');
      server.peerReads(matchId);
      server.peerTypes(matchId);
      await _settle(tester);
      expect(server.typingSent, 0);
      expect(find.textContaining('Seen'), findsNothing);
      expect(find.byKey(const Key('peer-typing')), findsNothing);

      server
        ..shareReceipts = true
        ..peerShares = true;
      // The app learns the setting when Settings are opened; here the fake
      // stands in for both people having switched it on.
      server.peerTypes(matchId);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Maya is typing…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      expect(find.byKey(const Key('peer-typing')), findsNothing);

      server.peerReads(matchId);
      await _settle(tester);
      expect(find.textContaining('· Seen'), findsOneWidget);
    });

    testWidgets('your typing is signalled only when you share, and throttled', (
      tester,
    ) async {
      final server = FakeVawraServer()..shareReceipts = true;
      await matchedWithMaya(tester, server);
      await openChats(tester);
      await tester.tap(find.byKey(const Key('new-match-Maya')));
      await _settle(tester);
      for (final text in ['H', 'He', 'Hey']) {
        await tester.enterText(find.byKey(const Key('message-composer')), text);
        await tester.pump();
      }
      expect(server.typingSent, 1);
    });

    testWidgets('an empty chat offers openers from what you share', (
      tester,
    ) async {
      final server = FakeVawraServer()
        ..verified = true
        ..addPerson(
          'Maya',
          likesMe: true,
          prompts: [
            {'question': 'Ask me about…', 'answer': 'my sourdough starter'},
          ],
        )
        ..profile = {
          'display_name': 'Alex',
          'relationship_intent': 'casual',
          'bio': '',
          'interests': <String>['Books'],
          'show_distance_band': true,
          'call_ready_by_default': false,
          'public_age': 28,
        };
      await _signIn(tester, server);
      await _settle(tester);
      await dismissSwipeTutorial(tester);
      await tester.tap(find.byKey(const Key('action-like')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('match-send-message')));
      await _settle(tester);
      expect(
        find.text('Okay, I am asking: tell me about my sourdough starter!'),
        findsOneWidget,
      );
      expect(find.textContaining('You like books too!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('opener-0')));
      await tester.pump();
      // It fills the box but sends nothing until the person does.
      expect(server.messages, isEmpty);
      await tester.tap(find.byKey(const Key('send-message')));
      await _settle(tester);
      expect(
        server.messages.values.single.single['text'],
        'Okay, I am asking: tell me about my sourdough starter!',
      );
      expect(find.byKey(const Key('openers')), findsNothing);
    });

    testWidgets('the settings switch saves to the account', (tester) async {
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
      await tester.tap(find.byKey(const Key('settings-read-receipts')));
      await _settle(tester);
      expect(server.shareReceipts, isTrue);
    });

    testWidgets('notification choices come from and save to the account', (
      tester,
    ) async {
      final server = FakeVawraServer()
        ..verified = true
        ..notificationPrefs['messages'] = false
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
      final calls = find.byKey(const Key('notify-Calls'));
      await tester.scrollUntilVisible(
        calls,
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('settings-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(calls);
      await _settle(tester);
      bool on(String label) => tester
          .widget<SwitchListTile>(find.byKey(Key('notify-$label')))
          .value;
      expect(on('Messages'), isFalse);
      expect(on('New matches'), isTrue);
      expect(find.byKey(const Key('notify-Safety tips')), findsNothing);
      await tester.tap(calls);
      await _settle(tester);
      expect(server.notificationPrefs['calls'], isFalse);
      expect(on('Calls'), isFalse);
    });
  });

  testWidgets('seeded test members show their portrait and a test label', (
    tester,
  ) async {
    final server = FakeVawraServer()
      ..verified = true
      ..addPerson('Maya', demoPortrait: 'assets/profiles/maya.webp')
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
    expect(find.byKey(const Key('demo-pill')), findsOneWidget);
    expect(find.text('TEST PROFILE · NOT A REAL PERSON'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/profiles/maya.webp',
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == noPhotoAsset,
      ),
      findsNothing,
    );
  });

  group('nudges', () {
    Future<String> openChatWithMaya(
      WidgetTester tester,
      FakeVawraServer server,
    ) async {
      server
        ..verified = true
        ..addPerson('Maya', likesMe: true)
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
      await tester.tap(find.byKey(const Key('action-like')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('match-send-message')));
      await _settle(tester);
      return server.matches.keys.single;
    }

    testWidgets('long chats open at the latest message and follow new ones', (
      tester,
    ) async {
      final server = FakeVawraServer();
      final matchId = await openChatWithMaya(tester, server);
      await tester.tap(find.byKey(const Key('thread-back')));
      await _settle(tester);
      for (var i = 0; i < 25; i++) {
        server.peerSays(matchId, 'Message number $i', nudge: false);
      }
      await tester.tap(find.byKey(const Key('chat-tab')));
      await _settle(tester);
      await closeSafetyGuideIfShown(tester);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('conversation-Maya')));
      await _settle(tester);
      bool visible(String text) =>
          find.text(text).hitTestable().evaluate().isNotEmpty;
      expect(visible('Message number 24'), isTrue);
      expect(visible('Message number 0'), isFalse);

      server.peerSays(matchId, 'Newest one');
      await _settle(tester);
      expect(visible('Newest one'), isTrue);
    });

    testWidgets('a reply shows at once from its nudge, not from a timer', (
      tester,
    ) async {
      final server = FakeVawraServer();
      final matchId = await openChatWithMaya(tester, server);
      expect(server.openStreams, 1);
      server.peerSays(matchId, 'Nudged in');
      // Far less than any safety refresh (3 s without, 30 s with a stream).
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Nudged in'), findsOneWidget);
    });

    testWidgets('while the stream is up, silent changes wait for the safety '
        'refresh', (tester) async {
      final server = FakeVawraServer();
      final matchId = await openChatWithMaya(tester, server);
      server.peerSays(matchId, 'No nudge for this one', nudge: false);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('No nudge for this one'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      await _settle(tester);
      expect(find.text('No nudge for this one'), findsOneWidget);
    });

    testWidgets('without a stream, the chat falls back to quick refreshes', (
      tester,
    ) async {
      final server = FakeVawraServer()..eventsEnabled = false;
      final matchId = await openChatWithMaya(tester, server);
      expect(server.openStreams, 0);
      server.peerSays(matchId, 'Found by the fallback', nudge: false);
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      expect(find.text('Found by the fallback'), findsOneWidget);
    });

    testWidgets('a dropped stream reconnects and catches up', (tester) async {
      final server = FakeVawraServer();
      final matchId = await openChatWithMaya(tester, server);
      await server.dropStreams();
      server.peerSays(matchId, 'Sent while disconnected', nudge: false);
      // Retry within the first back-off ceiling (2 s), then catch up.
      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);
      expect(server.eventsOpened, 2);
      expect(find.text('Sent while disconnected'), findsOneWidget);
    });

    testWidgets('the background closes the stream; returning reconnects', (
      tester,
    ) async {
      final server = FakeVawraServer();
      final matchId = await openChatWithMaya(tester, server);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(seconds: 2));
      expect(server.openStreams, 0);
      server.peerSays(matchId, 'While away', nudge: false);
      await tester.pump(const Duration(seconds: 40));
      expect(find.text('While away'), findsNothing);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await _settle(tester);
      expect(server.openStreams, 1);
      expect(find.text('While away'), findsOneWidget);
    });
  });

  testWidgets('profile details show their habits and prompts', (tester) async {
    final server = FakeVawraServer()
      ..verified = true
      ..addPerson(
        'Maya',
        lifestyle: {'drinking': 'Socially', 'pets': 'Dog person', 'x': 'y'},
        prompts: [
          {'question': 'Ask me about…', 'answer': 'my sourdough starter'},
        ],
      )
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
    await tester.tap(find.byKey(const Key('open-profile-details')));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-habits')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('profile-details-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Drinking: Socially'), findsOneWidget);
    expect(find.text('Pets: Dog person'), findsOneWidget);
    expect(find.textContaining(': y'), findsNothing);
    expect(find.text('Ask me about…'), findsOneWidget);
    expect(find.text('my sourdough starter'), findsOneWidget);
    // An empty bio has no empty "About" section.
    expect(find.text('About Maya'), findsNothing);
  });

  group('distance', () {
    final cell = snapToCell(49.89513, -97.13841);
    late _FakeArea area;
    late MemoryAreaPrefsStore places;
    setUp(() {
      areaLocator = area = _FakeArea(AreaFix.found(cell));
      areaPrefsStore = places = MemoryAreaPrefsStore();
    });
    tearDown(() {
      areaLocator = const GeolocatorAreaLocator();
      areaPrefsStore = const SecureAreaPrefsStore();
    });

    /// Nothing about a private place may ever reach the server.
    void expectPlacesNeverSent(
      FakeVawraServer server,
      AreaCell place, {
      int from = 0,
    }) {
      for (final request in server.requests.skip(from)) {
        expect(request.body, isNot(contains('${place.lat}')));
      }
    }

    Map<String, dynamic> profile() => {
      'display_name': 'Alex',
      'relationship_intent': 'casual',
      'bio': '',
      'interests': <String>['Books'],
      'show_distance_band': true,
      'call_ready_by_default': false,
      'public_age': 28,
    };

    Future<void> openArea(WidgetTester tester) async {
      await dismissSwipeTutorial(tester);
      await tester.tap(find.byKey(const Key('profile-tab')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('open-settings')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('settings-area')));
      await _settle(tester);
    }

    testWidgets('turning it on sends only the rounded cell, after asking', (
      tester,
    ) async {
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile();
      await _signIn(tester, server);
      await _settle(tester);
      expect(area.asks, isEmpty, reason: 'nothing happens until asked');
      await openArea(tester);
      expect(
        find.text('Your exact location never leaves your phone.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('area-on')));
      await _settle(tester);
      // The prompt, then a quiet re-check with the permission just given.
      expect(area.asks, [true, false]);
      expect(server.area, {'lat': cell.lat, 'lng': cell.lng});
      expect(find.text('Distance: on'), findsOneWidget);

      // Off again: removed on the server at once.
      await tester.tap(find.byKey(const Key('settings-area')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('area-off')));
      await _settle(tester);
      expect(server.area, isNull);
      expect(find.text('Distance: off'), findsOneWidget);
    });

    testWidgets('permission refused: nothing is sent and it says why', (
      tester,
    ) async {
      area.fix = const AreaFix.failed(AreaProblem.denied);
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile();
      await _signIn(tester, server);
      await _settle(tester);
      await openArea(tester);
      await tester.tap(find.byKey(const Key('area-on')));
      await _settle(tester);
      expect(server.area, isNull);
      expect(find.textContaining('didn\u2019t get permission'), findsOneWidget);
      expect(find.byKey(const Key('area-open-settings')), findsNothing);

      area.fix = const AreaFix.failed(AreaProblem.deniedForever);
      await tester.tap(find.byKey(const Key('area-on')));
      await _settle(tester);
      expect(find.byKey(const Key('area-open-settings')), findsOneWidget);
    });

    testWidgets('the server\u2019s 15-minute limit is explained', (
      tester,
    ) async {
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile()
        ..areaError = 'slow_down';
      await _signIn(tester, server);
      await _settle(tester);
      await openArea(tester);
      await tester.tap(find.byKey(const Key('area-on')));
      await _settle(tester);
      expect(find.textContaining('once every 15 minutes'), findsOneWidget);
    });

    testWidgets('cards show the server\u2019s band, or say it is hidden', (
      tester,
    ) async {
      final server = FakeVawraServer()
        ..verified = true
        ..addPerson('Maya', distanceBand: '5\u201310 km away')
        ..profile = profile();
      await _signIn(tester, server);
      await _settle(tester);
      await dismissSwipeTutorial(tester);
      expect(find.text('5\u201310 km away'), findsWidgets);
      expect(find.text('Distance hidden'), findsNothing);
    });

    testWidgets('on start the area is refreshed quietly, never with a prompt', (
      tester,
    ) async {
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile()
        ..areaAt = DateTime.utc(2026, 9, 27);
      await _signIn(tester, server);
      await _settle(tester);
      expect(area.asks, [false]);
      expect(server.area, {'lat': cell.lat, 'lng': cell.lng});
    });

    testWidgets('at a private place distance is hidden, and nothing is sent', (
      tester,
    ) async {
      places.prefs = AreaPrefs(wanted: true, zones: [cell]);
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile()
        ..areaAt = DateTime.utc(2026, 9, 27);
      await _signIn(tester, server);
      await _settle(tester);
      expect(area.asks, [false]);
      expect(server.area, isNull);
      expect(server.areaAt, isNull, reason: 'the old area was removed');
      expectPlacesNeverSent(server, cell);

      await dismissSwipeTutorial(tester);
      await tester.tap(find.byKey(const Key('profile-tab')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('open-settings')));
      await _settle(tester);
      expect(find.text('Distance: on'), findsOneWidget);
      expect(
        find.textContaining('you\u2019re at a private place'),
        findsOneWidget,
      );
    });

    testWidgets('away from private places distance works as usual', (
      tester,
    ) async {
      final far = snapToCell(43.6532, -79.3832);
      places.prefs = AreaPrefs(wanted: true, zones: [far]);
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile();
      await _signIn(tester, server);
      await _settle(tester);
      expect(server.area, {'lat': cell.lat, 'lng': cell.lng});
      expectPlacesNeverSent(server, far);
    });

    testWidgets('add this place as private, then remove it', (tester) async {
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile()
        ..areaAt = DateTime.utc(2026, 9, 27);
      await _signIn(tester, server);
      await _settle(tester);
      expect(server.area, isNotNull);
      await openArea(tester);
      final before = server.requests.length;
      await tester.ensureVisible(find.byKey(const Key('area-zone-add')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('area-zone-add')));
      await _settle(tester);
      expect(places.prefs.zones, [cell]);
      expect(server.area, isNull, reason: 'hidden at once');
      expect(find.byKey(const Key('area-note')), findsOneWidget);
      // Before it was private the area was sent as usual; never since.
      expectPlacesNeverSent(server, cell, from: before);

      await tester.tap(find.byKey(const Key('area-zone-remove-0')));
      await _settle(tester);
      expect(places.prefs.zones, isEmpty);
    });

    testWidgets('no quiet refresh when distance is off', (tester) async {
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile();
      await _signIn(tester, server);
      await _settle(tester);
      expect(area.asks, isEmpty);
      expect(server.area, isNull);
    });
  });

  test('the export limit says it is daily, not "a few minutes"', () {
    expect(
      describeExportError(ApiException(429, 'rate_limited')),
      'You can download your data 5 times a day. Try again tomorrow.',
    );
    expect(
      describeExportError(ApiException(403, 'account_paused')),
      isNot(contains('5 times a day')),
    );
  });

  group('download my data', () {
    Map<String, dynamic> profile() => {
      'display_name': 'Alex',
      'relationship_intent': 'casual',
      'bio': '',
      'interests': <String>['Books'],
      'show_distance_band': true,
      'call_ready_by_default': false,
      'public_age': 28,
      'gender': 'man',
      'show_me': <String>['woman'],
      'show_gender': false,
    };

    Future<void> openExport(WidgetTester tester) async {
      await dismissSwipeTutorial(tester);
      await tester.tap(find.byKey(const Key('profile-tab')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('open-settings')));
      await _settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-export')),
        200,
      );
      await tester.ensureVisible(find.byKey(const Key('settings-export')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('settings-export')));
      await _settle(tester);
    }

    testWidgets('shows what the server holds and copies the full file', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile();
      await _signIn(tester, server);
      await _settle(tester);
      await openExport(tester);

      expect(server.exports, 1);
      expect(find.text('Your data'), findsOneWidget);
      expect(find.text('alex@example.test'), findsOneWidget);
      expect(find.text('Women'), findsOneWidget, reason: 'Show me');
      await tester.scrollUntilVisible(find.text('Maya'), 200);
      expect(find.text('Maya'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('export-copy')),
        -200,
      );
      await tester.tap(find.byKey(const Key('export-copy')));
      await _settle(tester);
      expect(copied, contains('"format": "vawra-export-1"'));
      expect(copied, contains('Hi Maya'));
      expect(
        find.textContaining('Paste it somewhere only you'),
        findsOneWidget,
      );
    });

    testWidgets(
      'an old sign-in confirms first, then Back returns to Settings',
      (tester) async {
        final server = FakeVawraServer()
          ..verified = true
          ..profile = profile();
        await _signIn(tester, server);
        await _settle(tester);
        server.recentSignIn = false;
        await openExport(tester);
        expect(server.exports, 0);
        expect(find.textContaining('To download your data'), findsOneWidget);
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
        expect(server.exports, 1);
        expect(find.text('Your data'), findsOneWidget);

        await tester.pageBack();
        await _settle(tester);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.textContaining('To download your data'), findsNothing);
      },
    );

    testWidgets('can be taken while deletion is pending', (tester) async {
      final server = FakeVawraServer()
        ..verified = true
        ..profile = profile()
        ..deletionAt = DateTime.utc(2026, 10, 4, 12);
      await _signIn(tester, server);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('deletion-export')));
      await _settle(tester);
      expect(server.exports, 1);
      expect(find.text('Deletion scheduled'), findsOneWidget);
    });
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
      await tester.ensureVisible(find.byKey(const Key('settings-delete')));
      await _settle(tester);
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
