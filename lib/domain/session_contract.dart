enum SignInProvider {
  passwordlessEmail('passwordless_email'),
  googleOidc('google_oidc'),
  appleOidc('apple_oidc');

  const SignInProvider(this.backendKey);
  final String backendKey;
}

enum AccountRequestPurpose {
  signIn('sign_in'),
  recovery('recovery');

  const AccountRequestPurpose(this.backendKey);
  final String backendKey;
}

/// Starts sign-in or recovery without revealing whether an account exists.
class AccountRequest {
  const AccountRequest({required this.identifier, required this.purpose});

  final String identifier;
  final AccountRequestPurpose purpose;

  @override
  String toString() =>
      'AccountRequest(purpose: ${purpose.backendKey}, identifier: redacted)';
}

/// Short-lived provider proof. A transport may read it once for exchange but
/// must never persist it, log it, place it in a URL, or include it in analytics.
class ProviderExchangeProof {
  const ProviderExchangeProof({
    required this.provider,
    required this.authorizationCode,
    required this.pkceVerifier,
    required this.stateNonce,
  });

  final SignInProvider provider;
  final String authorizationCode;
  final String pkceVerifier;
  final String stateNonce;

  @override
  String toString() =>
      'ProviderExchangeProof(provider: ${provider.backendKey}, secrets: redacted)';
}

enum SessionState {
  active('active'),
  reauthenticationRequired('reauthentication_required'),
  revoked('revoked');

  const SessionState(this.backendKey);
  final String backendKey;
}

class SessionSnapshot {
  const SessionSnapshot({
    required this.opaqueSessionId,
    required this.opaqueAccountId,
    required this.state,
    required this.expiresAt,
  });

  final String opaqueSessionId;
  final String opaqueAccountId;
  final SessionState state;
  final DateTime expiresAt;

  bool allowsAuthenticatedRequestsAt(DateTime now) =>
      state == SessionState.active && expiresAt.isAfter(now.toUtc());
}

/// Intentionally generic for both known and unknown account identifiers.
class PublicAccountRequestReceipt {
  const PublicAccountRequestReceipt({required this.message});

  static const genericMessage =
      'If the account can continue, instructions will be sent.';

  final String message;

  Map<String, String> toContractMap() => {'message': message};
}
