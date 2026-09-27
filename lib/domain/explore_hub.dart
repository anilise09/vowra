import 'demo_profile.dart';

/// A themed way to browse: people grouped by a goal or an interest they
/// chose themselves. Never by inferred traits.
class ExploreHub {
  const ExploreHub(
    this.id,
    this.title,
    this.subtitle, {
    this.intent,
    this.interest,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? intent;
  final String? interest;

  bool includes(DemoProfile profile) =>
      (intent == null || profile.intent == intent) &&
      (interest == null || profile.interests.contains(interest));

  static const all = [
    ExploreHub(
      'long-term',
      'Here for something real',
      'Looking for a long-term relationship',
      intent: 'Long-term relationship',
    ),
    ExploreHub(
      'open',
      'Open to long-term',
      'Happy to see where it leads',
      intent: 'Open to long-term',
    ),
    ExploreHub(
      'outdoors',
      'Outdoor people',
      'Trails, parks and fresh air',
      interest: 'Outdoors',
    ),
    ExploreHub(
      'foodies',
      'Foodies',
      'Cooking, markets and long dinners',
      interest: 'Cooking',
    ),
    ExploreHub(
      'arts',
      'Art lovers',
      'Galleries, films and making things',
      interest: 'Arts',
    ),
    ExploreHub(
      'music',
      'Music fans',
      'Gigs, playlists and dancing',
      interest: 'Music',
    ),
    ExploreHub(
      'books',
      'Bookworms',
      'Bookshops and reading lists',
      interest: 'Books',
    ),
    ExploreHub(
      'travel',
      'Travellers',
      'Always planning the next trip',
      interest: 'Travel',
    ),
    ExploreHub(
      'fitness',
      'Active lifestyles',
      'Runs, gyms and weekend sport',
      interest: 'Fitness',
    ),
  ];
}
