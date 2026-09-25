enum MediaKind {
  photo('photo'),
  video('video');

  const MediaKind(this.backendKey);
  final String backendKey;
}

enum MediaAudience {
  profile('profile'),
  matchedConversation('matched_conversation');

  const MediaAudience(this.backendKey);
  final String backendKey;
}

enum ExplicitContentDeclaration {
  none('none'),
  sexuallyExplicit('sexually_explicit');

  const ExplicitContentDeclaration(this.backendKey);
  final String backendKey;
}

/// The bounded facts needed to request one upload grant.
///
/// Account identity, age, match state, recipient consent, moderation state,
/// storage keys, and entitlements are deliberately absent. The server derives
/// or authorizes every one of those from trusted state.
class MediaUploadRequest {
  const MediaUploadRequest({
    required this.clientUploadId,
    required this.kind,
    required this.audience,
    required this.mimeType,
    required this.byteLength,
    required this.sha256Hex,
    required this.explicitContent,
    this.opaqueConversationId,
  });

  final String clientUploadId;
  final MediaKind kind;
  final MediaAudience audience;
  final String mimeType;
  final int byteLength;
  final String sha256Hex;
  final ExplicitContentDeclaration explicitContent;
  final String? opaqueConversationId;

  bool get isStructurallyValid {
    final conversationShape = switch (audience) {
      MediaAudience.profile => opaqueConversationId == null,
      MediaAudience.matchedConversation =>
        opaqueConversationId?.trim().isNotEmpty == true,
    };
    final explicitShape =
        audience != MediaAudience.profile ||
        explicitContent == ExplicitContentDeclaration.none;
    return clientUploadId.trim().isNotEmpty &&
        mimeType.trim().isNotEmpty &&
        byteLength > 0 &&
        RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256Hex) &&
        conversationShape &&
        explicitShape;
  }

  bool get requiresRecipientConsent =>
      audience == MediaAudience.matchedConversation &&
      explicitContent == ExplicitContentDeclaration.sexuallyExplicit;

  Map<String, Object> toContractMap() => {
    'client_upload_id': clientUploadId,
    'kind': kind.backendKey,
    'audience': audience.backendKey,
    'mime_type': mimeType,
    'byte_length': byteLength,
    'sha256': sha256Hex,
    'explicit_content': explicitContent.backendKey,
    'conversation_id': ?opaqueConversationId,
  };
}

/// A short-lived, single-purpose grant for direct upload to private storage.
class SignedMediaUploadGrant {
  const SignedMediaUploadGrant({
    required this.opaqueMediaId,
    required this.signedUploadUri,
    required this.expiresAt,
    required this.maximumBytes,
  });

  final String opaqueMediaId;
  final Uri signedUploadUri;
  final DateTime expiresAt;
  final int maximumBytes;

  bool isUsableAt(DateTime now, {required int byteLength}) =>
      signedUploadUri.scheme == 'https' &&
      expiresAt.isAfter(now.toUtc()) &&
      byteLength > 0 &&
      byteLength <= maximumBytes;

  @override
  String toString() =>
      'SignedMediaUploadGrant(mediaId: $opaqueMediaId, uploadUri: redacted, '
      'expiresAt: ${expiresAt.toUtc().toIso8601String()})';
}

enum MediaModerationState {
  awaitingUpload('awaiting_upload'),
  quarantined('quarantined'),
  scanning('scanning'),
  humanReviewRequired('human_review_required'),
  approved('approved'),
  rejected('rejected'),
  deletionScheduled('deletion_scheduled'),
  deleted('deleted');

  const MediaModerationState(this.backendKey);
  final String backendKey;
}

/// Safe client view of a media object. No storage key or permanent URL exists.
class MediaModerationSnapshot {
  const MediaModerationSnapshot({
    required this.opaqueMediaId,
    required this.kind,
    required this.audience,
    required this.state,
    this.safeReasonCode,
  });

  final String opaqueMediaId;
  final MediaKind kind;
  final MediaAudience audience;
  final MediaModerationState state;
  final String? safeReasonCode;

  bool get mayBeDisplayed => state == MediaModerationState.approved;
}
