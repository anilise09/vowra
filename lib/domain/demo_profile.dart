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
