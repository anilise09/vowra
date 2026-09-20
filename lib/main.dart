import 'package:flutter/material.dart';

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
  static const profiles = [
    DemoProfile(
      'Maya',
      29,
      'Long-term relationship',
      '2–5 km away',
      'Sunday markets, tiny concerts, and ambitious pasta experiments.',
      ['Kindness', 'Live music', 'Cooking'],
    ),
    DemoProfile(
      'Jordan',
      31,
      'Open to long-term',
      '5–10 km away',
      'Climber, reader, and the friend who plans the whole road trip.',
      ['Outdoors', 'Books', 'Travel'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _discover(context),
      const EmptyTab(
        icon: Icons.favorite_outline,
        title: 'No matches yet',
        message: 'Mutual likes will appear here.',
      ),
      const EmptyTab(
        icon: Icons.chat_bubble_outline,
        title: 'Your conversations',
        message: 'Messaging opens only after a mutual match.',
      ),
      const EmptyTab(
        icon: Icons.person_outline,
        title: 'Build your profile',
        message: 'Profile editing arrives in the next vertical slice.',
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
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
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
              Container(
                height: 290,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF5B4C6), Color(0xFFFCE3C3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 150,
                  color: Colors.white70,
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
}

class DemoProfile {
  const DemoProfile(
    this.name,
    this.age,
    this.intent,
    this.distanceBand,
    this.bio,
    this.interests,
  );
  final String name;
  final int age;
  final String intent;
  final String distanceBand;
  final String bio;
  final List<String> interests;
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
