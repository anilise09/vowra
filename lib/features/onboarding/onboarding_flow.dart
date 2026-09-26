import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/user_profile.dart';
import '../../theme/vawra_theme.dart';

/// One question per screen. Name, age, intent and interests are required;
/// the bio can be skipped; privacy and call defaults are pre-set safely.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onComplete});

  final ValueChanged<UserProfile> onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Step { name, age, intent, interests, bio, privacy }

class _OnboardingFlowState extends State<OnboardingFlow> {
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final bioController = TextEditingController();
  var step = _Step.name;
  RelationshipIntent? intent;
  final interests = <String>{};
  var showDistanceBand = true;
  var callReadyByDefault = false;

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    bioController.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (step) {
    _Step.name => UserProfile.validateName(nameController.text) == null,
    _Step.age => UserProfile.validateAge(ageController.text) == null,
    _Step.intent => intent != null,
    _Step.interests => interests.isNotEmpty,
    _Step.bio => UserProfile.validateBio(bioController.text) == null,
    _Step.privacy => true,
  };

  void _next() {
    if (!_canContinue) return;
    if (step == _Step.privacy) {
      widget.onComplete(
        UserProfile(
          displayName: nameController.text.trim(),
          age: int.parse(ageController.text.trim()),
          intent: intent!,
          bio: bioController.text.trim(),
          interests: interests.toList()..sort(),
          showDistanceBand: showDistanceBand,
          callReadyByDefault: callReadyByDefault,
        ),
      );
      return;
    }
    setState(() => step = _Step.values[step.index + 1]);
  }

  void _skipBio() {
    bioController.clear();
    setState(() => step = _Step.privacy);
  }

