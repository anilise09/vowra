import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'server_photo.dart';

import '../../domain/account_profile_contract.dart';
import '../../domain/gender.dart';
import '../../domain/lifestyle.dart';
import '../../domain/location_grid.dart';
import '../../domain/match_reason.dart';
import '../../domain/profile_prompt.dart';
import '../../domain/safety_report.dart';
import '../../domain/user_profile.dart';

/// Server address, set at build time: --dart-define=VAWRA_API=http://10.0.2.2:8797
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
    this.lifestyle = const {},
    this.prompts = const [],
    this.reasons = const [],
    this.demoPortrait,
    this.gender,
    this.distanceBand,
    this.photos = const [],
  });

  final String accountId;
  final String name;
  final int? age;
  final RelationshipIntent? intent;
  final String bio;
  final List<String> interests;
  final bool superLike;
  final Map<LifestyleTopic, String> lifestyle;
  final List<ProfilePrompt> prompts;
  final List<MatchReason> reasons;

  /// Local test server only: a bundled synthetic portrait.
  final String? demoPortrait;

  /// Only present when this person chose to show it.
  final Gender? gender;

  /// A coarse band such as "5–10 km away", when both of you share an area.
  final String? distanceBand;

  /// Approved photos as short-lived links (relative to the server).
  final List<String> photos;

  factory ServerPerson.fromJson(Map<String, dynamic> json) => ServerPerson(
    accountId: json['account_id'] as String,
    name: json['display_name'] as String,
    age: json['public_age'] as int?,
    intent: _intent(json['relationship_intent'] as String?),
    bio: (json['bio'] as String?) ?? '',
    interests: ((json['interests'] as List?) ?? const []).cast<String>(),
    superLike: (json['super_like'] as bool?) ?? false,
    lifestyle: parseLifestyle(json['lifestyle']),
    prompts: parsePrompts(json['prompts']),
    reasons: MatchReason.parse(json['reasons']),
    demoPortrait: json['demo_portrait'] as String?,
    gender: Gender.fromKey(json['gender']),
    distanceBand: json['distance_band'] as String?,
    photos: [
      for (final p in (json['photos'] as List?) ?? const [])
        (p as Map<String, dynamic>)['url'] as String,
    ],
  );
}

class ServerMatch {
  const ServerMatch({
    required this.matchId,
    required this.peerAccountId,
    required this.peerName,
    required this.peerAge,
    required this.lastMessage,
    this.lastMessageMine,
    this.unread = 0,
    this.sharedInterests = const [],
    this.peerPrompts = const [],
    this.peerDemoPortrait,
    this.photosAllowedByMe = false,
    this.photosAllowedByThem = false,
    this.callReadyByMe = false,
    this.callReadyByThem = false,
    this.callsAvailable = false,
  });

  /// A call needs both people's yes, per match, and a server that can relay
  /// calls ([callsAvailable]).
  final bool callReadyByMe;
  final bool callReadyByThem;
  final bool callsAvailable;

  /// Photos in this chat need the receiver's yes, per match.
  final bool photosAllowedByMe;
  final bool photosAllowedByThem;

  final String matchId;
  final String peerAccountId;
  final String peerName;
  final int? peerAge;
  final String? lastMessage;

  /// Who wrote the last message; null when there is none.
  final bool? lastMessageMine;
  final int unread;

  /// What you share, for opening lines in an empty chat.
  final List<String> sharedInterests;
  final List<ProfilePrompt> peerPrompts;
  final String? peerDemoPortrait;

  /// The other person wrote last: it is your turn to reply.
  bool get yourTurn => lastMessage != null && lastMessageMine == false;

  factory ServerMatch.fromJson(
    Map<String, dynamic> json, {
    bool callsAvailable = false,
  }) => ServerMatch(
    matchId: json['match_id'] as String,
    peerAccountId: json['peer_account_id'] as String,
    peerName: json['peer_name'] as String,
    peerAge: json['peer_age'] as int?,
    lastMessage: json['last_message'] as String?,
    lastMessageMine: json['last_message_mine'] as bool?,
    unread: (json['unread'] as int?) ?? 0,
    sharedInterests: ((json['shared_interests'] as List?) ?? const [])
        .whereType<String>()
        .toList(),
    peerPrompts: parsePrompts(json['peer_prompts']),
    peerDemoPortrait: json['peer_demo_portrait'] as String?,
    photosAllowedByMe: (json['photos_allowed_by_me'] as bool?) ?? false,
    photosAllowedByThem: (json['photos_allowed_by_them'] as bool?) ?? false,
    callReadyByMe: (json['call_ready_by_me'] as bool?) ?? false,
    callReadyByThem: (json['call_ready_by_them'] as bool?) ?? false,
    callsAvailable: callsAvailable,
  );
}

