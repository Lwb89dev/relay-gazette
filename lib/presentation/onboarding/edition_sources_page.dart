import 'package:flutter/material.dart';

import '../theme/gazette_colors.dart';
import 'onboarding_step_list.dart';

/// Onboarding, page 1 of 3: how an edition actually gets built — which
/// source its stories are drawn from, chosen each time a reader generates
/// one (`EditionSource`, `edition_configuration_page.dart`'s `_SourceSelector`).
class EditionSourcesPage extends StatelessWidget {
  const EditionSourcesPage({super.key});

  static const _sources = [
    (
      Icons.hub_outlined,
      'Web of Trust',
      'Content your wider network — not just who you follow directly — has engaged with. '
          'The closest thing to word-of-mouth trust, computed for you instead of guessed at.',
    ),
    (
      Icons.trending_up,
      'Trending',
      'What\'s resonating across the wider Nostr network right now, regardless of who you follow.',
    ),
    (
      Icons.people_outline,
      'From Your Network',
      'Only the people you actually follow — your own contact list, nothing algorithmic.',
    ),
    (
      Icons.list_alt_outlined,
      'From a List',
      'A NIP-51 list you curate yourself, when you want an edition about one specific topic or group.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How your edition\nis built',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 8),
              Text(
                'Nostr produces the stream. You choose which source The Relay Gazette '
                'produces this edition from.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.inkFaded,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 28),
              OnboardingStepList(steps: _sources),
            ],
          ),
        ),
      ),
    );
  }
}
