class DiscoveryPreferences {
  const DiscoveryPreferences({this.minAge = 18, this.maxAge = 99, this.intent})
    : assert(minAge >= 18 && maxAge <= 99 && minAge <= maxAge);

  final int minAge;
  final int maxAge;
  final String? intent;

  bool includes({required int age, required String relationshipIntent}) {
    return age >= minAge &&
        age <= maxAge &&
        (intent == null || intent == relationshipIntent);
  }

  bool get isDefault => minAge == 18 && maxAge == 99 && intent == null;
}