/// How the phones in a call may reach each other: [relayOnly] sends all
/// media through the relay so neither person learns the other's address.
class IceSetup {
  const IceSetup({required this.relayOnly, required this.servers});

  final bool relayOnly;
  final List<Map<String, dynamic>> servers;

  static IceSetup? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return IceSetup(
      relayOnly: json['policy'] == 'relay',
      servers: ((json['servers'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

/// One call, as the server sees it.
class ServerCall {
  const ServerCall({
    required this.callId,
    required this.matchId,
    required this.video,
    required this.state,
    required this.isCaller,
    this.ice,
  });

  final String callId;
  final String matchId;
  final bool video;

  /// ringing, active, ended, declined, missed or cancelled.
  final String state;
  final bool isCaller;
  final IceSetup? ice;

  bool get live => state == 'ringing' || state == 'active';

  factory ServerCall.fromJson(Map<String, dynamic> json) => ServerCall(
    callId: json['call_id'] as String,
    matchId: json['match_id'] as String,
    video: json['kind'] == 'video',
    state: json['state'] as String,
    isCaller: json['role'] == 'caller',
    ice: IceSetup.fromJson(json['ice']),
  );
}

/// A setup message from the other phone (offer, answer or candidate).
class CallSignal {
  const CallSignal(this.seq, this.type, this.data);
  final int seq;
  final String type;
  final String data;
}

class ServerMessage {
  const ServerMessage({
    required this.id,
    required this.mine,
    required this.text,
    required this.sentAt,
    this.seen,
    this.safetyHints = const [],
    this.photoUrl,
  });

  final String id;
  final bool mine;
  final String? photoUrl;
  final String text;
  final DateTime sentAt;
  final bool? seen;
  final List<String> safetyHints;

  factory ServerMessage.fromJson(Map<String, dynamic> json) => ServerMessage(
    id: json['id'] as String,
    mine: json['mine'] as bool,
    text: json['text'] as String,
    sentAt: DateTime.parse(json['sent_at'] as String),
    seen: json['seen'] as bool?,
    safetyHints: ((json['safety_hints'] as List?) ?? const []).cast<String>(),
    photoUrl: (json['photo'] as Map<String, dynamic>?)?['url'] as String?,
  );
}

class MeState {
  const MeState({
    required this.ageState,
    required this.lifecycle,
    required this.profile,
    this.deletionEffectiveAt,
    this.areaUpdatedAt,
    this.suspension,
    this.moderator = false,
  });

  final String ageState;

  /// active, paused, deletion_scheduled or suspended.
  final String lifecycle;

  /// Only while suspended: why, since when, and the latest appeal.
  final Suspension? suspension;

  /// Whether this account reviews reports.
  final bool moderator;
  final UserProfile? profile;

  /// Set while a deletion is scheduled: the server's date, never assumed.
  final DateTime? deletionEffectiveAt;

  /// When the approximate area was last set; null when it is off.
  final DateTime? areaUpdatedAt;

  bool get paused => lifecycle == 'paused';
  bool get deletionScheduled => lifecycle == 'deletion_scheduled';
  bool get suspended => lifecycle == 'suspended';

  bool get canDate => ageState == 'adult_verified';
}

class Suspension {
  const Suspension({
    required this.since,
    this.reason,
    this.appealState,
    this.appealAt,
  });

  factory Suspension.fromJson(Map<String, dynamic> json) {
    final appeal = json['appeal'] as Map<String, dynamic>?;
    return Suspension(
      since: DateTime.parse(json['since'] as String).toLocal(),
      reason: reportReasonFromKey(json['reason'] as String?),
      appealState: appeal?['state'] as String?,
      appealAt: appeal == null
          ? null
          : DateTime.parse(appeal['created_at'] as String).toLocal(),
    );
  }

  final DateTime since;
  final ReportReason? reason;

  /// open, upheld or overturned; null before any appeal.
  final String? appealState;
  final DateTime? appealAt;
}

ReportReason? reportReasonFromKey(String? key) {
  for (final reason in ReportReason.values) {
    if (reason.backendKey == key) return reason;
  }
  return null;
}

/// A report waiting for a moderator. The reporter is never identified.
class ModReport {
  const ModReport({
    required this.reportId,
    required this.reason,
    required this.reportedAt,
    required this.accountId,
    required this.name,
    required this.bio,
    required this.status,
    required this.reportsAgainst,
    required this.reporterReportCount,
    this.messageText,
  });

  factory ModReport.fromJson(Map<String, dynamic> json) => ModReport(
    reportId: json['report_id'] as String,
    reason: reportReasonFromKey(json['reason'] as String?),
    reportedAt: DateTime.parse(json['reported_at'] as String).toLocal(),
    accountId: json['account_id'] as String,
    name: (json['display_name'] as String?) ?? 'No profile',
    bio: (json['bio'] as String?) ?? '',
    status: json['status'] as String,
    reportsAgainst: json['reports_against'] as int,
    reporterReportCount: json['reporter_report_count'] as int,
    messageText: (json['message'] as Map<String, dynamic>?)?['text'] as String?,
  );

  final String reportId;
  final ReportReason? reason;
  final DateTime reportedAt;
  final String accountId;
  final String name;
  final String bio;
  final String status;
  final int reportsAgainst;
  final int reporterReportCount;

  /// The one reported message, when the report pointed at one.
  final String? messageText;
}

class ModAppeal {
  const ModAppeal({
    required this.appealId,
    required this.message,
    required this.createdAt,
    required this.name,
    required this.suspendedByYou,
    this.suspendedAt,
    this.reason,
  });

  factory ModAppeal.fromJson(Map<String, dynamic> json) => ModAppeal(
    appealId: json['appeal_id'] as String,
    message: json['message'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    name: (json['display_name'] as String?) ?? 'No profile',
    suspendedByYou: json['suspended_by_you'] as bool,
    suspendedAt: switch (json['suspended_at']) {
      final String at => DateTime.parse(at).toLocal(),
      _ => null,
    },
    reason: reportReasonFromKey(json['suspension_reason'] as String?),
  );

  final String appealId;
  final String message;
  final DateTime createdAt;
  final String name;

  /// A different moderator must decide it.
  final bool suspendedByYou;
  final DateTime? suspendedAt;
  final ReportReason? reason;
}

/// One of your own photos and where it is in review.
class MyPhoto {
  const MyPhoto({
    required this.id,
    required this.state,
    this.rejectReason,
    this.url,
  });

  factory MyPhoto.fromJson(Map<String, dynamic> json) => MyPhoto(
    id: json['photo_id'] as String,
    state: json['state'] as String,
    rejectReason: json['reject_reason'] as String?,
    url: json['url'] as String?,
  );

  final String id;

  /// pending_review, approved or rejected.
  final String state;
  final String? rejectReason;
  final String? url;
}

/// A photo waiting for a moderator.
class ModPhoto {
  const ModPhoto({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.url,
  });

  factory ModPhoto.fromJson(Map<String, dynamic> json) => ModPhoto(
    id: json['photo_id'] as String,
    name: (json['display_name'] as String?) ?? 'No profile',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    url: json['url'] as String,
  );

  final String id;
  final String name;
  final DateTime createdAt;
  final String url;
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

/// Server habits; unknown topics or answers are ignored, never shown raw.
Map<LifestyleTopic, String> parseLifestyle(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final topic in LifestyleTopic.values)
      if (topic.options.contains(raw[topic.name]))
        topic: raw[topic.name] as String,
  };
}

List<ProfilePrompt> parsePrompts(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map &&
          ProfilePrompt.questions.contains(item['question']) &&
          item['answer'] is String)
        ProfilePrompt(item['question'] as String, item['answer'] as String),
  ];
}

RelationshipIntent? _intent(String? key) {
  for (final intent in RelationshipIntent.values) {
    if (intent.backendKey == key) return intent;
  }
  return null;
}

/// Where the refresh token survives an app restart. The short-lived access
/// token is never stored; it is rotated fresh on start.
abstract interface class SessionStore {
  Future<({String refreshToken, String? accountId})?> read();
  Future<void> write(String refreshToken, String? accountId);
  Future<void> clear();
}

/// Android Keystore / iOS Keychain backed, as SESSION_CONTRACT requires.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _refreshKey = 'vawra.refresh';
  static const _accountKey = 'vawra.account';

  @override
  Future<({String refreshToken, String? accountId})?> read() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null) return null;
    return (
      refreshToken: refresh,
      accountId: await _storage.read(key: _accountKey),
    );
  }

