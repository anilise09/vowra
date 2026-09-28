import 'gender.dart';
import 'lifestyle.dart';
import 'match_reason.dart';
import 'profile_prompt.dart';

class DemoProfile {
  const DemoProfile(
    this.name,
    this.age,
    this.intent,
    this.distanceBand,
    this.bio,
    this.interests,
    this.assetPath, [
    this.background,
  ]);

  final String name;
  final int age;
  final String intent;
  final String distanceBand;
  final String bio;
  final List<String> interests;
  final String assetPath;
  final String? background;
}

/// A person with the optional details a real account can share.
class DetailedProfile extends DemoProfile {
  const DetailedProfile(
    super.name,
    super.age,
    super.intent,
    super.distanceBand,
    super.bio,
    super.interests,
    super.assetPath, {
    this.lifestyle = const {},
    this.prompts = const [],
    this.reasons = const [],
    this.gender,
  });

  final Map<LifestyleTopic, String> lifestyle;
  final List<ProfilePrompt> prompts;

  /// Why the two of you might click, as the server explains its order.
  final List<MatchReason> reasons;

  /// Only set when the person chose to show it.
  final Gender? gender;
}
