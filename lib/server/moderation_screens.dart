import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api/server_photo.dart';
import '../data/api/vawra_api.dart';
import '../domain/safety_report.dart';
import '../main.dart' show WelcomeScreen;
import '../theme/vawra_theme.dart';
import 'photos_editor.dart' show rejectReasonLabels;
import 'server_flow.dart'
    show
        DeletionScheduledScreen,
        describeApiError,
        describeExportError,
        formatDay,
        openDataExport,
        withFreshSignIn;

String _reasonText(ReportReason? reason) =>
    reason == null ? 'a safety concern' : '“${reason.label}”';

String _moderationError(Object error) => switch (error) {
  ApiException(code: 'already_decided') => 'Someone already decided this one.',
  ApiException(code: 'second_moderator_required') =>
    'You suspended this account, so a different moderator must decide.',
  ApiException(code: 'conflict_of_interest') =>
    'This involves you, so another moderator must decide it.',
  ApiException(code: 'appeal_open') =>
    'Your appeal is already with a moderator.',
  _ => describeApiError(error),
};

/// What a suspended person sees after signing in: why, and how to appeal.
/// Downloading their data, deleting the account and signing out stay open.
class SuspendedScreen extends StatefulWidget {
  const SuspendedScreen({
    super.key,
    required this.api,
    required this.suspension,
  });

  final VawraApi api;
  final Suspension suspension;

