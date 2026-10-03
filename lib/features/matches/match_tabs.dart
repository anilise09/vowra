import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/chat_message.dart';
import '../../domain/demo_profile.dart';
import '../../domain/discovery_interaction.dart';
import '../../domain/local_like_event.dart';
import '../../domain/match_connection.dart';
import '../../domain/safety_report.dart';
import '../../theme/vawra_theme.dart';
import '../shared/profile_image.dart';
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
            if (!isServerPerson(activeConnection.peerProfileAssetPath))
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
            image: profileImage(activeConnection.peerProfileAssetPath),
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
                Image(
                  image: profileImage(profile.assetPath),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  semanticLabel: portraitLabel(profile.name, profile.assetPath),
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
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class ChatTab extends StatefulWidget {
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
    this.startInThread = false,
    this.openThreadRequest = 0,
    this.onBack,
    this.peerTyping = false,
    this.onComposing,
    this.openers = const [],
    this.live = false,
    this.photosAllowedByMe,
    this.photosAllowedByThem = false,
    this.onPhotoConsentChanged,
    this.onSendPhoto,
    this.photoProvider,
    this.onStartCall,
    this.showCalls = true,
  });

  /// Starts a real call (server only); `true` for video. Without it the call
  /// buttons explain that the prototype opens nothing.
  final void Function(bool video)? onStartCall;

  /// False hides calls entirely, e.g. while the server cannot relay them.
  final bool showCalls;

  /// Photos in chat (server only): whether you accept them from this person,
  /// and whether they accept yours. Null hides the switch.
  final bool? photosAllowedByMe;
  final bool photosAllowedByThem;
  final ValueChanged<bool>? onPhotoConsentChanged;
  final VoidCallback? onSendPhoto;

  /// Loads a photo message's link.
  final ImageProvider Function(String url)? photoProvider;

  /// Connected to the Vawra server: reports reach real moderators.
  final bool live;

  final MatchConnection? connection;
  final List<ChatMessage> messages;
  final SafetyReport? report;
  /// Sends a message. Answering false means it was not sent: the text goes
  /// back into the box so nothing typed is lost.
  final FutureOr<bool?> Function(String text) onSend;
  final ValueChanged<bool> onCallReadinessChanged;
  final ValueChanged<SafetyReport> onReport;
  final VoidCallback onUnmatch;
  final VoidCallback onBlock;
  final VoidCallback onOpenSafety;

  /// Opens straight into the conversation (used by focused widget tests).
  final bool startInThread;

  /// Increase to jump into the conversation, e.g. from "Send a message".
  final int openThreadRequest;

  /// Replaces the thread's back action, e.g. when the thread is its own page.
  final VoidCallback? onBack;

  /// Shows "Name is typing…" under the last message.
  final bool peerTyping;

  /// Called as the person types (the thread decides whether to signal it).
  final VoidCallback? onComposing;

  /// Suggested first lines, shown while the conversation is empty.
  final List<String> openers;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  late bool inThread = widget.startInThread;
  final composer = TextEditingController();
  final reactions = <String>{};
  var showPicker = false;

  /// Photo messages the person chose to see; the rest stay blurred.
  final revealed = <String>{};

  static const _emoji = [
    '😀',
    '😂',
    '😊',
    '😍',
    '🥰',
    '😘',
    '😉',
    '😎',
    '🤔',
    '😅',
    '🙈',
    '🥲',
    '😴',
    '🤗',
    '👋',
    '👍',
    '🙏',
    '👏',
    '🔥',
    '✨',
    '❤️',
    '💛',
    '💜',
    '💯',
    '☕',
    '🍕',
    '🌮',
    '🍜',
    '🍷',
    '🎶',
    '📚',
    '🏔️',
    '🌸',
    '🌞',
    '🌙',
    '🐶',
    '🐱',
    '🎉',
    '✈️',
    '🥾',
  ];

  static const _quickReplies = [
    'Hi! How is your week going?',
    'What are you reading at the moment?',
    'Best food spot in your area?',
    'Coffee or tea person?',
    'What does your ideal weekend look like?',
  ];

  /// Messages that are only a few emoji show large, without a bubble.
  static bool _emojiOnly(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.characters.length > 3) return false;
    return !RegExp(r'[A-Za-z0-9]').hasMatch(trimmed) &&
        trimmed.runes.every((r) => r >= 0x2000 || r == 0x20);
  }

  void _insert(String value) {
    composer.text = '${composer.text}$value';
    composer.selection = TextSelection.collapsed(offset: composer.text.length);
    setState(() {});
  }

  /// Words that trigger a gentle "are you sure?" before sending. The message
  /// is never blocked or reported; the sender decides.
  static final _hurtful = RegExp(
    r'\b(stupid|idiot|ugly|loser|shut up|hate you|worthless|pathetic|fat)\b',
    caseSensitive: false,
  );

  @override
  void didUpdateWidget(ChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openThreadRequest != oldWidget.openThreadRequest) {
      inThread = true;
    }
    final grew = widget.messages.length > oldWidget.messages.length;
    final startedTyping = widget.peerTyping && !oldWidget.peerTyping;
    if (oldWidget.messages.isEmpty && grew) {
      _toLatest(animate: false); // the conversation just loaded
    } else if (grew || startedTyping) {
      final mine =
          grew && widget.messages.last.author == MessageAuthor.currentUser;
      // Follow new messages only when already reading the latest ones, so
      // someone scrolled up to older messages is not pulled away.
      if (mine || _nearLatest) _toLatest();
    }
  }

  final threadScroll = ScrollController();

  bool get _nearLatest =>
      !threadScroll.hasClients || threadScroll.position.pixels < 240;

  void _toLatest({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !threadScroll.hasClients) return;
      if (animate) {
        threadScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        threadScroll.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    composer.dispose();
    threadScroll.dispose();
    super.dispose();
  }

  Widget _withHeader(Widget body) => SafeArea(
    child: Column(
      children: [
        _ChatsHeader(onOpenSafety: widget.onOpenSafety),
        Expanded(child: body),
      ],
    ),
  );

  Future<void> _send() async {
    final text = composer.text.trim();
    if (text.isEmpty) return;
    if (_hurtful.hasMatch(text)) {
      final send = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('are-you-sure'),
          title: const Text('Are you sure?'),
          content: const Text(
            'This might come across as hurtful. Kind first messages get far '
            'more replies.',
          ),
          actions: [
            TextButton(
              key: const Key('are-you-sure-edit'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Edit message'),
            ),
            TextButton(
              key: const Key('are-you-sure-send'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send anyway'),
            ),
          ],
        ),
      );
      if (send != true) return;
    }
    composer.clear();
    setState(() {});
    final sent = await widget.onSend(text);
    // A failed send puts the text back, unless something new was typed since.
    if (sent == false && mounted && composer.text.isEmpty) {
      composer.text = text;
      composer.selection = TextSelection.collapsed(offset: text.length);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeConnection = widget.connection;
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
    return inThread
        ? _thread(context, activeConnection)
        : _withHeader(_list(context, activeConnection));
  }

  Widget _list(BuildContext context, MatchConnection match) {
    final last = widget.messages.lastOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        Text('New matches', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: VawraColors.coral,
                  child: CircleAvatar(
                    radius: 31,
                    backgroundImage: profileImage(match.peerProfileAssetPath),
                  ),
                ),
                const SizedBox(height: 6),
                Text(match.peerName),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('Messages', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        ListTile(
          key: Key('conversation-${match.peerName}'),
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 28,
            backgroundImage: profileImage(match.peerProfileAssetPath),
          ),
          title: Text(
            match.peerName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            last == null
                ? 'Say hello'
                : '${last.author == MessageAuthor.currentUser ? 'You: ' : ''}${last.text}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: last == null ? null : Text(_time(last.sentAt)),
          onTap: () => setState(() => inThread = true),
        ),
        const Divider(),
        const Text(
          'Synthetic prototype chat · not a real person.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _thread(BuildContext context, MatchConnection match) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            children: [
              IconButton(
                key: const Key('thread-back'),
                tooltip: 'Back to chats',
                onPressed:
                    widget.onBack ?? () => setState(() => inThread = false),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              CircleAvatar(
                radius: 21,
                backgroundImage: profileImage(match.peerProfileAssetPath),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.peerName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      isServerPerson(match.peerProfileAssetPath)
                          ? 'Matched on Vawra'
                          : 'Matched · prototype chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (widget.showCalls) ...[
                IconButton(
                  key: const Key('request-voice-call'),
                  tooltip: match.canRequestCall
                      ? 'Voice call'
                      : 'Voice call: you both turn on "Open to a call" first',
                  onPressed: match.canRequestCall
                      ? () => _startCall(context, video: false)
                      : null,
                  icon: const Icon(Icons.call_outlined),
                ),
                IconButton.filled(
                  key: const Key('request-video-call'),
                  tooltip: match.canRequestCall
                      ? 'Video call'
                      : 'Video call: you both turn on "Open to a call" first',
                  onPressed: match.canRequestCall
                      ? () => _startCall(context, video: true)
                      : null,
                  icon: const Icon(Icons.videocam_outlined),
                ),
              ],
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
        ),
        const Divider(height: 1),
        Expanded(
          // Short chats stay at the top, as designed; long ones fill the
          // space and scroll.
          child: Align(
            alignment: Alignment.topCenter,
            child: ListView(
              key: const Key('thread-scroll'),
              controller: threadScroll,
              // Reversed, like every chat: offset 0 is always the newest
              // message, so the chat opens there and can follow new ones
              // without guessing the height of lazily built messages.
              reverse: true,
              // Sized to its messages (a page is at most 50) so a short chat
              // is not pushed to the bottom.
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                if (widget.report != null)
                  Card(
                    color: const Color(0xFFFFF1D6),
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(
                        'Report recorded: ${widget.report!.reason.label}',
                      ),
                      subtitle: Text(
                        widget.live
                            ? 'Sent privately to Vawra\'s moderators. They see only the message you included.'
                            : '${widget.report!.moderationState.label}. Saved in this device session only. No review team is connected.',
                      ),
                    ),
                  ),
                if (widget.showCalls)
                  Material(
                    color: VawraColors.blush,
                    borderRadius: BorderRadius.circular(18),
                    child: SwitchListTile(
                      key: const Key('call-ready-switch'),
                      title: const Text('Open to a call'),
                      subtitle: Text(
                        match.peerCallReady
                            ? '${match.peerName} is also open to a call. Both must opt in.'
                            : 'Both people opt in first. ${match.peerName} has not yet.',
                      ),
                      value: match.currentUserCallReady,
                      onChanged: widget.onCallReadinessChanged,
                    ),
                  ),
                if (widget.photosAllowedByMe case final allowed?) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: VawraColors.lavender,
                    borderRadius: BorderRadius.circular(18),
                    child: SwitchListTile(
                      key: const Key('photo-consent-switch'),
                      title: Text('Allow photos from ${match.peerName}'),
                      subtitle: const Text(
                        'Each photo is checked first and arrives blurred until '
                        'you tap it.',
                      ),
                      value: allowed,
                      onChanged: widget.onPhotoConsentChanged,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (widget.messages.isNotEmpty)
                  Center(
                    child: Text(
                      _day(widget.messages.first.sentAt),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: VawraColors.muted,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                for (final message in widget.messages) _bubble(message),
                if (widget.messages.isEmpty &&
                    widget.openers.isNotEmpty &&
                    match.canMessage)
                  Padding(
                    key: const Key('openers'),
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start with something you share',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: VawraColors.plum,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final (i, line) in widget.openers.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                              key: Key('opener-$i'),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () {
                                composer.text = line;
                                composer.selection = TextSelection.collapsed(
                                  offset: line.length,
                                );
                                setState(() {});
                              },
                              child: Text(line),
                            ),
                          ),
                        const Text(
                          'Tap one to put it in the message box, then make it '
                          'your own.',
                          style: TextStyle(
                            fontSize: 12,
                            color: VawraColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.peerTyping)
                  Padding(
                    key: const Key('peer-typing'),
                    padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
                    child: Text(
                      '${match.peerName} is typing…',
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: VawraColors.muted,
                      ),
                    ),
                  ),
              ].reversed.toList(),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF0E5EB))),
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('emoji-toggle'),
                tooltip: showPicker
                    ? 'Show keyboard'
                    : 'Emoji and quick replies',
                onPressed: match.canMessage
                    ? () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => showPicker = !showPicker);
                      }
                    : null,
                icon: Icon(
                  showPicker
                      ? Icons.keyboard_alt_outlined
                      : Icons.emoji_emotions_outlined,
                ),
              ),
              if (widget.onSendPhoto case final sendPhoto?)
                IconButton(
                  key: const Key('send-photo'),
                  tooltip: 'Send a photo',
                  onPressed: !match.canMessage
                      ? null
                      : widget.photosAllowedByThem
                      ? sendPhoto
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${match.peerName} hasn\'t turned on photos '
                              'from you yet.',
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.photo_outlined),
                ),
              Expanded(
                child: TextField(
                  key: const Key('message-composer'),
                  controller: composer,
                  enabled: match.canMessage,
                  maxLength: MessagePolicy.maxCharacters,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onChanged: (text) {
                    setState(() {});
                    if (text.trim().isNotEmpty) widget.onComposing?.call();
                  },
                  onTap: () => setState(() => showPicker = false),
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Write something thoughtful…',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('send-message'),
                tooltip: 'Send',
                style: IconButton.styleFrom(backgroundColor: VawraColors.coral),
                onPressed: composer.text.trim().isEmpty ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
        if (showPicker) _picker(),
      ],
    ),
  );

  Widget _picker() => DefaultTabController(
    length: 2,
    child: Container(
      key: const Key('emoji-panel'),
      height: 250,
      color: Colors.white,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Emoji'),
              Tab(text: 'Quick replies'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                GridView.count(
                  crossAxisCount: 8,
                  padding: const EdgeInsets.all(8),
                  children: [
                    for (final emoji in _emoji)
                      InkResponse(
                        key: Key('emoji-$emoji'),
                        onTap: () => _insert(emoji),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final reply in _quickReplies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ActionChip(
                          label: Text(reply),
                          onPressed: () {
                            composer.text = reply;
                            composer.selection = TextSelection.collapsed(
                              offset: reply.length,
                            );
                            setState(() => showPicker = false);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bubble(ChatMessage message) {
    final mine = message.author == MessageAuthor.currentUser;
    final reacted = reactions.contains(message.id);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        key: Key('bubble-${message.id}'),
        onDoubleTap: () => setState(
          () => reacted
              ? reactions.remove(message.id)
              : reactions.add(message.id),
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (message.photoUrl case final url?)
                  _photoBubble(message, url, mine)
                else if (_emojiOnly(message.text))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      message.text,
                      key: const Key('big-emoji'),
                      style: const TextStyle(fontSize: 44),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxWidth: 290),
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: mine ? const Color(0xFFDCDCE9) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(mine ? 20 : 5),
                        bottomRight: Radius.circular(mine ? 5 : 20),
                      ),
                      border: mine
                          ? null
                          : Border.all(color: VawraColors.coral, width: 1.2),
                    ),
                    child: Text(
                      message.text,
                      style: const TextStyle(color: Color(0xFF182465)),
                    ),
                  ),
                if (reacted)
                  Positioned(
                    bottom: -8,
                    right: mine ? null : -6,
                    left: mine ? -6 : null,
                    child: const CircleAvatar(
                      key: Key('reaction-heart'),
                      radius: 12,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 15,
                        color: VawraColors.coral,
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
              child: Text(
                mine
                    ? '${_time(message.sentAt)} · '
                          '${message.seen == true ? 'Seen' : 'Sent'}'
                    : _time(message.sentAt),
                style: const TextStyle(fontSize: 11, color: VawraColors.muted),
              ),
            ),
            if (!mine && message.safetyHints.isNotEmpty) _hint(message),
          ],
        ),
      ),
    );
  }

  /// A reviewed photo. From the other person it stays blurred until tapped,
  /// and can be reported once seen.
  Widget _photoBubble(ChatMessage message, String url, bool mine) {
    final shown = mine || revealed.contains(message.id);
    final provider = widget.photoProvider?.call(url);
    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: Key('photo-message-${message.id}'),
          onTap: shown ? null : () => setState(() => revealed.add(message.id)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 220,
              height: 260,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (provider != null)
                    ImageFiltered(
                      imageFilter: shown
                          ? ui.ImageFilter.blur()
                          : ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Image(
                        image: provider,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: VawraColors.lavender),
                      ),
                    )
                  else
                    const ColoredBox(color: VawraColors.lavender),
                  if (!shown)
                    const ColoredBox(
                      color: Color(0x55000000),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              color: Colors.white,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Photo \u00b7 Tap to see',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!mine && shown)
          TextButton(
            key: Key('photo-report-${message.id}'),
            onPressed: () async {
              final report = await _chooseReport(context, about: message);
              if (report != null) widget.onReport(report);
            },
            child: const Text('Report this photo'),
          ),
      ],
    );
  }

  /// A gentle warning under a message: what to watch for, and a one-tap
  /// report. Nothing is blocked; the person decides.
  Widget _hint(ChatMessage message) {
    final hints = message.safetyHints;
    final text = hints.contains('money')
        ? 'Asked for money? Never send money, gift cards or crypto to someone '
              'you haven\'t met.'
        : hints.contains('off_platform')
        ? 'Moving to another app? Take your time: here, block and report keep '
              'working.'
        : 'Links can lead to scams. Only open ones you trust.';
    return Container(
      key: Key('safety-hint-${message.id}'),
      constraints: const BoxConstraints(maxWidth: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: Icon(
              Icons.shield_outlined,
              size: 18,
              color: VawraColors.plum,
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          TextButton(
            key: Key('hint-report-${message.id}'),
            onPressed: () async {
              final report = await _chooseReport(
                context,
                about: message,
                initialReason: ReportReason.scam,
              );
              if (report != null) widget.onReport(report);
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _time(DateTime at) {
    final local = at.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  static String _day(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Today';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  /// [about] preselects a message (and [reason]), as the warning under a
  /// message does.
  void _startCall(BuildContext context, {required bool video}) {
    final start = widget.onStartCall;
    if (start != null) return start(video);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Prototype only: no camera, microphone, or network connection was opened.',
        ),
      ),
    );
  }

  Future<SafetyReport?> _chooseReport(
    BuildContext context, {
    ChatMessage? about,
    ReportReason? initialReason,
  }) {
    final activeConnection = widget.connection;
    if (activeConnection == null) return Future.value();
    ReportReason? reason = initialReason;
    final latestPeerMessage =
        about ??
        widget.messages
            .where((message) => message.author == MessageAuthor.peer)
            .lastOrNull;
    var includeMessageReference = about != null;
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
                  initialValue: reason,
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
                    title: Text(
                      about != null
                          ? 'Include this message'
                          : 'Include latest received message reference',
                    ),
                    subtitle: const Text(
                      'Optional. No conversation text is copied into this report.',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  widget.live
                      ? 'Sent privately to Vawra\'s moderators. They see only the message you include, never your whole chat.'
                      : 'Prototype only: this starts as local pending review and is not sent to a review team.',
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
              child: Text(widget.live ? 'Send report' : 'Record report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAction(BuildContext context, String action) async {
    final activeConnection = widget.connection;
    if (activeConnection == null) return;
    if (action == 'report') {
      final report = await _chooseReport(context);
      if (report != null) widget.onReport(report);
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
      widget.onBlock();
    } else {
      widget.onUnmatch();
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
