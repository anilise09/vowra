import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../domain/safety_report.dart';
import '../../domain/user_profile.dart';

/// Server address, set at build time: --dart-define=VAWRA_API=http://10.0.2.2:8787
/// Empty means the app runs as the offline prototype.
const vawraApiBase = String.fromEnvironment('VAWRA_API');

class ApiException implements Exception {
  ApiException(this.status, this.code);
  final int status;
  final String code;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// A person from the server. Photos arrive later with the reviewed media service.
class ServerPerson {
  const ServerPerson({
    required this.accountId,
    required this.name,
    required this.age,
    required this.intent,
    required this.bio,
    required this.interests,
    this.superLike = false,
  });

  final String accountId;
  final String name;
  final int? age;
  final RelationshipIntent? intent;
  final String bio;
  final List<String> interests;
  final bool superLike;

  factory ServerPerson.fromJson(Map<String, dynamic> json) => ServerPerson(
    accountId: json['account_id'] as String,
    name: json['display_name'] as String,
    age: json['public_age'] as int?,
    intent: _intent(json['relationship_intent'] as String?),
    bio: (json['bio'] as String?) ?? '',
    interests: ((json['interests'] as List?) ?? const []).cast<String>(),
    superLike: (json['super_like'] as bool?) ?? false,
  );
}

class ServerMatch {
  const ServerMatch({
    required this.matchId,
    required this.peerAccountId,
    required this.peerName,
    required this.peerAge,
    required this.lastMessage,
  });

  final String matchId;
  final String peerAccountId;
  final String peerName;
  final int? peerAge;
  final String? lastMessage;

  factory ServerMatch.fromJson(Map<String, dynamic> json) => ServerMatch(
    matchId: json['match_id'] as String,
    peerAccountId: json['peer_account_id'] as String,
    peerName: json['peer_name'] as String,
    peerAge: json['peer_age'] as int?,
    lastMessage: json['last_message'] as String?,
  );
}

class ServerMessage {
  const ServerMessage({
    required this.id,
    required this.mine,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final bool mine;
  final String text;
  final DateTime sentAt;

  factory ServerMessage.fromJson(Map<String, dynamic> json) => ServerMessage(
    id: json['id'] as String,
    mine: json['mine'] as bool,
    text: json['text'] as String,
    sentAt: DateTime.parse(json['sent_at'] as String),
  );
}

class MeState {
  const MeState({
    required this.ageState,
    required this.paused,
    required this.profile,
  });

  final String ageState;
  final bool paused;
  final UserProfile? profile;

  bool get canDate => ageState == 'adult_verified';
}

extension ReportReasonKey on ReportReason {
  /// The server's name for each reason (backend/src/rules.ts reportReasons).
  String get backendKey => switch (this) {
    ReportReason.harassment => 'harassment',
    ReportReason.impersonation => 'impersonation',
    ReportReason.scam => 'scam',
    ReportReason.sexualContent => 'sexual_content',
    ReportReason.underageConcern => 'underage_concern',
    ReportReason.other => 'other',
  };
}

RelationshipIntent? _intent(String? key) {
  for (final intent in RelationshipIntent.values) {
    if (intent.backendKey == key) return intent;
  }
  return null;
}

/// Talks to the Vawra backend. Session tokens live only in memory for now; a
/// later step moves them to platform-protected storage (see SESSION_CONTRACT).
class VawraApi {
  VawraApi(this.base, {http.Client? client, Random? random})
    : _client = client ?? http.Client(),
      _random = random ?? Random.secure();

  final Uri base;
  final http.Client _client;
  final Random _random;

  String? _access;
  String? _refresh;
  DateTime? _accessExpires;
  String? _verifier;
  String? _state;
  String? accountId;

  bool get signedIn => _access != null;

  String _randomToken() =>
      base64UrlEncode(List<int>.generate(32, (_) => _random.nextInt(256)))
          .replaceAll('=', '');

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    if (auth) await _ensureFresh();
    final request = http.Request(method, base.resolve(path));
    request.headers['content-type'] = 'application/json';
    if (auth && _access != null) {
      request.headers['authorization'] = 'Bearer $_access';
    }
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        decoded['error'] as String? ?? 'error',
      );
    }
    return decoded;
  }

  void _keep(Map<String, dynamic> session) {
    _access = session['access_token'] as String;
    _refresh = session['refresh_token'] as String;
    _accessExpires = DateTime.parse(session['access_expires_at'] as String);
    accountId = (session['account_id'] as String?) ?? accountId;
  }

  /// Rotates a minute before expiry. A revoked family signs the person out.
  Future<void> _ensureFresh() async {
    final expires = _accessExpires;
    final refresh = _refresh;
    if (expires == null || refresh == null) return;
    if (DateTime.now().isBefore(expires.subtract(const Duration(minutes: 1)))) {
      return;
    }
    try {
      _keep(
        await _send(
          'POST',
          '/v1/session/rotate',
          body: {'refresh_token': refresh},
          auth: false,
        ),
      );
    } on ApiException {
      signOutLocally();
      rethrow;
    }
  }

