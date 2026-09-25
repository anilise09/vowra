import 'package:ember_app/data/media_upload_api.dart';
import 'package:ember_app/domain/media_upload_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('profile request exposes only bounded upload facts', () {
    const request = MediaUploadRequest(
      clientUploadId: 'client-idempotency-key',
      kind: MediaKind.photo,
      audience: MediaAudience.profile,
      mimeType: 'image/jpeg',
      byteLength: 1024,
      sha256Hex: hash,
      explicitContent: ExplicitContentDeclaration.none,
    );

    expect(request.isStructurallyValid, isTrue);
    expect(request.toContractMap().keys, {
      'client_upload_id',
      'kind',
      'audience',
      'mime_type',
      'byte_length',
      'sha256',
      'explicit_content',
    });
    expect(request.toContractMap().containsKey('account_id'), isFalse);
    expect(request.toContractMap().containsKey('storage_key'), isFalse);
    expect(request.toContractMap().containsKey('moderation_state'), isFalse);
  });

  test('profile media cannot declare sexually explicit content', () {
    const request = MediaUploadRequest(
      clientUploadId: 'client-idempotency-key',
      kind: MediaKind.photo,
      audience: MediaAudience.profile,
      mimeType: 'image/jpeg',
      byteLength: 1024,
      sha256Hex: hash,
      explicitContent: ExplicitContentDeclaration.sexuallyExplicit,
    );

    expect(request.isStructurallyValid, isFalse);
  });

  test('explicit matched media requires a conversation and consent', () {
    const request = MediaUploadRequest(
      clientUploadId: 'client-idempotency-key',
      kind: MediaKind.photo,
      audience: MediaAudience.matchedConversation,
      mimeType: 'image/jpeg',
      byteLength: 1024,
      sha256Hex: hash,
      explicitContent: ExplicitContentDeclaration.sexuallyExplicit,
      opaqueConversationId: 'opaque-conversation',
    );

    expect(request.isStructurallyValid, isTrue);
    expect(request.requiresRecipientConsent, isTrue);
    expect(request.toContractMap()['conversation_id'], 'opaque-conversation');
  });

  test('signed grant is bounded, expires, and redacts its URL', () {
    final now = DateTime.utc(2026, 9, 24, 12);
    final grant = SignedMediaUploadGrant(
      opaqueMediaId: 'opaque-media',
      signedUploadUri: Uri.parse(
        'https://private-storage.example/upload?secret=do-not-log',
      ),
      expiresAt: now.add(const Duration(minutes: 1)),
      maximumBytes: 2048,
    );

    expect(grant.isUsableAt(now, byteLength: 2048), isTrue);
    expect(
      grant.isUsableAt(now.add(const Duration(minutes: 1)), byteLength: 1),
      isFalse,
    );
    expect(grant.isUsableAt(now, byteLength: 2049), isFalse);
    expect(grant.toString(), isNot(contains('secret=do-not-log')));
    expect(grant.toString(), contains('uploadUri: redacted'));
  });

  test('only approved moderation state may be displayed', () {
    for (final state in MediaModerationState.values) {
      final snapshot = MediaModerationSnapshot(
        opaqueMediaId: 'opaque-media',
        kind: MediaKind.photo,
        audience: MediaAudience.profile,
        state: state,
      );
      expect(snapshot.mayBeDisplayed, state == MediaModerationState.approved);
    }
  });

  test('unconfigured media API fails every operation', () async {
    const api = UnconfiguredMediaUploadApi();
    const request = MediaUploadRequest(
      clientUploadId: 'client-idempotency-key',
      kind: MediaKind.photo,
      audience: MediaAudience.profile,
      mimeType: 'image/jpeg',
      byteLength: 1024,
      sha256Hex: hash,
      explicitContent: ExplicitContentDeclaration.none,
    );

    final results = await Future.wait([
      api.requestUpload(request),
      api.completeUpload(
        opaqueMediaId: 'opaque-media',
        sha256Hex: hash,
        byteLength: 1024,
      ),
      api.fetchModeration('opaque-media'),
      api.deleteOwnMedia('opaque-media'),
    ]);

    expect(results, everyElement(isA<MediaUploadFailure>()));
    expect(
      results.cast<MediaUploadFailure>().map((failure) => failure.reason),
      everyElement(MediaUploadFailureReason.unavailable),
    );
  });
}
