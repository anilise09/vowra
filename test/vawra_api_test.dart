import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:ember_app/data/api/vawra_api.dart';
import 'package:ember_app/domain/lifestyle.dart';
import 'package:ember_app/domain/profile_prompt.dart';
import 'package:ember_app/domain/safety_report.dart';
import 'package:ember_app/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_vawra_server.dart';

void main() {
  group('sign-in', () {
    test('binds the code to this device with PKCE S256 and state', () async {
      final server = FakeVawraServer();
      final api = VawraApi(
        Uri.parse('http://vawra.test'),
        client: server.client,
      );
      await api.requestSignIn('  Alex@Example.TEST ');
      final sent = jsonDecode(server.requests.single.body) as Map;
      expect(sent['identifier'], 'alex@example.test');
      expect(sent['purpose'], 'sign_in');
      expect((sent['code_challenge'] as String).length, 43);
      expect((sent['state'] as String).length, greaterThanOrEqualTo(16));

      await api.exchange(server.outbox.last);
      final exchange = jsonDecode(server.requests.last.body) as Map;
      final challenge = base64UrlEncode(
        sha256.convert(utf8.encode(exchange['code_verifier'] as String)).bytes,
      ).replaceAll('=', '');
      expect(challenge, sent['code_challenge']);
      expect(exchange['state'], sent['state']);
      expect(api.signedIn, isTrue);
      expect(api.accountId, FakeVawraServer.me);
    });

    test('a wrong code fails and leaves the person signed out', () async {
      final server = FakeVawraServer();
      final api = VawraApi(
        Uri.parse('http://vawra.test'),
        client: server.client,
      );
      await api.requestSignIn('alex@example.test');
      await expectLater(
        api.exchange('proof-not-the-right-one-at-all'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_proof'),
        ),
      );
      expect(api.signedIn, isFalse);
    });

    test(
      'an exchange without a pending request never reaches the server',
      () async {
        final server = FakeVawraServer();
        final api = VawraApi(
          Uri.parse('http://vawra.test'),
          client: server.client,
        );
        await expectLater(
          api.exchange('proof-anything-long-enough'),
          throwsA(isA<ApiException>()),
        );
        expect(server.requests, isEmpty);
      },
    );
  });

  test('rotates the session shortly before it expires', () async {
    var rotations = 0;
    final seen = <String?>[];
    final client = MockClient((request) async {
      seen.add(request.headers['authorization']);
      if (request.url.path == '/v1/auth/requests') {
        return http.Response('{}', 202);
      }
      if (request.url.path == '/v1/session/rotate') {
        rotations++;
        expect(jsonDecode(request.body), {
          'refresh_token': 'refresh-1-xxxxxxxxxxxxxxxx',
        });
        return http.Response(
          jsonEncode({
            'access_token': 'access-2',
            'refresh_token': 'refresh-2-xxxxxxxxxxxxxxxx',
            'access_expires_at': DateTime.now()
                .add(const Duration(minutes: 15))
                .toUtc()
                .toIso8601String(),
          }),
          200,
        );
      }
      if (request.url.path == '/v1/auth/exchange') {
        return http.Response(
          jsonEncode({
            'access_token': 'access-1',
            'refresh_token': 'refresh-1-xxxxxxxxxxxxxxxx',
            // Already inside the one-minute margin.
            'access_expires_at': DateTime.now()
                .add(const Duration(seconds: 30))
                .toUtc()
                .toIso8601String(),
            'account_id': 'a1',
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'matches': []}), 200);
    });
    final api = VawraApi(Uri.parse('http://vawra.test'), client: client);
    await api.requestSignIn('alex@example.test');
    await api.exchange('proof-xxxxxxxxxxxxxxxxxxxx');
    await api.matches();
    expect(rotations, 1);
    expect(seen.last, 'Bearer access-2');
  });

  test('parallel calls near expiry share one rotation', () async {
    var rotations = 0;
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/v1/auth/requests':
          return http.Response('{}', 202);
        case '/v1/auth/exchange':
          return http.Response(
            jsonEncode({
              'access_token': 'access-1',
              'refresh_token': 'refresh-1-xxxxxxxxxxxxxxxx',
              'access_expires_at': DateTime.now().toUtc().toIso8601String(),
              'account_id': 'a1',
            }),
            200,
          );
        case '/v1/session/rotate':
          rotations++;
          // Slow enough that the other calls arrive while it is in flight.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            jsonEncode({
              'access_token': 'access-2',
              'refresh_token': 'refresh-2-xxxxxxxxxxxxxxxx',
              'access_expires_at': DateTime.now()
                  .add(const Duration(minutes: 15))
                  .toUtc()
                  .toIso8601String(),
            }),
            200,
          );
      }
      expect(request.headers['authorization'], 'Bearer access-2');
      return http.Response(jsonEncode({'matches': [], 'people': []}), 200);
    });
    final api = VawraApi(Uri.parse('http://vawra.test'), client: client);
    await api.requestSignIn('alex@example.test');
    await api.exchange('proof-xxxxxxxxxxxxxxxxxxxx');
    await Future.wait([api.matches(), api.discovery(), api.likesYou()]);
    expect(rotations, 1);
  });

  group('saved session', () {
    test('sign-in saves only the refresh token; sign-out clears it', () async {
      final server = FakeVawraServer();
      final store = MemorySessionStore();
      final api = VawraApi(
        Uri.parse('http://vawra.test'),
        client: server.client,
        store: store,
      );
      await api.requestSignIn('alex@example.test');
      await api.exchange(server.outbox.last);
      expect(store.saved?.refreshToken, 'refresh-token-00000000000');
      expect(store.saved?.accountId, FakeVawraServer.me);
      await api.signOut();
      expect(store.saved, isNull);
    });

    test('a restart resumes by rotating the saved token', () async {
      final server = FakeVawraServer();
      final store = MemorySessionStore()
        ..saved = (
          refreshToken: 'refresh-token-00000000000',
          accountId: FakeVawraServer.me,
        );
      final api = VawraApi(
        Uri.parse('http://vawra.test'),
        client: server.client,
        store: store,
      );
      expect(await api.resume(), isTrue);
      expect(server.rotations, 1);
      expect(api.accountId, FakeVawraServer.me);
      await api.me();
      expect(server.rotations, 1);
    });

    test('a session the server ended is forgotten', () async {
      final store = MemorySessionStore()
        ..saved = (refreshToken: 'refresh-revoked-xxxxxxxxx', accountId: 'a1');
      final api = VawraApi(
        Uri.parse('http://vawra.test'),
        client: FakeVawraServer().client,
        store: store,
      );
      expect(await api.resume(), isFalse);
      expect(store.saved, isNull);
    });

    test('no network keeps the saved session for a retry', () async {
      final store = MemorySessionStore()
        ..saved = (refreshToken: 'refresh-token-00000000000', accountId: 'a1');
      final api = VawraApi(
        Uri.parse('http://vawra.test'),
        client: MockClient((_) async => throw http.ClientException('offline')),
        store: store,
      );
      await expectLater(api.resume(), throwsA(isA<http.ClientException>()));
      expect(store.saved, isNotNull);
    });
  });

  test('a refused rotation signs the person out', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/session/rotate') {
        return http.Response(jsonEncode({'error': 'session_revoked'}), 401);
      }
      if (request.url.path == '/v1/auth/exchange') {
        return http.Response(
          jsonEncode({
            'access_token': 'access-1',
            'refresh_token': 'refresh-1-xxxxxxxxxxxxxxxx',
            'access_expires_at': DateTime.now().toUtc().toIso8601String(),
            'account_id': 'a1',
          }),
          200,
        );
      }
      return http.Response('{}', 202);
    });
    final api = VawraApi(Uri.parse('http://vawra.test'), client: client);
    await api.requestSignIn('alex@example.test');
    await api.exchange('proof-xxxxxxxxxxxxxxxxxxxx');
    await expectLater(api.matches(), throwsA(isA<ApiException>()));
    expect(api.signedIn, isFalse);
  });

  test('profile saves send only the contract fields, never age', () async {
    final server = FakeVawraServer();
    final api = VawraApi(Uri.parse('http://vawra.test'), client: server.client);
    await api.requestSignIn('alex@example.test');
    await api.exchange(server.outbox.last);
    await api.saveProfile(
      const UserProfile(
        displayName: 'Alex',
        age: 28,
        intent: RelationshipIntent.openToLongTerm,
        bio: '',
        interests: ['Books'],
      ),
    );
    final sent = jsonDecode(server.requests.last.body) as Map;
    expect(sent.keys.toSet(), {
      'display_name',
      'relationship_intent',
      'bio',
      'interests',
      'show_distance_band',
      'call_ready_by_default',
      'lifestyle',
      'prompts',
    });
    expect(sent['relationship_intent'], 'open_to_long_term');
    expect(
      server.requests.last.headers['authorization'],
      startsWith('Bearer '),
    );
  });

  test('habits and prompts round-trip through the account', () async {
    final server = FakeVawraServer();
    final api = VawraApi(Uri.parse('http://vawra.test'), client: server.client);
    await api.requestSignIn('alex@example.test');
    await api.exchange(server.outbox.last);
    await api.saveProfile(
      const UserProfile(
        displayName: 'Alex',
        age: 28,
        intent: RelationshipIntent.casual,
        bio: '',
        interests: ['Books'],
        lifestyle: {LifestyleTopic.exercise: 'Daily'},
        prompts: [ProfilePrompt('Ask me about…', 'trains')],
      ),
    );
    final sent = jsonDecode(server.requests.last.body) as Map;
    expect(sent['lifestyle'], {'exercise': 'Daily'});
    expect(sent['prompts'], [
      {'question': 'Ask me about…', 'answer': 'trains'},
    ]);
    final me = await api.me();
    expect(me.profile?.lifestyle, {LifestyleTopic.exercise: 'Daily'});
    expect(me.profile?.prompts.single.answer, 'trains');
  });

  test('report reasons use the server names', () {
    expect(ReportReason.values.map((r) => r.backendKey), [
      'harassment',
      'impersonation',
      'scam',
      'sexual_content',
      'underage_concern',
      'other',
    ]);
  });
}