  /// Step 1: ask for a one-time code. The answer is the same for every email.
  Future<void> requestSignIn(String email) async {
    _verifier = _randomToken();
    _state = _randomToken();
    final challenge = base64UrlEncode(
      sha256.convert(utf8.encode(_verifier!)).bytes,
    ).replaceAll('=', '');
    await _send(
      'POST',
      '/v1/auth/requests',
      auth: false,
      body: {
        'identifier': email.trim().toLowerCase(),
        'purpose': 'sign_in',
        'code_challenge': challenge,
        'state': _state,
      },
    );
  }

  /// Step 2: trade the code for a session, bound to this device's PKCE secret.
  Future<void> exchange(String proof) async {
    final verifier = _verifier;
    final state = _state;
    if (verifier == null || state == null) {
      throw ApiException(400, 'no_pending_sign_in');
    }
    _keep(
      await _send(
        'POST',
        '/v1/auth/exchange',
        auth: false,
        body: {
          'proof': proof.trim(),
          'code_verifier': verifier,
          'state': state,
        },
      ),
    );
    _verifier = null;
    _state = null;
  }

  void signOutLocally() {
    _access = null;
    _refresh = null;
    _accessExpires = null;
    accountId = null;
  }

  Future<void> signOut() async {
    try {
      await _send('DELETE', '/v1/session');
    } finally {
      signOutLocally();
    }
  }

  Future<MeState> me() async {
    final json = await _send('GET', '/v1/me/profile');
    final profile = json['profile'] as Map<String, dynamic>?;
    return MeState(
      ageState: json['age_state'] as String,
      paused: json['lifecycle'] == 'paused',
      profile: profile == null
          ? null
          : UserProfile(
              displayName: profile['display_name'] as String,
              age: (profile['public_age'] as int?) ?? 18,
              intent:
                  _intent(profile['relationship_intent'] as String?) ??
                  RelationshipIntent.figuringItOut,
              bio: profile['bio'] as String,
              interests: (profile['interests'] as List).cast<String>(),
              showDistanceBand: profile['show_distance_band'] as bool,
              callReadyByDefault: profile['call_ready_by_default'] as bool,
            ),
    );
  }

  /// Sends only the six fields the contract allows. Age is never sent.
  Future<void> saveProfile(UserProfile profile) => _send(
    'PATCH',
    '/v1/me/profile',
    body: {
      'display_name': profile.displayName,
      'relationship_intent': profile.intent.backendKey,
      'bio': profile.bio,
      'interests': profile.interests,
      'show_distance_band': profile.showDistanceBand,
      'call_ready_by_default': profile.callReadyByDefault,
    },
  );

  Future<void> setPaused(bool paused) =>
      _send(paused ? 'POST' : 'DELETE', '/v1/me/pause');

  Future<List<ServerPerson>> discovery() async =>
      ((await _send('GET', '/v1/discovery?limit=50'))['people'] as List)
          .map((p) => ServerPerson.fromJson(p as Map<String, dynamic>))
          .toList();

  Future<List<ServerPerson>> likesYou() async =>
      ((await _send('GET', '/v1/likes-you'))['people'] as List)
          .map((p) => ServerPerson.fromJson(p as Map<String, dynamic>))
          .toList();

  /// Returns the match id when this swipe completed a mutual like.
  Future<String?> swipe(String accountId, String kind) async {
    final json = await _send(
      'POST',
      '/v1/discovery/$accountId/swipe',
      body: {'kind': kind},
    );
    return json['matched'] == true ? json['match_id'] as String : null;
  }

  Future<List<ServerMatch>> matches() async =>
      ((await _send('GET', '/v1/matches'))['matches'] as List)
          .map((m) => ServerMatch.fromJson(m as Map<String, dynamic>))
          .toList();

  Future<List<ServerMessage>> messages(String matchId) async =>
      ((await _send('GET', '/v1/matches/$matchId/messages'))['messages']
              as List)
          .map((m) => ServerMessage.fromJson(m as Map<String, dynamic>))
          .toList();

  Future<ServerMessage> send(String matchId, String text) async =>
      ServerMessage.fromJson(
        await _send(
          'POST',
          '/v1/matches/$matchId/messages',
          body: {'text': text},
        ),
      );

  Future<void> unmatch(String matchId) =>
      _send('DELETE', '/v1/matches/$matchId');

  Future<void> block(String accountId) =>
      _send('POST', '/v1/blocks', body: {'account_id': accountId});

  Future<void> report(String accountId, String reason, {String? messageId}) =>
      _send(
        'POST',
        '/v1/reports',
        body: {
          'account_id': accountId,
          'reason': reason,
          'message_id': ?messageId,
        },
      );
}
