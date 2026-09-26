import 'package:flutter/material.dart';

import '../../domain/chat_message.dart';
import '../../domain/demo_profile.dart';
import '../../domain/discovery_interaction.dart';
import '../../domain/local_like_event.dart';
import '../../domain/match_connection.dart';
import '../../domain/safety_report.dart';
import '../../theme/vawra_theme.dart';
import '../discovery/discovery_deck.dart' show LocalActivityCard;
import '../shared/empty_tab.dart';

class MatchTab extends StatelessWidget {
  const MatchTab({
    super.key,
    required this.connection,
    required this.onOpenChat,
    this.likesYou = const [],
    this.onRespond,
    this.activity = const [],
  });

  final MatchConnection? connection;
  final VoidCallback onOpenChat;

  /// People who liked the current person. Seeing them is free in Vawra.
  final List<DemoProfile> likesYou;
  final void Function(DemoProfile profile, DiscoverySwipeAction action)?
  onRespond;

  /// On-device previews of like events; never sent anywhere.
  final List<LocalLikeEvent> activity;

  @override
  Widget build(BuildContext context) {
    final activeConnection = connection;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          Text('Matches', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text(
            'Start with something specific. Curiosity beats a generic hello.',
          ),
          if (likesYou.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Likes you',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                const _FreeBadge(),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 262,
              child: ListView.separated(
                key: const Key('likes-you-row'),
                scrollDirection: Axis.horizontal,
                itemCount: likesYou.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _LikesYouTile(
                  profile: likesYou[index],
                  onRespond: onRespond,
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (activeConnection == null)
            _MatchesEmpty(
              title: 'No matches yet',
              message: likesYou.isEmpty
                  ? 'When you and someone both like each other, they appear here.'
                  : 'Like someone back to match. Messaging is always free.',
            )
          else if (!activeConnection.isActive)
            const _MatchesEmpty(
              title: 'No active matches',
              message: 'Blocked and unmatched people cannot contact you.',
            )
          else ...[
            Text('New match', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _NewMatchCard(connection: activeConnection, onOpenChat: onOpenChat),
            const SizedBox(height: 16),
            const Text(
              'Synthetic prototype match · not a real person.',
              textAlign: TextAlign.center,
            ),
          ],
          if (activity.isNotEmpty) ...[
            const SizedBox(height: 22),
            LocalActivityCard(events: activity.take(3).toList()),
          ],
        ],
      ),
    );
  }
}

class _NewMatchCard extends StatelessWidget {
  const _NewMatchCard({required this.connection, required this.onOpenChat});

  final MatchConnection connection;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final activeConnection = connection;
    return InkWell(
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
    );
  }
}

class _FreeBadge extends StatelessWidget {
  const _FreeBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: VawraColors.blush,
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Text(
      'Free',
      style: TextStyle(
        color: VawraColors.coralDark,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}

class _LikesYouTile extends StatelessWidget {
  const _LikesYouTile({required this.profile, required this.onRespond});

  final DemoProfile profile;
  final void Function(DemoProfile profile, DiscoverySwipeAction action)?
  onRespond;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  profile.assetPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  semanticLabel: 'Synthetic portrait of ${profile.name}',
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.5, 1],
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Text(
                    '${profile.name}, ${profile.age}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton.outlined(
              key: Key('likes-you-pass-${profile.name}'),
              tooltip: 'Pass on ${profile.name}',
              onPressed: onRespond == null
                  ? null
                  : () => onRespond!(profile, DiscoverySwipeAction.reject),
              icon: const Icon(Icons.close_rounded),
            ),
            IconButton.filled(
              key: Key('likes-you-like-${profile.name}'),
              tooltip: 'Like ${profile.name} back',
              style: IconButton.styleFrom(backgroundColor: VawraColors.coral),
              onPressed: onRespond == null
                  ? null
                  : () => onRespond!(profile, DiscoverySwipeAction.like),
              icon: const Icon(Icons.favorite_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MatchesEmpty extends StatelessWidget {
  const _MatchesEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFF0E5EB)),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.favorite_outline_rounded,
          size: 40,
          color: VawraColors.coral,
        ),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
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
    required this.onOpenSafety,
  });

  final MatchConnection? connection;
  final List<ChatMessage> messages;
  final SafetyReport? report;
  final ValueChanged<String> onSend;
  final ValueChanged<bool> onCallReadinessChanged;
  final ValueChanged<SafetyReport> onReport;
  final VoidCallback onUnmatch;
  final VoidCallback onBlock;
  final VoidCallback onOpenSafety;

  Widget _withHeader(Widget body) => SafeArea(
    child: Column(
      children: [
        _ChatsHeader(onOpenSafety: onOpenSafety),
        Expanded(child: body),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final activeConnection = connection;
    if (activeConnection == null) {
      return _withHeader(
        const EmptyTab(
          icon: Icons.chat_bubble_outline,
          title: 'No chats yet',
          message: 'When you and someone both like each other, you can message here. Messaging is always free.',
        ),
      );
    }
    if (!activeConnection.isActive) {
      final blocked = activeConnection.status == ConnectionStatus.blocked;
      return _withHeader(
        EmptyTab(
          icon: blocked ? Icons.block : Icons.heart_broken_outlined,
          title: blocked ? 'Blocked' : 'Conversation closed',
          message: blocked
              ? '${activeConnection.peerName} can no longer message or call you.'
              : 'You unmatched. Messaging and calling are disabled.',
        ),
      );
    }
    return _withHeader(
      ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
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
            color: VawraColors.blush,
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
                      ? const Color(0xFFDCDCE9)
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
                      : Border.all(color: VawraColors.coral, width: 1.2),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(color: const Color(0xFF182465)),
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

class _ChatsHeader extends StatelessWidget {
  const _ChatsHeader({required this.onOpenSafety});

  final VoidCallback onOpenSafety;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 10, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Chats',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        IconButton.filledTonal(
          key: const Key('chats-safety'),
          tooltip: 'Safety tools',
          onPressed: onOpenSafety,
          icon: const Icon(Icons.shield_outlined),
        ),
      ],
    ),
  );
}
