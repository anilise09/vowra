import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/api/nudges.dart';
import '../data/api/vawra_api.dart';
import '../data/discovery_interaction_repository.dart';
import '../domain/chat_message.dart';
import '../domain/demo_profile.dart';
import '../domain/discovery_interaction.dart';
import '../domain/discovery_preferences.dart';
import '../domain/match_connection.dart';
import '../domain/openers.dart';
import '../domain/safety_report.dart';
import '../domain/user_profile.dart';
import '../features/discovery/discovery_deck.dart';
import '../features/matches/date_safely_guide.dart';
import '../features/matches/match_celebration.dart';
import '../features/matches/match_tabs.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/profile/profile_editor.dart';
import '../features/settings/settings_page.dart';
import '../features/shared/profile_image.dart';
import '../main.dart' show SafetySheet, WelcomeScreen;
import '../theme/vawra_navigation_shell.dart';
import '../theme/vawra_theme.dart';
import '../data/area_locator.dart';
import 'area_sheet.dart';
import 'data_export_page.dart';
import 'moderation_screens.dart';
import 'photos_editor.dart';

/// Plain-language text for a failed call. Server codes never reach the screen
/// raw, and nothing reveals whether an email has an account.
String describeApiError(Object error) {
  if (error is! ApiException) {
    return 'Can\'t reach Vawra. Check your connection and try again.';
  }
  return switch (error.code) {
    'invalid_proof' => 'That code didn\'t work. Codes work once and expire, so ask for a new one.',
    'slow_down' => 'Slow down a little: up to 5 messages a minute.',
    'super_like_limit' => 'You\'ve used today\'s Super Likes. More tomorrow.',
    'like_limit' => 'You\'ve liked a lot of people today. More tomorrow.',
    'report_limit' =>
      'You\'ve sent many reports today. You can still block anyone at any time.',
    'conversation_closed' => 'This conversation has closed.',
    'account_paused' => 'Your profile is paused. Resume it to meet new people.',
    'age_assurance_required' => 'Your age needs to be confirmed first.',
    'session_revoked' ||
    'unauthorized' => 'You were signed out. Sign in again.',
    'name_too_short' => 'Your name needs at least 2 characters.',
    'name_too_long' => 'Use 40 characters or fewer for your name.',
    'bio_too_short' =>
      'Write at least 20 characters in your bio, or leave it empty.',
    'bio_too_long' => 'Use 300 characters or fewer in your bio.',
    'message_empty' => 'Write a message first.',
    'message_too_long' => 'Messages are limited to 1000 characters.',
    'rate_limited' => 'Too many tries. Wait a few minutes and try again.',
    'reauthentication_required' => 'Please confirm it\'s you first.',
    'deletion_scheduled' =>
      'Your account is scheduled for deletion. Keep it to use Vawra again.',
    'deletion_effective' => 'This account has already been deleted.',
    'no_deletion_scheduled' => 'Your account is not scheduled for deletion.',
    _ => 'Something went wrong. Try again.',
  };
}

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// After sign-in: create the profile, wait for age assurance, or open Vawra.
Future<void> openSignedIn(NavigatorState navigator, VawraApi api) async {
  final me = await api.me();
  final Widget next;
  if (me.deletionScheduled) {
    next = DeletionScheduledScreen(
      api: api,
      effectiveAt: me.deletionEffectiveAt,
      signedIn: true,
    );
  } else if (me.suspension case final suspension? when me.suspended) {
    next = SuspendedScreen(api: api, suspension: suspension);
  } else if (me.profile == null) {
    next = _NewProfile(api: api);
  } else if (!me.canDate) {
    next = AgeCheckScreen(api: api);
  } else {
    next = ServerHome(api: api, me: me);
  }
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => next),
    (_) => false,
  );
}

Future<void> _signOut(NavigatorState navigator, VawraApi api) async {
  try {
    await api.signOut();
  } catch (_) {
    // The local session is gone either way.
  }
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => WelcomeScreen(api: api)),
    (_) => false,
  );
}

/// App start in account mode: resumes a saved session, or shows Welcome.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.api});

  final VawraApi api;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool offline = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => offline = false);
    final navigator = Navigator.of(context);
    try {
      if (await widget.api.resume()) {
        await openSignedIn(navigator, widget.api);
        return;
      }
    } catch (_) {
      // Unreachable server: keep the saved session and offer a retry.
      if (mounted) setState(() => offline = true);
      return;
    }
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => WelcomeScreen(api: widget.api)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: offline
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: VawraColors.muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    describeApiError(const _Offline()),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('retry-start'),
                    onPressed: _start,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          : Image.asset(
              'assets/branding/vawra_company_mark_clean.png',
              width: 120,
              semanticLabel: 'Vawra',
            ),
    ),
  );
}

class _Offline implements Exception {
  const _Offline();
}

/// "7 October 2026": the server's date, in the person's own time zone.
String formatDay(DateTime day) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final local = day.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

