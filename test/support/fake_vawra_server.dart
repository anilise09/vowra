import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A small in-memory stand-in for backend/ that speaks the same JSON, for
/// widget tests. The real routes are tested in backend/test.
class FakeVawraServer {
  FakeVawraServer() {
    client = MockClient.streaming((request, bodyStream) async {
      final body = await bodyStream.bytesToString();
      if (request.url.path == '/v1/events') return _events(request);
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers);
      if (body.isNotEmpty) copy.body = body;
      final response = await _handle(copy);
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    });
  }

  /// Whether `GET /v1/events` accepts connections.
  bool eventsEnabled = true;
  final _streams = <StreamController<List<int>>>[];
  int eventsOpened = 0;
  int get openStreams => _streams.length;

  Future<http.StreamedResponse> _events(http.BaseRequest request) async {
    final authorized =
        !_revoked &&
        request.headers['authorization'] == 'Bearer access-token-000000000000';
    if (!eventsEnabled || !authorized) {
      final r = _error(authorized ? 503 : 401, authorized ? 'down' : 'no');
      return http.StreamedResponse(Stream.value(r.bodyBytes), r.statusCode);
    }
    eventsOpened++;
    late final StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onCancel: () => _streams.remove(controller),
    );
    _streams.add(controller);
    controller.add(utf8.encode(': connected\n\n'));
    return http.StreamedResponse(controller.stream, 200);
  }

  /// Pushes a nudge to every open stream, like the real server.
  void nudge(String kind, {String? matchId}) {
    final data = jsonEncode({'kind': kind, 'match_id': ?matchId});
    for (final stream in [..._streams]) {
      stream.add(utf8.encode('event: nudge\ndata: $data\n\n'));
    }
  }

  /// Ends every open stream, as a server restart would.
  Future<void> dropStreams() async {
    for (final stream in [..._streams]) {
      await stream.close();
    }
    _streams.clear();
  }

  late final http.Client client;
  final requests = <http.Request>[];

  /// One-time codes "emailed" so far, newest last.
  final outbox = <String>[];

  bool verified = false;
  int rotations = 0;

  /// Read receipts and typing: this person, and every peer.
  bool shareReceipts = false;
  bool peerShares = false;

  /// How many messages of each match this person / the peer has read.
  final myRead = <String, int>{};
  final peerRead = <String, int>{};
  int typingSent = 0;

  /// The peer reads everything so far (and is told nothing unless both share).
  void peerReads(String matchId) {
    peerRead[matchId] = messages[matchId]?.length ?? 0;
    if (shareReceipts && peerShares) nudge('read', matchId: matchId);
  }

  void peerTypes(String matchId) {
    if (shareReceipts && peerShares) nudge('typing', matchId: matchId);
  }

  /// Whether the current session came from a sign-in inside the server's
  /// reauthentication window. Tests set it false to age the sign-in.
  bool recentSignIn = true;

  /// The server's deletion date while a deletion is scheduled.
  DateTime? deletionAt;
  bool _revoked = false;
  bool paused = false;
  Map<String, dynamic>? profile;
  final people = <String, Map<String, dynamic>>{};
  final likedMe = <String>{};
  final mySwipes = <String, String>{};
  final matches = <String, String>{}; // match id -> peer id
  final messages = <String, List<Map<String, dynamic>>>{};
  final blocked = <String>{};
  final reports = <Map<String, dynamic>>[];

  String? _challenge;
  String? _state;
  var _clock = DateTime.utc(2026, 9, 27, 12);
  var _ids = 100; // above [me]

  static const me = '00000000-0000-4000-8000-000000000001';

  String _id() =>
      '00000000-0000-4000-8000-${(++_ids).toString().padLeft(12, '0')}';

  void addPerson(
    String name, {
    int age = 30,
    bool likesMe = false,
    Map<String, String> lifestyle = const {},
    List<Map<String, String>> prompts = const [],
    List<Map<String, String>> reasons = const [],
  }) {
    final id = _id();
    people[id] = {
      'reasons': reasons,
      'lifestyle': lifestyle,
      'prompts': prompts,
      'account_id': id,
      'display_name': name,
      'public_age': age,
      'relationship_intent': 'long_term',
      'bio': '$name likes long walks and good coffee.',
      'interests': ['Books'],
    };
    if (likesMe) likedMe.add(id);
  }

  String idOf(String name) =>
      people.values.firstWhere((p) => p['display_name'] == name)['account_id']
          as String;

  void peerSays(String matchId, String text, {bool nudge = true}) {
    messages.putIfAbsent(matchId, () => []).add({
      'id': _id(),
      'mine': false,
      'text': text,
      'sent_at': (_clock = _clock.add(
        const Duration(minutes: 1),
      )).toIso8601String(),
    });
    if (nudge) this.nudge('message', matchId: matchId);
  }

  http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response _error(int status, String code) =>
      _json(status, {'error': code});

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    final method = request.method;

    if (method == 'POST' && path == '/v1/auth/requests') {
      _challenge = body['code_challenge'] as String;
      _state = body['state'] as String;
      outbox.add('proof-${_id()}');
      return _json(202, {
        'message': 'If the account can continue, instructions will be sent.',
      });
    }
    if (method == 'POST' && path == '/v1/auth/exchange') {
      final verifier = body['code_verifier'] as String;
      final challenge = base64UrlEncode(
        sha256.convert(utf8.encode(verifier)).bytes,
      ).replaceAll('=', '');
      if (body['proof'] != outbox.lastOrNull ||
          challenge != _challenge ||
          body['state'] != _state) {
        return _error(400, 'invalid_proof');
      }
      outbox.clear();
      _revoked = false;
      recentSignIn = true;
      return _json(200, {
        'session_id': 's1',
        'access_token': 'access-token-000000000000',
        'access_expires_at': DateTime.now()
            .add(const Duration(minutes: 15))
            .toUtc()
            .toIso8601String(),
        'refresh_token': 'refresh-token-00000000000',
        'account_id': me,
        'age_state': verified ? 'adult_verified' : 'assurance_required',
      });
    }
    if (method == 'POST' && path == '/v1/session/rotate') {
      if (_revoked || body['refresh_token'] != 'refresh-token-00000000000') {
        return _error(401, 'session_revoked');
      }
      rotations++;
      return _json(200, {
        'session_id': 's2',
        'access_token': 'access-token-000000000000',
        'access_expires_at': DateTime.now()
            .add(const Duration(minutes: 15))
            .toUtc()
            .toIso8601String(),
        'refresh_token': 'refresh-token-00000000000',
      });
    }
    if (_revoked ||
        request.headers['authorization'] !=
            'Bearer access-token-000000000000') {
      return _error(401, 'unauthenticated');
    }
    if (path == '/v1/session' && method == 'DELETE') {
      return http.Response('', 204);
    }
    if (path == '/v1/me/profile') {
      if (method == 'PATCH') {
        profile = {...?profile, ...body, 'public_age': null};
      }
      return _json(200, {
        'age_state': verified ? 'adult_verified' : 'assurance_required',
        'lifecycle': deletionAt != null
            ? 'deletion_scheduled'
            : paused
            ? 'paused'
            : 'active',
        'deletion_effective_at': deletionAt?.toIso8601String(),
        'profile': profile,
      });
    }
    if (path == '/v1/me/deletion') {
      if (!recentSignIn) return _error(403, 'reauthentication_required');
      if (method == 'POST') {
        deletionAt ??= DateTime.utc(2026, 10, 4, 12);
        _revoked = true;
        return _json(202, {
          'state': 'scheduled',
          'effective_at': deletionAt!.toIso8601String(),
        });
      }
      if (deletionAt == null) return _error(409, 'no_deletion_scheduled');
      deletionAt = null;
      return http.Response('', 204);
    }
    if (deletionAt != null) return _error(409, 'deletion_scheduled');
    if (path == '/v1/me/settings') {
      if (method == 'PATCH') {
        shareReceipts = body['share_read_receipts'] as bool;
      }
      return _json(200, {'share_read_receipts': shareReceipts});
    }
    if (path == '/v1/me/pause') {
      paused = method == 'POST';
      return http.Response('', 204);
    }
    if (!verified) return _error(403, 'age_assurance_required');
    final chatRoute = path.startsWith('/v1/matches');
    if (paused && !chatRoute) return _error(409, 'account_paused');

    if (path == '/v1/discovery') {
      return _json(200, {
        'people': [
          for (final p in people.values)
            if (!mySwipes.containsKey(p['account_id']) &&
                !blocked.contains(p['account_id']))
              {...p, 'distance_band': null},
        ],
      });
    }
    if (path == '/v1/likes-you') {
      return _json(200, {
        'people': [
          for (final id in likedMe)
            if (!mySwipes.containsKey(id) && !blocked.contains(id))
              {...people[id]!, 'super_like': false},
        ],
      });
    }
    final swipe = RegExp(r'^/v1/discovery/([^/]+)/swipe$').firstMatch(path);
    if (swipe != null) {
      final peer = swipe.group(1)!;
      mySwipes.putIfAbsent(peer, () => body['kind'] as String);
      if (mySwipes[peer] != 'pass' && likedMe.contains(peer)) {
        final existing = matches.entries
            .where((m) => m.value == peer)
            .firstOrNull
            ?.key;
        final matchId = existing ?? _id();
        matches[matchId] = peer;
        return _json(200, {'matched': true, 'match_id': matchId});
      }
      return _json(200, {'matched': false});
    }
    if (path == '/v1/matches' && method == 'GET') {
      return _json(200, {
        'matches': [
          for (final m in matches.entries)
            if (!blocked.contains(m.value))
              {
                'match_id': m.key,
                'peer_account_id': m.value,
                'peer_name': people[m.value]!['display_name'],
                'peer_age': people[m.value]!['public_age'],
                'last_message': messages[m.key]?.lastOrNull?['text'],
                'last_message_mine': messages[m.key]?.lastOrNull?['mine'],
                'unread': [...?messages[m.key]?.skip(myRead[m.key] ?? 0)]
                    .where((x) => x['mine'] == false)
                    .length,
              },
        ],
      });
    }
    final action = RegExp(r'^/v1/matches/([^/]+)/(read|typing)$')
        .firstMatch(path);
    if (action != null) {
      final matchId = action.group(1)!;
      if (action.group(2) == 'read') {
        myRead[matchId] = messages[matchId]?.length ?? 0;
      } else {
        typingSent++;
      }
      return http.Response('', 204);
    }
    final thread = RegExp(r'^/v1/matches/([^/]+)/messages$').firstMatch(path);
    if (thread != null) {
      final matchId = thread.group(1)!;
      if (!matches.containsKey(matchId) || blocked.contains(matches[matchId])) {
        return _error(409, 'conversation_closed');
      }
      if (method == 'POST') {
        final message = {
          'id': _id(),
          'mine': true,
          'text': (body['text'] as String).trim(),
          'sent_at': (_clock = _clock.add(
            const Duration(minutes: 1),
          )).toIso8601String(),
        };
        messages.putIfAbsent(matchId, () => []).add(message);
        return _json(201, message);
      }
      final list = messages[matchId] ?? [];
      final both = shareReceipts && peerShares;
      return _json(200, {
        'messages': [
          for (final (i, m) in list.indexed)
            {
              ...m,
              if (both && m['mine'] == true)
                'seen': i < (peerRead[matchId] ?? 0),
            },
        ],
      });
    }
    if (path == '/v1/blocks' && method == 'POST') {
      blocked.add(body['account_id'] as String);
      return http.Response('', 204);
    }
    if (path == '/v1/reports' && method == 'POST') {
      reports.add(body);
      return _json(202, {'state': 'pending_review'});
    }
    return _error(404, 'not_found');
  }
}
