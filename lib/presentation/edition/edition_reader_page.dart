import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/edition_summary.dart';
import '../../domain/entities/gazette_edition.dart';
import '../../domain/entities/story.dart';
import '../common/state_views.dart';
import '../theme/aged_paper_surface.dart';
import '../theme/breakpoints.dart';
import '../theme/gazette_colors.dart';
import 'edition_providers.dart';
import 'widgets/masthead.dart';
import 'widgets/story_blocks.dart';

/// A front page, not a feed: a single hero story, a couple of runners-up,
/// and everything else folded into a bordered "brief" column — laid out as
/// a single stack on a phone, and as real newspaper-style columns once
/// there's enough width for them (tablet portrait: 2, tablet landscape /
/// wide: 3). See GazetteBreakpoints.
class EditionReaderPage extends ConsumerWidget {
  final GazetteEdition edition;

  const EditionReaderPage({super.key, required this.edition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editionNumber = _editionNumber(
      ref.watch(archiveSummariesProvider),
      edition,
    );
    final authorCount = edition.stories
        .map((s) => s.author.pubkey.hex)
        .toSet()
        .length;
    final masthead = Masthead(
      edition: edition,
      editionNumber: editionNumber,
      authorCount: authorCount,
    );

    if (edition.isEmpty) {
      return Scaffold(
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: readingSystemBars(context),
          child: AgedPaperSurface(
            child: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      masthead,
                      Expanded(
                        child: GazetteStateView(
                          icon: Icons.inbox_outlined,
                          title: 'No stories cleared the bar',
                          message:
                              'Nothing in this window met your thresholds. '
                              'Try a wider window or lower minimums next time.',
                          actionLabel: 'Back',
                          onAction: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
                const _ReaderBackButton(),
              ],
            ),
          ),
        ),
      );
    }

    final layout = _frontPage(edition);

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: readingSystemBars(context),
        child: AgedPaperSurface(
          child: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: GazetteBreakpoints.editionMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          masthead,
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth >=
                                  GazetteBreakpoints.wide) {
                                return _WideFrontPage(
                                  layout: layout,
                                  edition: edition,
                                );
                              }
                              if (GazetteBreakpoints.isTablet(context)) {
                                return _TabletFrontPage(
                                  layout: layout,
                                  edition: edition,
                                );
                              }
                              return _MobileFrontPage(layout: layout);
                            },
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
                            child: Center(
                              child: Text(
                                '— End of this edition —',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const _ReaderBackButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the paper painting show through Android's transparent system bars.
/// The safe area still protects the editorial content; only the background
/// extends beneath the status and navigation controls.
SystemUiOverlayStyle readingSystemBars(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarIconBrightness: icons,
    systemNavigationBarIconBrightness: icons,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}

/// A front page has no AppBar (the masthead stands in for one visually),
/// so Flutter never gets the chance to add its usual automatic back
/// button — without this, there was genuinely no way to leave the reader
/// on a platform without a system back gesture. Floats over the scrolling
/// content rather than taking up its own row, to keep the front-page look.
class _ReaderBackButton extends StatelessWidget {
  const _ReaderBackButton();

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();
    final colors = context.gazetteColors;

    // Solid ink-on-paper (inverted from the page itself), not a translucent
    // paper-on-paper circle — the previous version was nearly invisible
    // against the masthead/paper background it floats over, which is
    // exactly the "too discreet" complaint. This reads unambiguously as a
    // floating control regardless of theme or scroll position.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: colors.ink,
          shape: const CircleBorder(),
          elevation: 4,
          shadowColor: Colors.black,
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.paper),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

int _editionNumber(
  AsyncValue<List<GazetteEditionSummary>> summariesAsync,
  GazetteEdition edition,
) {
  return summariesAsync.maybeWhen(
    data: (summaries) {
      final sorted = [...summaries]
        ..sort((a, b) => a.generatedAt.compareTo(b.generatedAt));
      final index = sorted.indexWhere((s) => s.id == edition.id);
      return index == -1 ? sorted.length + 1 : index + 1;
    },
    orElse: () => 1,
  );
}

/// Image posts and brief one-liners both belong in the "Off the Wire"
/// (Wire News) column, never in an article slot — a picture with a
/// caption, or a "gm" with nothing to elaborate on, reads as a wire item,
/// not a front-page piece. A naked ordinary link is neither an article
/// nor a wire image, so it stays omitted from the printed edition
/// entirely. This is deliberately independent of ranking: article columns
/// are reserved for text-led stories with an actual body, and a NIP-23
/// article with a cover image follows the same media rule as any other
/// article. Which stories belong to *sections* remains up to
/// `BuildEditionSections`; this only decides layout.
class _FrontPageLayout {
  final Story? hero;
  final String heroKicker;
  final List<Story> secondary;
  final List<Story> brief;
  final String briefTitle;

  const _FrontPageLayout({
    required this.hero,
    required this.heroKicker,
    required this.secondary,
    required this.brief,
    required this.briefTitle,
  });
}

_FrontPageLayout _frontPage(GazetteEdition edition) {
  final sections = edition.sections;
  if (sections.isEmpty) {
    return const _FrontPageLayout(
      hero: null,
      heroKicker: '',
      secondary: [],
      brief: [],
      briefTitle: '',
    );
  }

  final allStories = [for (final section in sections) ...section.stories];

  // A plain note with no image still isn't an article if there's nothing
  // to actually elaborate — `headlineFor` already tells us that: `body ==
  // null` means the note's whole content fit in the headline itself
  // (extractHeadline's own definition of "too short to split"). A NIP-23
  // article is exempt: it's substantial by construction, whether or not
  // it happens to carry an optional `summary` tag.
  bool wireOnly(Story s) {
    if (s.isLongFormArticle) return false;
    if (s.imageUrls.isNotEmpty) return true;
    return headlineFor(s).body == null;
  }

  // There is intentionally no quota that can promote media/brief posts
  // back into an article column. A post containing only a non-image URL
  // is excluded from both — it's neither.
  final articles = allStories
      .where((s) => !s.isLinkOnlyPost && !wireOnly(s))
      .toList();
  final hero = articles.isNotEmpty ? articles.first : null;
  final secondary = articles.skip(1).toList();
  final brief = allStories.where((s) => !s.isLinkOnlyPost && wireOnly(s)).toList();

  var heroKicker = sections.first.title;
  if (hero != null) {
    for (final section in sections) {
      if (section.stories.any((s) => s.id == hero.id)) {
        heroKicker = section.title;
        break;
      }
    }
  }

  return _FrontPageLayout(
    hero: hero,
    heroKicker: heroKicker,
    secondary: secondary,
    brief: brief,
    briefTitle: 'Off the Wire',
  );
}

class _MobileFrontPage extends StatelessWidget {
  final _FrontPageLayout layout;
  const _MobileFrontPage({required this.layout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (layout.hero != null)
          HeroStoryBlock(story: layout.hero!, kicker: layout.heroKicker),
        for (final story in layout.secondary) StoryBlock(story: story),
        if (layout.brief.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: BriefsSection(
              title: layout.briefTitle,
              stories: layout.brief,
            ),
          ),
      ],
    );
  }
}

class _TabletFrontPage extends StatelessWidget {
  final _FrontPageLayout layout;
  final GazetteEdition edition;
  const _TabletFrontPage({required this.layout, required this.edition});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              children: [
                if (layout.hero != null)
                  HeroStoryBlock(
                    story: layout.hero!,
                    kicker: layout.heroKicker,
                    showFullContent: true,
                  ),
                for (final story in layout.secondary)
                  StoryBlock(story: story, showFullContent: true),
              ],
            ),
          ),
          Container(width: 1, color: context.gazetteColors.rule),
          Expanded(
            flex: 3,
            child: _EditionSideRail(layout: layout, edition: edition),
          ),
        ],
      ),
    );
  }
}

