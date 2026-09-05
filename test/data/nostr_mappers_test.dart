import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:relay_gazette/data/nostr/nostr_mappers.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';

Nip01Event _event({
  required String id,
  int kind = 1,
  List<List<String>> tags = const [],
  String content = '',
}) {
  return Nip01Event(
    id: id,
    pubKey: 'p' * 64,
    kind: kind,
    tags: tags,
    content: content,
  );
}

void main() {
  group('referencedStoryId', () {
    test('finds the e-tag that matches one of the candidate ids', () {
      final event = _event(
        id: 'reaction-1',
        tags: [
          ['e', 'note-a'],
        ],
      );
      expect(referencedStoryId(event, {'note-a', 'note-b'}), 'note-a');
    });

    test('returns null when no e-tag matches a candidate', () {
      final event = _event(
        id: 'reaction-1',
        tags: [
          ['e', 'unrelated-note'],
        ],
      );
      expect(referencedStoryId(event, {'note-a'}), isNull);
    });

    test('picks the first matching e-tag when several are present', () {
      final event = _event(
        id: 'reaction-1',
        tags: [
          ['e', 'root-note'],
          ['e', 'note-a'],
        ],
      );
      expect(referencedStoryId(event, {'note-a', 'root-note'}), 'root-note');
    });
  });

  group('zapSatsFromReceipt', () {
    test('reads the amount (millisats) from the embedded zap request', () {
      final zapRequest = jsonEncode({
        'tags': [
          ['amount', '21000'],
        ],
      });
      final receipt = _event(
        id: 'zap-1',
        kind: 9735,
        tags: [
          ['description', zapRequest],
        ],
      );
      expect(zapSatsFromReceipt(receipt), 21);
    });

    test('returns 0 when there is no description tag', () {
      final receipt = _event(id: 'zap-1', kind: 9735);
      expect(zapSatsFromReceipt(receipt), 0);
    });

    test('returns 0 for malformed description JSON instead of throwing', () {
      final receipt = _event(
        id: 'zap-1',
        kind: 9735,
        tags: [
          ['description', 'not json'],
        ],
      );
      expect(zapSatsFromReceipt(receipt), 0);
    });
  });

  group('isReplyNote', () {
    test('false for a note with no e-tags at all', () {
      final event = _event(id: 'note-1', content: 'a standalone thought');
      expect(isReplyNote(event), isFalse);
    });

    test('true for a NIP-10 reply using root/reply markers', () {
      final event = _event(
        id: 'reply-1',
        tags: [
          ['e', 'root-note', '', 'root'],
          ['e', 'parent-note', '', 'reply'],
        ],
      );
      expect(isReplyNote(event), isTrue);
    });

    test('true for the older positional (unmarked) e-tag convention', () {
      final event = _event(
        id: 'reply-2',
        tags: [
          ['e', 'parent-note'],
        ],
      );
      expect(isReplyNote(event), isTrue);
    });

    test('false for a quote-repost, which tags with q rather than e', () {
      final event = _event(
        id: 'quote-1',
        tags: [
          ['q', 'quoted-note'],
        ],
      );
      expect(isReplyNote(event), isFalse);
    });
  });

  group('mentionedPubkeysIn / resolveMentions', () {
    final aliceHex = 'a' * 64;
    final aliceNpub = Nip19.encodePubKey(aliceHex);

    test('mentionedPubkeysIn finds an npub mention with the nostr: prefix', () {
      expect(mentionedPubkeysIn('hey nostr:$aliceNpub check this out'), {
        aliceHex,
      });
    });

    test('mentionedPubkeysIn also finds a bare npub with no scheme prefix', () {
      expect(mentionedPubkeysIn('hey $aliceNpub check this out'), {aliceHex});
    });

    test('mentionedPubkeysIn returns nothing for content with no mentions', () {
      expect(mentionedPubkeysIn('just a plain note'), isEmpty);
    });

    test('resolveMentions replaces a resolved mention with @DisplayName', () {
      final metadata = Metadata(
        pubKey: aliceHex,
        displayName: 'Alice',
        updatedAt: 0,
      );
      final result = resolveMentions('hey nostr:$aliceNpub!', {
        aliceHex: metadata,
      });
      expect(result, 'hey @Alice!');
    });

    test(
      'resolveMentions falls back to @name when there is no display name',
      () {
        final metadata = Metadata(
          pubKey: aliceHex,
          name: 'alice',
          updatedAt: 0,
        );
        final result = resolveMentions('nostr:$aliceNpub', {
          aliceHex: metadata,
        });
        expect(result, '@alice');
      },
    );

    test(
      'resolveMentions falls back to a plain @user placeholder when unresolved',
      () {
        final result = resolveMentions('nostr:$aliceNpub', const {});
        expect(result, '@user');
      },
    );

    test('resolveMentions leaves content with no mentions untouched', () {
      expect(
        resolveMentions('nothing to see here', const {}),
        'nothing to see here',
      );
    });

    test(
      'regression: an npub immediately followed by more lowercase text '
      '(no separating space) still resolves instead of leaking raw bech32',
      () {
        // Every character in "says" is itself valid in the bech32
        // alphabet, so with the old open-ended `{20,}` pattern this whole
        // run got swallowed into one "npub", broke its checksum, failed to
        // decode, and was left on screen verbatim — exactly the reported
        // "mentions still show as npub" symptom. A real npub is always
        // exactly 58 characters after "npub1", so the fixed pattern stops
        // there regardless of what immediately follows.
        final metadata = Metadata(
          pubKey: aliceHex,
          displayName: 'Alice',
          updatedAt: 0,
        );
        final result = resolveMentions('nostr:${aliceNpub}says hi', {
          aliceHex: metadata,
        });
        expect(result, '@Alicesays hi');
        expect(result, isNot(contains('npub1')));
      },
    );

    test('resolveMentions never leaves raw bech32 visible, even when the '
        'checksum fails to decode', () {
      // Same length and alphabet as a real npub (so the pattern still
      // matches it), but the trailing checksum character is flipped to a
      // different valid bech32 letter — bech32's checksum is designed to
      // catch exactly this kind of single-character substitution, so
      // Nip19.decode fails. Exercises that failure path specifically,
      // distinct from the regex simply not matching malformed text.
      final lastChar = aliceNpub[aliceNpub.length - 1];
      final flipped = lastChar == 'q' ? 'p' : 'q';
      final corrupted =
          '${aliceNpub.substring(0, aliceNpub.length - 1)}$flipped';

      final result = resolveMentions('hey nostr:$corrupted!', const {});
      expect(result, isNot(contains('npub1')));
    });
  });

  group('storyFromEvent', () {
    test('extracts image URLs separately from other links', () {
      final event = _event(
        id: 'note-1',
        content:
            'check this out https://example.com/pic.jpg and https://example.com/article',
      );
      final pubkey = NostrPublicKey.fromHex('a' * 64);
      final story = storyFromEvent(
        event,
        authorFromMetadata(pubkey, null),
        EngagementCounts.zero,
      );
      expect(story.imageUrls, ['https://example.com/pic.jpg']);
      expect(story.links, ['https://example.com/article']);
    });

    test('uses NIP-92 imeta MIME metadata for an extensionless image URL', () {
      const imageUrl = 'https://cdn.example.com/media/8d7f4c';
      final event = _event(
        id: 'note-imeta-image',
        content: 'A photo from the relay: $imageUrl',
        tags: [
          [
            'imeta',
            'url $imageUrl',
            'm image/avif',
            'dim 1600x900',
            'alt A relay under a blue sky',
          ],
        ],
      );
      final pubkey = NostrPublicKey.fromHex('a' * 64);

      final story = storyFromEvent(
        event,
        authorFromMetadata(pubkey, null),
        EngagementCounts.zero,
      );

      expect(story.imageUrls, [imageUrl]);
      expect(story.links, isEmpty);
    });

    test(
      'ignores imeta whose URL is not actually present in the event content',
      () {
        const contentUrl = 'https://example.com/read-more';
        final event = _event(
          id: 'note-imeta-mismatch',
          content: contentUrl,
          tags: const [
            ['imeta', 'url https://tracking.example.com/pixel', 'm image/png'],
          ],
        );
        final pubkey = NostrPublicKey.fromHex('a' * 64);

        final story = storyFromEvent(
          event,
          authorFromMetadata(pubkey, null),
          EngagementCounts.zero,
        );

        expect(story.imageUrls, isEmpty);
        expect(story.links, [contentUrl]);
      },
    );

    test('does not classify non-image imeta media as an image post', () {
      const videoUrl = 'https://cdn.example.com/media/video';
      final event = _event(
        id: 'note-imeta-video',
        content: videoUrl,
        tags: const [
          ['imeta', 'url https://cdn.example.com/media/video', 'm video/mp4'],
        ],
      );
      final pubkey = NostrPublicKey.fromHex('a' * 64);

      final story = storyFromEvent(
        event,
        authorFromMetadata(pubkey, null),
        EngagementCounts.zero,
      );

      expect(story.imageUrls, isEmpty);
      expect(story.links, [videoUrl]);
    });
  });

  group('articleFromEvent', () {
    test('reads title/summary/image/d from NIP-23 tags, not from content', () {
      final event = _event(
        id: 'article-1',
        kind: 30023,
        content: '# Heading\n\nThe article body, in Markdown.',
        tags: [
          ['d', 'my-article-slug'],
          ['title', 'A Proper Headline'],
          ['summary', 'A one-line summary of the piece.'],
          ['image', 'https://example.com/cover.jpg'],
          ['published_at', '1755900000'],
        ],
      );
      final pubkey = NostrPublicKey.fromHex('a' * 64);

      final story = articleFromEvent(
        event,
        authorFromMetadata(pubkey, null),
        EngagementCounts.zero,
      );

      expect(story.title, 'A Proper Headline');
      expect(story.summary, 'A one-line summary of the piece.');
      expect(story.dTag, 'my-article-slug');
      expect(story.imageUrls, ['https://example.com/cover.jpg']);
      expect(story.content, '# Heading\n\nThe article body, in Markdown.');
      expect(story.isLongFormArticle, isTrue);
    });

    test('missing optional tags produce null fields rather than throwing', () {
      final event = _event(id: 'article-2', kind: 30023, content: 'body only');
      final pubkey = NostrPublicKey.fromHex('a' * 64);

      final story = articleFromEvent(
        event,
        authorFromMetadata(pubkey, null),
        EngagementCounts.zero,
      );

      expect(story.title, isNull);
      expect(story.summary, isNull);
      expect(story.dTag, isNull);
      expect(story.imageUrls, isEmpty);
    });

    test('also recognizes NIP-92 inline image metadata in article content', () {
      const imageUrl = 'https://cdn.example.com/image/without-an-extension';
      final event = _event(
        id: 'article-imeta',
        kind: 30023,
        content: '![Cover]($imageUrl)',
        tags: [
          ['imeta', 'url $imageUrl', 'm image/webp'],
        ],
      );
      final pubkey = NostrPublicKey.fromHex('a' * 64);

      final story = articleFromEvent(
        event,
        authorFromMetadata(pubkey, null),
        EngagementCounts.zero,
      );

      expect(story.imageUrls, [imageUrl]);
    });
  });
}
