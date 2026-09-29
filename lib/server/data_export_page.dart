import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/gender.dart';
import '../domain/user_profile.dart';
import '../theme/vawra_theme.dart';
import 'server_flow.dart' show formatDay;

/// A readable copy of what the Vawra server holds about the person, from
/// `GET /v1/me/export`, with the full file one tap away. Nothing is saved to
/// the phone unless the person pastes it somewhere themselves.
class DataExportPage extends StatelessWidget {
  const DataExportPage({super.key, required this.data});

  final Map<String, dynamic> data;

  static String? _day(Object? iso) =>
      iso is String ? formatDay(DateTime.parse(iso).toLocal()) : null;

  static const _ageStates = {
    'assurance_required': 'Not checked yet',
    'pending_review': 'Being checked',
    'adult_verified': 'Checked: 18+',
    'rejected': 'Not passed',
  };

  static const _lifecycles = {
    'active': 'Active',
    'paused': 'Paused',
    'deletion_scheduled': 'Deletion scheduled',
  };

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Copied. Paste it somewhere only you can see.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = (data['account'] as Map?) ?? const {};
    final profile = data['profile'] as Map?;
    final swipes = (data['swipes'] as List?) ?? const [];
    final matches = (data['matches'] as List?) ?? const [];
    int swiped(String kind) => swipes.where((s) => s['kind'] == kind).length;
    final sentCount = matches.fold<int>(
      0,
      (n, m) => n + ((m['messages_you_sent'] as List?)?.length ?? 0),
    );
    final showMe = ((profile?['show_me'] as List?) ?? const [])
        .map((k) => Gender.fromKey(k)?.plural)
        .whereType<String>()
        .toList();
    final intent = RelationshipIntent.values
        .where((i) => i.backendKey == profile?['relationship_intent'])
        .firstOrNull;
    final asOf = _day(data['generated_at']);
    return Scaffold(
      appBar: AppBar(title: const Text('Your data')),
      body: ListView(
        key: const Key('export-scroll'),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          Text(
            'Everything the Vawra server holds about you'
            '${asOf == null ? '' : ', as of $asOf'}.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('export-copy'),
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy the full file'),
          ),
          _Section('Account', [
            ('Email', account['email'] as String?),
            ('Member since', _day(account['created_at'])),
            ('Age check', _ageStates[account['age_state']]),
            ('Status', _lifecycles[account['lifecycle']]),
            if (_day(account['deletion_effective_at']) case final d?)
              ('Deleted on', d),
            (
              'Distance',
              data['approximate_area'] == null
                  ? 'Off'
                  : 'On, from an area about 2 km across',
            ),
          ]),
          if (profile != null)
            _Section('Profile', [
              ('Name', profile['display_name'] as String?),
              ('I am', Gender.fromKey(profile['gender'])?.label),
              (
                'Gender on profile',
                profile['show_gender'] == true ? 'Shown' : 'Hidden',
              ),
              ('Show me', showMe.isEmpty ? 'Everyone' : showMe.join(', ')),
              ('Looking for', intent?.label),
              (
                'Interests',
                ((profile['interests'] as List?) ?? const []).join(', '),
              ),
              ('About', profile['bio'] as String?),
            ]),
          _Section('Activity', [
            ('Likes', '${swiped('like')}'),
            ('Super Likes', '${swiped('super_like')}'),
            ('Passes', '${swiped('pass')}'),
            ('Matches', '${matches.length}'),
            ('Messages you sent', '$sentCount'),
            ('Blocks', '${(data['blocks'] as List?)?.length ?? 0}'),
            (
              'Reports you made',
              '${(data['reports_you_made'] as List?)?.length ?? 0}',
            ),
            ('Sign-ins', '${(data['sign_ins'] as List?)?.length ?? 0}'),
          ]),
          if (matches.isNotEmpty)
            _Section('Matches', [
              for (final m in matches)
                (
                  (m['with'] as String?) ?? 'A deleted account',
                  [
                    if (_day(m['matched_at']) case final d?) 'matched $d',
                    '${(m['messages_you_sent'] as List?)?.length ?? 0} sent',
                    if (m['status'] != 'active') '${m['status']}',
                  ].join(' · '),
                ),
            ]),
          _Section('Not in this file', bullets: true, [
            for (final line in (data['not_included'] as List?) ?? const [])
              ('$line', null),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.rows, {this.bullets = false});

  final String title;
  final List<(String, String?)> rows;

  /// Plain lines instead of label and value.
  final bool bullets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (final (label, value) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: bullets
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2, right: 10),
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 16,
                                    color: VawraColors.muted,
                                  ),
                                ),
                                Expanded(child: Text(label)),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      color: VawraColors.muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    value == null || value.isEmpty
                                        ? '—'
                                        : value,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
