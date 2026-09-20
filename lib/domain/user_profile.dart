enum RelationshipIntent {
  longTerm('Long-term relationship'),
  openToLongTerm('Open to long-term'),
  casual('Casual dating'),
  figuringItOut('Figuring it out');

  const RelationshipIntent(this.label);
  final String label;
}

class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.age,
    required this.intent,
    required this.bio,
    required this.interests,
    this.showDistanceBand = true,
    this.callReadyByDefault = false,
  });

  final String displayName;
  final int age;
  final RelationshipIntent intent;
  final String bio;
  final List<String> interests;
  final bool showDistanceBand;
  final bool callReadyByDefault;

  static String? validateName(String value) {
    final normalized = value.trim();
    if (normalized.length < 2) return 'Enter at least 2 characters.';
    if (normalized.length > 40) return 'Use 40 characters or fewer.';
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(normalized)) {
      return 'Remove unsupported control characters.';
    }
    return null;
  }

  static String? validateAge(String value) {
    final age = int.tryParse(value.trim());
    if (age == null) return 'Enter your age as a whole number.';
    if (age < 18) return 'Project Ember is only for adults 18+.';
    if (age > 99) return 'Enter an age from 18 to 99.';
    return null;
  }

  static String? validateBio(String value) {
    final normalized = value.trim();
    if (normalized.length < 20) return 'Write at least 20 characters.';
    if (normalized.length > 300) return 'Use 300 characters or fewer.';
    return null;
  }
}
