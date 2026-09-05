import 'package:flutter/material.dart';

import '../theme/gazette_colors.dart';
import 'onboarding_step_list.dart';

/// Onboarding, page 2 of 3: what a reader can actually do once an edition
/// is open — signing in (page 3) unlocks the interactive ones.
class InteractionsPage extends StatelessWidget {
  const InteractionsPage({super.key});

  static const _actions = [
    (
      Icons.favorite_border,
      'Heart a story',
      'A quick reaction, sent as a real Nostr event — visible to the author and anyone else.',
    ),
    (
      Icons.format_quote_outlined,
      'Highlight a passage',
      'Save the exact sentence worth keeping (NIP-84) — not the whole note, just the good part.',
    ),
    (
      Icons.photo_library_outlined,
      'Swipe through photos',
      'A story with more than one image becomes a slider — swipe between them, tap to view full-screen.',
    ),
    (
      Icons.menu_book_outlined,
      'Continue reading',
      'A long note or article is never cut off with nowhere to go — there\'s always a full page to open.',
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
                'What you can do\nwith a story',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 8),
              Text(
                'Reading never requires signing in — hearting, highlighting, and zapping do, '
                'once you connect a signer on the next page.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.inkFaded,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 28),
              OnboardingStepList(steps: _actions),
            ],
          ),
        ),
      ),
    );
  }
}
