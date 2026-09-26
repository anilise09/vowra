import 'package:flutter/material.dart';

import '../../domain/lifestyle.dart';
import '../../theme/vawra_theme.dart';

/// One-choice-per-topic chip groups; tapping the chosen chip clears it.
class LifestylePicker extends StatelessWidget {
  const LifestylePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Map<LifestyleTopic, String> selected;
  final void Function(LifestyleTopic topic, String option) onChanged;

  static const _icons = {
    LifestyleTopic.drinking: Icons.local_bar_outlined,
    LifestyleTopic.smoking: Icons.smoke_free_rounded,
    LifestyleTopic.exercise: Icons.directions_run_rounded,
    LifestyleTopic.pets: Icons.pets_outlined,
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final topic in LifestyleTopic.values) ...[
        if (topic.index > 0) const Divider(height: 28),
        Row(
          children: [
            Icon(_icons[topic], size: 20, color: VawraColors.plum),
            const SizedBox(width: 8),
            Text(topic.label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in topic.options)
              ChoiceChip(
                key: Key('lifestyle-${topic.name}-$option'),
                label: Text(option),
                selected: selected[topic] == option,
                selectedColor: VawraColors.blush,
                side: BorderSide(
                  color: selected[topic] == option
                      ? VawraColors.coral
                      : const Color(0xFFE2D7DE),
                ),
                onSelected: (_) => onChanged(topic, option),
              ),
          ],
        ),
      ],
    ],
  );
}
