import 'package:ndk/ndk.dart';

import '../../domain/entities/author.dart';
import '../../domain/entities/engagement.dart';
import '../../domain/entities/nostr_list.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/feed_provider.dart';
import '../nostr/event_kinds.dart';
import '../nostr/nostr_mappers.dart';
import '../nostr/relay_defaults.dart';
import 'primal_cache_client.dart';
import 'primal_event_kinds.dart';
import 'primal_mappers.dart';

/// [FeedProvider] backed by Primal's caching/discovery API instead of
/// direct relay queries. Only serves trending/discovery content — Primal is
/// never required for the app's basic (personal network) operation, per
/// the product brief. See [CompositeFeedProvider] for how the two are
/// combined behind a single [FeedProvider] the rest of the app consumes.
class PrimalFeedProvider implements FeedProvider {
  final PrimalCacheClient _client;
  final EventVerifier _verifier;

  PrimalFeedProvider(this._client, {EventVerifier? verifier})
    : _verifier = verifier ?? Bip340EventVerifier();

  @override
  bool get supportsTrending => true;

  @override
  Future<Author> resolveViewer(NostrPublicKey pubkey) {
    throw UnsupportedError(
      'PrimalFeedProvider does not resolve reader profiles; use RelayFeedProvider.',
    );
  }

  @override
  Future<List<Story>> fetchPersonalNetworkStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  }) {
    throw UnsupportedError(
      'PrimalFeedProvider only serves trending/discovery content; '
      'use RelayFeedProvider for the personal network.',
    );
  }

  @override
  Future<List<Story>> fetchTrendingStories({
    required DateTime since,
    required DateTime until,
  }) async {
    final raw = await _client.fetchCacheEvents('explore', {
      'scope': 'global',
      'timeframe': 'trending',
      'created_after': since.millisecondsSinceEpoch ~/ 1000,
      'limit': kMaxNotesPerEdition,
    });

    // Unlike RelayFeedProvider (where ndk verifies every event as it comes
    // off a relay connection), events here arrive as plain JSON from
    // Primal's cache protocol — nothing has checked yet that a note's
    // signature actually matches its claimed author, or even that the JSON
    // is well-formed. One bad record from a third-party service shouldn't
    // take down an entire edition, so parsing and verification both happen
    // per-event with failures skipped rather than propagated.
    final untilSeconds = until.millisecondsSinceEpoch ~/ 1000;
    final notes = <String, Nip01Event>{};
    final metadataByPubkey = <String, Metadata>{};
    final engagementByEventId = <String, EngagementCounts>{};

    for (final json in raw) {
      try {
        final event = Nip01EventModel.fromJson(json);
        switch (event.kind) {
          case NostrEventKinds.textNote:
            // Trending, as Primal's own "explore" scope reports it, is
            // dominated by reply activity under a handful of viral notes —
            // filtering those out here (rather than after fetching) is
            // what actually fixes the slowness the reader hit: the
            // `limit: kMaxNotesPerEdition` budget above stops being spent
            // on thread replies, so it takes fewer round trips through
            // this cache query to fill an edition with real top-level
            // stories.
            if (event.createdAt <= untilSeconds &&
                !isReplyNote(event) &&
                await _verifier.verify(event)) {
              notes[event.id] = event;
            }
          case NostrEventKinds.metadata:
            if (await _verifier.verify(event)) {
              metadataByPubkey[event.pubKey] = Metadata.fromEvent(event);
            }
          case PrimalEventKinds.eventStats:
            // Server-aggregated counters, not a claim signed by a Nostr
            // identity — there is nothing here for a signature to verify.
            final stats = engagementFromEventStats(event);
            if (stats != null)
              engagementByEventId[stats.eventId] = stats.counts;
        }
      } catch (_) {
        continue;
      }
    }

    final stories = <Story>[];
    for (final note in notes.values) {
      try {
        final author = authorFromMetadata(
          NostrPublicKey.fromHex(note.pubKey),
          metadataByPubkey[note.pubKey],
        );
        final engagement =
            engagementByEventId[note.id] ?? EngagementCounts.zero;
        // `metadataByPubkey` already holds every kind:0 event Primal sent
        // in this same batch — if it happens to include mentioned authors
        // as well as note authors, mentions resolve for free; if not,
        // `resolveMentions` degrades to a plain "@user" placeholder rather
        // than leaving raw bech32 in the text.
        stories.add(storyFromEvent(note, author, engagement, mentionedAuthors: metadataByPubkey));
      } catch (_) {
        continue;
      }
    }
    return stories;
  }

  @override
  bool get supportsLists => false;

  @override
  Future<List<NostrList>> fetchLists(NostrPublicKey owner) {
    throw UnsupportedError('PrimalFeedProvider does not resolve NIP-51 lists; use RelayFeedProvider.');
  }

  @override
  Future<List<Story>> fetchStoriesFromList({
    required NostrPublicKey owner,
    required String listId,
    required DateTime since,
    required DateTime until,
  }) {
    throw UnsupportedError('PrimalFeedProvider does not resolve NIP-51 lists; use RelayFeedProvider.');
  }
}