/// Account actions that need a fresh sign-in (deletion, keeping the account)
/// run through here: a code to the email first, then [then].
Future<void> withFreshSignIn(
  NavigatorState navigator,
  VawraApi api, {
  required String reason,
  required Future<void> Function() action,
  required Future<void> Function(NavigatorState navigator) then,
}) async {
  try {
    await action();
    await then(navigator);
  } on ApiException catch (e) {
    if (e.code != 'reauthentication_required') rethrow;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreen(
          api: api,
          confirmReason: reason,
          onConfirmed: (nav) async {
            await action();
            await then(nav);
          },
        ),
      ),
    );
  }
}

/// The export allows a few copies a day; say so rather than "a few minutes".
String describeExportError(Object error) =>
    error is ApiException && error.code == 'rate_limited'
    ? 'You can download your data 5 times a day. Try again tomorrow.'
    : describeApiError(error);

/// Fetches the person's data (confirming a recent sign-in first when the
/// server asks) and opens it above the page it was asked from.
Future<void> openDataExport(NavigatorState navigator, VawraApi api) async {
  Route<dynamic>? from;
  navigator.popUntil((route) {
    from = route;
    return true;
  });
  late Map<String, dynamic> data;
  await withFreshSignIn(
    navigator,
    api,
    reason: 'download your data',
    action: () async => data = await api.exportData(),
    then: (nav) async {
      nav.popUntil((route) => route == from);
      unawaited(
        nav.push(
          MaterialPageRoute<void>(builder: (_) => DataExportPage(data: data)),
        ),
      );
    },
  );
}

/// Email and a one-time code. No password is ever created. With
/// [confirmReason] it confirms the person before an account action instead.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.api,
    this.confirmReason,
    this.onConfirmed,
  });

  final VawraApi api;
  final String? confirmReason;
  final Future<void> Function(NavigatorState navigator)? onConfirmed;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController();
  final code = TextEditingController();
  final codeFocus = FocusNode();
  bool codeSent = false;
  bool busy = false;
  String? error;

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    codeFocus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = describeApiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _send() async {
    if (!_emailShape.hasMatch(email.text.trim())) {
      setState(() => error = 'Enter an email address like name@example.com.');
      return;
    }
    await _run(() async {
      await widget.api.requestSignIn(email.text);
      code.clear();
      setState(() => codeSent = true);
      codeFocus.requestFocus();
    });
  }

  Future<void> _verify() async {
    if (code.text.trim().length < 20) {
      setState(() => error = 'Paste the whole code from the email.');
      return;
    }
    final navigator = Navigator.of(context);
    await _run(() async {
      await widget.api.exchange(code.text);
      final confirmed = widget.onConfirmed;
      if (confirmed != null) {
        await confirmed(navigator);
      } else {
        await openSignedIn(navigator, widget.api);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.confirmReason == null ? 'Sign in' : 'Confirm it\'s you',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Text(
              codeSent ? 'Check your email' : 'What\'s your email?',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              codeSent
                  ? 'If ${email.text.trim()} can sign in, a one-time code is '
                        'on its way. It works once and expires soon.'
                  : widget.confirmReason != null
                  ? 'To ${widget.confirmReason}, enter the email for this account and we\'ll '
                        'send a one-time code.'
                  : 'We\'ll email you a one-time code. No password to '
                        'remember, and your email is never shown to anyone.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            if (!codeSent)
              TextField(
                key: const Key('sign-in-email'),
                controller: email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => busy ? null : _send(),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              )
            else
              TextField(
                key: const Key('sign-in-code'),
                controller: code,
                focusNode: codeFocus,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => busy ? null : _verify(),
                decoration: const InputDecoration(
                  labelText: 'Code',
                  prefixIcon: Icon(Icons.key_rounded),
                ),
              ),
            if (error case final message?) ...[
              const SizedBox(height: 12),
              Text(
                message,
                key: const Key('sign-in-error'),
                style: const TextStyle(color: VawraColors.coralDark),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: Key(codeSent ? 'verify-code' : 'send-code'),
              onPressed: busy ? null : (codeSent ? _verify : _send),
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(codeSent ? 'Sign in' : 'Send code'),
            ),
            if (codeSent) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('resend-code'),
                onPressed: busy ? null : _send,
                child: const Text('Send a new code'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        codeSent = false;
                        error = null;
                      }),
                child: const Text('Use a different email'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A scheduled deletion: the server's date, and a way to keep the account.
class DeletionScheduledScreen extends StatefulWidget {
  const DeletionScheduledScreen({
    super.key,
    required this.api,
    required this.effectiveAt,
    required this.signedIn,
  });

  final VawraApi api;
  final DateTime? effectiveAt;

  /// False straight after scheduling: the server signed out every device.
  final bool signedIn;

  @override
  State<DeletionScheduledScreen> createState() =>
      _DeletionScheduledScreenState();
}

class _DeletionScheduledScreenState extends State<DeletionScheduledScreen> {
  bool busy = false;

  String get _when => widget.effectiveAt == null
      ? 'soon'
      : 'on ${formatDay(widget.effectiveAt!)}';

  Future<void> _keep() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    try {
      await withFreshSignIn(
        navigator,
        widget.api,
        reason: 'keep your account',
        action: widget.api.cancelDeletion,
        then: (nav) async {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Welcome back. Your account is kept.'),
            ),
          );
          await openSignedIn(nav, widget.api);
        },
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await openDataExport(Navigator.of(context), widget.api);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeExportError(e))));
    }
  }

  void _toStart() => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => WelcomeScreen(api: widget.api)),
    (_) => false,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
          children: [
            const Icon(
              Icons.hourglass_bottom_rounded,
              size: 64,
              color: VawraColors.coral,
            ),
            const SizedBox(height: 20),
            Text(
              'Your account will be deleted $_when',
              key: const Key('deletion-date'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              widget.signedIn
                  ? 'Your profile, matches and messages are deleted then. '
                        'Until that day nobody can see or message you. Changed '
                        'your mind? You can keep your account.'
                  : 'You are signed out on every device. Your profile, '
                        'matches and messages are deleted then, and until '
                        'that day nobody can see or message you. To keep your '
                        'account, sign in again before then.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            if (widget.signedIn) ...[
              FilledButton(
                key: const Key('keep-account'),
                onPressed: busy ? null : _keep,
                child: const Text('Keep my account'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('deletion-export'),
                onPressed: busy ? null : _export,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download a copy of your data'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('deletion-sign-out'),
                onPressed: () => _signOut(Navigator.of(context), widget.api),
                child: const Text('Sign out'),
              ),
            ] else
              FilledButton(
                key: const Key('deletion-done'),
                onPressed: _toStart,
                child: const Text('Done'),
              ),
          ],
        ),
      ),
    );
  }
}

