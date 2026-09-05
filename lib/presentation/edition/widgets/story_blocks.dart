import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../domain/entities/story.dart';
import '../../../domain/usecases/story_headline.dart';
import '../../theme/gazette_colors.dart';
import '../article_reader_page.dart';
import 'drop_cap_text.dart';
import 'fullscreen_image_viewer.dart';
import 'kicker.dart';
import 'story_actions.dart';
import 'story_meta.dart';

/// The headline/body pair to display for [story]: a NIP-23 article uses
/// its own `title`/`summary` tags verbatim; a plain note falls back to
/// [extractHeadline] splitting its content, since it has no such tags.
/// Public because `ArticleReaderPage` needs the same headline for its own
/// title.
StoryHeadline headlineFor(Story story) {
  if (story.isLongFormArticle) {
    return StoryHeadline(
      headline: story.title ?? story.content,
      body: story.summary,
    );
  }
  return extractHeadline(story.content);
}

/// The newspaper "jump line" — a real paper doesn't just cut a story off
/// mid-sentence with nowhere to go; it says "continued on page 12". Shown
/// on *any* story whose body is being clipped for layout (a long note in
/// [StoryBlock]/[_BriefItem]'s few lines, not just a NIP-23 long-form
/// article), so there's always a way to actually finish reading.
class _ContinueReadingLink extends StatelessWidget {
  final Story article;
  const _ContinueReadingLink({required this.article});

  @override
  Widget build(BuildContext context) {
    final colors = context.gazetteColors;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArticleReaderPage(article: article),
          ),
        ),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
        ),
        child: Text(
          'Continue reading →',
          style: TextStyle(color: colors.accent, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// The lead story: kicker, a large headline, its image (if any), a byline,
/// then the rest of the note as a drop-capped paragraph. Reserved for the
/// single most prominent story in a section.
class HeroStoryBlock extends StatelessWidget {
  final Story story;
  final String kicker;
  final bool showFullContent;

  const HeroStoryBlock({
    super.key,
    required this.story,
    required this.kicker,
    this.showFullContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = headlineFor(story);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(text: story.isLongFormArticle ? 'Long-Form' : kicker),
          const SizedBox(height: 8),
          Text(
            headline.headline,
            style: theme.textTheme.displayLarge?.copyWith(letterSpacing: -0.8),
          ),
          const SizedBox(height: 12),
          ByLine(story: story),
          if (story.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            _StoryImage(urls: story.imageUrls, height: 220),
            const SizedBox(height: 6),
            Text(
              'Image via ${story.author.label}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (showFullContent && story.isLongFormArticle) ...[
            const SizedBox(height: 14),
            _FullStoryBody(story: story),
          ] else if (headline.body != null) ...[
            const SizedBox(height: 14),
            DropCapText(
              text: headline.body!,
              bodyStyle: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
            ),
          ],
          // A plain note's full body is already shown above via
          // DropCapText, unclipped — nothing to continue to. A long-form
          // article's body here is only its *summary*, though, so the
          // link is still needed to reach the actual full text.
          if (story.isLongFormArticle && !showFullContent)
            _ContinueReadingLink(article: story),
          const SizedBox(height: 12),
          EngagementFooter(story: story),
          const SizedBox(height: 4),
          StoryActions(story: story),
        ],
      ),
    );
  }
}

/// A secondary story: smaller headline, with a mobile preview or a complete
/// newspaper-column rendering on a tablet. Used for every non-hero article.
class StoryBlock extends StatelessWidget {
  final Story story;
  final String? kicker;
  final bool showFullContent;

  const StoryBlock({
    super.key,
    required this.story,
    this.kicker,
    this.showFullContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = headlineFor(story);
    final effectiveKicker = story.isLongFormArticle ? 'Long-Form' : kicker;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: context.gazetteColors.rule),
          const SizedBox(height: 16),
          if (effectiveKicker != null) ...[
            Kicker(text: effectiveKicker),
            const SizedBox(height: 6),
          ],
          Text(headline.headline, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          ByLine(story: story, avatarRadius: 12),
          if (story.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            _StoryImage(urls: story.imageUrls, height: 150),
          ],
          if (showFullContent && story.isLongFormArticle) ...[
            const SizedBox(height: 8),
            _FullStoryBody(story: story),
          ] else if (headline.body != null) ...[
            const SizedBox(height: 8),
            Text(
              headline.body!,
              style: theme.textTheme.bodyMedium,
              maxLines: showFullContent ? null : 4,
              overflow: showFullContent
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            // Clipped to 4 lines above, so — unlike HeroStoryBlock — there
            // is almost always more to read whenever a body exists at all.
            if (!showFullContent) _ContinueReadingLink(article: story),
          ],
          const SizedBox(height: 8),
          EngagementFooter(story: story),
          const SizedBox(height: 4),
          StoryActions(story: story),
        ],
      ),
    );
  }
}

