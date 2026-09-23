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
  });

  final String matchId;
  final ReportReason reason;
  final DateTime createdAt;
  final String? messageId;
}

class DiscoveryProfileReport {
  const DiscoveryProfileReport({
    required this.profileAssetPath,
    required this.profileName,
    required this.reason,
    required this.createdAt,
  });

  final String profileAssetPath;
  final String profileName;
  final ReportReason reason;
  final DateTime createdAt;
}
