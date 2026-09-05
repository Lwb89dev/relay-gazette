import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/gazette_edition.dart';
import '../../theme/gazette_colors.dart';

/// A front-page masthead: volume/issue and date on one rule, the paper's
/// name, a standing motto, then a second rule with this edition's stats —
/// the newspaper equivalent of a feed's "N new posts" counter, but framed
/// as what it actually is: a finite, dated publication.
class Masthead extends StatelessWidget {
  final GazetteEdition edition;
  final int editionNumber;
  final int authorCount;

  const Masthead({
    super.key,
    required this.edition,
    required this.editionNumber,
    required this.authorCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    final date = DateFormat(
      'EEEE, MMMM d, y',
    ).format(edition.generatedAt.toLocal());
    final sourceLabel = edition.source.label;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, compact ? 16 : 22, 20, 16),
          child: Column(
            children: [
              _Rule(color: colors.ink),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'VOL. I · NO. $editionNumber',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      date.toUpperCase(),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _Rule(color: colors.ink),
              SizedBox(height: compact ? 14 : 20),
              Text(
                'The',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFamily: 'UnifrakturCook',
                  fontWeight: FontWeight.normal,
                  fontSize: compact ? 24 : 30,
                  height: 0.9,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Relay Gazette',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFamily: 'UnifrakturCook',
                  fontWeight: FontWeight.normal,
                  fontSize: compact ? 40 : 54,
                  height: 0.92,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ALL THE NOTES FIT TO RANK',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              _Rule(color: colors.rule, thickness: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sourceLabel.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'PAST ${edition.filterConfiguration.timeWindow.label.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${edition.storyCount} STORIES · $authorCount AUTHORS',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Rule(color: colors.rule, thickness: 1),
            ],
          ),
        );
      },
    );
  }
}

class _Rule extends StatelessWidget {
  final Color color;
  final double thickness;
  const _Rule({required this.color, this.thickness = 2});

  @override
  Widget build(BuildContext context) =>
      Container(height: thickness, color: color);
}
