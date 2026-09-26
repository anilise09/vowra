class DiscoveryPreferences {
  const DiscoveryPreferences({
    this.minAge = 18,
    this.maxAge = 99,
    this.intent,
    this.maxDistanceKm,
  }) : assert(minAge >= 18 && maxAge <= 99 && minAge <= maxAge);

  /// Distance limits offered in the preferences sheet (null means any).
  static const distanceChoices = [5, 10, 20, 50];

  final int minAge;
  final int maxAge;
  final String? intent;

  /// Upper limit in km, compared against the far edge of a profile's band.
  final int? maxDistanceKm;

  bool includes({
    required int age,
    required String relationshipIntent,
    String? distanceBand,
  }) {
    final withinDistance =
        maxDistanceKm == null ||
        distanceBand == null ||
        (bandUpperKm(distanceBand) ?? 0) <= maxDistanceKm!;
    return age >= minAge &&
        age <= maxAge &&
        (intent == null || intent == relationshipIntent) &&
        withinDistance;
  }

  /// "5–10 km away" -> 10. Only the band is ever known, never a location.
  static int? bandUpperKm(String band) {
    final numbers = RegExp(r'\d+').allMatches(band).toList();
    return numbers.isEmpty ? null : int.parse(numbers.last.group(0)!);
  }

  bool get isDefault =>
      minAge == 18 && maxAge == 99 && intent == null && maxDistanceKm == null;
}
