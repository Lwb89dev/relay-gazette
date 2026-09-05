import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/story.dart';
import '../../theme/gazette_colors.dart';

/// Author avatar + name + relative time — shared between every story
/// block regardless of how prominently that story is displayed.
class ByLine extends StatelessWidget {
  final Story story;
  final double avatarRadius;

  const ByLine({super.key, required this.story, this.avatarRadius = 14});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    final picture = story.author.pictureUrl;
    return Row(
      children: [
        CircleAvatar(
          radius: avatarRadius,
          backgroundColor: colors.paperMuted,
          foregroundImage: picture != null
              ? CachedNetworkImageProvider(picture)
              : null,
          child: picture == null
              ? Text(
                  story.author.label.isEmpty
                      ? '?'
                      : story.author.label[0].toUpperCase(),
                  style: theme.textTheme.labelMedium,
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            story.author.label,
            style: theme.textTheme.labelLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(relativeTime(story.createdAt), style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class EngagementFooter extends StatelessWidget {
  final Story story;
  const EngagementFooter({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final e = story.engagement;
    final parts = <String>[
      if (e.reactions > 0) '${e.reactions} hearts',
      if (e.zapSats > 0) '${e.zapSats} sats',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('   ·   '),
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

String relativeTime(DateTime time) {
  final diff = DateTime.now().toUtc().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
