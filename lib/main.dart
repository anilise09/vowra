import 'package:flutter/material.dart';

import 'data/message_repository.dart';
import 'data/profile_repository.dart';
import 'domain/chat_message.dart';
import 'domain/match_connection.dart';
import 'domain/user_profile.dart';

void main() => runApp(const EmberApp());

class EmberApp extends StatelessWidget {
  const EmberApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Project Ember',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE84A72)),
      scaffoldBackgroundColor: const Color(0xFFFFF9FA),
      useMaterial3: true,
    ),
    home: const WelcomeScreen(),
  );
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool isAdult = false;
  bool acceptsRules = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 64,
                  color: Color(0xFFE84A72),
                ),
                const SizedBox(height: 20),
                Text(
                  'Meet with intention.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Project Ember is a private, safety-first place to meet. This early prototype uses synthetic profiles only.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          key: const Key('adult-checkbox'),
                          value: isAdult,
                          onChanged: (value) =>
                              setState(() => isAdult = value ?? false),
                          title: const Text('I am at least 18 years old'),
                          subtitle: const Text(
                            'Age assurance will be required before public launch.',
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          key: const Key('rules-checkbox'),
                          value: acceptsRules,
                          onChanged: (value) =>
                              setState(() => acceptsRules = value ?? false),
                          title: const Text(
                            'I agree to treat people with respect',
                          ),
                          subtitle: const Text(
                            'No harassment, hate, impersonation, scams, or sexual content without consent.',
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('continue-button'),
                  onPressed: isAdult && acceptsRules
                      ? () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const DiscoveryScreen(),
                          ),
                        )
                      : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Continue'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Continuing will not create an account or upload data in this prototype.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  int selectedIndex = 0;
  int profileIndex = 0;
  final ProfileRepository profileRepository = MemoryProfileRepository();
  final MemoryMessageRepository messageRepository = MemoryMessageRepository();
  UserProfile? userProfile;
  MatchConnection connection = const MatchConnection(
    matchId: 'synthetic-match-1',
    peerName: 'Maya',
    peerCallReady: true,
  );

  @override
  void initState() {
    super.initState();
    messageRepository.seed(connection.matchId, [
      ChatMessage(
        id: 'seed-peer',
        author: MessageAuthor.peer,
        text: 'Hi! What is your ideal Sunday?',
        sentAt: DateTime.utc(2026, 9, 20, 12),
      ),
      ChatMessage(
        id: 'seed-user',
        author: MessageAuthor.currentUser,
        text: 'Coffee, a long walk, and cooking something new.',
        sentAt: DateTime.utc(2026, 9, 20, 12, 1),
      ),
    ]);
  }

  static const profiles = [
    DemoProfile(
      'Maya',
      29,
      'Long-term relationship',
      '2–5 km away',
      'Sunday markets, tiny concerts, and ambitious pasta experiments.',
      ['Kindness', 'Live music', 'Cooking'],
      'assets/profiles/maya.png',
    ),
    DemoProfile(
      'Elena',
      32,
      'Long-term relationship',
      '5–10 km away',
      'Bookshop regular, neighborhood explorer, and enthusiastic brunch host.',
      ['Books', 'Cooking', 'Arts'],
      'assets/profiles/elena.png',
    ),
    DemoProfile(
      'Amina',
      27,
      'Open to long-term',
      '2–5 km away',
      'Plant lover, weekend cyclist, and always looking for a new gallery.',
      ['Outdoors', 'Fitness', 'Arts'],
      'assets/profiles/amina.png',
    ),
    DemoProfile(
      'Sofia',
      35,
      'Long-term relationship',
      '10–20 km away',
      'Farmers markets, live jazz, and dinners that run pleasantly late.',
      ['Music', 'Cooking', 'Travel'],
      'assets/profiles/sofia.png',
    ),
    DemoProfile(
      'Mei',
      30,
      'Open to long-term',
      '5–10 km away',
      'Museum afternoons, design books, and finding the best noodles in town.',
      ['Arts', 'Books', 'Travel'],
      'assets/profiles/mei.png',
    ),
    DemoProfile(
      'Nadia',
      33,
      'Long-term relationship',
      '5–10 km away',
      'Riverside walks, contemporary fiction, and finding the perfect flatbread.',
      ['Books', 'Outdoors', 'Cooking'],
      'assets/profiles/nadia.png',
    ),
    DemoProfile(
      'Grace',
      28,
      'Open to long-term',
      '2–5 km away',
      'Early bakery runs, dance classes, and hosting game nights.',
      ['Cooking', 'Fitness', 'Music'],
      'assets/profiles/grace.png',
    ),
    DemoProfile(
      'Valentina',
      31,
      'Long-term relationship',
      '10–20 km away',
      'Garden weekends, live theater, and making travel plans over coffee.',
      ['Outdoors', 'Arts', 'Travel'],
      'assets/profiles/valentina.png',
    ),
    DemoProfile(
      'Leila',
      36,
      'Open to long-term',
      '5–10 km away',
      'Gallery openings, architecture walks, and slow Sunday breakfasts.',
      ['Arts', 'Books', 'Cooking'],
      'assets/profiles/leila.png',
    ),
    DemoProfile(
      'Chloe',
      26,
      'Long-term relationship',
      '2–5 km away',
      'Lakeside picnics, indie films, and learning new recipes.',
      ['Outdoors', 'Arts', 'Cooking'],
      'assets/profiles/chloe.png',
    ),
    DemoProfile(
      'Camila',
      34,
      'Long-term relationship',
      '5–10 km away',
      'City gardens, weekend dancing, and sharing ambitious home cooking.',
      ['Outdoors', 'Music', 'Cooking'],
      'assets/profiles/camila.png',
    ),
    DemoProfile(
      'Derya',
      29,
      'Open to long-term',
      '2–5 km away',
      'Waterfront walks, live comedy, and a carefully curated reading list.',
      ['Books', 'Arts', 'Outdoors'],
      'assets/profiles/derya.png',
    ),
    DemoProfile(
      'Thuy',
      37,
      'Long-term relationship',
      '10–20 km away',
      'Libraries, quiet courtyards, and planning trips around great food.',
      ['Books', 'Travel', 'Cooking'],
      'assets/profiles/thuy.png',
    ),
    DemoProfile(
      'Selam',
      31,
      'Open to long-term',
      '5–10 km away',
      'Botanical walks, dance workouts, and trying every café nearby.',
      ['Outdoors', 'Fitness', 'Cooking'],
      'assets/profiles/selam.png',
    ),
    DemoProfile(
      'Amelie',
      27,
      'Long-term relationship',
      '2–5 km away',
      'Flower markets, sketchbooks, and films with excellent soundtracks.',
      ['Arts', 'Music', 'Travel'],
      'assets/profiles/amelie.png',
    ),
    DemoProfile(
      'Zuri',
      32,
      'Long-term relationship',
      '5–10 km away',
      'Community gardens, morning runs, and cooking for friends.',
      ['Outdoors', 'Fitness', 'Cooking'],
      'assets/profiles/zuri.png',
    ),
    DemoProfile(
      'Ines',
      35,
      'Open to long-term',
      '10–20 km away',
      'City overlooks, pottery classes, and slow weekend breakfasts.',
      ['Arts', 'Travel', 'Cooking'],
      'assets/profiles/ines.png',
    ),
    DemoProfile(
      'Yara',
      28,
      'Long-term relationship',
      '2–5 km away',
      'Courtyard cafés, contemporary novels, and live acoustic sets.',
      ['Books', 'Music', 'Arts'],
      'assets/profiles/yara.png',
    ),
    DemoProfile(
      'Sari',
      30,
      'Open to long-term',
      '5–10 km away',
      'Riverside cycling, design markets, and finding excellent noodles.',
      ['Fitness', 'Arts', 'Cooking'],
      'assets/profiles/sari.png',
    ),
    DemoProfile(
      'Anya',
      38,
      'Long-term relationship',
      '10–20 km away',
      'Outdoor book stalls, classical concerts, and winter walks.',
      ['Books', 'Music', 'Outdoors'],
      'assets/profiles/anya.png',
    ),
    DemoProfile(
      'Aisha',
      34,
      'Long-term relationship',
      '5–10 km away',
      'Tropical gardens, craft workshops, and long weekend lunches.',
      ['Outdoors', 'Arts', 'Cooking'],
      'assets/profiles/aisha.png',
    ),
    DemoProfile(
      'Lucia',
      29,
      'Open to long-term',
      '2–5 km away',
      'Waterfront sunsets, salsa nights, and neighborhood food finds.',
      ['Music', 'Fitness', 'Cooking'],
      'assets/profiles/lucia.png',
    ),
    DemoProfile(
      'Kasia',
      36,
      'Long-term relationship',
      '10–20 km away',
      'Autumn walks, mystery novels, and learning new recipes.',
      ['Outdoors', 'Books', 'Cooking'],
      'assets/profiles/kasia.png',
    ),
    DemoProfile(
      'Hodan',
      31,
      'Open to long-term',
      '5–10 km away',
      'Botanical courtyards, thoughtful conversation, and museum weekends.',
      ['Outdoors', 'Books', 'Arts'],
      'assets/profiles/hodan.png',
    ),
    DemoProfile(
      'Mariam',
      38,
      'Long-term relationship',
      '10–20 km away',
      'Golden-hour walks, family recipes, and independent films.',
      ['Outdoors', 'Cooking', 'Arts'],
      'assets/profiles/mariam.png',
    ),
    DemoProfile(
      'Noura',
      33,
      'Long-term relationship',
      '5–10 km away',
      'Coastal gardens, jazz evenings, and shared meals.',
      ['Outdoors', 'Music', 'Cooking'],
      'assets/profiles/noura.png',
    ),
    DemoProfile(
      'Elise',
      28,
      'Open to long-term',
      '2–5 km away',
      'Sculpture parks, cycling, and quiet Sunday cafés.',
      ['Arts', 'Fitness', 'Books'],
      'assets/profiles/elise.png',
    ),
    DemoProfile(
      'Adwoa',
      36,
      'Long-term relationship',
      '10–20 km away',
      'Garden walks, live music, and dinner with friends.',
      ['Outdoors', 'Music', 'Cooking'],
      'assets/profiles/adwoa.png',
    ),
    DemoProfile(
      'Rina',
      30,
      'Open to long-term',
      '5–10 km away',
      'Waterfront walks, design exhibits, and weekend travel.',
      ['Outdoors', 'Arts', 'Travel'],
      'assets/profiles/rina.png',
    ),
    DemoProfile(
      'Milena',
      39,
      'Long-term relationship',
      '10–20 km away',
      'Riverside evenings, novels, and ambitious baking.',
      ['Outdoors', 'Books', 'Cooking'],
      'assets/profiles/milena.png',
    ),
    DemoProfile(
      'Samira',
      32,
      'Long-term relationship',
      '5–10 km away',
      'Garden walks, music, and shared dinners.',
      ['Outdoors', 'Music', 'Cooking'],
      'assets/profiles/samira.png',
    ),
    DemoProfile(
      'Maeve',
      37,
      'Open to long-term',
      '10–20 km away',
      'Coastal paths, novels, and live shows.',
      ['Outdoors', 'Books', 'Music'],
      'assets/profiles/maeve.png',
    ),
    DemoProfile(
      'Lindiwe',
      29,
      'Long-term relationship',
      '2–5 km away',
      'Botanical walks, dance, and weekend cooking.',
      ['Outdoors', 'Fitness', 'Cooking'],
      'assets/profiles/lindiwe.png',
    ),
    DemoProfile(
      'Petra',
      35,
      'Open to long-term',
      '5–10 km away',
      'Marina evenings, photography, and travel.',
      ['Outdoors', 'Arts', 'Travel'],
      'assets/profiles/petra.png',
    ),
    DemoProfile(
      'Noor',
      30,
      'Long-term relationship',
      '10–20 km away',
      'Courtyard cafés, books, and museum days.',
      ['Books', 'Arts', 'Cooking'],
      'assets/profiles/noor.png',
    ),
    DemoProfile(
      'Nino',
      34,
      'Long-term relationship',
      '5–10 km away',
      'Hillside gardens, architecture, and long dinners.',
      ['Outdoors', 'Arts', 'Cooking'],
      'assets/profiles/nino.png',
    ),
    DemoProfile(
      'Marisol',
      29,
      'Open to long-term',
      '2–5 km away',
      'Botanical walks, dancing, and weekend markets.',
      ['Outdoors', 'Fitness', 'Cooking'],
      'assets/profiles/marisol.png',
    ),
    DemoProfile(
      'Keza',
      37,
      'Long-term relationship',
      '10–20 km away',
      'Lakeside walks, books, and live jazz.',
      ['Outdoors', 'Books', 'Music'],
      'assets/profiles/keza.png',
    ),
    DemoProfile(
      'Aino',
      31,
      'Open to long-term',
      '5–10 km away',
      'Harbor gardens, design, and hiking weekends.',
      ['Outdoors', 'Arts', 'Travel'],
      'assets/profiles/aino.png',
    ),
    DemoProfile(
      'Rima',
      35,
      'Long-term relationship',
      '10–20 km away',
      'Stone courtyards, museums, and shared recipes.',
      ['Outdoors', 'Arts', 'Cooking'],
      'assets/profiles/rima.png',
    ),
    DemoProfile(
      'Oksana',
      33,
      'Long-term relationship',
      '5–10 km away',
      'Courtyard gardens, architecture, and weekend baking.',
      ['Outdoors', 'Arts', 'Cooking'],
      'assets/profiles/oksana.png',
    ),
    DemoProfile(
      'Isidora',
      30,
      'Open to long-term',
      '2–5 km away',
      'Botanical walks, dancing, and independent films.',
      ['Outdoors', 'Fitness', 'Arts'],
      'assets/profiles/isidora.png',
    ),
    DemoProfile(
      'Abena',
      36,
      'Long-term relationship',
      '10–20 km away',
      'Garden afternoons, live music, and dinner with friends.',
      ['Outdoors', 'Music', 'Cooking'],
      'assets/profiles/abena.png',
    ),
    DemoProfile(
      'Freyja',
      28,
      'Open to long-term',
      '5–10 km away',
      'Waterfront walks, design books, and quiet road trips.',
      ['Outdoors', 'Books', 'Travel'],
      'assets/profiles/freyja.png',
    ),
    DemoProfile(
      'Dalia',
      38,
      'Long-term relationship',
      '10–20 km away',
      'Stone courtyards, family recipes, and museum weekends.',
      ['Outdoors', 'Cooking', 'Arts'],
      'assets/profiles/dalia.png',
    ),
    DemoProfile(
      'Marcus',
      30,
      'Long-term relationship',
      '2–5 km away',
      'Coffee walks, pickup basketball, and cooking for friends.',
      ['Fitness', 'Cooking', 'Music'],
      'assets/profiles/marcus.png',
    ),
    DemoProfile(
      'Daniel',
      34,
      'Open to long-term',
      '5–10 km away',
      'Record collector, amateur photographer, and reliable road-trip DJ.',
      ['Music', 'Arts', 'Travel'],
      'assets/profiles/daniel.png',
    ),
    DemoProfile(
      'Arjun',
      29,
      'Long-term relationship',
      '10–20 km away',
      'Runner, home cook, and the person who reads every museum label.',
      ['Fitness', 'Cooking', 'Arts'],
      'assets/profiles/arjun.png',
    ),
    DemoProfile(
      'Ethan',
      36,
      'Open to long-term',
      '5–10 km away',
      'Community gardener, history reader, and beginner bread baker.',
      ['Outdoors', 'Books', 'Cooking'],
      'assets/profiles/ethan.png',
    ),
    DemoProfile(
      'Minjun',
      31,
      'Long-term relationship',
      '2–5 km away',
      'City walks, independent films, and planning the next hiking weekend.',
      ['Arts', 'Outdoors', 'Travel'],
      'assets/profiles/minjun.png',
    ),
    DemoProfile(
      'Jamal',
      32,
      'Long-term relationship',
      '5–10 km away',
      'Botanical gardens, jazz playlists, and cooking with friends.',
      ['Outdoors', 'Music', 'Cooking'],
      'assets/profiles/jamal.png',
    ),
    DemoProfile(
      'Luca',
      35,
      'Open to long-term',
      '10–20 km away',
      'Old-town cafés, cycling, and an unreasonable number of cookbooks.',
      ['Fitness', 'Books', 'Cooking'],
      'assets/profiles/luca.png',
    ),
    DemoProfile(
      'Tomas',
      28,
      'Long-term relationship',
      '2–5 km away',
      'Weekend football, street photography, and hunting down great tacos.',
      ['Fitness', 'Arts', 'Cooking'],
      'assets/profiles/tomas.png',
    ),
    DemoProfile(
      'Andre',
      37,
      'Open to long-term',
      '5–10 km away',
      'Waterfront runs, soul records, and planning relaxed dinner parties.',
      ['Fitness', 'Music', 'Cooking'],
      'assets/profiles/andre.png',
    ),
    DemoProfile(
      'Noah',
      30,
      'Long-term relationship',
      '10–20 km away',
      'Mountain trails, small-town cafés, and documentary nights.',
      ['Outdoors', 'Travel', 'Arts'],
      'assets/profiles/noah.png',
    ),
    DemoProfile(
      'Kwame',
      33,
      'Long-term relationship',
      '5–10 km away',
      'Public gardens, live percussion, and cooking for a full table.',
      ['Outdoors', 'Music', 'Cooking'],
      'assets/profiles/kwame.png',
    ),
    DemoProfile(
      'Ronan',
      36,
      'Open to long-term',
      '10–20 km away',
      'Coastal hikes, history podcasts, and finding welcoming pubs.',
      ['Outdoors', 'Books', 'Travel'],
      'assets/profiles/ronan.png',
    ),
    DemoProfile(
      'Omar',
      30,
      'Long-term relationship',
      '2–5 km away',
      'Museum afternoons, pickup football, and perfecting breakfast.',
      ['Arts', 'Fitness', 'Cooking'],
      'assets/profiles/omar.png',
    ),
    DemoProfile(
      'Niran',
      28,
      'Open to long-term',
      '5–10 km away',
      'Rainy park walks, street food, and a growing vinyl collection.',
      ['Outdoors', 'Cooking', 'Music'],
      'assets/profiles/niran.png',
    ),
    DemoProfile(
      'Nikos',
      38,
      'Long-term relationship',
      '10–20 km away',
      'Marina evenings, architecture, and hosting relaxed Sunday lunches.',
      ['Travel', 'Arts', 'Cooking'],
      'assets/profiles/nikos.png',
    ),
    DemoProfile(
      'Mateo',
      31,
      'Long-term relationship',
      '2–5 km away',
      'Colorful neighborhoods, weekend football, and sunset photography.',
      ['Arts', 'Fitness', 'Travel'],
      'assets/profiles/mateo.png',
    ),
    DemoProfile(
      'Emmanuel',
      35,
      'Open to long-term',
      '5–10 km away',
      'Public gardens, contemporary art, and elaborate Sunday dinners.',
      ['Outdoors', 'Arts', 'Cooking'],
      'assets/profiles/emmanuel.png',
    ),
    DemoProfile(
      'Tane',
      29,
      'Long-term relationship',
      '10–20 km away',
      'Waterfront trails, social basketball, and discovering new music.',
      ['Outdoors', 'Fitness', 'Music'],
      'assets/profiles/tane.png',
    ),
    DemoProfile(
      'Pavel',
      37,
      'Open to long-term',
      '5–10 km away',
      'Old-town walks, history books, and experimenting with bread.',
      ['Outdoors', 'Books', 'Cooking'],
      'assets/profiles/pavel.png',
    ),
    DemoProfile(
      'Farid',
      33,
      'Long-term relationship',
      '2–5 km away',
      'Botanical gardens, documentary films, and generous dinner tables.',
      ['Outdoors', 'Arts', 'Cooking'],
      'assets/profiles/farid.png',
    ),
    DemoProfile(
      'Daan',
      32,
      'Long-term relationship',
      '5–10 km away',
      'Canal cycling, live music, and experimental home cooking.',
      ['Fitness', 'Music', 'Cooking'],
      'assets/profiles/daan.png',
    ),
    DemoProfile(
      'Idrissa',
      35,
      'Open to long-term',
      '2–5 km away',
      'Art spaces, community events, and a great Sunday playlist.',
      ['Arts', 'Music', 'Outdoors'],
      'assets/profiles/idrissa.png',
    ),
    DemoProfile(
      'Sebastian',
      28,
      'Long-term relationship',
      '10–20 km away',
      'Hilltop hikes, street photography, and late coffee.',
      ['Outdoors', 'Arts', 'Travel'],
      'assets/profiles/sebastian.png',
    ),
    DemoProfile(
      'Andrei',
      37,
      'Open to long-term',
      '5–10 km away',
      'Old-town walks, tennis, and hosting relaxed dinners.',
      ['Outdoors', 'Fitness', 'Cooking'],
      'assets/profiles/andrei.png',
    ),
    DemoProfile(
      'Timur',
      30,
      'Long-term relationship',
      '2–5 km away',
      'Modern gardens, architecture books, and weekend road trips.',
      ['Outdoors', 'Books', 'Travel'],
      'assets/profiles/timur.png',
    ),
    DemoProfile(
      'Youssef',
      34,
      'Long-term relationship',
      '5–10 km away',
      'Courtyard cafés, running, and cooking for friends.',
      ['Outdoors', 'Fitness', 'Cooking'],
      'assets/profiles/youssef.png',
    ),
    DemoProfile(
      'Henrik',
      38,
      'Open to long-term',
      '10–20 km away',
      'Harbor walks, design books, and live concerts.',
      ['Outdoors', 'Books', 'Music'],
      'assets/profiles/henrik.png',
    ),
    DemoProfile(
      'Chinedu',
      31,
      'Long-term relationship',
      '2–5 km away',
      'Botanical trails, basketball, and film nights.',
      ['Outdoors', 'Fitness', 'Arts'],
      'assets/profiles/chinedu.png',
    ),
    DemoProfile(
      'Rafael',
      29,
      'Open to long-term',
      '5–10 km away',
      'City plazas, street photography, and weekend cooking.',
      ['Arts', 'Travel', 'Cooking'],
      'assets/profiles/rafael.png',
    ),
    DemoProfile(
      'Batu',
      35,
      'Long-term relationship',
      '10–20 km away',
      'Public gardens, hiking, and architecture podcasts.',
      ['Outdoors', 'Fitness', 'Books'],
      'assets/profiles/batu.png',
    ),
    DemoProfile(
      'Karim',
      36,
      'Long-term relationship',
      '5–10 km away',
      'Seaside walks, running, and home cooking.',
      ['Outdoors', 'Fitness', 'Cooking'],
      'assets/profiles/karim.png',
    ),
    DemoProfile(
      'Marek',
      33,
      'Open to long-term',
      '10–20 km away',
      'River walks, history, and small concerts.',
      ['Outdoors', 'Books', 'Music'],
      'assets/profiles/marek.png',
    ),
    DemoProfile(
      'Tendai',
      38,
      'Long-term relationship',
      '2–5 km away',
      'City gardens, jazz, and dinner parties.',
      ['Outdoors', 'Music', 'Cooking'],
      'assets/profiles/tendai.png',
    ),
    DemoProfile(
      'Joao',
      28,
      'Open to long-term',
      '5–10 km away',
      'City overlooks, football, and photography.',
      ['Travel', 'Fitness', 'Arts'],
      'assets/profiles/joao.png',
    ),
    DemoProfile(
      'Ari',
      31,
      'Long-term relationship',
      '10–20 km away',
      'Harbor trails, hiking, and film nights.',
      ['Outdoors', 'Travel', 'Arts'],
      'assets/profiles/ari.png',
    ),
    DemoProfile(
      'Diego',
      32,
      'Long-term relationship',
      '5–10 km away',
      'Hilltop walks, football, and photography.',
      ['Outdoors', 'Fitness', 'Arts'],
      'assets/profiles/diego.png',
    ),
    DemoProfile(
      'Dawit',
      38,
      'Open to long-term',
      '10–20 km away',
      'Botanical trails, jazz, and Sunday cooking.',
      ['Outdoors', 'Music', 'Cooking'],
      'assets/profiles/dawit.png',
    ),
    DemoProfile(
      'Lars',
      30,
      'Long-term relationship',
      '2–5 km away',
      'Waterfront hikes, books, and live shows.',
      ['Outdoors', 'Books', 'Music'],
      'assets/profiles/lars.png',
    ),
    DemoProfile(
      'Giorgi',
      36,
      'Open to long-term',
      '5–10 km away',
      'Garden terraces, architecture, and dinner parties.',
      ['Outdoors', 'Arts', 'Cooking'],
      'assets/profiles/giorgi.png',
    ),
    DemoProfile(
      'Sami',
      28,
      'Long-term relationship',
      '10–20 km away',
      'Coastal walks, running, and weekend travel.',
      ['Outdoors', 'Fitness', 'Travel'],
      'assets/profiles/sami.png',
    ),
    DemoProfile(
      'Luka',
      35,
      'Long-term relationship',
      '5–10 km away',
      'Seaside walks, photography, and cooking for friends.',
      ['Outdoors', 'Arts', 'Cooking'],
      'assets/profiles/luka.png',
    ),
    DemoProfile(
      'Nicolas',
      31,
      'Open to long-term',
      '10–20 km away',
      'Hillside trails, live music, and weekend travel.',
      ['Outdoors', 'Music', 'Travel'],
      'assets/profiles/nicolas.png',
    ),
    DemoProfile(
      'Kato',
      39,
      'Long-term relationship',
      '5–10 km away',
      'Lakeside gardens, jazz records, and Sunday brunch.',
      ['Outdoors', 'Music', 'Cooking'],
      'assets/profiles/kato.png',
    ),
    DemoProfile(
      'Mikkel',
      29,
      'Open to long-term',
      '2–5 km away',
      'Waterfront runs, novels, and small concerts.',
      ['Fitness', 'Books', 'Music'],
      'assets/profiles/mikkel.png',
    ),
    DemoProfile(
      'Yacine',
      34,
      'Long-term relationship',
      '10–20 km away',
      'Garden terraces, architecture, and coastal drives.',
      ['Outdoors', 'Arts', 'Travel'],
      'assets/profiles/yacine.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _discover(context),
      MatchTab(
        connection: connection,
        onOpenChat: () => setState(() => selectedIndex = 2),
      ),
      ChatTab(
        connection: connection,
        messages: messageRepository.list(connection.matchId),
        onSend: _sendMessage,
        onCallReadinessChanged: (value) => setState(
          () => connection = connection.setCurrentUserCallReady(value),
        ),
        onReport: () => setState(() => connection = connection.report()),
        onUnmatch: () => setState(() => connection = connection.unmatch()),
        onBlock: () => setState(() => connection = connection.block()),
      ),
      ProfileEditor(
        initialProfile: userProfile,
        onSaved: (profile) {
          profileRepository.save(profile);
          setState(() => userProfile = profileRepository.load());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile saved on this device session only.'),
            ),
          );
        },
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Project Ember',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Safety center',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => const SafetySheet(),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) => setState(() => selectedIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Matches',
          ),
          NavigationDestination(
            key: Key('chat-tab'),
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            key: Key('profile-tab'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _discover(BuildContext context) {
    final profile = profiles[profileIndex % profiles.length];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text(
          'PROTOTYPE PROFILE · NOT A REAL PERSON',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 380,
                child: Image.asset(
                  profile.assetPath,
                  key: ValueKey(profile.assetPath),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  semanticLabel: 'Synthetic portrait of ${profile.name}',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.name}, ${profile.age}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('${profile.intent} · ${profile.distanceBand}'),
                    const SizedBox(height: 16),
                    Text(
                      profile.bio,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: profile.interests
                          .map((item) => Chip(label: Text(item)))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.lock_outline, size: 17),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Exact location and precise distance are never shown.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: 'Pass',
              iconSize: 32,
              onPressed: _nextProfile,
              icon: const Icon(Icons.close),
            ),
            const SizedBox(width: 24),
            IconButton.filled(
              tooltip: 'Like',
              iconSize: 32,
              onPressed: _nextProfile,
              icon: const Icon(Icons.favorite),
            ),
          ],
        ),
      ],
    );
  }

  void _nextProfile() => setState(() => profileIndex += 1);

  void _sendMessage(String text) {
    final result = messageRepository.send(
      matchId: connection.matchId,
      text: text,
      connectionActive: connection.canMessage,
    );
    if (!result.accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Message was not sent.')),
      );
      return;
    }
    setState(() {});
  }
}

