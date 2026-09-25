import '../domain/media_upload_contract.dart';

sealed class MediaUploadResult {
  const MediaUploadResult();
}

class MediaUploadGrantIssued extends MediaUploadResult {
  const MediaUploadGrantIssued(this.grant);
  final SignedMediaUploadGrant grant;
}

class MediaModerationUpdated extends MediaUploadResult {
  const MediaModerationUpdated(this.snapshot);
  final MediaModerationSnapshot snapshot;
}

enum MediaUploadFailureReason {
  unavailable,
  unauthenticated,
  ageAssuranceRequired,
  invalidRequest,
  matchRequired,
  recipientConsentRequired,
  uploadGrantExpired,
  moderationRejected,
  rateLimited,
}

class MediaUploadFailure extends MediaUploadResult {
  const MediaUploadFailure(this.reason, this.message);
  final MediaUploadFailureReason reason;
  final String message;
}

/// Future boundary for the authenticated account's own media.
///
/// Passing a media or conversation ID never proves ownership, an active match,
/// recipient consent, or permission to view/delete. A real server must derive
/// account identity from the validated session and authorize every operation.
abstract interface class MediaUploadApi {
  Future<MediaUploadResult> requestUpload(MediaUploadRequest request);

  Future<MediaUploadResult> completeUpload({
    required String opaqueMediaId,
    required String sha256Hex,
    required int byteLength,
  });

  Future<MediaUploadResult> fetchModeration(String opaqueMediaId);

  Future<MediaUploadResult> deleteOwnMedia(String opaqueMediaId);
}

/// Fail-closed until storage, malware scanning, moderation, consent, deletion,
/// and cross-account authorization pass provider and security review.
class UnconfiguredMediaUploadApi implements MediaUploadApi {
  const UnconfiguredMediaUploadApi();

  static const _failure = MediaUploadFailure(
    MediaUploadFailureReason.unavailable,
    'Media upload and moderation are not connected in this prototype.',
  );

  @override
  Future<MediaUploadResult> requestUpload(MediaUploadRequest request) async =>
      _failure;

  @override
  Future<MediaUploadResult> completeUpload({
    required String opaqueMediaId,
    required String sha256Hex,
    required int byteLength,
  }) async => _failure;

  @override
  Future<MediaUploadResult> fetchModeration(String opaqueMediaId) async =>
      _failure;

  @override
  Future<MediaUploadResult> deleteOwnMedia(String opaqueMediaId) async =>
      _failure;
}