  @override
  Future<void> write(String refreshToken, String? accountId) async {
    await _storage.write(key: _refreshKey, value: refreshToken);
    if (accountId != null) {
      await _storage.write(key: _accountKey, value: accountId);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _accountKey);
  }
}

/// Keeps nothing past the process; used by tests.
class MemorySessionStore implements SessionStore {
  ({String refreshToken, String? accountId})? saved;

  @override
  Future<({String refreshToken, String? accountId})?> read() async => saved;

  @override
  Future<void> write(String refreshToken, String? accountId) async =>
      saved = (refreshToken: refreshToken, accountId: accountId);

  @override
  Future<void> clear() async => saved = null;
}

/// Talks to the Vawra backend.
class VawraApi {
  VawraApi(
    this.base, {
    http.Client? client,
    Random? random,
    SessionStore? store,
  }) : _client = client ?? http.Client(),
       _random = random ?? Random.secure(),
       _store = store ?? MemorySessionStore() {
    serverPhotoClient = _client;
  }

  final Uri base;
  final http.Client _client;
  final Random _random;
  final SessionStore _store;

  /// One rotation at a time: a refresh token works once, so parallel calls
  /// rotating it separately would look like reuse and revoke the session.
  Future<void>? _rotation;

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
    if (auth && _access != null) {
      request.headers['authorization'] = 'Bearer $_access';
    }
    // A JSON content type only with a JSON body: servers reject the header
    // on an empty body (this broke read, typing, pause and deletion).
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
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

