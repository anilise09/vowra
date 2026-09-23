enum LocalLikeEventType {
  outboundLike('outbound_like', 'You liked this profile'),
  notificationPreview('notification_preview', 'Notification preview queued'),
  mutualLike('mutual_like', 'Mutual like can connect');

  const LocalLikeEventType(this.backendKey, this.label);
  final String backendKey;
  final String label;
}

class LocalLikeEvent {
  const LocalLikeEvent({
    required this.id,
    required this.type,
    required this.profileAssetPath,
    required this.profileName,
    required this.createdAt,
  });

  final String id;
  final LocalLikeEventType type;
  final String profileAssetPath;
  final String profileName;
  final DateTime createdAt;

  String get summary => switch (type) {
    LocalLikeEventType.outboundLike => 'Liked $profileName locally.',
    LocalLikeEventType.notificationPreview =>
      'Notification preview for $profileName: someone liked your profile.',
    LocalLikeEventType.mutualLike =>
      'Mutual like with $profileName can connect and message in the free core.',
  };
}

List<LocalLikeEvent> localLikeEventsFor({
  required String profileAssetPath,
  required String profileName,
  required DateTime createdAt,
  bool mutualLike = false,
}) {
  final stamp = createdAt.microsecondsSinceEpoch;
  return [
    LocalLikeEvent(
      id: '$stamp-outbound-like',
      type: LocalLikeEventType.outboundLike,
      profileAssetPath: profileAssetPath,
      profileName: profileName,
      createdAt: createdAt,
    ),
    LocalLikeEvent(
      id: '$stamp-notification-preview',
      type: LocalLikeEventType.notificationPreview,
      profileAssetPath: profileAssetPath,
      profileName: profileName,
      createdAt: createdAt,
    ),
    if (mutualLike)
      LocalLikeEvent(
        id: '$stamp-mutual-like',
        type: LocalLikeEventType.mutualLike,
        profileAssetPath: profileAssetPath,
        profileName: profileName,
        createdAt: createdAt,
      ),
  ];
}
