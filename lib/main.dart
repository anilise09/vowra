import 'package:flutter/material.dart';

import 'data/profile_repository.dart';
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
  UserProfile? userProfile;
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
