import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/presentation/edition/article_reader_page.dart';
import 'package:relay_gazette/presentation/theme/app_theme.dart';

Story _plainNote(String content) {
  final pubkey = NostrPublicKey.fromHex('a' * 64);
  return Story(
    id: 'note-1',
    kind: Story.kTextNote,
    author: Author(pubkey: pubkey, npub: 'npub1note', displayName: 'A Writer'),
    content: content,
    createdAt: DateTime.utc(2026, 8, 23, 10),
    engagement: const EngagementCounts(),
  );
}

Widget _wrapped(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

void main() {
  testWidgets(
    'a plain note (not a NIP-23 article) shows its extracted headline as the title, '
    'not the entire raw content',
    (tester) async {
      const content = 'This is the opening sentence of a much longer note. '
          'It keeps going for a while after that, well past the short-note threshold, '
          'to make sure the full body is reachable from here.';
      final story = _plainNote(content);

      await tester.pumpWidget(_wrapped(ArticleReaderPage(article: story)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The extracted headline (first sentence) renders as its own
      // distinct widget — this used to be `article.title ?? article.content`,
      // which meant the *entire* note (all three sentences, unsplit) was
      // the only text ever shown as the title for anything that wasn't a
      // NIP-23 article, since a plain note has no `title` tag.
      expect(find.text('This is the opening sentence of a much longer note.'), findsOneWidget);
    },
  );

  testWidgets('the full body is reachable on the reader page, not clipped', (tester) async {
    const content = 'A short lead-in. '
        'Then a very long remainder that would normally be clipped to four lines '
        'in a StoryBlock or BriefsSection preview, but must be fully readable here '
        'since this page exists specifically so a truncated story has somewhere to go.';
    final story = _plainNote(content);

    await tester.pumpWidget(_wrapped(ArticleReaderPage(article: story)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('must be fully readable here'), findsOneWidget);
  });
}
