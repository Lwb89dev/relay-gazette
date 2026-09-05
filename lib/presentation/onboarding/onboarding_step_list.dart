import 'package:flutter/material.dart';

import '../theme/gazette_colors.dart';

/// The icon/title/subtitle row shared by every onboarding explanation page
/// — one visual pattern for "here's a list of things to know", reused
/// across the edition-sources and interactions pages rather than each
/// re-styling its own list.
class OnboardingStepList extends StatelessWidget {
  final List<(IconData, String, String)> steps;
  const OnboardingStepList({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    return Column(
      children: [
        for (final (icon, title, subtitle) in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: colors.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.labelLarge),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: colors.inkFaded, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
