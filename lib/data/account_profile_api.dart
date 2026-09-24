import '../domain/account_profile_contract.dart';

sealed class AccountProfileResult {
  const AccountProfileResult();
}

class AccountProfileSuccess extends AccountProfileResult {
  const AccountProfileSuccess(this.profile);
  final ServerAccountProfile profile;
}

enum AccountProfileFailureReason {
  unavailable,
  unauthenticated,
  ageAssuranceRequired,
  rejectedByServer,
}

class AccountProfileFailure extends AccountProfileResult {
  const AccountProfileFailure(this.reason, this.message);
  final AccountProfileFailureReason reason;
  final String message;
}

/// Future network boundary for the authenticated account's own profile.
///
/// There is intentionally no caller-supplied account ID. A real implementation
/// must bind both operations to the server-validated session and must not trust
/// any client claim about age, identity, location, entitlement, or matches.
abstract interface class AccountProfileApi {
  Future<AccountProfileResult> fetchOwnProfile();
  Future<AccountProfileResult> saveOwnProfile(ProfileMutation mutation);
}

/// Fail-closed placeholder used until the account service passes review.
class UnconfiguredAccountProfileApi implements AccountProfileApi {
  const UnconfiguredAccountProfileApi();

  static const _failure = AccountProfileFailure(
    AccountProfileFailureReason.unavailable,
    'Account and profile service is not connected in this prototype.',
  );

  @override
  Future<AccountProfileResult> fetchOwnProfile() async => _failure;

  @override
  Future<AccountProfileResult> saveOwnProfile(ProfileMutation mutation) async =>
      _failure;
}
