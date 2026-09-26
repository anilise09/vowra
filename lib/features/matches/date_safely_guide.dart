import 'package:flutter/material.dart';

import '../../theme/vawra_theme.dart';

/// Three short pages of safety guidance shown the first time Chats opens.
/// Always reachable again from the shield in the Chats header.
class DateSafelyGuide extends StatefulWidget {
  const DateSafelyGuide({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const DateSafelyGuide(),
  );

  @override
  State<DateSafelyGuide> createState() => _DateSafelyGuideState();
}

class _GuidePage {
  const _GuidePage(this.icon, this.points);

  final IconData icon;
  final List<(String, String)> points;
}

const _pages = [
  _GuidePage(Icons.favorite_outline_rounded, [
    (
      'Kindness first',
      'No insults, threats or pressure. Vawra has no room for hate or discrimination.',
    ),
    (
      'Consent, always',
      'Ask before raising anything intimate, and take no for an answer.',
    ),
  ]),
  _GuidePage(Icons.savings_outlined, [
    (
      'Money talk is a red flag',
      'Nobody genuine asks a new match for money, gift cards or crypto. You can say no and leave.',
    ),
    (
      'Too good to be true?',
      'Investment tips and quick-profit offers from matches are almost always scams.',
    ),
  ]),
  _GuidePage(Icons.shield_outlined, [
    (
      'Go at your pace',
      'Keep chatting here until you are ready. A video call needs both of you to opt in.',
    ),
    (
      'Block and report are free',
      'Blocking ends contact straight away. Reports are private; the other person is never told.',
    ),
  ]),
];

class _DateSafelyGuideState extends State<DateSafelyGuide> {
  final controller = PageController();
  var page = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = page == _pages.length - 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: VawraColors.coral),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Date safely',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                key: const Key('safety-guide-close'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            // Tall enough for large text; each page also scrolls if needed.
            height: (MediaQuery.sizeOf(context).height * 0.5).clamp(
              300.0,
              460.0,
            ),
            child: PageView(
              key: const Key('safety-guide-pages'),
              controller: controller,
              onPageChanged: (value) => setState(() => page = value),
              children: [
                for (final guide in _pages)
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 96,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [VawraColors.blush, VawraColors.lavender],
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            guide.icon,
                            size: 44,
                            color: VawraColors.plum,
                          ),
                        ),
                        for (final (title, body) in guide.points) ...[
                          const SizedBox(height: 16),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(body),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == page
                        ? VawraColors.coral
                        : const Color(0xFFE2D7DE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('safety-guide-next'),
            onPressed: () => last
                ? Navigator.pop(context)
                : controller.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(last ? 'Got it' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }
}