/// First sign-in: the same onboarding as the prototype, saved to the server.
class _NewProfile extends StatelessWidget {
  const _NewProfile({required this.api});

  final VawraApi api;

  @override
  Widget build(BuildContext context) => OnboardingFlow(
    live: true,
    onComplete: (profile) async {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        await api.saveProfile(profile);
        await openSignedIn(navigator, api);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    },
  );
}

/// Dating stays closed until an independent age check passes.
class AgeCheckScreen extends StatefulWidget {
  const AgeCheckScreen({super.key, required this.api});

  final VawraApi api;

  @override
  State<AgeCheckScreen> createState() => _AgeCheckScreenState();
}

class _AgeCheckScreenState extends State<AgeCheckScreen> {
  bool checking = false;

  Future<void> _checkAgain() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => checking = true);
    try {
      final me = await widget.api.me();
      if (me.canDate) {
        messenger.clearSnackBars();
        await openSignedIn(navigator, widget.api);
        return;
      }
      if (mounted) _toast(context, 'Not confirmed yet.');
    } catch (e) {
      if (mounted) _toast(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 64,
              color: VawraColors.coral,
            ),
            const SizedBox(height: 20),
            Text(
              'One more step: confirming you\'re 18+',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Your profile is saved. Before Discover, matches and chat open, '
              'Vawra confirms every member\'s age with an independent '
              'age-check service. That service is not connected yet, so '
              'this step cannot be completed today.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            FilledButton(
              key: const Key('age-check-again'),
              onPressed: checking ? null : _checkAgain,
              child: const Text('Check again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('age-sign-out'),
              onPressed: () => _signOut(Navigator.of(context), widget.api),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

DemoProfile _card(ServerPerson person, VawraApi api) {
  final key = '$serverPersonPrefix${person.accountId}';
  registerDemoPortrait(key, person.demoPortrait);
  // Approved photos win over a demo portrait; none means the placeholder.
  registerServerPhotos(key, [
    for (final url in person.photos) api.absolute(url),
  ]);
  return _detailed(person);
}

DemoProfile _detailed(ServerPerson person) => DetailedProfile(
  person.name,
  person.age ?? 18,
  person.intent?.label ?? '',
  person.distanceBand ?? 'Distance hidden',
  person.bio,
  person.interests,
  '$serverPersonPrefix${person.accountId}',
  lifestyle: person.lifestyle,
  prompts: person.prompts,
  reasons: person.reasons,
  gender: person.gender,
);

String _accountOf(String photoKey) =>
    photoKey.substring(serverPersonPrefix.length);

MatchConnection _connection(
  ServerMatch match, {
  ConnectionStatus status = ConnectionStatus.active,
  bool callReady = false,
}) => MatchConnection(
  matchId: match.matchId,
  peerName: match.peerName,
  peerProfileAssetPath: '$serverPersonPrefix${match.peerAccountId}',
  status: status,
  currentUserCallReady: callReady,
);

/// Vawra with a real account: Discover, Matches, Chats and Profile.
class ServerHome extends StatefulWidget {
  const ServerHome({
    super.key,
    required this.api,
    required this.me,
    this.checkEvery = const Duration(seconds: 10),
  });

  final VawraApi api;
  final MeState me;

  /// How often to consider a safety refresh. With the nudge stream up a
  /// refresh happens at most every [ServerHome.safetyRefresh]; without it, on
  /// every check.
  final Duration checkEvery;

  static const safetyRefresh = Duration(seconds: 60);

  @override
  State<ServerHome> createState() => _ServerHomeState();
}

class _ServerHomeState extends State<ServerHome> {
  static const tabDiscover = 0;
  static const tabChats = 2; // Discover, Matches, Chats, Profile

  VawraApi get api => widget.api;

  int tab = tabDiscover;
  List<ServerPerson> people = const [];
  List<ServerPerson> likes = const [];
  List<ServerMatch> matches = const [];
  bool loaded = false;
  String? loadError;
  late UserProfile? profile = widget.me.profile;
  late bool paused = widget.me.paused;
  final interactions = MemoryDiscoveryInteractionRepository();
  final reports = <String, DiscoveryProfileReport>{};
  DiscoveryPreferences preferences = const DiscoveryPreferences();
  int profileIndex = 0;
  int superLikesLeft = 3;
  bool tutorialSeen = false;
  bool safetyGuideSeen = false;
  final notificationPrefs = <String, bool>{
    'New matches': true,
    'Messages': true,
    'Likes you': true,
    'Safety tips': true,
  };
  Timer? check;

  /// Nudges fan out to open chat threads.
  final _nudges = StreamController<Nudge>.broadcast();
  late final NudgeLink link = NudgeLink(api, onNudge: _onNudge);

  /// False while the app is in the background: no stream, no refreshes.
  final foreground = ValueNotifier<bool>(true);
  AppLifecycleListener? _lifecycle;
  Timer? _pendingStop;

  /// Read receipts and typing; null until loaded.
  bool? shareReceipts;

  /// When the approximate area was set; null when distance is off.
  late DateTime? areaSetAt = widget.me.areaUpdatedAt;

  /// Checks since the last refresh; counting ticks keeps this testable.
  int _checksSinceRefresh = 0;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    if (areaSetAt != null) _refreshArea();
    api
        .shareReadReceipts()
        .then((on) {
          if (mounted) setState(() => shareReceipts = on);
        })
        .catchError((Object _) {});
    link.start();
    check = Timer.periodic(widget.checkEvery, (_) => _safetyCheck());
    _lifecycle = AppLifecycleListener(
      onResume: _resumed,
      onHide: _backgrounded,
      onPause: _backgrounded,
    );
  }

  @override
  void dispose() {
    check?.cancel();
    _pendingStop?.cancel();
    _lifecycle?.dispose();
    link.dispose();
    _nudges.close();
    foreground.dispose();
    super.dispose();
  }

  /// A system dialog or a quick app switch should not drop the stream, so
  /// stopping waits a second (the same smoothing Tinder's Scarlet applies).
  void _backgrounded() {
    _pendingStop ??= Timer(const Duration(seconds: 1), () {
      _pendingStop = null;
      foreground.value = false;
      link.stop();
    });
  }

  void _resumed() {
    _pendingStop?.cancel();
    _pendingStop = null;
    if (foreground.value) return;
    foreground.value = true;
    link.start(); // reconnecting sends a catch-up
  }

  void _onNudge(Nudge nudge) {
    if (!_nudges.isClosed) _nudges.add(nudge);
    // Typing is only for an open chat; everything else can change the list.
    if (nudge.kind != 'typing') _refreshMatches();
  }

  /// A missed nudge costs at most a minute; without the stream this falls
  /// back to refreshing on every check.
  void _safetyCheck() {
    if (!foreground.value) return;
    _checksSinceRefresh++;
    final since = widget.checkEvery * _checksSinceRefresh;
    if (link.connected && since < ServerHome.safetyRefresh) return;
    _refreshMatches();
  }

  /// A revoked or expired session goes back to the start.
  bool _signedOutBy(Object error) {
    if (error is ApiException && error.status == 401) {
      _signOut(Navigator.of(context), api);
      return true;
    }
    return false;
  }

  /// While paused only existing matches are reachable; new people and
  /// incoming likes wait until the person resumes.
  Future<List<ServerPerson>> _newPeople() async =>
      paused ? const [] : api.discovery();
  Future<List<ServerPerson>> _likes() async =>
      paused ? const [] : api.likesYou();

  Future<void> _refreshAll() async {
    try {
      final results = await Future.wait([
        _newPeople(),
        _likes(),
        api.matches(),
      ]);
      if (!mounted) return;
      _registerMatchPortraits(results[2] as List<ServerMatch>);
      setState(() {
        people = results[0] as List<ServerPerson>;
        likes = results[1] as List<ServerPerson>;
        matches = results[2] as List<ServerMatch>;
        profileIndex = 0;
        loaded = true;
        loadError = null;
      });
    } catch (e) {
      if (!mounted || _signedOutBy(e)) return;
      setState(() => loadError = describeApiError(e));
    }
  }

  Future<void> _refreshMatches() async {
    _checksSinceRefresh = 0;
    try {
      final results = await Future.wait([_likes(), api.matches()]);
      if (!mounted) return;
      _registerMatchPortraits(results[1] as List<ServerMatch>);
      setState(() {
        likes = results[0] as List<ServerPerson>;
        matches = results[1] as List<ServerMatch>;
      });
    } catch (e) {
      if (mounted) _signedOutBy(e);
    }
  }

  void _registerMatchPortraits(List<ServerMatch> list) {
    for (final m in list) {
      registerDemoPortrait(
        '$serverPersonPrefix${m.peerAccountId}',
        m.peerDemoPortrait,
      );
    }
  }

  void _selectTab(int index) {
    setState(() => tab = index);
    if (index == tabDiscover) _refreshAll();
    if (index != tabDiscover) _refreshMatches();
    if (index == tabChats && !safetyGuideSeen) {
      safetyGuideSeen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) DateSafelyGuide.show(context);
      });
    }
  }

  Future<void> _swipe(DemoProfile card, DiscoverySwipeAction action) async {
    final String kind;
    switch (action) {
      case DiscoverySwipeAction.skip:
        setState(() => profileIndex += 1);
        return;
      case DiscoverySwipeAction.reject:
        kind = 'pass';
        setState(() => interactions.reject(card));
      case DiscoverySwipeAction.like:
        kind = 'like';
        setState(
          () => interactions.recordLike(
            card,
            createdAt: DateTime.now().toUtc(),
            mutualLike: false,
          ),
        );
      case DiscoverySwipeAction.superLike:
        if (superLikesLeft <= 0) return;
        kind = 'super_like';
        setState(() {
          final recorded = interactions.recordLike(
            card,
            createdAt: DateTime.now().toUtc(),
            mutualLike: false,
            superLike: true,
          );
          if (recorded) superLikesLeft -= 1;
        });
    }
    final accountId = _accountOf(card.assetPath);
    try {
      final matchId = await api.swipe(accountId, kind);
      if (!mounted) return;
      setState(
        () => likes = [
          for (final p in likes)
            if (p.accountId != accountId) p,
        ],
      );
      if (matchId != null) {
        await _refreshMatches();
        if (mounted) _celebrate(card, matchId, kind == 'super_like');
      }
    } catch (e) {
      if (!mounted || _signedOutBy(e)) return;
      if (e is ApiException && e.code == 'super_like_limit') {
        setState(() => superLikesLeft = 0);
      }
      _toast(context, describeApiError(e));
    }
  }

  void _celebrate(DemoProfile card, String matchId, bool superLike) {
    final name = profile?.displayName.trim() ?? '';
    MatchCelebration.show(
      context,
      peerName: card.name,
      peerPhotoAsset: card.assetPath,
      ownInitial: name.isEmpty ? 'You' : name.characters.first.toUpperCase(),
      superLike: superLike,
      onMessage: () {
        final match = matches.where((m) => m.matchId == matchId).firstOrNull;
        if (match != null) _openThread(match);
      },
    );
  }

  Future<void> _openThread(ServerMatch match) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServerThreadPage(
          api: api,
          match: match,
          nudges: _nudges.stream,
          streaming: () => link.connected,
          foreground: foreground,
          sharesReceipts: () => shareReceipts == true,
        ),
      ),
    );
    if (mounted) _refreshMatches();
  }

  Future<void> _report(DiscoveryProfileReport report) async {
    try {
      await api.report(
        _accountOf(report.profileAssetPath),
        report.reason.backendKey,
      );
      if (mounted) setState(() => reports[report.profileAssetPath] = report);
    } catch (e) {
      if (mounted && !_signedOutBy(e)) _toast(context, describeApiError(e));
    }
  }

  Future<void> _block(DemoProfile card) async {
    try {
      await api.block(_accountOf(card.assetPath));
      if (!mounted) return;
      setState(() {
        interactions.block(card);
        profileIndex = 0;
      });
      _refreshMatches();
    } catch (e) {
      if (mounted && !_signedOutBy(e)) _toast(context, describeApiError(e));
    }
  }

  Future<void> _deleteAccount(NavigatorState navigator) async {
    late DateTime effectiveAt;
    try {
      await withFreshSignIn(
        navigator,
        api,
        reason: 'delete your account',
        action: () async => effectiveAt = await api.scheduleDeletion(),
        then: (nav) async => nav.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => DeletionScheduledScreen(
              api: api,
              effectiveAt: effectiveAt,
              signedIn: false,
            ),
          ),
          (_) => false,
        ),
      );
    } catch (e) {
      if (mounted) _toast(context, describeApiError(e));
    }
  }

  Future<void> _downloadData(NavigatorState navigator) async {
    try {
      await openDataExport(navigator, api);
    } catch (e) {
      if (mounted && !_signedOutBy(e)) _toast(context, describeExportError(e));
    }
  }

  /// Keeps the area current without asking: only with a permission the
  /// person already gave, and quietly (the server allows a new area every 15
  /// minutes).
  Future<void> _refreshArea() async {
    final fix = await areaLocator.locate(ask: false);
    final cell = fix.cell;
    if (cell == null) return;
    try {
      await api.setArea(cell);
    } catch (_) {}
  }

  Future<bool> _chooseArea(BuildContext context) async {
    final on = await AreaSheet.show(context, api: api, on: areaSetAt != null);
    if (!mounted) return on;
    final changed = on != (areaSetAt != null);
    setState(() => areaSetAt = on ? (areaSetAt ?? DateTime.now()) : null);
    if (changed) _refreshAll();
    return on;
  }

  Future<void> _setShareReceipts(bool on) async {
    try {
      final saved = await api.setShareReadReceipts(on);
      if (mounted) setState(() => shareReceipts = saved);
    } catch (e) {
      if (mounted && !_signedOutBy(e)) _toast(context, describeApiError(e));
    }
  }

  Future<void> _setPaused(bool value) async {
    try {
      await api.setPaused(value);
      if (!mounted) return;
      setState(() => paused = value);
      _refreshAll();
    } catch (e) {
      if (mounted && !_signedOutBy(e)) _toast(context, describeApiError(e));
    }
  }

  Widget _discover(BuildContext context) {
    if (!loaded) {
      return Center(
        child: loadError == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('retry-load'),
                      onPressed: _refreshAll,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
      );
    }
    final deck = DiscoveryDeck(
      profiles: [for (final p in people) _card(p, api)],
      extraPhotos: {
        for (final p in people)
          '$serverPersonPrefix${p.accountId}': morePhotos(
            '$serverPersonPrefix${p.accountId}',
          ),
      },
      preferences: preferences,
      blockedProfileAssets: interactions.blockedProfileAssets(),
      likedProfiles: interactions.likedProfiles(),
      rejectedProfileAssets: interactions.rejectedProfileAssets(),
      reports: reports,
      likeEvents: const [],
      profileIndex: profileIndex,
      onPreferencesChanged: (updated) => setState(() {
        preferences = updated;
        profileIndex = 0;
      }),
      onSwipeAction: _swipe,
      onReport: _report,
      onBlockProfile: _block,
      onOpenSafety: () => _openSafety(context),
      superLikesLeft: superLikesLeft,
      showTutorial: !tutorialSeen,
      onTutorialDone: () => setState(() => tutorialSeen = true),
    );
    if (!paused) return deck;
    return Column(
      key: const Key('paused-discover'),
      children: [
        SafeArea(
          bottom: false,
          child: Container(
            key: const Key('paused-banner'),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: BoxDecoration(
              color: VawraColors.lavender,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.pause_circle_outline, color: VawraColors.plum),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your profile is paused. New people cannot see you.',
                  ),
                ),
                TextButton(
                  key: const Key('resume-profile'),
                  onPressed: () => _setPaused(false),
                  child: const Text('Resume'),
                ),
              ],
            ),
          ),
        ),
        const Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Discover is resting while your profile is paused. Your matches '
                'and chats are still here.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openSafety(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const SafetySheet(),
  );

  void _openSettings(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          paused: paused,
          onPausedChanged: _setPaused,
          notifications: notificationPrefs,
          onNotificationChanged: (kind, on) =>
              setState(() => notificationPrefs[kind] = on),
          onOpenSafetyGuide: () => DateSafelyGuide.show(context),
          onOpenSafetyCenter: () => _openSafety(context),
          onDeleteProfile: () => _deleteAccount(navigator),
          onSignOut: () => _signOut(navigator, api),
          shareReadReceipts: shareReceipts ?? false,
          onShareReadReceiptsChanged: _setShareReceipts,
          onDownloadData: () => _downloadData(navigator),
          areaOn: areaSetAt != null,
          onArea: () => _chooseArea(navigator.context),
          onModeration: widget.me.moderator
              ? () => navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => ModerationPage(api: api),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _profile(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 10, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.filledTonal(
                key: const Key('open-settings'),
                tooltip: 'Settings',
                onPressed: () => _openSettings(context),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: ProfileEditor(
            initialProfile: profile,
            prototypeMode: false,
            photosCard: ServerPhotosCard(api: api),
            onSaved: (updated) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await api.saveProfile(updated);
                if (mounted) setState(() => profile = updated);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Profile saved.')),
                );
              } catch (e) {
                if (mounted && !_signedOutBy(e)) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(describeApiError(e))),
                  );
                }
              }
            },
          ),
        ),
      ],
    ),
  );

  int get _unreadTotal => matches.fold(0, (sum, m) => sum + m.unread);

  @override
  Widget build(BuildContext context) {
    final latest = matches.firstOrNull;
    final answered = {
      ...interactions.likedProfiles().keys,
      ...interactions.rejectedProfileAssets(),
      ...interactions.blockedProfileAssets(),
    };
    final pages = [
      _discover(context),
      MatchTab(
        connection: latest == null ? null : _connection(latest),
        onOpenChat: () {
          if (latest != null) _openThread(latest);
        },
        likesYou: [
          for (final p in [for (final l in likes) _card(l, api)])
            if (!answered.contains(p.assetPath)) p,
        ],
        onRespond: _swipe,
      ),
      ServerChatList(
        matches: matches,
        onOpen: _openThread,
        onOpenSafety: () => DateSafelyGuide.show(context),
      ),
      _profile(context),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: VawraNavigationShell(
        child: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: _selectTab,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: likes.isNotEmpty,
                child: const Icon(Icons.favorite_outline),
              ),
              selectedIcon: const Icon(Icons.favorite_rounded),
              label: 'Matches',
            ),
            NavigationDestination(
              key: const Key('chat-tab'),
              icon: Badge(
                key: const Key('chats-unread'),
                isLabelVisible: _unreadTotal > 0,
                label: Text('$_unreadTotal'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              selectedIcon: Badge(
                isLabelVisible: _unreadTotal > 0,
                label: Text('$_unreadTotal'),
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              label: 'Chats',
            ),
            const NavigationDestination(
              key: Key('profile-tab'),
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Every active match: new ones as a row of faces, conversations below.
class ServerChatList extends StatelessWidget {
  const ServerChatList({
    super.key,
    required this.matches,
    required this.onOpen,
    required this.onOpenSafety,
  });

  final List<ServerMatch> matches;
  final ValueChanged<ServerMatch> onOpen;
  final VoidCallback onOpenSafety;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fresh = matches.where((m) => m.lastMessage == null).toList();
    final talking = matches.where((m) => m.lastMessage != null).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Chats', style: theme.textTheme.headlineSmall),
              ),
              IconButton(
                tooltip: 'Date safely',
                onPressed: onOpenSafety,
                icon: const Icon(Icons.shield_outlined),
              ),
            ],
          ),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 48,
                    color: VawraColors.muted,
                  ),
                  const SizedBox(height: 12),
                  Text('No matches yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  const Text(
                    'When you and someone both like each other, you can '
                    'chat here. Messaging is always free.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          if (fresh.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('New matches', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fresh.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) => InkWell(
                  key: Key('new-match-${fresh[i].peerName}'),
                  borderRadius: BorderRadius.circular(40),
                  onTap: () => onOpen(fresh[i]),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: VawraColors.coral,
                        child: CircleAvatar(
                          radius: 31,
                          backgroundImage: profileImage(
                            '$serverPersonPrefix${fresh[i].peerAccountId}',
                          ),
                          child:
                              isDemoPerson(
                                '$serverPersonPrefix${fresh[i].peerAccountId}',
                              )
                              ? null
                              : Text(
                                  fresh[i].peerName.characters.first
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: VawraColors.plum,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(fresh[i].peerName),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (talking.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Messages', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final match in talking)
              ListTile(
                key: Key('conversation-${match.peerName}'),
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: profileImage(
                    '$serverPersonPrefix${match.peerAccountId}',
                  ),
                  child:
                      isDemoPerson('$serverPersonPrefix${match.peerAccountId}')
                      ? null
                      : Text(
                          match.peerName.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: VawraColors.plum,
                          ),
                        ),
                ),
                title: Text(
                  match.peerName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${match.lastMessageMine == true ? 'You: ' : ''}'
                  '${match.lastMessage!}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: match.unread > 0
                      ? const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: VawraColors.ink,
                        )
                      : null,
                ),
                trailing: match.unread > 0
                    ? Badge(
                        key: Key('unread-${match.peerName}'),
                        backgroundColor: VawraColors.coral,
                        label: Text('${match.unread}'),
                      )
                    : match.yourTurn
                    ? Container(
                        key: Key('your-turn-${match.peerName}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: VawraColors.blush,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Your turn',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: VawraColors.coralDark,
                          ),
                        ),
                      )
                    : null,
                onTap: () => onOpen(match),
              ),
          ],
        ],
      ),
    );
  }
}

