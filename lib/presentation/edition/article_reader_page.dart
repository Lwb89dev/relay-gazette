import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/entities/story.dart';
import '../theme/aged_paper_surface.dart';
import '../theme/gazette_colors.dart';
import 'edition_reader_page.dart' show readingSystemBars;
import 'widgets/story_actions.dart';
import 'widgets/story_blocks.dart' show headlineFor;
import 'widgets/story_meta.dart';

/// The "deeper" reading view for a NIP-23 long-form article — reached from
/// its story block via "Read the full article." Renders the article's
/// Markdown body properly instead of showing it as flattened plain text.
class ArticleReaderPage extends StatelessWidget {
  final Story article;

  const ArticleReaderPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Article'),
      ),
      body: AnnotatedRegion(
        value: readingSystemBars(context),
        child: AgedPaperSurface(
          child: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  kToolbarHeight + 12,
                  20,
                  40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // `article.title` covers NIP-23 long-form
                          // articles; a plain note has no such tag, so it
                          // falls back to the same extracted headline the
                          // front page previews with — using the raw
                          // `content` here (as this used to) showed the
                          // *entire* note as one giant title for anything
                          // that wasn't a long-form article.
                          headlineFor(article).headline,
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 30,
                          ),
                        ),
                        if (article.summary != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            article.summary!,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: colors.inkFaded,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ByLine(story: article),
                        const SizedBox(height: 20),
                        Container(height: 1, color: colors.rule),
                        const SizedBox(height: 20),
                        MarkdownBody(
                          data: article.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 18,
                            ),
                            h1: theme.textTheme.headlineLarge,
                            h2: theme.textTheme.headlineMedium,
                            h3: theme.textTheme.headlineSmall,
                            blockquote: theme.textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: colors.accent,
                                  width: 3,
                                ),
                              ),
                            ),
                            blockquotePadding: const EdgeInsets.only(left: 16),
                            code: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              backgroundColor: colors.paperMuted,
                            ),
                            a: TextStyle(
                              color: colors.accent,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(height: 1, color: colors.rule),
                        const SizedBox(height: 12),
                        EngagementFooter(story: article),
                        const SizedBox(height: 4),
                        StoryActions(story: article),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
