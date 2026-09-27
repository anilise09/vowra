import 'package:flutter/material.dart';

import '../../domain/profile_prompt.dart';
import '../../theme/vawra_theme.dart';

/// Up to two prompts: pick a question, then answer it in a line or two.
class PromptsSection extends StatelessWidget {
  const PromptsSection({
    super.key,
    required this.prompts,
    required this.onChanged,
  });

  final List<ProfilePrompt> prompts;
  final ValueChanged<List<ProfilePrompt>> onChanged;

  Future<void> _add(BuildContext context) async {
    final used = prompts.map((p) => p.question).toSet();
    final question = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          key: const Key('prompt-picker'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              'Choose a prompt',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final q in ProfilePrompt.questions)
              if (!used.contains(q))
                ListTile(
                  title: Text(q),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(sheetContext, q),
                ),
          ],
        ),
      ),
    );
    if (question == null || !context.mounted) return;
    final answer = await _answer(context, question, '');
    if (answer == null) return;
    onChanged([...prompts, ProfilePrompt(question, answer)]);
  }

  Future<String?> _answer(
    BuildContext context,
    String question,
    String initial,
  ) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final error = controller.text.isEmpty
              ? null
              : ProfilePrompt.validateAnswer(controller.text);
          return AlertDialog(
            title: Text(question),
            content: TextField(
              key: const Key('prompt-answer'),
              controller: controller,
              autofocus: true,
              maxLength: ProfilePrompt.maxAnswer,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Your answer',
                errorText: error,
              ),
              onChanged: (_) => setDialogState(() {}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('prompt-save'),
                onPressed: ProfilePrompt.validateAnswer(controller.text) == null
                    ? () => Navigator.pop(dialogContext, controller.text.trim())
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('prompts-section'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Prompts', style: Theme.of(context).textTheme.titleMedium),
      const Text('Optional. Up to two. Great conversation starters.'),
      const SizedBox(height: 10),
      for (var i = 0; i < prompts.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0E5EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompts[i].question,
                      style: const TextStyle(
                        color: VawraColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prompts[i].answer,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit prompt',
                onPressed: () async {
                  final answer = await _answer(
                    context,
                    prompts[i].question,
                    prompts[i].answer,
                  );
                  if (answer == null) return;
                  onChanged([
                    for (var j = 0; j < prompts.length; j++)
                      j == i
                          ? ProfilePrompt(prompts[i].question, answer)
                          : prompts[j],
                  ]);
                },
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Remove prompt',
                onPressed: () => onChanged([...prompts]..removeAt(i)),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      if (prompts.length < ProfilePrompt.maxPrompts)
        OutlinedButton.icon(
          key: const Key('add-prompt'),
          onPressed: () => _add(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a prompt'),
        ),
    ],
  );
}
