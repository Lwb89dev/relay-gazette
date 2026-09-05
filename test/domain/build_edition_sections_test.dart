import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/edition_source.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/domain/usecases/build_edition_sections.dart';

Story _story(String id, {int reactions = 0, DateTime? createdAt}) {
  final pubkey = NostrPublicKey.fromHex(id.hashCode.toRadixString(16).padLeft(64, '0'));
  return Story(
    id: id,
    kind: Story.kTextNote,
    author: Author.unknown(pubkey, npub: 'npub1$id'),
    content: 'content $id',
    createdAt: createdAt ?? DateTime.utc(2026, 8, 23),
    engagement: EngagementCounts(reactions: reactions),
  );
}

void main() {
  const build = BuildEditionSections(topStoriesCount: 2);

  test('an empty story list produces no sections', () {
    expect(build(source: EditionSource.personalNetwork, qualifyingStories: []), isEmpty);
  });

  test('personal network: highest-engagement stories lead Top Stories', () {
    final stories = [
      _story('a', reactions: 1),
      _story('b', reactions: 10),
      _story('c', reactions: 5),
    ];

    final sections = build(source: EditionSource.personalNetwork, qualifyingStories: stories);

    expect(sections.map((s) => s.id), ['top-stories', 'from-your-network']);
    expect(sections[0].stories.map((s) => s.id), ['b', 'c']);
    expect(sections[1].stories.map((s) => s.id), ['a']);
  });

  test('Top Stories is the only section when everything fits inside it', () {
    final stories = [_story('a', reactions: 1), _story('b', reactions: 2)];
    final sections = build(source: EditionSource.personalNetwork, qualifyingStories: stories);
    expect(sections.map((s) => s.id), ['top-stories']);
  });

  test('"From Your Network" overflow is ordered chronologically, not by engagement', () {
    final older = _story('a1', reactions: 50, createdAt: DateTime.utc(2026, 8, 20));
    final newer = _story('a2', reactions: 1, createdAt: DateTime.utc(2026, 8, 23));
    final leader1 = _story('b1', reactions: 100);
    final leader2 = _story('b2', reactions: 99);

    final sections = build(
      source: EditionSource.personalNetwork,
      qualifyingStories: [older, newer, leader1, leader2],
    );

    final overflow = sections.firstWhere((s) => s.id == 'from-your-network');
    expect(overflow.stories.map((s) => s.id), ['a2', 'a1']);
  });

  test('trending source collapses everything into a single ranked section', () {
    final stories = [_story('a', reactions: 1), _story('b', reactions: 2), _story('c', reactions: 3)];
    final sections = build(source: EditionSource.trending, qualifyingStories: stories);
    expect(sections.map((s) => s.id), ['trending']);
    expect(sections.single.stories.map((s) => s.id), ['c', 'b', 'a']);
  });

  test('an injected custom ranker overrides the default engagement weight ordering', () {
    final withRanker = BuildEditionSections(
      topStoriesCount: 2,
      // Deliberately the opposite of engagement: fewer reactions ranks first.
      ranker: (story) => -story.engagement.reactions,
    );
    final stories = [_story('a', reactions: 1), _story('b', reactions: 10), _story('c', reactions: 5)];

    final sections = withRanker(source: EditionSource.trending, qualifyingStories: stories);

    expect(sections.single.stories.map((s) => s.id), ['a', 'c', 'b']);
  });
}
