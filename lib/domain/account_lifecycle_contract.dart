enum AccountLifecycleState {
  active('active'),
  paused('paused'),
  deletionScheduled('deletion_scheduled'),
  deleted('deleted');

  const AccountLifecycleState(this.backendKey);
  final String backendKey;
}

class AccountLifecycleSnapshot {
  const AccountLifecycleSnapshot({
    required this.state,
    this.deletionEffectiveAt,
  });

  final AccountLifecycleState state;
  final DateTime? deletionEffectiveAt;

  bool get mayUseDatingFeatures => state == AccountLifecycleState.active;

  bool mayCancelDeletionAt(DateTime now) =>
      state == AccountLifecycleState.deletionScheduled &&
      deletionEffectiveAt?.isAfter(now.toUtc()) == true;
}

enum DataExportState {
  requested('requested'),
  preparing('preparing'),
  ready('ready'),
  expired('expired'),
  failed('failed');

  const DataExportState(this.backendKey);
  final String backendKey;
}

class DataExportReceipt {
  const DataExportReceipt({
    required this.opaqueRequestId,
    required this.state,
    this.downloadExpiresAt,
  });

  final String opaqueRequestId;
  final DataExportState state;
  final DateTime? downloadExpiresAt;

  bool isDownloadReadyAt(DateTime now) =>
      state == DataExportState.ready &&
      downloadExpiresAt?.isAfter(now.toUtc()) == true;
}

/// An exact location encrypted to a reviewed server key before transport.
/// The plaintext coordinate is deliberately not represented in this contract.
class EncryptedLocationEnvelope {
  const EncryptedLocationEnvelope({
    required this.ciphertext,
    required this.keyId,
    required this.capturedAt,
  });

  final String ciphertext;
  final String keyId;
  final DateTime capturedAt;

  Map<String, String> toContractMap() => {
    'encrypted_location': ciphertext,
    'key_id': keyId,
    'captured_at': capturedAt.toUtc().toIso8601String(),
  };

  @override
  String toString() =>
      'EncryptedLocationEnvelope(keyId: $keyId, ciphertext: redacted)';
}

class LocationPrivacySnapshot {
  const LocationPrivacySnapshot({
    required this.distanceBand,
    required this.discoverable,
    required this.privacyZoneApplied,
  });

  final String distanceBand;
  final bool discoverable;
  final bool privacyZoneApplied;
}
