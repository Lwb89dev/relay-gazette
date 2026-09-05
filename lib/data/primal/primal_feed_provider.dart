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
    // `explore` (the function backing Primal's own "Trending" tab) has no
    // `kinds` filter of its own — confirmed live: passing one is rejected
    // with a NOTICE — so it only ever returns kind:1 notes. Long-form
    // articles (kind:30023) need a second, separate call through
    // `advanced_search` instead (also confirmed live: `kind:30023` with no
    // `scope:` keyword — meaning global, the same reach `explore` has —
    // returns real articles with no `user_pubkey` needed).
    final notesRaw = await _client.fetchCacheEvents('explore', {
      'scope': 'global',
      'timeframe': 'trending',
      'created_after': since.millisecondsSinceEpoch ~/ 1000,
      'limit': kMaxNotesPerEdition,
    });
    final articlesRaw = await _client.fetchCacheEvents('advanced_search', {
      'query': 'kind:30023 since:${_dateOnly(since)}',
      'limit': kMaxNotesPerEdition,
    });
    return _parseStories([...notesRaw, ...articlesRaw], since: since, until: until);
  }

  @override
  bool get supportsWebOfTrust => true;

  @override
  Future<List<Story>> fetchWebOfTrustStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  }) async {
    // Primal's own "My Network Interactions" scope: notes the reader's
    // wider network (not just their direct follows) has engaged with —
    // computed server-side from Primal's own follow-graph index, which is
    // the only practical way to get a Web-of-Trust-shaped signal without
    // this client crawling the graph itself. Confirmed live against
    // Primal's production cache server while building this — see
    // TASKS.md for how (`advanced_search` isn't in any NIP, and only
    // partially traces to the public `primal-server` repo, since the
    // actual query engine behind it is a separate, not-open-sourced
    // module Primal's own servers load).
    //
    // The query string's `since:`/`until:` keywords are day-granularity
    // (`YYYY-MM-DD`), not exact timestamps, so the window is widened to
    // the whole calendar day on both ends here and trimmed to the exact
    // `[since, until)` bound client-side in `_parseStories`, same as
    // `fetchTrendingStories` already does for its own upper bound.
    //
    // Two separate calls (kind:1, kind:30023), same as `fetchTrendingStories`
    // — `advanced_search`'s query language takes one `kind:` per call, not
    // an OR of several.
    final notesRaw = await _client.fetchCacheEvents('advanced_search', {
      'query': 'kind:1 scope:mynetworkinteractions since:${_dateOnly(since)}',
      'user_pubkey': pubkey.hex,
      'limit': kMaxNotesPerEdition,
    });
    final articlesRaw = await _client.fetchCacheEvents('advanced_search', {
      'query': 'kind:30023 scope:mynetworkinteractions since:${_dateOnly(since)}',
      'user_pubkey': pubkey.hex,
      'limit': kMaxNotesPerEdition,
    });
    return _parseStories([...notesRaw, ...articlesRaw], since: since, until: until);
  }

  Future<List<Story>> _parseStories(
    List<Map<String, dynamic>> raw, {
    required DateTime since,
    required DateTime until,
  }) async {
    // Unlike RelayFeedProvider (where ndk verifies every event as it comes
    // off a relay connection), events here arrive as plain JSON from
    // Primal's cache protocol — nothing has checked yet that a note's
    // signature actually matches its claimed author, or even that the JSON
    // is well-formed. One bad record from a third-party service shouldn't
    // take down an entire edition, so parsing and verification both happen
    // per-event with failures skipped rather than propagated.
    final sinceSeconds = since.millisecondsSinceEpoch ~/ 1000;
    final untilSeconds = until.millisecondsSinceEpoch ~/ 1000;
    final notes = <String, Nip01Event>{};
    final metadataByPubkey = <String, Metadata>{};
    final engagementByEventId = <String, EngagementCounts>{};

    for (final json in raw) {
      try {
        final event = Nip01EventModel.fromJson(json);
        switch (event.kind) {
          case NostrEventKinds.textNote:
            // Trending/Web-of-Trust, as Primal's own scopes report them,
            // are dominated by reply activity under a handful of viral
            // notes — filtering those out here (rather than after
            // fetching) is what actually fixes the slowness reported
            // against trending: the `limit: kMaxNotesPerEdition` budget
            // above stops being spent on thread replies, so it takes
            // fewer round trips through this cache query to fill an
            // edition with real top-level stories.
            if (event.createdAt >= sinceSeconds &&
                event.createdAt <= untilSeconds &&
                !isReplyNote(event) &&
                await _verifier.verify(event)) {
              notes[event.id] = event;
            }
          case NostrEventKinds.longFormArticle:
            // No reply concept for NIP-23 articles — unlike a plain note,
            // there is nothing here to filter the way `isReplyNote` filters
            // kind:1 thread replies.
            if (event.createdAt >= sinceSeconds &&
                event.createdAt <= untilSeconds &&
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
        stories.add(
          note.kind == NostrEventKinds.longFormArticle
              ? articleFromEvent(note, author, engagement, mentionedAuthors: metadataByPubkey)
              : storyFromEvent(note, author, engagement, mentionedAuthors: metadataByPubkey),
        );
      } catch (_) {
        continue;
      }
    }
    return stories;
  }

  /// `YYYY-MM-DD` in UTC — the granularity Primal's `advanced_search`
  /// query-string `since:`/`until:` keywords accept (confirmed live: a raw
  /// unix timestamp there is rejected with a NOTICE).
  String _dateOnly(DateTime date) {
    final utc = date.toUtc();
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${pad2(utc.month)}-${pad2(utc.day)}';
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