  void _back() {
    if (step == _Step.name) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => step = _Step.values[step.index - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final total = _Step.values.length;
    return PopScope(
      canPop: step == _Step.name,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: VawraColors.canvas,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('onboarding-back'),
                          tooltip: 'Back',
                          onPressed: _back,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: (step.index + 1) / total),
                              duration: const Duration(milliseconds: 250),
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                    key: const Key('onboarding-progress'),
                                    value: value,
                                    minHeight: 6,
                                    color: VawraColors.coral,
                                    backgroundColor: const Color(0xFFF0E6EB),
                                    semanticsLabel: 'Profile setup progress',
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: step == _Step.bio
                              ? TextButton(
                                  key: const Key('onboarding-skip'),
                                  onPressed: _skipBio,
                                  child: const Text('Skip'),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.06, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: SingleChildScrollView(
                        key: ValueKey(step),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: _stepBody(context, total),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('onboarding-next'),
                        onPressed: _canContinue ? _next : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            step == _Step.privacy
                                ? 'Start discovering'
                                : 'Continue',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(BuildContext context, int total) {
    final (title, helper) = switch (step) {
      _Step.name => (
        'What should matches call you?',
        'Your first name or the name you go by.',
      ),
      _Step.age => (
        'How old are you?',
        'Vawra is for adults 18 and over. Only your age is shown, never a birthday.',
      ),
      _Step.intent => (
        'What are you hoping to find?',
        'Shown on your profile so expectations are clear from the start.',
      ),
      _Step.interests => (
        'What do you enjoy?',
        'Pick up to ${UserProfile.maxInterests}. They give matches an easy way to start talking.',
      ),
      _Step.bio => (
        'Add a short intro',
        'A few lines a match could ask you about. You can skip this and add it later.',
      ),
      _Step.privacy => (
        'Your privacy, your call',
        'You can change these any time from your profile.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${step.index + 1} of $total',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: VawraColors.coral),
        ),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(helper, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        switch (step) {
          _Step.name => TextField(
            key: const Key('onboarding-name'),
            controller: nameController,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'First name'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _next(),
          ),
          _Step.age => _AgeField(
            controller: ageController,
            onChanged: () => setState(() {}),
            onSubmitted: _next,
          ),
          _Step.intent => Column(
            children: RelationshipIntent.values
                .map(
                  (value) => _IntentCard(
                    intent: value,
                    selected: intent == value,
                    onTap: () => setState(() => intent = value),
                  ),
                )
                .toList(),
          ),
          _Step.interests => _InterestPicker(
            selected: interests,
            onToggle: (value) => setState(
              () => interests.contains(value)
                  ? interests.remove(value)
                  : interests.add(value),
            ),
          ),
          _Step.bio => TextField(
            key: const Key('onboarding-bio'),
            controller: bioController,
            maxLength: 300,
            minLines: 4,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Weekend plans, a small obsession, a good first date…',
              errorText: UserProfile.validateBio(bioController.text),
            ),
            onChanged: (_) => setState(() {}),
          ),
          _Step.privacy => _PrivacyChoices(
            showDistanceBand: showDistanceBand,
            callReadyByDefault: callReadyByDefault,
            onDistanceChanged: (value) =>
                setState(() => showDistanceBand = value),
            onCallsChanged: (value) =>
                setState(() => callReadyByDefault = value),
          ),
        },
      ],
    );
  }
}

class _AgeField extends StatelessWidget {
  const _AgeField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = controller.text.trim();
    // Only speak up once a full two-digit age is typed.
    final error = text.length < 2 ? null : UserProfile.validateAge(text);
    return TextField(
      key: const Key('onboarding-age'),
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: 'Age', errorText: error),
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted(),
    );
  }
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.intent,
    required this.selected,
    required this.onTap,
  });

  final RelationshipIntent intent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, detail) = switch (intent) {
      RelationshipIntent.longTerm => (
        Icons.favorite_rounded,
        'Looking for a committed partner.',
      ),
      RelationshipIntent.openToLongTerm => (
        Icons.favorite_border_rounded,
        'Happy to see where it leads.',
      ),
      RelationshipIntent.casual => (
        Icons.local_cafe_outlined,
        'Easygoing dates, no pressure.',
      ),
      RelationshipIntent.figuringItOut => (
        Icons.explore_outlined,
        'Still deciding, and that is fine.',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? VawraColors.blush : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected ? VawraColors.coral : const Color(0xFFE2D7DE),
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            key: Key('intent-${intent.backendKey}'),
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: selected
                        ? VawraColors.coral
                        : VawraColors.lavender,
                    child: Icon(
                      icon,
                      color: selected ? Colors.white : VawraColors.plum,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          intent.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(detail),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: VawraColors.coral,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestPicker extends StatelessWidget {
  const _InterestPicker({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final full = selected.length >= UserProfile.maxInterests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: UserProfile.availableInterests.map((value) {
            final isSelected = selected.contains(value);
            return FilterChip(
              key: Key('interest-$value'),
              label: Text(value),
              selected: isSelected,
              showCheckmark: true,
              selectedColor: VawraColors.blush,
              checkmarkColor: VawraColors.coral,
              side: BorderSide(
                color: isSelected ? VawraColors.coral : const Color(0xFFE2D7DE),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              onSelected: !isSelected && full ? null : (_) => onToggle(value),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text(
          '${selected.length} of ${UserProfile.maxInterests} chosen',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PrivacyChoices extends StatelessWidget {
  const _PrivacyChoices({
    required this.showDistanceBand,
    required this.callReadyByDefault,
    required this.onDistanceChanged,
    required this.onCallsChanged,
  });

  final bool showDistanceBand;
  final bool callReadyByDefault;
  final ValueChanged<bool> onDistanceChanged;
  final ValueChanged<bool> onCallsChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: VawraColors.lavender,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('onboarding-distance'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Show a rough distance'),
                subtitle: const Text(
                  'Matches see a band like "5–10 km away", never where you are.',
                ),
                value: showDistanceBand,
                onChanged: onDistanceChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                key: const Key('onboarding-calls'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Open to video calls'),
                subtitle: const Text(
                  'Only with a match, only when you both opt in, and never recorded.',
                ),
                value: callReadyByDefault,
                onChanged: onCallsChanged,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 20, color: VawraColors.plum),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Matching, messaging, blocking and reporting are always free. '
              'This prototype keeps your answers on this device only.',
            ),
          ),
        ],
      ),
    ],
  );
}