/// One conversation. It reloads on a nudge for this match; the timer is only
/// a safety net (every 30 s with the stream up, every few seconds without).
class ServerThreadPage extends StatefulWidget {
  const ServerThreadPage({
    super.key,
    required this.api,
    required this.match,
    this.nudges,
    this.streaming,
    this.foreground,
    this.sharesReceipts,
    this.checkEvery = const Duration(seconds: 3),
  });

  final VawraApi api;
  final ServerMatch match;
  final Stream<Nudge>? nudges;
  final bool Function()? streaming;
  final ValueListenable<bool>? foreground;

  /// Whether this person shares read receipts and typing.
  final bool Function()? sharesReceipts;
  final Duration checkEvery;

  /// How long "is typing…" stays without a fresh signal.
  static const typingShownFor = Duration(seconds: 6);

  static const safetyRefresh = Duration(seconds: 30);

  @override
  State<ServerThreadPage> createState() => _ServerThreadPageState();
}

class _ServerThreadPageState extends State<ServerThreadPage> {
  List<ChatMessage> messages = const [];
  ConnectionStatus status = ConnectionStatus.active;
  bool callReady = false;
  SafetyReport? report;
  Timer? poll;
  StreamSubscription<Nudge>? _nudgeSub;
  int _checksSinceLoad = 0;
  bool peerTyping = false;
  Timer? _typingTimer;
  String? _markedUpTo;
  DateTime? _lastTypingSent;

