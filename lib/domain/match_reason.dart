/// One plain-language reason two people might click, from the server's
/// visible compatibility signals (backend/src/compatibility.ts).
enum ReasonKind { goal, interests, habit }

class MatchReason {
  const MatchReason(this.kind, this.text);

  final ReasonKind kind;
  final String text;

  /// The reason to show on a card, where the goal already has its own line:
  /// shared interests first, then habits, then the goal.
  static MatchReason? forCard(List<MatchReason> reasons) {
    for (final kind in const [
      ReasonKind.interests,
      ReasonKind.habit,
      ReasonKind.goal,
    ]) {
      for (final reason in reasons) {
        if (reason.kind == kind) return reason;
      }
    }
    return null;
  }

  static List<MatchReason> parse(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && item['text'] is String)
          for (final kind in ReasonKind.values)
            if (kind.name == item['kind'])
              MatchReason(kind, item['text'] as String),
    ];
  }
}
