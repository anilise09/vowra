enum LocalModerationState {
  localPending('local_pending', 'Local pending review'),
  readyForReview('ready_for_review', 'Ready for future review'),
  reviewedNoAction('reviewed_no_action', 'Reviewed: no action'),
  actioned('actioned', 'Action taken');

  const LocalModerationState(this.backendKey, this.label);
  final String backendKey;
  final String label;
}

enum ReportReason {
  harassment('Harassment or hate'),
  impersonation('Impersonation'),
  scam('Scam or suspicious request'),
  sexualContent('Sexual content without consent'),
  underageConcern('Possible underage account'),
  other('Something else');

  const ReportReason(this.label);
  final String label;
}

class SafetyReport {
  const SafetyReport({
    required this.matchId,
    required this.reason,
    required this.createdAt,
    this.messageId,
    this.moderationState = LocalModerationState.localPending,
  });

  final String matchId;
  final ReportReason reason;
  final DateTime createdAt;
  final String? messageId;
  final LocalModerationState moderationState;
}

class DiscoveryProfileReport {
  const DiscoveryProfileReport({
    required this.profileAssetPath,
    required this.profileName,
    required this.reason,
    required this.createdAt,
    this.moderationState = LocalModerationState.localPending,
  });

  final String profileAssetPath;
  final String profileName;
  final ReportReason reason;
  final DateTime createdAt;
  final LocalModerationState moderationState;
}
