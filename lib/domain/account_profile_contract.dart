import 'lifestyle.dart';
import 'profile_prompt.dart';
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
    this.lifestyle = const {},
    this.prompts = const [],
  });

  factory ProfileMutation.fromLocalProfile(UserProfile profile) =>
      ProfileMutation(
        displayName: profile.displayName,
        intent: profile.intent,
        bio: profile.bio,
        interests: List.unmodifiable(profile.interests),
        showDistanceBand: profile.showDistanceBand,
        callReadyByDefault: profile.callReadyByDefault,
        lifestyle: Map.unmodifiable(profile.lifestyle),
        prompts: List.unmodifiable(profile.prompts),
      );

  final String displayName;
  final RelationshipIntent intent;
  final String bio;
  final List<String> interests;
  final bool showDistanceBand;
  final bool callReadyByDefault;

  /// Optional habits, one fixed answer per topic.
  final Map<LifestyleTopic, String> lifestyle;

  /// Up to two answers to fixed questions.
  final List<ProfilePrompt> prompts;

  Map<String, Object> toContractMap() => {
    'display_name': displayName,
    'relationship_intent': intent.backendKey,
    'bio': bio,
    'interests': List<String>.unmodifiable(interests),
    'show_distance_band': showDistanceBand,
    'call_ready_by_default': callReadyByDefault,
    'lifestyle': {
      for (final entry in lifestyle.entries) entry.key.name: entry.value,
    },
    'prompts': [
      for (final prompt in prompts)
        {'question': prompt.question, 'answer': prompt.answer},
    ],
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