/// A bordered Wire News sidebar. On a phone it is a compact preview column;
/// a tablet gives each item its full text, like a newspaper column.
class BriefsSection extends StatelessWidget {
  final String title;
  final List<Story> stories;
  final bool showFullContent;

  const BriefsSection({
    super.key,
    required this.title,
    required this.stories,
    this.showFullContent = false,
  });

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = context.gazetteColors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: colors.rule)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Container(height: 1, color: colors.rule),
          for (final story in stories)
            _BriefItem(story: story, showFullContent: showFullContent),
        ],
      ),
    );
  }
}

class _BriefItem extends StatelessWidget {
  final Story story;
  final bool showFullContent;
  const _BriefItem({required this.story, required this.showFullContent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = headlineFor(story);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: context.gazetteColors.rule),
          const SizedBox(height: 12),
          // Image posts land here rather than as a full article (see
          // `_frontPage` in edition_reader_page.dart) specifically so the
          // image actually shows — a wire item with a thumbnail, not just
          // a link buried in the text.
          if (story.imageUrls.isNotEmpty) ...[
            _StoryImage(urls: story.imageUrls, height: 120),
            const SizedBox(height: 8),
          ],
          if (showFullContent && story.isLongFormArticle)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline.headline, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                _FullStoryBody(story: story),
              ],
            )
          else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${headline.headline} ',
                    style: theme.textTheme.labelLarge,
                  ),
                  if (headline.body != null)
                    TextSpan(
                      text: headline.body,
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
              maxLines: showFullContent ? null : 4,
              overflow: showFullContent
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          Text(
            '${story.author.label} · ${relativeTime(story.createdAt)}',
            style: theme.textTheme.labelSmall,
          ),
          // Same "there's almost always more" reasoning as StoryBlock —
          // this item is clipped to 4 lines too.
          if (headline.body != null && !showFullContent)
            _ContinueReadingLink(article: story),
          const SizedBox(height: 4),
          StoryActions(story: story),
        ],
      ),
    );
  }
}

/// Tablet columns carry a whole story instead of a mobile preview. Long-form
/// posts retain their summary and Markdown structure; ordinary notes are
/// already rendered in full by their headline/body pair above.
class _FullStoryBody extends StatelessWidget {
  final Story story;
  const _FullStoryBody({required this.story});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (story.summary != null && story.summary!.isNotEmpty) ...[
          Text(
            story.summary!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: colors.inkFaded,
            ),
          ),
          const SizedBox(height: 10),
        ],
        MarkdownBody(
          data: story.content,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: theme.textTheme.bodyMedium,
            h1: theme.textTheme.headlineSmall,
            h2: theme.textTheme.titleLarge,
            h3: theme.textTheme.titleMedium,
            blockquote: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: colors.accent, width: 3)),
            ),
            blockquotePadding: const EdgeInsets.only(left: 12),
            code: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: colors.paperMuted,
            ),
            a: TextStyle(
              color: colors.accent,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

/// One image if that's all a story has; a swipeable carousel (with a dot
/// page indicator) when there's more than one — previously only
/// `imageUrls.first` ever rendered at all, silently dropping the rest.
/// Tapping any page opens the full-screen viewer already on that image.
class _StoryImage extends StatefulWidget {
  final List<String> urls;
  final double height;
  const _StoryImage({required this.urls, required this.height});

  @override
  State<_StoryImage> createState() => _StoryImageState();
}

class _StoryImageState extends State<_StoryImage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final url = widget.urls[index];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    FullscreenImageViewer.route(widget.urls, initialIndex: index),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: widget.height,
                    placeholder: (context, url) =>
                        Container(color: context.gazetteColors.paperMuted),
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                  ),
                );
              },
            ),
            if (widget.urls.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.urls.length; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: i == _index ? 0.9 : 0.4),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