  Future<void> _keep(Map<String, dynamic> session) async {
    _access = session['access_token'] as String;
    _refresh = session['refresh_token'] as String;
    _accessExpires = DateTime.parse(session['access_expires_at'] as String);
    accountId = (session['account_id'] as String?) ?? accountId;
    await _store.write(_refresh!, accountId);
  }

  /// Opens the nudge stream (`GET /v1/events`) and returns its text as it
  /// arrives. Throws [ApiException] when the server refuses it.
  Future<Stream<String>> openEvents() async {
    await _ensureFresh();
    final request = http.Request('GET', base.resolve('/v1/events'));
    request.headers['accept'] = 'text/event-stream';
    if (_access != null) request.headers['authorization'] = 'Bearer $_access';
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      String code = 'error';
      try {
        code = (jsonDecode(body) as Map<String, dynamic>)['error'] as String;
      } catch (_) {}
      throw ApiException(response.statusCode, code);
    }
    return response.stream.transform(utf8.decoder);
  }

  /// Picks up a saved session after an app restart. False when there is none
  /// or the server has ended it; network failures are thrown so the caller can
  /// offer a retry without losing the saved session.
  Future<bool> resume() async {
    final saved = await _store.read();
    if (saved == null) return false;
    _refresh = saved.refreshToken;
    accountId = saved.accountId;
    _accessExpires = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await _ensureFresh();
    } on ApiException {
      return false;
    }
    return signedIn;
  }

  /// Rotates a minute before expiry. A revoked family signs the person out.
  Future<void> _ensureFresh() {
    final expires = _accessExpires;
    if (expires == null || _refresh == null) return Future.value();
    if (DateTime.now().isBefore(expires.subtract(const Duration(minutes: 1)))) {
      return Future.value();
    }
    return _rotation ??= _rotate().whenComplete(() => _rotation = null);
  }

  Future<void> _rotate() async {
    try {
      await _keep(
        await _send(
          'POST',
          '/v1/session/rotate',
          body: {'refresh_token': _refresh},
          auth: false,
        ),
      );
    } on ApiException {
      await signOutLocally();
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
    await _keep(
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

  Future<void> signOutLocally() async {
    _access = null;
    _refresh = null;
    _accessExpires = null;
    accountId = null;
    await _store.clear();
  }

  Future<void> signOut() async {
    try {
      await _send('DELETE', '/v1/session');
    } finally {
      await signOutLocally();
    }
  }

  Future<MeState> me() async {
    final json = await _send('GET', '/v1/me/profile');
    final profile = json['profile'] as Map<String, dynamic>?;
    final deletion = json['deletion_effective_at'] as String?;
    final area = json['location_updated_at'] as String?;
    final suspension = json['suspension'] as Map<String, dynamic>?;
    return MeState(
      ageState: json['age_state'] as String,
      lifecycle: json['lifecycle'] as String,
      deletionEffectiveAt: deletion == null
          ? null
          : DateTime.parse(deletion).toLocal(),
      areaUpdatedAt: area == null ? null : DateTime.parse(area).toLocal(),
      suspension: suspension == null ? null : Suspension.fromJson(suspension),
      moderator: (json['moderator'] as bool?) ?? false,
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
              lifestyle: parseLifestyle(profile['lifestyle']),
              prompts: parsePrompts(profile['prompts']),
              gender: Gender.fromKey(profile['gender']),
              showMe: {
                for (final key in (profile['show_me'] as List?) ?? const [])
                  ?Gender.fromKey(key),
              },
              showGender: (profile['show_gender'] as bool?) ?? false,
            ),
    );
  }

  /// Whether you accept photos from the other person in this match.
  Future<void> setPhotoConsent(String matchId, bool allow) => _send(
    'PUT',
    '/v1/matches/$matchId/photo-consent',
    body: {'allow': allow},
  );

  /// Sends a photo in a conversation: it is checked by a moderator and
  /// arrives as a message once approved.
  Future<void> sendChatPhoto(
    String matchId,
    List<int> bytes,
    String mimeType,
  ) async {
    final grant = await _send(
      'POST',
      '/v1/matches/$matchId/photos',
      body: {
        'client_upload_id': _randomToken(),
        'mime_type': mimeType,
        'byte_length': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
      },
    );
    final response = await _client.put(
      base.resolve(grant['upload_url'] as String),
      headers: {'content-type': mimeType},
      body: bytes,
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'upload_failed');
    }
  }

  /// Whether you are open to a call in this conversation.
  Future<void> setCallReady(String matchId, bool ready) =>
      _send('PUT', '/v1/matches/$matchId/call-ready', body: {'ready': ready});

  Future<ServerCall> startCall(String matchId, {required bool video}) async =>
      ServerCall.fromJson(
        await _send(
          'POST',
          '/v1/matches/$matchId/calls',
          body: {'kind': video ? 'video' : 'audio'},
        ),
      );

  Future<ServerCall> call(String callId) async =>
      ServerCall.fromJson(await _send('GET', '/v1/calls/$callId'));

  Future<ServerCall> answerCall(String callId) async =>
      ServerCall.fromJson(await _send('POST', '/v1/calls/$callId/answer'));

  Future<void> declineCall(String callId) =>
      _send('POST', '/v1/calls/$callId/decline');

  Future<void> endCall(String callId) => _send('POST', '/v1/calls/$callId/end');

  Future<void> sendSignal(String callId, String type, String data) => _send(
    'POST',
    '/v1/calls/$callId/signals',
    body: {'type': type, 'data': data},
  );

  /// The other phone's setup messages after [after], and the call's state.
  Future<({String state, List<CallSignal> signals})> signals(
    String callId, {
    int after = 0,
  }) async {
    final json = await _send('GET', '/v1/calls/$callId/signals?after=$after');
    return (
      state: json['state'] as String,
      signals: (json['signals'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (s) => CallSignal(
              s['seq'] as int,
              s['type'] as String,
              s['data'] as String,
            ),
          )
          .toList(),
    );
  }

  /// A server link (relative) as a full address for loading.
  String absolute(String url) => base.resolve(url).toString();

  Future<List<MyPhoto>> myPhotos() async {
    final json = await _send('GET', '/v1/me/photos');
    return [
      for (final p in json['photos'] as List)
        MyPhoto.fromJson(p as Map<String, dynamic>),
    ];
  }

  /// Uploads one profile photo: asks for a grant with the exact size, type
  /// and SHA-256, then sends the bytes to that one-time link.
  Future<void> uploadPhoto(List<int> bytes, String mimeType) async {
    final grant = await _send(
      'POST',
      '/v1/me/photos',
      body: {
        'client_upload_id': _randomToken(),
        'mime_type': mimeType,
        'byte_length': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
      },
    );
    final response = await _client.put(
      base.resolve(grant['upload_url'] as String),
      headers: {'content-type': mimeType},
      body: bytes,
    );
    if (response.statusCode != 200) {
      var code = 'upload_failed';
      try {
        code =
            (jsonDecode(response.body) as Map<String, dynamic>)['error']
                as String;
      } catch (_) {}
      throw ApiException(response.statusCode, code);
    }
  }

  Future<void> deletePhoto(String id) => _send('DELETE', '/v1/me/photos/$id');

  Future<void> orderPhotos(List<String> ids) =>
      _send('PUT', '/v1/me/photos/order', body: {'photo_ids': ids});

  /// Starts authenticator setup for a moderator: the secret, shown once.
  Future<({String secret, String uri})> setupModeratorSecondFactor() async {
    final json = await _send('POST', '/v1/mod/second-factor/setup');
    return (
      secret: json['secret'] as String,
      uri: json['otpauth_uri'] as String,
    );
  }

  /// Proves the authenticator works and turns the second factor on.
  Future<void> confirmModeratorSecondFactor(String code) =>
      _send('POST', '/v1/mod/second-factor/confirm', body: {'code': code});

  /// Opens moderation on this sign-in for the next half hour.
  Future<void> verifyModeratorSecondFactor(String code) =>
      _send('POST', '/v1/mod/second-factor/verify', body: {'code': code});

  Future<List<ModPhoto>> moderationPhotos() async {
    final json = await _send('GET', '/v1/mod/photos');
    return [
      for (final p in json['photos'] as List)
        ModPhoto.fromJson(p as Map<String, dynamic>),
    ];
  }

  /// [outcome] is `approved` or `rejected` (with a [reason]).
  Future<void> decidePhoto(String id, String outcome, {String? reason}) =>
      _send(
        'POST',
        '/v1/mod/photos/$id/decision',
        body: {'outcome': outcome, 'reason': ?reason},
      );

  /// A suspended person asks for another look; one open appeal at a time.
  Future<void> appeal(String message) =>
      _send('POST', '/v1/me/appeal', body: {'message': message});

  Future<List<ModReport>> moderationReports() async {
    final json = await _send('GET', '/v1/mod/reports');
    return [
      for (final r in json['reports'] as List)
        ModReport.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// [outcome] is `dismissed` or `suspended`. Needs a recent sign-in.
  Future<void> decideReport(String reportId, String outcome, {String? note}) =>
      _send(
        'POST',
        '/v1/mod/reports/$reportId/decision',
        body: {
          'outcome': outcome,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

  Future<List<ModAppeal>> moderationAppeals() async {
    final json = await _send('GET', '/v1/mod/appeals');
    return [
      for (final a in json['appeals'] as List)
        ModAppeal.fromJson(a as Map<String, dynamic>),
    ];
  }

  /// [outcome] is `upheld` or `overturned`. Needs a recent sign-in.
  Future<void> decideAppeal(String appealId, String outcome, {String? note}) =>
      _send(
        'POST',
        '/v1/mod/appeals/$appealId/decision',
        body: {
          'outcome': outcome,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

  /// Sets the approximate area: a cell centre, never an exact point.
  Future<void> setArea(AreaCell cell) =>
      _send('PUT', '/v1/me/location', body: {'lat': cell.lat, 'lng': cell.lng});

  /// Removes the area; distances are hidden again at once.
  Future<void> clearArea() => _send('DELETE', '/v1/me/location');

  /// Everything the server holds about this account, as its JSON. Needs a
  /// recent sign-in, like deletion.
  Future<Map<String, dynamic>> exportData() => _send('GET', '/v1/me/export');

  /// Sends only the fields [ProfileMutation] allows. Age is never sent.
  Future<void> saveProfile(UserProfile profile) => _send(
    'PATCH',
    '/v1/me/profile',
    body: ProfileMutation.fromLocalProfile(profile).toContractMap(),
  );

  /// Schedules deletion and returns the server's date. The server signs the
  /// account out everywhere, so the local session ends too.
  Future<DateTime> scheduleDeletion() async {
    final json = await _send('POST', '/v1/me/deletion');
    await signOutLocally();
    return DateTime.parse(json['effective_at'] as String).toLocal();
  }

  Future<void> cancelDeletion() => _send('DELETE', '/v1/me/deletion');

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

  Future<List<ServerMatch>> matches() async {
    final json = await _send('GET', '/v1/matches');
    final callsAvailable = json['calls_available'] == true;
    return (json['matches'] as List)
        .map(
          (m) => ServerMatch.fromJson(
            m as Map<String, dynamic>,
            callsAvailable: callsAvailable,
          ),
        )
        .toList();
  }

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

  Future<void> markRead(String matchId) =>
      _send('POST', '/v1/matches/$matchId/read');

  Future<void> typing(String matchId) =>
      _send('POST', '/v1/matches/$matchId/typing');

  /// Read receipts and typing, shown only when both people share them.
  Future<bool> shareReadReceipts() async =>
      (await _send('GET', '/v1/me/settings'))['share_read_receipts'] as bool;

  Future<bool> setShareReadReceipts(bool on) async =>
      (await _send(
            'PATCH',
            '/v1/me/settings',
            body: {'share_read_receipts': on},
          ))['share_read_receipts']
          as bool;

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
