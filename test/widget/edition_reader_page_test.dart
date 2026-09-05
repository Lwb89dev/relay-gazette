import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/edition_section.dart';
import 'package:relay_gazette/domain/entities/edition_source.dart';
import 'package:relay_gazette/domain/entities/edition_summary.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/filter_configuration.dart';
import 'package:relay_gazette/domain/entities/gazette_edition.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/domain/entities/time_window.dart';
import 'package:relay_gazette/presentation/edition/edition_providers.dart';
import 'package:relay_gazette/presentation/edition/edition_reader_page.dart';
import 'package:relay_gazette/presentation/edition/widgets/fullscreen_image_viewer.dart';
import 'package:relay_gazette/presentation/edition/widgets/story_blocks.dart';
import 'package:relay_gazette/presentation/theme/aged_paper_surface.dart';
import 'package:relay_gazette/presentation/theme/app_theme.dart';

Story _story(
  String id, {
  required String content,
  int reactions = 3,
  bool withImage = false,
  bool withLightning = false,
  List<String> links = const [],
}) {
  final pubkey = NostrPublicKey.fromHex(
    id.hashCode.toRadixString(16).padLeft(64, '0'),
  );
  return Story(
    id: id,
    kind: Story.kTextNote,
    author: Author(
      pubkey: pubkey,
      npub: 'npub1$id',
      displayName: 'Author $id',
      lightningAddress: withLightning ? 'author$id@example.com' : null,
    ),
    content: content,
    createdAt: DateTime.utc(2026, 8, 23, 10),
    engagement: EngagementCounts(
      reactions: reactions,
      replies: 1,
      reposts: 0,
      zapSats: 0,
    ),
    imageUrls: withImage ? const ['https://example.com/photo.jpg'] : const [],
    links: links,
  );
}

GazetteEdition _sampleEdition() {
  final longContent =
      'Two blocks were mined at height 961,632 before the chain stalled entirely. '
      'The rest of the network kept going, carrying full difficulty on a fraction of the hash rate, '
      'and nobody quite agrees yet on what any of it actually meant for the fork.';

  return GazetteEdition(
    id: 'edition-1',
    generatedAt: DateTime.utc(2026, 8, 23, 12),
    windowStart: DateTime.utc(2026, 8, 22, 12),
    windowEnd: DateTime.utc(2026, 8, 23, 12),
    source: EditionSource.personalNetwork,
    filterConfiguration: const FilterConfiguration(
      source: EditionSource.personalNetwork,
      timeWindow: EditionTimeWindow.twentyFourHours,
    ),
    sections: [
      EditionSection(
        id: 'top-stories',
        title: 'Top Stories',
        stories: [
          _story(
            'hero',
            content: longContent,
            reactions: 42,
            withImage: true,
            withLightning: true,
          ),
          _story(
            'second',
            // 'hero' is excluded from the article columns despite its id —
            // it carries an image, and image posts always go to the wire
            // (see `_frontPage`). This story has no image and enough body
            // to actually qualify as an article, so it's the one that
            // ends up as `layout.hero` / feeds the "Quotation of the Day"
            // panel in the wide layout.
            content: 'A genuine secondary article about something else entirely. '
                'It has a real body that runs on well past the short-note '
                'threshold, not just a one-liner clipped for the wire column.',
            reactions: 12,
          ),
          _story(
            'third',
            content: 'gm nostr, off to touch some grass today',
            reactions: 8,
          ),
        ],
      ),
      EditionSection(
        id: 'from-your-network',
        title: 'From Your Network',
        stories: [
          for (var i = 0; i < 5; i++)
            _story(
              'brief-$i',
              content: 'A brief update, number $i.',
              reactions: i,
            ),
        ],
      ),
    ],
  );
}

