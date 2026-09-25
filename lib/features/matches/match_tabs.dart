import 'package:flutter/material.dart';

import '../../domain/chat_message.dart';
import '../../domain/match_connection.dart';
import '../../domain/safety_report.dart';
import '../../theme/vawra_theme.dart';
import '../shared/empty_tab.dart';

class MatchTab extends StatelessWidget {
  const MatchTab({
    super.key,
    required this.connection,
    required this.onOpenChat,
  });

  final MatchConnection? connection;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final activeConnection = connection;
    if (activeConnection == null) {
      return const SafeArea(
        child: EmptyTab(
          icon: Icons.favorite_outline,
          title: 'No active matches yet',
          message: 'Mutual likes can connect and message in the free core.',
        ),
      );
    }
    if (!activeConnection.isActive) {
      return const SafeArea(
        child: EmptyTab(
          icon: Icons.favorite_outline,
          title: 'No active matches',
          message: 'Blocked and unmatched people cannot contact you.',
        ),
      );
    }
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Text(
            'Connections',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 5),
          const Text(
            'Start with something specific. Curiosity beats a generic hello.',
          ),
          const SizedBox(height: 22),
          Text('New match', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onOpenChat,
            child: Ink(
              height: 430,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                image: DecorationImage(
                  image: AssetImage(activeConnection.peerProfileAssetPath),
                  fit: BoxFit.cover,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x245A274F),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD9140C13)],
                    stops: [0.45, 1],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Align(
                        alignment: Alignment.topRight,
                        child: _MatchPill(
                          icon: Icons.science_outlined,
                          label: 'Prototype',
                        ),
                      ),
                      const Spacer(),
                      const _MatchPill(
                        icon: Icons.favorite_rounded,
                        label: 'It\'s mutual',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        activeConnection.peerName,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.white, fontSize: 34),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        activeConnection.peerCallReady
                            ? 'Ready to message · open to a call'
                            : 'Ready to message · text first',
                        style: const TextStyle(
                          color: Color(0xFFEFE7ED),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: onOpenChat,
                        icon: const Icon(Icons.chat_bubble_rounded),
                        label: const Text('Start a conversation'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Synthetic prototype match · not a real person.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MatchPill extends StatelessWidget {
  const _MatchPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 17),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
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

  final MatchConnection? connection;
  final List<ChatMessage> messages;
  final SafetyReport? report;
  final ValueChanged<String> onSend;
  final ValueChanged<bool> onCallReadinessChanged;
  final ValueChanged<SafetyReport> onReport;
  final VoidCallback onUnmatch;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final activeConnection = connection;
    if (activeConnection == null) {
      return const SafeArea(
        child: EmptyTab(
          icon: Icons.chat_bubble_outline,
          title: 'No chat yet',
          message: 'Like someone who likes you back to open free messaging.',
        ),
      );
    }
    if (!activeConnection.isActive) {
      final blocked = activeConnection.status == ConnectionStatus.blocked;
      return SafeArea(
        child: EmptyTab(
          icon: blocked ? Icons.block : Icons.heart_broken_outlined,
          title: blocked ? 'Blocked' : 'Conversation closed',
          message: blocked
              ? '${activeConnection.peerName} can no longer message or call you.'
              : 'You unmatched. Messaging and calling are disabled.',
        ),
      );
    }
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: AssetImage(
                  activeConnection.peerProfileAssetPath,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeConnection.peerName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Row(
                      children: [
                        Icon(Icons.circle, color: Color(0xFF39B56A), size: 9),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Matched · prototype chat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton(
                key: const Key('request-video-call'),
                onPressed: activeConnection.canRequestCall
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Prototype only: no camera, microphone, or network connection was opened.',
                          ),
                        ),
                      )
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  maximumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.videocam_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'Conversation safety actions',
                onSelected: (value) => _confirmAction(context, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Text('Report privately'),
                  ),
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
                subtitle: Text(
                  '${report!.moderationState.label}. Saved in this device session only. No review team is connected. The other person is not notified.',
                ),
              ),
            ),
          const SizedBox(height: 16),
          Material(
            color: VawraColors.lavender,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    key: const Key('call-ready-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Open to a call'),
                    subtitle: const Text(
                      'Both people opt in before either can request one.',
                    ),
                    value: activeConnection.currentUserCallReady,
                    onChanged: onCallReadinessChanged,
                  ),
                  Text(
                    activeConnection.peerCallReady
                        ? '${activeConnection.peerName} is also open to a call.'
                        : '${activeConnection.peerName} has not opted in.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...messages.map(
            (message) => Align(
              alignment: message.author == MessageAuthor.currentUser
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 290),
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: message.author == MessageAuthor.currentUser
                      ? VawraColors.plum
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(
                      message.author == MessageAuthor.currentUser ? 20 : 5,
                    ),
                    bottomRight: Radius.circular(
                      message.author == MessageAuthor.currentUser ? 5 : 20,
                    ),
                  ),
                  border: message.author == MessageAuthor.currentUser
                      ? null
                      : Border.all(color: const Color(0xFFEEE4EA)),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: message.author == MessageAuthor.currentUser
                        ? Colors.white
                        : VawraColors.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('message-composer'),
            enabled: activeConnection.canMessage,
            maxLength: MessagePolicy.maxCharacters,
            textInputAction: TextInputAction.send,
            onSubmitted: onSend,
            decoration: const InputDecoration(
              hintText: 'Write something thoughtful…',
              helperText: 'Press send on the keyboard. Anti-spam limits apply.',
              prefixIcon: Icon(Icons.add_circle_outline_rounded),
              suffixIcon: Icon(Icons.send_rounded, color: VawraColors.coral),
            ),
          ),
        ],
      ),
    );
  }

  Future<SafetyReport?> _chooseReport(BuildContext context) {
    final activeConnection = connection;
    if (activeConnection == null) return Future.value();
    ReportReason? reason;
    final latestPeerMessage = messages
        .where((message) => message.author == MessageAuthor.peer)
        .lastOrNull;
    var includeMessageReference = false;
    return showDialog<SafetyReport>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Report ${activeConnection.peerName} privately'),
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
                  'Prototype only: this starts as local pending review and is not sent to a review team.',
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
                        matchId: activeConnection.matchId,
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
    final activeConnection = connection;
    if (activeConnection == null) return;
    if (action == 'report') {
      final report = await _chooseReport(context);
      if (report != null) onReport(report);
      return;
    }
    final verb = action == 'block' ? 'Block' : 'Unmatch';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$verb ${activeConnection.peerName}?'),
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
