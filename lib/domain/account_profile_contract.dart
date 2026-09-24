import 'user_profile.dart';

enum AgeAccessState {
  assuranceRequired('assurance_required'),
  pendingReview('pending_review'),
  adultVerified('adult_verified'),
  rejected('rejected');

  const AgeAccessState(this.backendKey);
  final String backendKey;
}

/// Public profile fields the client may ask the server to change.
///
/// Age, date of birth, coordinates, account identity, entitlement, match, and
/// verification claims are deliberately absent. The server derives or
/// authorizes those values from the authenticated session and trusted systems.
class ProfileMutation {
  const ProfileMutation({
    required this.displayName,
    required this.intent,
    required this.bio,
    required this.interests,
    required this.showDistanceBand,
    required this.callReadyByDefault,
  });

  factory ProfileMutation.fromLocalProfile(UserProfile profile) =>
      ProfileMutation(
        displayName: profile.displayName,
        intent: profile.intent,
        bio: profile.bio,
        interests: List.unmodifiable(profile.interests),
        showDistanceBand: profile.showDistanceBand,
        callReadyByDefault: profile.callReadyByDefault,
      );

  final String displayName;
  final RelationshipIntent intent;
  final String bio;
  final List<String> interests;
  final bool showDistanceBand;
  final bool callReadyByDefault;

  Map<String, Object> toContractMap() => {
    'display_name': displayName,
    'relationship_intent': intent.backendKey,
    'bio': bio,
    'interests': List<String>.unmodifiable(interests),
    'show_distance_band': showDistanceBand,
    'call_ready_by_default': callReadyByDefault,
  };
}

class ServerAccountProfile {
  const ServerAccountProfile({
    required this.opaqueAccountId,
    required this.profile,
    required this.ageAccessState,
  });

  final String opaqueAccountId;
  final UserProfile profile;
  final AgeAccessState ageAccessState;

  bool get mayUseDatingFeatures =>
      ageAccessState == AgeAccessState.adultVerified;
}
