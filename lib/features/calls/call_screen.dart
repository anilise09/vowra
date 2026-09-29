import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/safety_report.dart';
import '../../theme/vawra_theme.dart';
import 'call_controller.dart';

/// The whole call on one screen: ringing either way, the call itself, and how
/// it ended. It closes itself a moment after the call ends.
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.controller,
    this.peerPhoto,
    this.onReport,
    this.onBlock,
    this.closeAfter = const Duration(seconds: 2),
  });

  final CallController controller;
  final ImageProvider? peerPhoto;

  /// Report or block from inside the call; blocking also ends it.
  final Future<void> Function(ReportReason reason)? onReport;
  final VoidCallback? onBlock;
  final Duration closeAfter;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallController get call => widget.controller;
  Timer? _clock;
  Timer? _close;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    call.addListener(_changed);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (call.phase == CallPhase.live && mounted) setState(() {});
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (call.ended && _close == null) {
      _close = Timer(widget.closeAfter, () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    call.removeListener(_changed);
    // The screen going away (sign-out, the app closing it) ends the call:
    // a call never carries on unseen.
    if (!call.ended) call.hangUp();
    _clock?.cancel();
    _close?.cancel();
    super.dispose();
  }

  String get _status => switch (call.phase) {
    CallPhase.ringingOut => 'Calling…',
    CallPhase.ringingIn =>
      call.video ? 'Incoming video call' : 'Incoming voice call',
    CallPhase.connecting => 'Connecting…',
    CallPhase.live =>
      call.reconnecting ? 'Reconnecting…' : _elapsed(call.connectedAt),
    CallPhase.ended => call.endedBecause ?? 'Call ended',
  };

  static String _elapsed(DateTime? since) {
    if (since == null) return '0:00';
    final d = DateTime.now().difference(since);
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours}:${(m % 60).toString().padLeft(2, '0')}:$s'
        : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final remote = call.video && call.phase == CallPhase.live
        ? call.media.remoteView()
        : null;
    final local = call.video && call.cameraOn && !call.ended
        ? call.media.localView()
        : null;
    return PopScope(
      // Back never leaves a call running unseen: hang up first.
      canPop: call.ended,
      child: Scaffold(
        key: const Key('call-screen'),
        backgroundColor: const Color(0xFF1B1119),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (remote != null) ...[
              Positioned.fill(child: remote),
              // Keeps the name, clock and buttons readable on a bright picture.
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: Key('call-video-scrim'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x73000000),
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x99000000),
                        ],
                        stops: [0, 0.22, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (remote == null) const _Backdrop(),
            SafeArea(
              child: Column(
                children: [
                  _topBar(context),
                  if (remote == null) ...[
                    const Spacer(),
                    _Portrait(photo: widget.peerPhoto, name: call.peerName),
                    const SizedBox(height: 16),
                  ] else
                    const Spacer(),
                  Text(
                    call.peerName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _status,
                      key: const Key('call-status'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (_reported)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Reported privately to Vawra\'s moderators.',
                        key: Key('call-reported'),
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  const Spacer(),
                  if (call.phase == CallPhase.ringingIn ||
                      call.phase == CallPhase.ringingOut)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(32, 0, 32, 20),
                      child: Text(
                        'Vawra never records calls. If anything feels wrong, hang up and report.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: call.phase == CallPhase.ringingIn
                        ? _incomingControls()
                        : call.ended
                        ? const SizedBox(height: 72)
                        : _callControls(),
                  ),
                ],
              ),
            ),
            if (local != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 64,
                right: 16,
                width: 104,
                height: 148,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: local,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        const SizedBox(width: 16),
        const Icon(Icons.lock_outline, color: Colors.white54, size: 16),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Private call · not recorded',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        if (widget.onReport != null || widget.onBlock != null)
          PopupMenuButton<String>(
            key: const Key('call-safety-menu'),
            tooltip: 'Safety',
            iconColor: Colors.white,
            onSelected: (value) {
              if (value == 'report') _report();
              if (value == 'block') {
                call.hangUp();
                widget.onBlock?.call();
              }
            },
            itemBuilder: (_) => [
              if (widget.onReport != null)
                const PopupMenuItem(value: 'report', child: Text('Report')),
              if (widget.onBlock != null)
                const PopupMenuItem(
                  value: 'block',
                  child: Text('End call and block'),
                ),
            ],
          ),
      ],
    ),
  );

  Future<void> _report() async {
    final reason = await showDialog<ReportReason>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Report ${call.peerName} privately'),
        children: [
          for (final reason in ReportReason.values)
            SimpleDialogOption(
              key: Key('call-report-${reason.name}'),
              onPressed: () => Navigator.of(context).pop(reason),
              child: Text(reason.label),
            ),
        ],
      ),
    );
    if (reason == null) return;
    await widget.onReport?.call(reason);
    if (mounted) setState(() => _reported = true);
  }

  Widget _incomingControls() => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundButton(
            key: const Key('call-decline'),
            icon: Icons.call_end,
            label: 'Decline',
            color: const Color(0xFFE5484D),
            onPressed: call.decline,
          ),
          _RoundButton(
            key: const Key('call-accept'),
            icon: call.video ? Icons.videocam : Icons.call,
            label: 'Accept',
            color: const Color(0xFF2FA96B),
            onPressed: () => call.accept(),
          ),
        ],
      ),
      if (call.video)
        TextButton(
          key: const Key('call-accept-audio'),
          onPressed: () => call.accept(withVideo: false),
          child: const Text(
            'Answer without video',
            style: TextStyle(color: Colors.white),
          ),
        ),
    ],
  );

  Widget _callControls() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _RoundButton(
        key: const Key('call-mute'),
        icon: call.muted ? Icons.mic_off : Icons.mic,
        label: call.muted ? 'Unmute' : 'Mute',
        selected: call.muted,
        onPressed: call.toggleMute,
      ),
      if (call.video) ...[
        _RoundButton(
          key: const Key('call-camera'),
          icon: call.cameraOn ? Icons.videocam : Icons.videocam_off,
          label: call.cameraOn ? 'Camera off' : 'Camera on',
          selected: !call.cameraOn,
          onPressed: call.toggleCamera,
        ),
        _RoundButton(
          key: const Key('call-flip'),
          icon: Icons.cameraswitch_outlined,
          label: 'Flip',
          onPressed: call.cameraOn ? call.switchCamera : null,
        ),
      ],
      _RoundButton(
        key: const Key('call-speaker'),
        icon: call.speakerOn ? Icons.volume_up : Icons.hearing,
        label: call.speakerOn ? 'Speaker' : 'Phone',
        selected: call.speakerOn,
        onPressed: call.toggleSpeaker,
      ),
      _RoundButton(
        key: const Key('call-hang-up'),
        icon: Icons.call_end,
        label: 'End',
        color: const Color(0xFFE5484D),
        onPressed: call.hangUp,
      ),
    ],
  );
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [VawraColors.plum, Color(0xFF1B1119)],
      ),
    ),
  );
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.photo, required this.name});
  final ImageProvider? photo;
  final String name;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 64,
    backgroundColor: VawraColors.coral,
    foregroundImage: photo,
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: const TextStyle(
        fontSize: 48,
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final background =
        color ??
        (selected ? Colors.white : Colors.white.withValues(alpha: 0.16));
    final foreground = color != null
        ? Colors.white
        : (selected ? VawraColors.ink : Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: label,
          child: Material(
            color: background,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: color != null ? 68 : 56,
                height: color != null ? 68 : 56,
                child: Icon(icon, color: foreground, size: 26),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
