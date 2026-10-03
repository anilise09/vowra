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
      // Raw bytes: photo uploads are binary, not text.
      final bytes = await bodyStream.toBytes();
      if (request.url.path == '/v1/events') return _events(request);
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers);
      if (bytes.isNotEmpty) copy.bodyBytes = bytes;
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
  void nudge(String kind, {String? matchId, String? callId}) {
    final data = jsonEncode({
      'kind': kind,
      'match_id': ?matchId,
      'call_id': ?callId,
    });
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
  int _codes = 1;

  bool verified = false;

  /// The next message send fails, as when the phone loses its connection.
  bool refuseNextMessage = false;

  /// Where an unconfirmed account's age check stands.
  String unverifiedAgeState = 'assurance_required';

  /// The provider link handed out; null means no age-check service.
  String? ageCheckUrl = 'https://checks.example.test/start?ref=r1';
  int ageChecksStarted = 0;

  /// What the account is told about while the app is closed.
  final notificationPrefs = <String, bool>{
    'matches': true,
    'messages': true,
    'likes': true,
    'calls': true,
  };
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

  /// How many times the data export was served.
  int exports = 0;

  /// The approximate area as sent (a cell centre), and when.
  Map<String, dynamic>? area;
  DateTime? areaAt;

  /// An error code the next area update fails with, like the real server.
  String? areaError;

  /// Set to suspend the signed-in person: {since, reason}.
  Map<String, dynamic>? suspension;
  final appeals = <String>[];
  String? appealState;
  bool moderator = false;

  /// The moderator's authenticator: `none`, `enabled` (needs a code) or
  /// `verified` (open). Verified by default, so older tests are unchanged.
  String modSecondFactor = 'verified';
  static const modSecret = 'JBSWY3DPEHPK3PXP';

  /// The code the fake accepts; anything else is wrong.
  static const modCode = '135790';
  final modCodesTried = <String>[];

  /// The moderation queue and decisions made on it.
  final modReports = <Map<String, dynamic>>[];
  final modAppeals = <Map<String, dynamic>>[];
  final decisions = <String>[];

  /// Your own photos as the server lists them, and every upload received.
  final myPhotos = <Map<String, dynamic>>[];

  /// Photo consent per match: yours, and theirs.
  final photosAllowedByMe = <String>{};
  final photosAllowedByThem = <String>{};
  final chatPhotoUploads = <String>[];

  /// Calls: whether the server can relay them, who is open to one, and each
  /// call's state. [sentSignals] is what the app sent; [peerSignalsFor] what
  /// the other phone sent.
  bool callsAvailable = true;
  final callReadyByMe = <String>{};
  final callReadyByThem = <String>{};
  final calls = <String, Map<String, dynamic>>{};
  final sentSignals = <String, List<Map<String, String>>>{};
  final peerSignalsFor = <String, List<Map<String, dynamic>>>{};
  int _signalSeq = 0;

  Map<String, dynamic> _callView(String id) => {
    ...calls[id]!,
    'call_id': id,
    'ice': {
      'policy': 'relay',
      'servers': [
        {
          'urls': ['turn:turn.example.test:3478'],
          'username': 'u',
          'credential': 'c',
        },
      ],
    },
  };

  /// The other person rings this phone.
  String peerRings(String matchId, {bool video = true}) {
    final id = 'call${calls.length + 1}';
    calls[id] = {
      'match_id': matchId,
      'kind': video ? 'video' : 'audio',
      'state': 'ringing',
      'role': 'callee',
    };
    nudge('call', matchId: matchId, callId: id);
    return id;
  }

  /// A setup message from the other phone.
  void peerSignal(String callId, String type, String data) {
    peerSignalsFor.putIfAbsent(callId, () => []).add({
      'seq': ++_signalSeq,
      'type': type,
      'data': data,
    });
    nudge('call', callId: callId);
  }

  void peerCallState(String callId, String state) {
    calls[callId]!['state'] = state;
    nudge('call', callId: callId);
  }

  final uploads = <List<int>>[];
  final modPhotos = <Map<String, dynamic>>[];

  /// A 1x1 PNG served for any photo link.
  static const pixel = [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    6,
    0,
    0,
    0,
    31,
    21,
    196,
    137,
    0,
    0,
    0,
    13,
    73,
    68,
    65,
    84,
    120,
    156,
    99,
    248,
    207,
    192,
    240,
    31,
    0,
    5,
    0,
    1,
    255,
    137,
    153,
    61,
    29,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130,
  ];

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
    String? demoPortrait,
    String? distanceBand,
    List<String> photos = const [],
  }) {
    final id = _id();
    people[id] = {
      'photos': [
        for (final p in photos) {'photo_id': p, 'url': '/v1/media/$p?p=view'},
      ],
      'distance_band': distanceBand,
      'demo_portrait': demoPortrait,
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

  void peerSays(
    String matchId,
    String text, {
    bool nudge = true,
    List<String> hints = const [],
    String? photo,
  }) {
    messages.putIfAbsent(matchId, () => []).add({
      'id': _id(),
      'mine': false,
      'text': text,
      if (hints.isNotEmpty) 'safety_hints': hints,
      if (photo != null) 'photo': {'url': '/v1/media/$photo?p=view'},
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
    // Like the real server (Fastify): a JSON content type needs a JSON body.
    if ((request.headers['content-type'] ?? '').contains('json') &&
        request.body.isEmpty) {
      return _error(400, 'invalid_request');
    }
    final path = request.url.path;
    final isJson = (request.headers['content-type'] ?? '').contains('json');
    final body = request.bodyBytes.isEmpty || !isJson
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    final method = request.method;

    if (method == 'POST' && path == '/v1/auth/requests') {
      _challenge = body['code_challenge'] as String;
      _state = body['state'] as String;
      // Six digits, like the real server; never 000000, which tests use as a wrong code.
      outbox.add('${100000 + outbox.length + _codes++}');
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
        'age_state': verified ? 'adult_verified' : unverifiedAgeState,
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
    // Photo links and upload grants carry their own authority.
    if (path.startsWith('/v1/media/')) {
      return http.Response.bytes(
        pixel,
        200,
        headers: {'content-type': 'image/png'},
      );
    }
    if (path.startsWith('/v1/uploads/') && method == 'PUT') {
      uploads.add(request.bodyBytes);
      final id = path.split('/').last;
      if (id.startsWith('c')) return _json(200, {'state': 'pending_review'});
      myPhotos.add({
        'photo_id': id,
        'state': 'pending_review',
        'reject_reason': null,
        'url': '/v1/media/$id?p=view',
      });
      return _json(200, {'state': 'pending_review'});
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
        'age_state': verified ? 'adult_verified' : unverifiedAgeState,
        'lifecycle': deletionAt != null
            ? 'deletion_scheduled'
            : suspension != null
            ? 'suspended'
            : paused
            ? 'paused'
            : 'active',
        'deletion_effective_at': deletionAt?.toIso8601String(),
        'profile': profile,
        'location_updated_at': areaAt?.toIso8601String(),
        'suspension': suspension == null
            ? null
            : {
                ...suspension!,
                'appeal': appealState == null
                    ? null
                    : {
                        'state': appealState,
                        'created_at': '2026-09-29T12:00:00.000Z',
                      },
              },
        'moderator': moderator,
      });
    }
    if (path == '/v1/me/photos') {
      if (method == 'GET') {
        return _json(200, {'photos': myPhotos, 'max_photos': 6});
      }
      final id = 'p${myPhotos.length + uploads.length + 1}';
      return _json(200, {
        'photo_id': id,
        'upload_url': '/v1/uploads/$id?grant=g',
        'expires_at': '2026-09-29T12:10:00.000Z',
      });
    }
    if (path == '/v1/me/photos/order') {
      final ids = (body['photo_ids'] as List).cast<String>();
      myPhotos.sort(
        (a, b) =>
            ids.indexOf(a['photo_id'] as String) -
            ids.indexOf(b['photo_id'] as String),
      );
      return http.Response('', 204);
    }
    if (path.startsWith('/v1/me/photos/') && method == 'DELETE') {
      myPhotos.removeWhere((p) => p['photo_id'] == path.split('/').last);
      return http.Response('', 204);
    }
    if (path == '/v1/me/appeal') {
      if (appealState == 'open') return _error(409, 'appeal_open');
      appeals.add(body['message'] as String);
      appealState = 'open';
      return _json(202, {
        'state': 'open',
        'created_at': '2026-09-29T12:00:00.000Z',
      });
    }
    if (path.startsWith('/v1/mod/')) {
      if (!moderator) return _error(404, 'not_found');
      if (path == '/v1/mod/second-factor/setup') {
        return _json(200, {
          'secret': modSecret,
          'otpauth_uri': 'otpauth://totp/Vawra?secret=$modSecret',
        });
      }
      if (path == '/v1/mod/second-factor/confirm' ||
          path == '/v1/mod/second-factor/verify') {
        modCodesTried.add(body['code'] as String);
        if (body['code'] != modCode) return _error(400, 'invalid_code');
        modSecondFactor = 'verified';
        return _json(200, {'verified_until': '2026-09-30T12:30:00.000Z'});
      }
      if (modSecondFactor == 'none') {
        return _error(403, 'second_factor_setup_required');
      }
      if (modSecondFactor == 'enabled') {
        return _error(403, 'second_factor_required');
      }
      if (path == '/v1/mod/reports') return _json(200, {'reports': modReports});
      if (path == '/v1/mod/appeals') return _json(200, {'appeals': modAppeals});
      if (path == '/v1/mod/photos') return _json(200, {'photos': modPhotos});
      final decision = RegExp(
        r'^/v1/mod/(reports|appeals|photos)/([^/]+)/decision$',
      ).firstMatch(path);
      if (decision != null) {
        if (!recentSignIn) return _error(403, 'reauthentication_required');
        final id = decision.group(2)!;
        decisions.add('${decision.group(1)}:$id:${body['outcome']}');
        modReports.removeWhere((r) => r['report_id'] == id);
        modAppeals.removeWhere((a) => a['appeal_id'] == id);
        modPhotos.removeWhere((p) => p['photo_id'] == id);
        return _json(200, {'state': body['outcome']});
      }
    }
    if (path == '/v1/me/location') {
      if (method == 'DELETE') {
        area = null;
        areaAt = null;
        return http.Response('', 204);
      }
      if (areaError case final code?) {
        areaError = null;
        return _error(code == 'slow_down' ? 429 : 422, code);
      }
      area = Map<String, dynamic>.from(body);
      areaAt = DateTime.utc(2026, 9, 28, 12);
      return _json(200, {
        'updated_at': areaAt!.toIso8601String(),
        'cell_km': 2,
      });
    }
    if (path == '/v1/me/export') {
      if (!recentSignIn) return _error(403, 'reauthentication_required');
      exports++;
      return _json(200, {
        'format': 'vawra-export-1',
        'generated_at': '2026-09-28T12:00:00.000Z',
        'account': {
          'email': 'alex@example.test',
          'created_at': '2026-09-20T12:00:00.000Z',
          'age_state': verified ? 'adult_verified' : unverifiedAgeState,
          'lifecycle': deletionAt != null ? 'deletion_scheduled' : 'active',
          'deletion_effective_at': deletionAt?.toIso8601String(),
          'share_read_receipts': shareReceipts,
        },
        'profile': profile,
        'swipes': [
          {'kind': 'like', 'at': '2026-09-21T12:00:00.000Z'},
          {'kind': 'pass', 'at': '2026-09-21T12:01:00.000Z'},
        ],
        'matches': [
          {
            'with': 'Maya',
            'status': 'active',
            'matched_at': '2026-09-21T12:02:00.000Z',
            'messages_you_sent': [
              {'at': '2026-09-21T12:03:00.000Z', 'text': 'Hi Maya'},
            ],
          },
        ],
        'blocks': <Object>[],
        'reports_you_made': <Object>[],
        'sign_ins': [
          {'signed_in_at': '2026-09-28T11:00:00.000Z', 'ended_at': null},
        ],
        'security_events': <Object>[],
        'not_included': [
          'Messages other people sent you, their profiles and their account IDs',
        ],
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
    if (path == '/v1/me/age-check' && method == 'POST') {
      if (verified) return _error(409, 'already_verified');
      if (unverifiedAgeState == 'rejected') {
        return _error(409, 'age_check_failed');
      }
      final url = ageCheckUrl;
      if (url == null) return _error(503, 'age_check_unavailable');
      ageChecksStarted++;
      return _json(200, {'url': url});
    }
    if (path == '/v1/me/notifications') {
      if (method == 'PUT') notificationPrefs.addAll(body.cast<String, bool>());
      return _json(200, notificationPrefs);
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
              p,
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
        'calls_available': callsAvailable,
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
                'shared_interests': [
                  for (final i in people[m.value]!['interests'] as List)
                    if ((profile?['interests'] as List?)?.contains(i) ?? false)
                      i,
                ],
                'peer_prompts': people[m.value]!['prompts'],
                'peer_demo_portrait': people[m.value]!['demo_portrait'],
                'photos_allowed_by_me': photosAllowedByMe.contains(m.key),
                'photos_allowed_by_them': photosAllowedByThem.contains(m.key),
                'call_ready_by_me': callReadyByMe.contains(m.key),
                'call_ready_by_them': callReadyByThem.contains(m.key),
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
    final callReady = RegExp(r'^/v1/matches/([^/]+)/call-ready$')
        .firstMatch(path);
    if (callReady != null) {
      final id = callReady.group(1)!;
      body['ready'] == true ? callReadyByMe.add(id) : callReadyByMe.remove(id);
      return http.Response('', 204);
    }
    final startCall = RegExp(r'^/v1/matches/([^/]+)/calls$').firstMatch(path);
    if (startCall != null) {
      final matchId = startCall.group(1)!;
      if (!callsAvailable) return _error(503, 'calls_unavailable');
      if (!callReadyByMe.contains(matchId) ||
          !callReadyByThem.contains(matchId)) {
        return _error(409, 'not_ready');
      }
      final id = 'call${calls.length + 1}';
      calls[id] = {
        'match_id': matchId,
        'kind': body['kind'],
        'state': 'ringing',
        'role': 'caller',
      };
      return _json(200, _callView(id));
    }
    final callRoute = RegExp(
      r'^/v1/calls/([^/]+)(?:/(answer|decline|end|signals))?$',
    ).firstMatch(path);
    if (callRoute != null) {
      final id = callRoute.group(1)!;
      final call = calls[id];
      if (call == null) return _error(404, 'not_found');
      final live = call['state'] == 'ringing' || call['state'] == 'active';
      switch ((method, callRoute.group(2))) {
        case ('GET', null):
          return _json(200, _callView(id));
        case ('POST', 'answer'):
          if (call['state'] != 'ringing') return _error(409, 'not_ringing');
          call['state'] = 'active';
          return _json(200, _callView(id));
        case ('POST', 'decline'):
          call['state'] = 'declined';
          return http.Response('', 204);
        case ('POST', 'end'):
          if (live) {
            call['state'] = call['state'] == 'ringing' ? 'cancelled' : 'ended';
          }
          return http.Response('', 204);
        case ('POST', 'signals'):
          if (!live) return _error(409, 'call_over');
          sentSignals.putIfAbsent(id, () => []).add({
            'type': body['type'] as String,
            'data': body['data'] as String,
          });
          return _json(202, {'ok': true});
        case ('GET', 'signals'):
          final after = int.parse(request.url.queryParameters['after'] ?? '0');
          return _json(200, {
            'state': call['state'],
            'signals': [
              if (live)
                for (final s in peerSignalsFor[id] ?? const [])
                  if ((s['seq'] as int) > after) s,
            ],
          });
      }
    }
    final consent = RegExp(r'^/v1/matches/([^/]+)/photo-consent$')
        .firstMatch(path);
    if (consent != null) {
      final id = consent.group(1)!;
      body['allow'] == true
          ? photosAllowedByMe.add(id)
          : photosAllowedByMe.remove(id);
      return http.Response('', 204);
    }
    final chatPhoto = RegExp(r'^/v1/matches/([^/]+)/photos$').firstMatch(path);
    if (chatPhoto != null) {
      final id = chatPhoto.group(1)!;
      if (!photosAllowedByThem.contains(id)) {
        return _error(409, 'photos_not_allowed');
      }
      chatPhotoUploads.add(id);
      return _json(200, {
        'photo_id': 'c${chatPhotoUploads.length}',
        'upload_url': '/v1/uploads/c${chatPhotoUploads.length}?grant=g',
        'expires_at': '2026-09-29T12:10:00.000Z',
      });
    }
    final thread = RegExp(r'^/v1/matches/([^/]+)/messages$').firstMatch(path);
    if (thread != null) {
      final matchId = thread.group(1)!;
      if (!matches.containsKey(matchId) || blocked.contains(matches[matchId])) {
        return _error(409, 'conversation_closed');
      }
      if (method == 'POST') {
        if (refuseNextMessage) {
          refuseNextMessage = false;
          return _error(503, 'unavailable');
        }
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