class DemoProfile {
  const DemoProfile(
    this.name,
    this.age,
    this.intent,
    this.distanceBand,
    this.bio,
    this.interests,
    this.assetPath,
  );
  final String name;
  final int age;
  final String intent;
  final String distanceBand;
  final String bio;
  final List<String> interests;
  final String assetPath;
}

class MatchTab extends StatelessWidget {
  const MatchTab({
    super.key,
    required this.connection,
    required this.onOpenChat,
  });

  final MatchConnection connection;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    if (!connection.isActive) {
      return const EmptyTab(
        icon: Icons.favorite_outline,
        title: 'No active matches',
        message: 'Blocked and unmatched people cannot contact you.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Your matches',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('Synthetic prototype match — not a real person.'),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(connection.peerName),
            subtitle: Text(
              connection.peerCallReady
                  ? 'Matched · open to a call'
                  : 'Matched · text first',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenChat,
          ),
        ),
      ],
    );
  }
}

class ChatTab extends StatelessWidget {
  const ChatTab({
    super.key,
    required this.connection,
    required this.messages,
    required this.onSend,
    required this.onCallReadinessChanged,
    required this.onReport,
    required this.onUnmatch,
    required this.onBlock,
  });

  final MatchConnection connection;
  final List<ChatMessage> messages;
  final ValueChanged<String> onSend;
  final ValueChanged<bool> onCallReadinessChanged;
  final VoidCallback onReport;
  final VoidCallback onUnmatch;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    if (!connection.isActive) {
      final blocked = connection.status == ConnectionStatus.blocked;
      return EmptyTab(
        icon: blocked ? Icons.block : Icons.heart_broken_outlined,
        title: blocked ? 'Blocked' : 'Conversation closed',
        message: blocked
            ? '${connection.peerName} can no longer message or call you.'
            : 'You unmatched. Messaging and calling are disabled.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connection.peerName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text('Synthetic prototype conversation'),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Conversation safety actions',
              onSelected: (value) => _confirmAction(context, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Report privately')),
                PopupMenuItem(value: 'unmatch', child: Text('Unmatch')),
                PopupMenuItem(value: 'block', child: Text('Block')),
              ],
            ),
          ],
        ),
        if (connection.reported)
          const Card(
            color: Color(0xFFFFF1D6),
            child: ListTile(
              leading: Icon(Icons.flag_outlined),
              title: Text('Report saved for review'),
              subtitle: Text('The other person is not notified.'),
            ),
          ),
        const SizedBox(height: 18),
        ...messages.map(
          (message) => Align(
            alignment: message.author == MessageAuthor.currentUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Card(
              color: message.author == MessageAuthor.currentUser
                  ? const Color(0xFFFFD9E3)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(message.text),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Call readiness',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'No surprise calls. Both people opt in, and every call still requires acceptance.',
                ),
                SwitchListTile(
                  key: const Key('call-ready-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I am open to a call'),
                  value: connection.currentUserCallReady,
                  onChanged: onCallReadinessChanged,
                ),
                Text(
                  connection.peerCallReady
                      ? '${connection.peerName} is also open to a call.'
                      : '${connection.peerName} has not opted in.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('request-video-call'),
                  onPressed: connection.canRequestCall
                      ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Prototype only: no camera, microphone, or network connection was opened.',
                            ),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Request video call'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('message-composer'),
          enabled: connection.canMessage,
          maxLength: MessagePolicy.maxCharacters,
          textInputAction: TextInputAction.send,
          onSubmitted: onSend,
          decoration: const InputDecoration(
            labelText: 'Message',
            helperText: 'Press send on the keyboard. Anti-spam limits apply.',
            suffixIcon: Icon(Icons.send_outlined),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAction(BuildContext context, String action) async {
    if (action == 'report') {
      onReport();
      return;
    }
    final verb = action == 'block' ? 'Block' : 'Unmatch';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$verb ${connection.peerName}?'),
        content: Text(
          action == 'block'
              ? 'They will immediately lose access to this conversation and cannot call you.'
              : 'This closes the conversation and disables messages and calls.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Key('confirm-$action'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(verb),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (action == 'block') {
      onBlock();
    } else {
      onUnmatch();
    }
  }
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.initialProfile,
    required this.onSaved,
  });

  final UserProfile? initialProfile;
  final ValueChanged<UserProfile> onSaved;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  static const availableInterests = [
    'Arts',
    'Books',
    'Cooking',
    'Fitness',
    'Music',
    'Outdoors',
    'Travel',
  ];
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController ageController;
  late final TextEditingController bioController;
  late RelationshipIntent intent;
  late Set<String> interests;
  late bool showDistanceBand;
  late bool callReadyByDefault;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    nameController = TextEditingController(text: profile?.displayName ?? '');
    ageController = TextEditingController(text: profile?.age.toString() ?? '');
    bioController = TextEditingController(text: profile?.bio ?? '');
    intent = profile?.intent ?? RelationshipIntent.openToLongTerm;
    interests = {...?profile?.interests};
    showDistanceBand = profile?.showDistanceBand ?? true;
    callReadyByDefault = profile?.callReadyByDefault ?? false;
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: SingleChildScrollView(
      key: const Key('profile-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your profile',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Prototype data stays in memory and disappears when the app closes.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('profile-name'),
            controller: nameController,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: (value) => UserProfile.validateName(value ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('profile-age'),
            controller: ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age'),
            validator: (value) => UserProfile.validateAge(value ?? ''),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RelationshipIntent>(
            key: const Key('profile-intent'),
            initialValue: intent,
            decoration: const InputDecoration(
              labelText: 'What are you looking for?',
            ),
            items: RelationshipIntent.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => intent = value ?? intent),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('profile-bio'),
            controller: bioController,
            maxLength: 300,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'About you',
              hintText: 'What would you enjoy talking about?',
            ),
            validator: (value) => UserProfile.validateBio(value ?? ''),
          ),
          const SizedBox(height: 10),
          Text('Interests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: availableInterests
                .map(
                  (value) => FilterChip(
                    label: Text(value),
                    selected: interests.contains(value),
                    onSelected: (selected) => setState(
                      () => selected
                          ? interests.add(value)
                          : interests.remove(value),
                    ),
                  ),
                )
                .toList(),
          ),
          if (interests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Choose at least one interest.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show a coarse distance band'),
            subtitle: const Text('Exact location is never displayed.'),
            value: showDistanceBand,
            onChanged: (value) => setState(() => showDistanceBand = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Open to calls by default'),
            subtitle: const Text(
              'Calls still require a match, mutual readiness, and acceptance.',
            ),
            value: callReadyByDefault,
            onChanged: (value) => setState(() => callReadyByDefault = value),
          ),
          const SizedBox(height: 14),
          FilledButton(
            key: const Key('save-profile'),
            onPressed: _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Save profile'),
            ),
          ),
        ],
      ),
    ),
  );

  void _save() {
    if (!(formKey.currentState?.validate() ?? false) || interests.isEmpty) {
      return;
    }
    widget.onSaved(
      UserProfile(
        displayName: nameController.text.trim(),
        age: int.parse(ageController.text.trim()),
        intent: intent,
        bio: bioController.text.trim(),
        interests: interests.toList()..sort(),
        showDistanceBand: showDistanceBand,
        callReadyByDefault: callReadyByDefault,
      ),
    );
  }
}

class EmptyTab extends StatelessWidget {
  const EmptyTab({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class SafetySheet extends StatelessWidget {
  const SafetySheet({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Safety center',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.block),
            title: Text('Block and report'),
            subtitle: Text(
              'Available from every profile, conversation, and call.',
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.videocam_outlined),
            title: Text('Calls require mutual readiness'),
            subtitle: Text(
              'A match can always decline. Calls are not recorded.',
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.location_off_outlined),
            title: Text('Location stays coarse'),
            subtitle: Text(
              'Profiles show distance bands, never exact coordinates.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}
