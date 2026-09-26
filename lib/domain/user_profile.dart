import 'lifestyle.dart';

enum RelationshipIntent {
  longTerm('long_term', 'Long-term relationship'),
  openToLongTerm('open_to_long_term', 'Open to long-term'),
  casual('casual', 'Casual dating'),
  figuringItOut('figuring_it_out', 'Figuring it out');

  const RelationshipIntent(this.backendKey, this.label);
  final String backendKey;
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
    this.lifestyle = const {},
  });

  final String displayName;
  final int age;
  final RelationshipIntent intent;
  final String bio;
  final List<String> interests;
  final bool showDistanceBand;
  final bool callReadyByDefault;
  final Map<LifestyleTopic, String> lifestyle;

  static const availableInterests = [
    'Arts',
    'Books',
    'Cooking',
    'Fitness',
    'Music',
    'Outdoors',
    'Travel',
  ];
  static const maxInterests = 5;

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
    if (age < 18) return 'Vawra is only for adults 18+.';
    if (age > 99) return 'Enter an age from 18 to 99.';
    return null;
  }

  /// The bio is optional; when present it must say something meaningful.
  static String? validateBio(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    if (normalized.length < 20) return 'Write at least 20 characters.';
    if (normalized.length > 300) return 'Use 300 characters or fewer.';
    return null;
  }
}
