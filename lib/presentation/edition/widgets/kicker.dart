import 'package:flutter/material.dart';

import '../../theme/gazette_colors.dart';

/// The small colored overline above a headline (e.g. "TOP STORIES",
/// "FROM YOUR NETWORK") — a section label, not a headline itself.
class Kicker extends StatelessWidget {
  final String text;
  const Kicker({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.gazetteColors.accent,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}