  @override
  State<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends State<SuspendedScreen> {
  final message = TextEditingController();
  late String? appealState = widget.suspension.appealState;
  late DateTime? appealAt = widget.suspension.appealAt;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> _sendAppeal() async {
    final text = message.text.trim();
    if (text.isEmpty) {
      setState(() => error = 'Write a few words about what happened.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.appeal(text);
      if (!mounted) return;
      setState(() {
        busy = false;
        appealState = 'open';
        appealAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = _moderationError(e);
      });
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

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'Your profile, likes, matches and chats are deleted after a waiting '
          'period. Deleting does not lift the suspension in the meantime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('suspended-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    late DateTime effectiveAt;
    try {
      await withFreshSignIn(
        navigator,
        widget.api,
        reason: 'delete your account',
        action: () async => effectiveAt = await widget.api.scheduleDeletion(),
        then: (nav) async => nav.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => DeletionScheduledScreen(
              api: widget.api,
              effectiveAt: effectiveAt,
              signedIn: false,
            ),
          ),
          (_) => false,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
    }
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    try {
      await widget.api.signOut();
    } catch (_) {}
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => WelcomeScreen(api: widget.api)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.suspension;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
          children: [
            const Icon(
              Icons.gpp_maybe_outlined,
              size: 64,
              color: VawraColors.coral,
            ),
            const SizedBox(height: 18),
            Text(
              'Your account is suspended',
              key: const Key('suspended-title'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Since ${formatDay(s.since)}, after a report for '
              '${_reasonText(s.reason)}. While it is suspended, nobody can see '
              'or message you.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Material(
              color: VawraColors.blush,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: appealState == 'open'
                    ? Text(
                        'Your appeal was sent on '
                        '${formatDay(appealAt ?? DateTime.now())}. A different '
                        'moderator from the one who suspended you will review '
                        'it.',
                        key: const Key('appeal-pending'),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Appeal', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            appealState == 'upheld'
                                ? 'Your last appeal was reviewed and the '
                                      'suspension stays. You can explain once '
                                      'more.'
                                : 'If this is a mistake, tell us what happened. '
                                      'A different moderator will look again.',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('appeal-message'),
                            controller: message,
                            maxLength: 1000,
                            minLines: 3,
                            maxLines: 6,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'What happened?',
                            ),
                          ),
                          if (error case final text?)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                text,
                                style: const TextStyle(
                                  color: VawraColors.coralDark,
                                ),
                              ),
                            ),
                          FilledButton(
                            key: const Key('appeal-send'),
                            onPressed: busy ? null : _sendAppeal,
                            child: const Text('Send appeal'),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              key: const Key('suspended-export'),
              onPressed: _export,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download a copy of your data'),
            ),
            TextButton(
              key: const Key('suspended-delete'),
              onPressed: _delete,
              child: const Text('Delete my account'),
            ),
            TextButton(
              key: const Key('suspended-sign-out'),
              onPressed: _signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reports and appeals for moderators. Every decision is confirmed, needs a
/// recent sign-in, and is recorded on the server.
class ModerationPage extends StatefulWidget {
  const ModerationPage({super.key, required this.api});

  final VawraApi api;

  @override
  State<ModerationPage> createState() => _ModerationPageState();
}

class _ModerationPageState extends State<ModerationPage> {
  List<ModReport>? reports;
  List<ModAppeal>? appeals;
  List<ModPhoto>? photos;
  String? loadError;

  /// `setup` or `verify` while moderation waits for the authenticator code.
  String? gate;

  /// Moderation needs the authenticator: on first use, and every half hour.
  bool _gateFor(Object error) {
    if (error is! ApiException) return false;
    final next = switch (error.code) {
      'second_factor_setup_required' => 'setup',
      'second_factor_required' => 'verify',
      _ => null,
    };
    if (next == null) return false;
    if (mounted) setState(() => gate = next);
    return true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.moderationReports();
      final a = await widget.api.moderationAppeals();
      final p = await widget.api.moderationPhotos();
      if (!mounted) return;
      setState(() {
        reports = r;
        appeals = a;
        photos = p;
        loadError = null;
      });
    } catch (e) {
      if (_gateFor(e)) return;
      if (mounted) setState(() => loadError = describeApiError(e));
    }
  }

  /// Confirms, then runs the decision (asking for a code first if the
  /// sign-in is old), and comes back here with the lists reloaded.
  Future<void> _decide({
    required String title,
    required String body,
    required String confirm,
    required Future<void> Function(String note) action,
  }) async {
    // The dialog owns its note field, so nothing is disposed while it
    // animates out; null means cancelled.
    final text = await showDialog<String>(
      context: context,
      builder: (_) =>
          _DecisionDialog(title: title, body: body, confirm: confirm),
    );
    if (text == null || !mounted) return;
    await _run(() => action(text));
  }

  /// Runs a decision, asking for a code first if the sign-in is old, then
  /// comes back here with the lists reloaded.
  Future<void> _run(Future<void> Function() action) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Route<dynamic>? here;
    navigator.popUntil((route) {
      here = route;
      return true;
    });
    try {
      await withFreshSignIn(
        navigator,
        widget.api,
        reason: 'make a moderation decision',
        action: action,
        then: (nav) async => nav.popUntil((route) => route == here),
      );
    } catch (e) {
      if (_gateFor(e)) return;
      messenger.showSnackBar(SnackBar(content: Text(_moderationError(e))));
    }
    await _load();
  }

  Future<void> _rejectPhoto(ModPhoto p) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Why is it not approved?'),
        children: [
          for (final entry in rejectReasonLabels.entries)
            if (entry.key != 'unreadable')
              SimpleDialogOption(
                key: Key('mod-reason-${entry.key}'),
                onPressed: () => Navigator.pop(dialogContext, entry.key),
                child: Text(
                  '${entry.value[0].toUpperCase()}${entry.value.substring(1)}',
                ),
              ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _run(() => widget.api.decidePhoto(p.id, 'rejected', reason: reason));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Moderation'),
        actions: [
          IconButton(
            key: const Key('mod-reload'),
            tooltip: 'Reload',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          tabs: [
            Tab(text: 'Reports (${reports?.length ?? '…'})'),
            Tab(text: 'Appeals (${appeals?.length ?? '…'})'),
            Tab(text: 'Photos (${photos?.length ?? '…'})'),
          ],
        ),
      ),
      body: gate != null
          ? _SecondFactorGate(
              key: Key('mod-gate-$gate'),
              api: widget.api,
              setup: gate == 'setup',
              onOpened: () {
                setState(() => gate = null);
                _load();
              },
            )
          : loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(loadError!, textAlign: TextAlign.center),
              ),
            )
          : TabBarView(
              children: [
                _list(reports, empty: 'No reports waiting.', item: _reportCard),
                _list(appeals, empty: 'No appeals waiting.', item: _appealCard),
                _list(photos, empty: 'No photos waiting.', item: _photoCard),
              ],
            ),
    ),
  );

  Widget _list<T>(
    List<T>? items, {
    required String empty,
    required Widget Function(T) item,
  }) {
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return Center(child: Text(empty));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [for (final i in items) item(i)],
    );
  }

  Widget _reportCard(ModReport r) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              r.reason?.label ?? 'Report',
              style: theme.textTheme.titleMedium?.copyWith(
                color: VawraColors.coralDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Reported ${formatDay(r.reportedAt)} · ${r.reportsAgainst} '
              '${r.reportsAgainst == 1 ? 'report' : 'reports'} about this person '
              '· the reporter has made ${r.reporterReportCount}',
              style: const TextStyle(color: VawraColors.muted),
            ),
            const SizedBox(height: 12),
            Text(r.name, style: theme.textTheme.titleMedium),
            if (r.status != 'active')
              Text(
                'Account: ${r.status.replaceAll('_', ' ')}',
                style: const TextStyle(color: VawraColors.muted),
              ),
            if (r.bio.isNotEmpty) ...[const SizedBox(height: 4), Text(r.bio)],
            if (r.messageText case final text?) ...[
              const SizedBox(height: 12),
              Container(
                key: Key('mod-evidence-${r.reportId}'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VawraColors.blush,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('Reported message: “$text”'),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  key: Key('mod-dismiss-${r.reportId}'),
                  onPressed: () => _decide(
                    title: 'Dismiss this report?',
                    body: 'Nothing changes for ${r.name}.',
                    confirm: 'Dismiss',
                    action: (note) => widget.api.decideReport(
                      r.reportId,
                      'dismissed',
                      note: note,
                    ),
                  ),
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  key: Key('mod-suspend-${r.reportId}'),
                  onPressed: () => _decide(
                    title: 'Suspend ${r.name}?',
                    body:
                        'They are signed out, hidden from everyone, and their '
                        'chats close. They can appeal, and a different '
                        'moderator will decide.',
                    confirm: 'Suspend',
                    action: (note) => widget.api.decideReport(
                      r.reportId,
                      'suspended',
                      note: note,
                    ),
                  ),
                  child: const Text('Suspend'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoCard(ModPhoto p) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: Image(
            key: Key('mod-photo-${p.id}'),
            image: ServerPhoto(widget.api.absolute(p.url)),
            fit: BoxFit.cover,
            semanticLabel: 'Photo from ${p.name} waiting for review',
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: VawraColors.lavender),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.name, style: Theme.of(context).textTheme.titleMedium),
              Text(
                'Uploaded ${formatDay(p.createdAt)}',
                style: const TextStyle(color: VawraColors.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    key: Key('mod-photo-reject-${p.id}'),
                    onPressed: () => _rejectPhoto(p),
                    child: const Text('Not approved'),
                  ),
                  FilledButton(
                    key: Key('mod-photo-approve-${p.id}'),
                    onPressed: () =>
                        _run(() => widget.api.decidePhoto(p.id, 'approved')),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _appealCard(ModAppeal a) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(a.name, style: theme.textTheme.titleMedium),
            Text(
              [
                if (a.suspendedAt case final at?) 'Suspended ${formatDay(at)}',
                if (a.reason case final reason?) 'for ${_reasonText(reason)}',
              ].join(' '),
              style: const TextStyle(color: VawraColors.muted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VawraColors.lavender,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('“${a.message}”'),
            ),
            const SizedBox(height: 4),
            Text(
              'Sent ${formatDay(a.createdAt)}',
              style: const TextStyle(color: VawraColors.muted),
            ),
            if (a.suspendedByYou)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'You suspended this account, so another moderator must '
                  'decide.',
                  key: Key('mod-not-yours'),
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  key: Key('mod-uphold-${a.appealId}'),
                  onPressed: a.suspendedByYou
                      ? null
                      : () => _decide(
                          title: 'Keep ${a.name} suspended?',
                          body: 'They can explain once more in a new appeal.',
                          confirm: 'Keep suspended',
                          action: (note) => widget.api.decideAppeal(
                            a.appealId,
                            'upheld',
                            note: note,
                          ),
                        ),
                  child: const Text('Keep suspended'),
                ),
                FilledButton(
                  key: Key('mod-overturn-${a.appealId}'),
                  onPressed: a.suspendedByYou
                      ? null
                      : () => _decide(
                          title: 'Lift the suspension?',
                          body: '${a.name} can use Vawra again straight away.',
                          confirm: 'Lift suspension',
                          action: (note) => widget.api.decideAppeal(
                            a.appealId,
                            'overturned',
                            note: note,
                          ),
                        ),
                  child: const Text('Lift suspension'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({
    required this.title,
    required this.body,
    required this.confirm,
  });

  final String title;
  final String body;
  final String confirm;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.body),
        const SizedBox(height: 12),
        TextField(
          key: const Key('mod-note'),
          controller: note,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Note for moderators (optional)',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('mod-confirm'),
        onPressed: () => Navigator.pop(context, note.text.trim()),
        child: Text(widget.confirm),
      ),
    ],
  );
}

/// Moderation is opened with an authenticator app (Google Authenticator,
/// Microsoft Authenticator, 1Password and the like): set up once, then a
/// six-digit code every half hour. The secret is shown once, during setup.
class _SecondFactorGate extends StatefulWidget {
  const _SecondFactorGate({
    super.key,
    required this.api,
    required this.setup,
    required this.onOpened,
  });

  final VawraApi api;
  final bool setup;
  final VoidCallback onOpened;

  @override
  State<_SecondFactorGate> createState() => _SecondFactorGateState();
}

class _SecondFactorGateState extends State<_SecondFactorGate> {
  final code = TextEditingController();
  String? secret;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  /// Setup needs a recent sign-in; an old one is asked to sign in again first.
  Future<void> _start() async {
    final navigator = Navigator.of(context);
    Route<dynamic>? here;
    navigator.popUntil((route) {
      here = route;
      return true;
    });
    setState(() => error = null);
    try {
      await withFreshSignIn(
        navigator,
        widget.api,
        reason: 'set up moderation sign-in',
        action: () async {
          final result = await widget.api.setupModeratorSecondFactor();
          if (mounted) setState(() => secret = result.secret);
        },
        then: (nav) async => nav.popUntil((route) => route == here),
      );
    } catch (e) {
      if (mounted) setState(() => error = describeApiError(e));
    }
  }

  Future<void> _submit() async {
    if (busy || code.text.length != 6) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.setup) {
        await widget.api.confirmModeratorSecondFactor(code.text);
      } else {
        await widget.api.verifyModeratorSecondFactor(code.text);
      }
      widget.onOpened();
    } on ApiException catch (e) {
      if (!mounted) return;
      code.clear();
      setState(
        () => error = switch (e.code) {
          'invalid_code' =>
            'That code didn\'t work. Wait for the next one and try again.',
          'slow_down' => 'Too many tries. Wait 15 minutes, then try again.',
          _ => describeApiError(e),
        },
      );
    } catch (e) {
      if (mounted) setState(() => error = describeApiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String get _grouped => (secret ?? '')
      .replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ')
      .trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsSecret = widget.setup && secret == null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified_user_outlined, size: 40),
          const SizedBox(height: 16),
          Text(
            widget.setup ? 'Protect moderation' : 'Enter your code',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            widget.setup
                ? 'Moderators see reports and photos people trust us with, so moderation needs an authenticator app as well as your email code.'
                : 'Open your authenticator app and enter the 6-digit code for Vawra Moderation. It keeps moderation open for half an hour.',
          ),
          const SizedBox(height: 20),
          if (needsSecret)
            FilledButton(
              key: const Key('mod-2fa-start'),
              onPressed: _start,
              child: const Text('Set up an authenticator app'),
            )
          else ...[
            if (widget.setup) ...[
              const Text(
                'In your authenticator app, add an account by setup key and enter this key. It is shown only now.',
              ),
              const SizedBox(height: 12),
              Material(
                color: VawraColors.blush,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  title: SelectableText(
                    _grouped,
                    key: const Key('mod-2fa-secret'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  trailing: IconButton(
                    key: const Key('mod-2fa-copy'),
                    tooltip: 'Copy the key',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: secret!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Key copied.')),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Then enter the 6-digit code it shows:'),
              const SizedBox(height: 8),
            ],
            TextField(
              key: const Key('mod-2fa-code'),
              controller: code,
              autofocus: !widget.setup,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (text) {
                if (text.length == 6) _submit();
              },
              decoration: const InputDecoration(
                labelText: '6-digit code',
                prefixIcon: Icon(Icons.password_rounded),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('mod-2fa-submit'),
              onPressed: busy ? null : _submit,
              child: Text(widget.setup ? 'Turn on' : 'Open moderation'),
            ),
          ],
          if (error case final text?) ...[
            const SizedBox(height: 12),
            Text(
              text,
              key: const Key('mod-2fa-error'),
              style: const TextStyle(color: VawraColors.coralDark),
            ),
          ],
        ],
      ),
    );
  }
}