  @override
  void initState() {
    super.initState();
    _load();
    _nudgeSub = widget.nudges?.listen((nudge) {
      final forThis = nudge.matchId == widget.match.matchId;
      if (forThis && nudge.kind == 'typing') {
        _showTyping();
      } else if (nudge.isCatchUp || forThis) {
        if (nudge.kind == 'message') _hideTyping();
        _load();
      }
    });
    poll = Timer.periodic(widget.checkEvery, (_) {
      if (widget.foreground?.value == false) return;
      _checksSinceLoad++;
      final since = widget.checkEvery * _checksSinceLoad;
      final streaming = widget.streaming?.call() ?? false;
      if (streaming && since < ServerThreadPage.safetyRefresh) return;
      _load();
    });
  }

  @override
  void dispose() {
    poll?.cancel();
    _nudgeSub?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _showTyping() {
    _typingTimer?.cancel();
    _typingTimer = Timer(ServerThreadPage.typingShownFor, _hideTyping);
    if (!peerTyping) setState(() => peerTyping = true);
  }

  void _hideTyping() {
    _typingTimer?.cancel();
    if (mounted && peerTyping) setState(() => peerTyping = false);
  }

  /// Tells the other person you are typing, at most every 3 seconds, and only
  /// when you share receipts (the server also checks that they do).
  void _composing() {
    if (widget.sharesReceipts?.call() != true) return;
    final now = DateTime.now();
    final last = _lastTypingSent;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _lastTypingSent = now;
    widget.api.typing(widget.match.matchId).catchError((Object _) {});
  }

  /// Marks the chat read once a new message from them is on screen.
  void _markRead() {
    final newest = messages
        .where((m) => m.author == MessageAuthor.peer)
        .lastOrNull;
    if (newest == null || newest.id == _markedUpTo) return;
    if (widget.foreground?.value == false) return;
    _markedUpTo = newest.id;
    widget.api.markRead(widget.match.matchId).catchError((Object _) {});
  }

  ChatMessage _message(ServerMessage m) => ChatMessage(
    id: m.id,
    author: m.mine ? MessageAuthor.currentUser : MessageAuthor.peer,
    text: m.text,
    sentAt: m.sentAt,
    seen: m.seen,
  );

  void _closed() {
    poll?.cancel();
    if (status == ConnectionStatus.active) {
      setState(() => status = ConnectionStatus.unmatched);
    }
  }

  Future<void> _load() async {
    if (status != ConnectionStatus.active) return;
    _checksSinceLoad = 0;
    try {
      final loaded = await widget.api.messages(widget.match.matchId);
      if (!mounted) return;
      setState(() => messages = loaded.map(_message).toList());
      _markRead();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'conversation_closed' || e.status == 404) _closed();
    } catch (_) {
      // Offline for a moment; the next poll tries again.
    }
  }