class _WideFrontPage extends StatelessWidget {
  final _FrontPageLayout layout;
  final GazetteEdition edition;
  const _WideFrontPage({required this.layout, required this.edition});

  @override
  Widget build(BuildContext context) {
    final leftColumnStories = <Story>[];
    final centerColumnStories = <Story>[];
    for (var index = 0; index < layout.secondary.length; index++) {
      // The hero already occupies the left column. Send the next article to
      // the centre, then alternate, so the broadsheet keeps filling both
      // editorial columns instead of becoming a one-column stack.
      (index.isEven ? centerColumnStories : leftColumnStories).add(
        layout.secondary[index],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              children: [
                if (layout.hero != null)
                  HeroStoryBlock(
                    story: layout.hero!,
                    kicker: layout.heroKicker,
                    showFullContent: true,
                  ),
                for (final story in leftColumnStories)
                  StoryBlock(story: story, showFullContent: true),
              ],
            ),
          ),
          Container(width: 1, color: context.gazetteColors.rule),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                for (final story in centerColumnStories)
                  StoryBlock(story: story, showFullContent: true),
              ],
            ),
          ),
          Container(width: 1, color: context.gazetteColors.rule),
          Expanded(
            flex: 3,
            child: _EditionSideRail(layout: layout, edition: edition),
          ),
        ],
      ),
    );
  }
}

/// The reference paper's right-most column is more than a list of briefs:
/// it also provides one textual pull quote and the edition's vital signs.
/// Both panels are derived from the actual local edition, never invented.
class _EditionSideRail extends StatelessWidget {
  final _FrontPageLayout layout;
  final GazetteEdition edition;

  const _EditionSideRail({required this.layout, required this.edition});

  @override
  Widget build(BuildContext context) {
    final quoteStory =
        layout.hero ??
        (layout.secondary.isNotEmpty ? layout.secondary.first : null);
    final authorCount = edition.stories
        .map((story) => story.author.pubkey.hex)
        .toSet()
        .length;

    return Column(
      children: [
        BriefsSection(
          title: layout.briefTitle,
          stories: layout.brief,
          showFullContent: true,
        ),
        if (quoteStory != null) ...[
          const SizedBox(height: 20),
          _QuoteOfTheDay(story: quoteStory),
        ],
        const SizedBox(height: 20),
        _EditionConditions(edition: edition, authorCount: authorCount),
      ],
    );
  }
}

class _RailPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _RailPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: colors.rule)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 1.3),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: colors.rule),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _QuoteOfTheDay extends StatelessWidget {
  final Story story;
  const _QuoteOfTheDay({required this.story});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = headlineFor(story);
    final quote = (headline.body ?? headline.headline).trim();
    return _RailPanel(
      title: 'QUOTATION OF THE DAY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“$quote”',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 19,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${story.author.label.toUpperCase()} · FEATURED NOTE',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _EditionConditions extends StatelessWidget {
  final GazetteEdition edition;
  final int authorCount;

  const _EditionConditions({required this.edition, required this.authorCount});

  @override
  Widget build(BuildContext context) {
    final source = edition.source.label;
    return _RailPanel(
      title: 'EDITION CONDITIONS',
      child: Column(
        children: [
          _ConditionRow(label: 'Stories', value: '${edition.storyCount}'),
          _ConditionRow(label: 'Authors', value: '$authorCount'),
          _ConditionRow(
            label: 'Window',
            value: edition.filterConfiguration.timeWindow.label,
          ),
          _ConditionRow(label: 'Source', value: source),
        ],
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConditionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
