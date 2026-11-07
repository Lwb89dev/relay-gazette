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
    final isSport = colors.style == GazetteVisualStyle.sport;
    final isDark = colors.style == GazetteVisualStyle.nocturne;
    final nameplateColor = isSport || isDark ? colors.accent : colors.ink;
    final nameplateFamily = isSport ? 'PlayfairDisplay' : 'UnifrakturCook';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, compact ? 14 : 22, 20, 18),
          child: Column(
            children: [
              _Rule(color: nameplateColor, thickness: isSport ? 4 : 3),
              const SizedBox(height: 7),
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
              const SizedBox(height: 7),
              _Rule(color: colors.rule),
              SizedBox(height: compact ? 12 : 18),
              Text(
                'The',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFamily: nameplateFamily,
                  fontWeight: isSport ? FontWeight.w800 : FontWeight.normal,
                  fontStyle: isSport ? FontStyle.italic : FontStyle.normal,
                  fontSize: isSport ? (compact ? 13 : 15) : (compact ? 22 : 28),
                  height: 0.9,
                  letterSpacing: isSport ? 3.2 : 1,
                  color: nameplateColor,
                ),
              ),
              SizedBox(height: isSport ? 8 : 4),
              Text(
                'Relay Gazette',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFamily: nameplateFamily,
                  fontWeight: isSport ? FontWeight.w900 : FontWeight.normal,
                  fontStyle: isSport ? FontStyle.italic : FontStyle.normal,
                  fontSize: isSport ? (compact ? 39 : 56) : (compact ? 42 : 57),
                  height: 0.9,
                  letterSpacing: isSport ? -1.4 : 0.7,
                  color: nameplateColor,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'ALL THE NOTES FIT TO RANK',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSport ? colors.ink : colors.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: colors.paperMuted.withValues(alpha: 0.45),
                  border: Border(
                    top: BorderSide(color: colors.ink, width: 1.5),
                    bottom: BorderSide(color: colors.ink, width: 1.5),
                  ),
                ),
                child: Row(
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
              ),
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