Widget _wrapped(Widget child) {
  return ProviderScope(
    overrides: [
      archiveSummariesProvider.overrideWith(
        (ref) async => <GazetteEditionSummary>[],
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Story _imageStory(
  String id, {
  int reactions = 0,
  String content = 'a photo worth a thousand likes',
  List<String> imageUrls = const ['https://example.com/photo.jpg'],
}) {
  return Story(
    id: id,
    kind: Story.kTextNote,
    author: Author(
      pubkey: NostrPublicKey.fromHex(
        id.hashCode.toRadixString(16).padLeft(64, '0'),
      ),
      npub: 'npub1$id',
    ),
    content: content,
    createdAt: DateTime.utc(2026, 8, 23, 10),
    engagement: EngagementCounts(reactions: reactions),
    imageUrls: imageUrls,
  );
}

Widget _frontPageFor(List<Story> stories) {
  return _wrapped(
    EditionReaderPage(
      edition: GazetteEdition(
        id: 'edition-quota-test',
        generatedAt: DateTime.utc(2026, 8, 23, 12),
        windowStart: DateTime.utc(2026, 8, 22, 12),
        windowEnd: DateTime.utc(2026, 8, 23, 12),
        source: EditionSource.personalNetwork,
        filterConfiguration: const FilterConfiguration(
          source: EditionSource.personalNetwork,
          timeWindow: EditionTimeWindow.twentyFourHours,
        ),
        sections: [
          EditionSection(
            id: 'top-stories',
            title: 'Top Stories',
            stories: stories,
          ),
        ],
      ),
    ),
  );
}

void main() {
  final edition = _sampleEdition();

  testWidgets(
    'renders the front page on a phone-sized viewport without layout errors',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(_wrapped(EditionReaderPage(edition: edition)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Relay Gazette'), findsOneWidget);
      expect(find.textContaining('Two blocks were mined'), findsOneWidget);
      // Copied verbatim from a real newspaper masthead template and never
      // adapted — the app has no real sats total to show here.
      expect(find.text('0 SATS'), findsNothing);
    },
  );

  testWidgets(
    'keeps the paper treatment at viewport size, not the edition scroll height',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(_wrapped(EditionReaderPage(edition: edition)));
      await tester.pumpAndSettle();

      // The contents are longer than a phone viewport. If the surface followed
      // that full height, the radial centre would be far below the first screen
      // and the reader would see only a flat-looking outer gradient stop.
      expect(
        tester.getSize(find.byType(AgedPaperSurface)),
        const Size(390, 844),
      );
    },
  );

  testWidgets(
    'renders the front page on a tablet-portrait viewport without layout errors',
    (tester) async {
      await _setViewport(tester, const Size(820, 1180));
      await tester.pumpWidget(_wrapped(EditionReaderPage(edition: edition)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders the front page on a tablet-landscape / wide viewport without layout errors',
    (tester) async {
      await _setViewport(tester, const Size(1194, 834));
      await tester.pumpWidget(_wrapped(EditionReaderPage(edition: edition)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('FROM YOUR NETWORK'), findsWidgets);
      expect(find.text('QUOTATION OF THE DAY'), findsOneWidget);
      expect(find.text('EDITION CONDITIONS'), findsOneWidget);
    },
  );

  testWidgets('renders the empty-edition state without layout errors', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final emptyEdition = GazetteEdition(
      id: 'empty',
      generatedAt: DateTime.utc(2026, 8, 23),
      windowStart: DateTime.utc(2026, 8, 22),
      windowEnd: DateTime.utc(2026, 8, 23),
      source: EditionSource.personalNetwork,
      filterConfiguration: const FilterConfiguration(
        source: EditionSource.personalNetwork,
        timeWindow: EditionTimeWindow.twentyFourHours,
      ),
      sections: const [],
    );

    await tester.pumpWidget(_wrapped(EditionReaderPage(edition: emptyEdition)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No stories cleared the bar'), findsOneWidget);
  });

  testWidgets('an image post always stays in Off the Wire', (tester) async {
    await _setViewport(tester, const Size(390, 844));

    // It remains in the Wire column even though it outranks every prose
    // story: image placement never depends on an article quota.
    final stories = [
      _imageStory(
        'image-one',
        reactions: 99,
        content: 'a photo worth a thousand likes',
      ),
      for (var i = 0; i < 4; i++)
        _story(
          'written-$i',
          content: 'Written note number $i is a genuine article. It has a real body that runs on well past the short-note threshold, not just a one-liner clipped for the wire column.',
          reactions: 5,
        ),
    ];

    await tester.pumpWidget(_frontPageFor(stories));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(BriefsSection),
        matching: find.textContaining('a photo worth a thousand'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(BriefsSection),
        matching: find.textContaining('Written note number'),
      ),
      findsNothing,
    );
  });

  testWidgets('image posts never get promoted to full articles', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));

    final stories = [
      for (var i = 0; i < 2; i++)
        _story(
          'written-$i',
          content: 'Written note number $i is a genuine article. It has a real body that runs on well past the short-note threshold, not just a one-liner clipped for the wire column.',
          reactions: 5,
        ),
      for (var i = 0; i < 8; i++)
        _imageStory(
          'image-$i',
          reactions: 10 - i,
          content: 'Image post number $i',
        ),
    ];

    await tester.pumpWidget(_frontPageFor(stories));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Every image post remains in the Wire column, independently of the
    // number of prose stories available.
    for (var i = 0; i < 8; i++) {
      expect(
        find.descendant(
          of: find.byType(BriefsSection),
          matching: find.textContaining('Image post number $i'),
        ),
        findsOneWidget,
        reason: 'image-$i should have stayed in Off the Wire',
      );
    }
  });

  testWidgets(
    'a short one-liner with no image still lands in Off the Wire, not as an article',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));

      final stories = [
        _story(
          'gm',
          content: 'gm nostr, off to touch some grass today',
          reactions: 50, // outranks the real article; must not matter
        ),
        _story(
          'real-article',
          content: 'This is a genuine written article with a real headline. '
              'It has a proper body that runs on well past the short-note '
              'threshold, unlike a bare one-liner.',
          reactions: 1,
        ),
      ];

      await tester.pumpWidget(_frontPageFor(stories));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(BriefsSection),
          matching: find.textContaining('gm nostr'),
        ),
        findsOneWidget,
        reason: 'a bare one-liner has no body to make an article out of',
      );
      expect(
        find.descendant(
          of: find.byType(BriefsSection),
          matching: find.textContaining('This is a genuine written article'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('a naked non-image link is omitted from the edition', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    const imageLink = 'https://media.example.com/upload/without-extension';

    await tester.pumpWidget(
      _frontPageFor([
        _story('link-only', content: imageLink, links: const [imageLink]),
        _story('written', content: 'A proper written note with a real body.'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(imageLink), findsNothing);
  });

  testWidgets('a tablet renders complete stories without continue-reading links', (
    tester,
  ) async {
    await _setViewport(tester, const Size(820, 1180));
    final longNote =
        'The first sentence is the headline. The rest of this note must be visible in the tablet column without opening another page. '
        'Its final sentence confirms that the whole note stays in the newspaper layout.';
    final longForm = Story(
      id: 'tablet-long-form',
      kind: Story.kLongFormArticle,
      author: Author(
        pubkey: NostrPublicKey.fromHex('f'.padLeft(64, '0')),
        npub: 'npub1tabletlongform',
      ),
      content:
          'The complete long-form article is rendered directly in the Wire News column on a tablet.',
      title: 'A long-form article with an image',
      summary: 'Its summary is also present without opening another page.',
      imageUrls: const ['https://example.com/long-form-cover.jpg'],
      createdAt: DateTime.utc(2026, 8, 23, 10),
      engagement: const EngagementCounts(),
    );

    await tester.pumpWidget(
      _frontPageFor([
        _story('tablet-note', content: longNote),
        _imageStory('tablet-image', content: longNote),
        longForm,
      ]),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Continue reading →'), findsNothing);
    expect(
      find.textContaining('Its final sentence confirms'),
      findsAtLeastNWidgets(2),
    );
    expect(
      find.textContaining('complete long-form article is rendered directly'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a story image in Off the Wire opens it full-screen', (tester) async {
    await _setViewport(tester, const Size(390, 844));

    final stories = [
      _story('written', content: 'A proper written note with a real, substantial body — plenty of prose here.'),
      _imageStory('image-one', content: 'a photo worth a thousand likes'),
    ];

    await tester.pumpWidget(_frontPageFor(stories));
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenImageViewer), findsNothing);

    await tester.tap(
      find.descendant(of: find.byType(BriefsSection), matching: find.byType(CachedNetworkImage)).first,
    );
    // Not pumpAndSettle: the viewer's loading placeholder is a
    // CircularProgressIndicator, which animates forever until the image
    // resolves — there's no real network in this test, so it never does.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FullscreenImageViewer), findsOneWidget);

    // The explicit close button dismisses it (a bare full-area tap-to-close
    // gesture is harder to assert reliably here, since `InteractiveViewer`
    // — needed for pinch-to-zoom — competes for the same tap).
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FullscreenImageViewer), findsNothing);
  });

  testWidgets(
    'a story with multiple images renders all of them in a swipeable carousel, not just the first',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));

      const urls = [
        'https://example.com/photo-1.jpg',
        'https://example.com/photo-2.jpg',
        'https://example.com/photo-3.jpg',
      ];
      final stories = [
        _story('written', content: 'A proper written note with a real, substantial body — plenty of prose here.'),
        _imageStory('multi-image', imageUrls: urls),
      ];

      await tester.pumpWidget(_frontPageFor(stories));
      await tester.pumpAndSettle();

      // `PageView` only builds the current page's item, so all three
      // images are checked by swiping through, one at a time — this is
      // exactly what regresses to "only imageUrls.first ever renders" if
      // the carousel is accidentally reverted to a single image.
      CachedNetworkImage currentImage() => tester.widget<CachedNetworkImage>(
            find.descendant(of: find.byType(BriefsSection), matching: find.byType(CachedNetworkImage)),
          );

      expect(currentImage().imageUrl, urls[0]);

      final pageViewFinder = find.descendant(of: find.byType(BriefsSection), matching: find.byType(PageView));
      await tester.drag(pageViewFinder, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(currentImage().imageUrl, urls[1]);

      await tester.drag(pageViewFinder, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(currentImage().imageUrl, urls[2]);

      // Swipe back to the second image before tapping, so the full-screen
      // viewer below can be checked against a non-zero initial index.
      await tester.drag(pageViewFinder, const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(currentImage().imageUrl, urls[1]);

      await tester.tap(
        find.descendant(of: find.byType(BriefsSection), matching: find.byType(CachedNetworkImage)).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final viewer = tester.widget<FullscreenImageViewer>(find.byType(FullscreenImageViewer));
      expect(viewer.urls, urls);
      expect(viewer.initialIndex, 1);
    },
  );
}