  Future<void> _send(String text) async {
    try {
      final sent = await widget.api.send(widget.match.matchId, text);
      if (mounted) setState(() => messages = [...messages, _message(sent)]);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 'conversation_closed') _closed();
      _toast(context, describeApiError(e));
    }
  }

  Future<void> _act(Future<void> Function() call, VoidCallback after) async {
    try {
      await call();
      if (mounted) setState(after);
    } catch (e) {
      if (mounted) _toast(context, describeApiError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ChatTab(
      connection: _connection(
        widget.match,
        status: status,
        callReady: callReady,
      ),
      messages: messages,
      report: report,
      startInThread: true,
      peerTyping: peerTyping,
      onComposing: _composing,
      openers: openersFor(
        sharedInterests: widget.match.sharedInterests,
        peerPrompts: widget.match.peerPrompts,
      ),
      onBack: () => Navigator.of(context).pop(),
      onSend: _send,
      onCallReadinessChanged: (value) => setState(() => callReady = value),
      onReport: (r) => _act(
        () => widget.api.report(
          widget.match.peerAccountId,
          r.reason.backendKey,
          messageId: r.messageId,
        ),
        () => report = r,
      ),
      onUnmatch: () => _act(() => widget.api.unmatch(widget.match.matchId), () {
        poll?.cancel();
        status = ConnectionStatus.unmatched;
      }),
      onBlock: () =>
          _act(() => widget.api.block(widget.match.peerAccountId), () {
            poll?.cancel();
            status = ConnectionStatus.blocked;
          }),
      onOpenSafety: () => DateSafelyGuide.show(context),
    ),
  );
}
