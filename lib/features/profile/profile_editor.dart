import 'package:flutter/material.dart';

import '../../domain/gender.dart';
import '../../domain/lifestyle.dart';
import '../../domain/profile_prompt.dart';
import '../../domain/user_profile.dart';
import '../../theme/vawra_theme.dart';
import '../shared/lifestyle_picker.dart';
import 'photo_tips.dart';
import 'profile_preview.dart';
import 'prompts_section.dart';

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.initialProfile,
    required this.onSaved,
    this.prototypeMode = true,
  });

  final UserProfile? initialProfile;
  final ValueChanged<UserProfile> onSaved;
  final bool prototypeMode;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController ageController;
  late final TextEditingController bioController;
  late RelationshipIntent intent;
  late Set<String> interests;
  late bool showDistanceBand;
  late bool callReadyByDefault;
  late Map<LifestyleTopic, String> lifestyle;
  late List<ProfilePrompt> prompts;
  Gender? gender;
  late Set<Gender> showMe;
  late bool showGender;

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
    lifestyle = {...?profile?.lifestyle};
    prompts = [...?profile?.prompts];
    gender = profile?.gender;
    showMe = {...?profile?.showMe};
    showGender = profile?.showGender ?? false;
    bioController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    bioController.removeListener(_refresh);
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  VawraColors.plum,
                  Color(0xFF8A346C),
                  VawraColors.coral,
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x255A274F),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(
                    'assets/branding/vawra_company_mark_clean.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialProfile == null
                            ? 'Create your profile'
                            : 'Make your profile memorable',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Give someone an easy reason to start a real conversation.',
                        style: TextStyle(
                          color: Color(0xFFFFEAF1),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.prototypeMode
                ? 'Prototype data stays in memory and disappears when the app closes.'
                : 'Changes are saved to your account when you tap Save.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('preview-card'),
            onPressed: () => ProfilePreviewSheet.show(context, _draft()),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview my card'),
          ),
          const SizedBox(height: 12),
          ProfileStrengthCard(
            hasIntro: bioController.text.trim().isNotEmpty,
            interestCount: interests.length,
            hasLifestyle: lifestyle.isNotEmpty,
            hasPrompt: prompts.isNotEmpty,
          ),
          const SizedBox(height: 12),
          const PhotosCard(),
          const SizedBox(height: 22),
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
            isExpanded: true,
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
          DropdownButtonFormField<Gender>(
            key: const Key('profile-gender'),
            initialValue: gender,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'I am'),
            items: Gender.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => gender = value ?? gender),
          ),
          const SizedBox(height: 16),
          Text('Show me', style: Theme.of(context).textTheme.titleMedium),
          const Text('Private. Only used to find matches, never shown.'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                key: const Key('profile-showme-everyone'),
                label: const Text('Everyone'),
                selected: showMe.isEmpty,
                onSelected: (_) => setState(showMe.clear),
              ),
              for (final value in Gender.values)
                FilterChip(
                  key: Key('profile-showme-${value.backendKey}'),
                  label: Text(value.plural),
                  selected: showMe.contains(value),
                  onSelected: (selected) => setState(() {
                    selected ? showMe.add(value) : showMe.remove(value);
                    // All three is the same as everyone.
                    if (showMe.length == Gender.values.length) showMe.clear();
                  }),
                ),
            ],
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
              hintText: 'Optional. What would you enjoy talking about?',
            ),
            validator: (value) => UserProfile.validateBio(value ?? ''),
          ),
          const SizedBox(height: 10),
          Text('Interests', style: Theme.of(context).textTheme.titleMedium),
          const Text('Choose at least one'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: UserProfile.availableInterests
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
          const SizedBox(height: 18),
          PromptsSection(
            prompts: prompts,
            onChanged: (updated) => setState(() => prompts = updated),
          ),
          const SizedBox(height: 18),
          Text('Lifestyle', style: Theme.of(context).textTheme.titleMedium),
          const Text('Optional. Tap a chosen answer again to clear it.'),
          const SizedBox(height: 12),
          LifestylePicker(
            selected: lifestyle,
            onChanged: (topic, option) => setState(
              () => lifestyle[topic] == option
                  ? lifestyle.remove(topic)
                  : lifestyle[topic] = option,
            ),
          ),
          const SizedBox(height: 18),
          Material(
            color: VawraColors.lavender,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('profile-show-gender'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show my gender on my profile'),
                    subtitle: const Text('Off means only matching uses it.'),
                    value: showGender,
                    onChanged: gender == null
                        ? null
                        : (value) => setState(() => showGender = value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show a coarse distance band'),
                    subtitle: const Text('Exact location is never displayed.'),
                    value: showDistanceBand,
                    onChanged: (value) =>
                        setState(() => showDistanceBand = value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Open to calls by default'),
                    subtitle: const Text(
                      'Calls still require a match, mutual readiness, and acceptance.',
                    ),
                    value: callReadyByDefault,
                    onChanged: (value) =>
                        setState(() => callReadyByDefault = value),
                  ),
                ],
              ),
            ),
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

  /// The current form as a profile, unvalidated, for the preview.
  UserProfile _draft() => UserProfile(
    displayName: nameController.text,
    age: int.tryParse(ageController.text.trim()) ?? 18,
    intent: intent,
    bio: bioController.text.trim(),
    interests: interests.toList()..sort(),
    showDistanceBand: showDistanceBand,
    callReadyByDefault: callReadyByDefault,
    lifestyle: Map.unmodifiable(lifestyle),
    prompts: List.unmodifiable(prompts),
    gender: gender,
    showMe: Set.unmodifiable(showMe),
    showGender: showGender,
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
        lifestyle: Map.unmodifiable(lifestyle),
        prompts: List.unmodifiable(prompts),
        gender: gender,
        showMe: Set.unmodifiable(showMe),
        showGender: showGender,
      ),
    );
  }
}
