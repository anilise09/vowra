import 'package:ember_app/data/account_profile_api.dart';
import 'package:ember_app/domain/account_profile_contract.dart';
import 'package:ember_app/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const localProfile = UserProfile(
    displayName: 'Alex',
    age: 31,
    intent: RelationshipIntent.longTerm,
    bio: 'A thoughtful introduction with enough context.',
    interests: ['Books', 'Cooking'],
  );

  test('profile mutation excludes client-authoritative sensitive claims', () {
    final payload = ProfileMutation.fromLocalProfile(localProfile)
        .toContractMap();

    expect(payload.keys, {
      'display_name',
      'relationship_intent',
      'bio',
      'interests',
      'show_distance_band',
      'call_ready_by_default',
    });
    for (final forbidden in const [
      'age',
      'date_of_birth',
      'latitude',
      'longitude',
      'account_id',
      'verified',
      'entitlement',
      'match_id',
    ]) {
      expect(payload.containsKey(forbidden), isFalse);
    }
  });

  test(
    'age access uses stable server states and only verified adults pass',
    () {
      expect(AgeAccessState.values.map((state) => state.backendKey), [
        'assurance_required',
        'pending_review',
        'adult_verified',
        'rejected',
      ]);
      for (final state in AgeAccessState.values) {
        final account = ServerAccountProfile(
          opaqueAccountId: 'opaque-account',
          profile: localProfile,
          ageAccessState: state,
        );
        expect(
          account.mayUseDatingFeatures,
          state == AgeAccessState.adultVerified,
        );
      }
    },
  );

  test(
    'unconfigured API never pretends to fetch or persist a profile',
    () async {
      const api = UnconfiguredAccountProfileApi();
      final mutation = ProfileMutation.fromLocalProfile(localProfile);

      final fetch = await api.fetchOwnProfile();
      final save = await api.saveOwnProfile(mutation);

      expect(fetch, isA<AccountProfileFailure>());
      expect(save, isA<AccountProfileFailure>());
      expect(
        (save as AccountProfileFailure).reason,
        AccountProfileFailureReason.unavailable,
      );
    },
  );
}
