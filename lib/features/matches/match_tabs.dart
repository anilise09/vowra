import 'package:flutter/material.dart';

import '../../domain/chat_message.dart';
import '../../domain/match_connection.dart';
import '../../domain/safety_report.dart';
import '../shared/empty_tab.dart';

class MatchTab extends StatelessWidget {
  const MatchTab({
    super.key,
    required this.connection,
    required this.onOpenChat,
  });

  final MatchConnection connection;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    if (!connection.isActive) {
      return const EmptyTab(
        icon: Icons.favorite_outline,
        title: 'No active matches',
        message: 'Blocked and unmatched people cannot contact you.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Your matches',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('Synthetic prototype match — not a real person.'),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(connection.peerName),
            subtitle: Text(
              connection.peerCallReady
                  ? 'Matched · open to a call'
                  : 'Matched · text first',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenChat,
          ),
        ),
      ],
    );
  }
}

class ChatTab extends StatelessWidget {
  const ChatTab({
    super.key,
    required this.connection,
    required this.messages,
    required this.report,
    required this.onSend,
    required this.onCallReadinessChanged,
    required this.onReport,
    required this.onUnmatch,
    required this.onBlock,
  });

  final MatchConnection connection;
  final List<ChatMessage> messages;
  final SafetyReport? report;
  final ValueChanged<String> onSend;
  final ValueChanged<bool> onCallReadinessChanged;
  final ValueChanged<SafetyReport> onReport;
  final VoidCallback onUnmatch;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    if (!connection.isActive) {
      final blocked = connection.status == ConnectionStatus.blocked;
      return EmptyTab(
        icon: blocked ? Icons.block : Icons.heart_broken_outlined,
        title: blocked ? 'Blocked' : 'Conversation closed',
        message: blocked
            ? '${connection.peerName} can no longer message or call you.'
            : 'You unmatched. Messaging and calling are disabled.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connection.peerName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text('Synthetic prototype conversation'),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Conversation safety actions',
              onSelected: (value) => _confirmAction(context, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Report privately')),
                PopupMenuItem(value: 'unmatch', child: Text('Unmatch')),
                PopupMenuItem(value: 'block', child: Text('Block')),
              ],
            ),
          ],
        ),
        if (report != null)
          Card(
            color: const Color(0xFFFFF1D6),
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text('Report recorded: ${report!.reason.label}'),
              subtitle: const Text(
                'Saved in this device session only. No review team is connected. The other person is not notified.',
              ),
            ),
          ),
        const SizedBox(height: 18),
        ...messages.map(
          (message) => Align(
            alignment: message.author == MessageAuthor.currentUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Card(
              color: message.author == MessageAuthor.currentUser
                  ? const Color(0xFFFFD9E3)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(message.text),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Call readiness',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'No surprise calls. Both people opt in, and every call still requires acceptance.',
                ),
                SwitchListTile(
                  key: const Key('call-ready-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I am open to a call'),
                  value: connection.currentUserCallReady,
                  onChanged: onCallReadinessChanged,
                ),
                Text(
                  connection.peerCallReady
                      ? '${connection.peerName} is also open to a call.'
                      : '${connection.peerName} has not opted in.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('request-video-call'),
                  onPressed: connection.canRequestCall
                      ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Prototype only: no camera, microphone, or network connection was opened.',
                            ),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Request video call'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('message-composer'),
          enabled: connection.canMessage,
          maxLength: MessagePolicy.maxCharacters,
          textInputAction: TextInputAction.send,
          onSubmitted: onSend,
          decoration: const InputDecoration(
            labelText: 'Message',
            helperText: 'Press send on the keyboard. Anti-spam limits apply.',
            suffixIcon: Icon(Icons.send_outlined),
          ),
        ),
      ],
    );
  }

  Future<SafetyReport?> _chooseReport(BuildContext context) {
    ReportReason? reason;
    final latestPeerMessage = messages
        .where((message) => message.author == MessageAuthor.peer)
        .lastOrNull;
    var includeMessageReference = false;
    return showDialog<SafetyReport>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Report ${connection.peerName} privately'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose the concern. Reporting does not block this person; you can block separately.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ReportReason>(
                  key: const Key('report-reason'),
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: ReportReason.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => reason = value),
                ),
                if (latestPeerMessage != null) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    key: const Key('report-message-reference'),
                    contentPadding: EdgeInsets.zero,
                    value: includeMessageReference,
                    onChanged: (value) => setDialogState(
                      () => includeMessageReference = value ?? false,
                    ),
                    title: const Text(
                      'Include latest received message reference',
                    ),
                    subtitle: const Text(
                      'Optional. No conversation text is copied into this report.',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Prototype only: this report stays in memory and is not sent to a review team.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('submit-report'),
              onPressed: reason == null
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      SafetyReport(
                        matchId: connection.matchId,
                        reason: reason!,
                        createdAt: DateTime.now().toUtc(),
                        messageId: includeMessageReference
                            ? latestPeerMessage?.id
                            : null,
                      ),
                    ),
              child: const Text('Record report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAction(BuildContext context, String action) async {
    if (action == 'report') {
      final report = await _chooseReport(context);
      if (report != null) onReport(report);
      return;
    }
    final verb = action == 'block' ? 'Block' : 'Unmatch';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$verb ${connection.peerName}?'),
        content: Text(
          action == 'block'
              ? 'They will immediately lose access to this conversation and cannot call you.'
              : 'This closes the conversation and disables messages and calls.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Key('confirm-$action'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(verb),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (action == 'block') {
      onBlock();
    } else {
      onUnmatch();
    }
  }
}
