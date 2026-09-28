/// How a person identifies, used for matching. It is shown on their profile
/// only if they choose to show it; who they want to meet is never shown.
enum Gender {
  woman('woman', 'Woman', 'Women'),
  man('man', 'Man', 'Men'),
  nonbinary('nonbinary', 'Non-binary', 'Non-binary people');

  const Gender(this.backendKey, this.label, this.plural);
  final String backendKey;
  final String label;

  /// For "Show me": "Women", "Men", "Non-binary people".
  final String plural;

  static Gender? fromKey(Object? key) {
    for (final g in values) {
      if (g.backendKey == key) return g;
    }
    return null;
  }
}

/// "Show me": an empty set means everyone.
bool wantsToMeet(Set<Gender> showMe, Gender? other) =>
    showMe.isEmpty || (other != null && showMe.contains(other));

/// Both people fit each other's "Show me", the way the server matches.
bool mutuallyWanted({
  required Set<Gender> myShowMe,
  required Gender? myGender,
  required Set<Gender> theirShowMe,
  required Gender? theirGender,
}) => wantsToMeet(myShowMe, theirGender) && wantsToMeet(theirShowMe, myGender);
