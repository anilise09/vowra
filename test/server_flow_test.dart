import 'package:ember_app/data/api/vawra_api.dart';
import 'package:ember_app/features/shared/profile_image.dart';
import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
