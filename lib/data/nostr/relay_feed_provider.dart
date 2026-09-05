import 'package:ndk/ndk.dart';

import '../../domain/entities/author.dart';
import '../../domain/entities/engagement.dart';
import '../../domain/entities/nostr_list.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/feed_provider.dart';
import 'event_kinds.dart';
import 'nostr_mappers.dart';
import 'relay_defaults.dart';

/// [FeedProvider] backed directly by Nostr relays via ndk. This is the only
/// place in the app that speaks NIP-01 filters and raw events — everything
/// it returns has already been normalized into domain [Story]/[Author]
/// objects.
class RelayFeedProvider implements FeedProvider {
  final Ndk _ndk;

  RelayFeedProvider(this._ndk);

  @override
  bool get supportsTrending => false;

  @override
  bool get supportsLists => true;

  @override
  Future<Author> resolveViewer(NostrPublicKey pubkey) async {
    final metadata = await _ndk.metadata.loadMetadata(pubkey.hex);
    return authorFromMetadata(pubkey, metadata);
  }

  @override
  Future<List<Story>> fetchPersonalNetworkStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  }) async {
    final contactList = await _ndk.follows.getContactList(pubkey.hex);
    final follows = contactList?.contacts ?? const <String>[];
    return _fetchStoriesForAuthors(
      authors: follows,
      since: since,
      until: until,
    );
  }

  @override
  Future<List<Story>> fetchTrendingStories({
    required DateTime since,
    required DateTime until,
  }) {
    throw UnsupportedError(
      'RelayFeedProvider has no trending algorithm of its own. '
      'Trending is served by PrimalFeedProvider (Phase 2).',
    );
  }

  @override
  bool get supportsWebOfTrust => false;

  @override
  Future<List<Story>> fetchWebOfTrustStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  }) {
    throw UnsupportedError(
      'RelayFeedProvider has no way to compute a Web-of-Trust ranking '
      'without crawling the follow graph itself. Served by '
      'PrimalFeedProvider instead.',
    );
  }

  @override
  Future<List<NostrList>> fetchLists(NostrPublicKey owner) async {
    final response = await _ndk.requests
        .query(
          filter: Filter(
            kinds: const [NostrEventKinds.followSet],
            authors: [owner.hex],
          ),
        )
        .future;

    final lists = <String, NostrList>{};
    for (final event in response) {
      final id = _firstTagValue(event, 'd');
      if (id == null) continue;

      final members = event.tags
          .where((tag) => tag.length >= 2 && tag[0] == 'p')
          .map((tag) => tag[1])
          .where(NostrPublicKey.looksLikeHex)
          .map(NostrPublicKey.fromHex)
          .toList();

      final title = _firstTagValue(event, 'title') ?? id;
      // A d-tag is a replaceable-event identifier — keep only the newest
      // version of each list if a relay hands back more than one.
      lists[id] = NostrList(id: id, title: title, members: members);
    }
    return lists.values.toList();
  }

  @override
  Future<List<Story>> fetchStoriesFromList({
    required NostrPublicKey owner,
    required String listId,
    required DateTime since,
    required DateTime until,
  }) async {
    final lists = await fetchLists(owner);
    NostrList? list;
    for (final candidate in lists) {
      if (candidate.id == listId) {
        list = candidate;
        break;
      }
    }
    if (list == null) return const [];

    return _fetchStoriesForAuthors(
      authors: list.members.map((p) => p.hex).toList(),
      since: since,
      until: until,
    );
  }

  String? _firstTagValue(Nip01Event event, String tagName) {
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == tagName) return tag[1];
    }
    return null;
  }

  Future<List<Story>> _fetchStoriesForAuthors({
    required List<String> authors,
    required DateTime since,
    required DateTime until,
  }) async {
    if (authors.isEmpty) return const [];

    final boundedAuthors = authors.length > kMaxAuthorsPerQuery
        ? authors.sublist(0, kMaxAuthorsPerQuery)
        : authors;

    // Resolving NIP-65 relay lists for every followed author requires an
    // extra network round-trip per account and can turn one edition into
    // hundreds of connection probes. A newspaper needs a prompt snapshot,
    // so personal editions query the already-connected bootstrap relays
    // directly. Readers can still add their preferred relays in Settings.
    //
    // Long-form articles (NIP-23) are fetched in the same query as plain
    // notes — they're "deeper" stories from the same authors and window.
    final notesResponse = _ndk.requests.query(
      filter: Filter(
        kinds: const [
          NostrEventKinds.textNote,
          NostrEventKinds.longFormArticle,
        ],
        authors: boundedAuthors,
        since: since.millisecondsSinceEpoch ~/ 1000,
        until: until.millisecondsSinceEpoch ~/ 1000,
        limit: kMaxNotesPerEdition,
      ),
    );
    final rawNotes = await notesResponse.future;

    final uniqueNotes = <String, Nip01Event>{};
    for (final note in rawNotes) {
      // Thread replies aren't excluded by the relay filter (NIP-01 has no
      // "root notes only" filter field) — drop them here instead of
      // showing a front page full of comment fragments.
      if (note.kind == NostrEventKinds.textNote && isReplyNote(note)) continue;
      uniqueNotes[note.id] = note;
    }
    if (uniqueNotes.isEmpty) return const [];

    // Metadata for note authors *and* anyone the notes mention inline
    // (`nostr:npub1...`), fetched together so `resolveMentions` can turn a
    // mention into "@DisplayName" instead of leaving a 60+ character
    // bech32 string in the middle of a sentence.
    final authorPubkeys = uniqueNotes.values.map((e) => e.pubKey).toSet();
    final mentionedPubkeys = uniqueNotes.values
        .expand((e) => mentionedPubkeysIn(e.content))
        .toSet();
    final noteIds = uniqueNotes.keys.toSet();
    // Both operations are independent after the notes arrive. Starting them
    // together removes one whole network wait from personal editions.
    final engagementFuture = _fetchEngagementCounts(noteIds);
    final metadataFuture = _ndk.metadata.loadMetadatas([
      ...authorPubkeys,
      ...mentionedPubkeys,
    ], null);
    final engagementByNoteId = await engagementFuture;
    final metadataList = await metadataFuture;
    final metadataByPubkey = {
      for (final metadata in metadataList) metadata.pubKey: metadata,
    };

    return uniqueNotes.values.map((note) {
      final authorPubkey = NostrPublicKey.fromHex(note.pubKey);
      final author = authorFromMetadata(
        authorPubkey,
        metadataByPubkey[note.pubKey],
      );
      final engagement = engagementByNoteId[note.id] ?? EngagementCounts.zero;
      return note.kind == NostrEventKinds.longFormArticle
          ? articleFromEvent(
              note,
              author,
              engagement,
              mentionedAuthors: metadataByPubkey,
            )
          : storyFromEvent(
              note,
              author,
              engagement,
              mentionedAuthors: metadataByPubkey,
            );
    }).toList();
  }

  /// Fetches reactions, reposts, replies, and zap receipts for [noteIds] in
  /// four relay queries total — regardless of how many notes are being
  /// scored — by filtering on `#e` membership rather than querying per note.
  /// They deliberately start together: waiting for each relay's EOSE in
  /// sequence was the dominant cost of a personal-edition generation.
  Future<Map<String, EngagementCounts>> _fetchEngagementCounts(
    Set<String> noteIds,
  ) async {
    final ids = noteIds.toList();

    final responses = await Future.wait([
      _ndk.requests
          .query(
            filter: Filter(kinds: const [NostrEventKinds.reaction], eTags: ids),
          )
          .future,
      _ndk.requests
          .query(
            filter: Filter(kinds: const [NostrEventKinds.repost], eTags: ids),
          )
          .future,
      _ndk.requests
          .query(
            filter: Filter(kinds: const [NostrEventKinds.textNote], eTags: ids),
          )
          .future,
      _ndk.requests
          .query(
            filter: Filter(
              kinds: const [NostrEventKinds.zapReceipt],
              eTags: ids,
            ),
          )
          .future,
    ]);
    final reactions = responses[0];
    final reposts = responses[1];
    final replies = responses[2];
    final zaps = responses[3];

    final counts = <String, EngagementCounts>{};
    void update(String? id, EngagementCounts Function(EngagementCounts) apply) {
      if (id == null) return;
      counts[id] = apply(counts[id] ?? EngagementCounts.zero);
    }

    for (final event in reactions) {
      update(
        referencedStoryId(event, noteIds),
        (c) => c.copyWith(reactions: c.reactions + 1),
      );
    }
    for (final event in reposts) {
      update(
        referencedStoryId(event, noteIds),
        (c) => c.copyWith(reposts: c.reposts + 1),
      );
    }
    for (final event in replies) {
      if (noteIds.contains(event.id)) {
        continue; // a candidate note is not its own reply
      }
      update(
        referencedStoryId(event, noteIds),
        (c) => c.copyWith(replies: c.replies + 1),
      );
    }
    for (final event in zaps) {
      final sats = zapSatsFromReceipt(event);
      update(
        referencedStoryId(event, noteIds),
        (c) => c.copyWith(zapCount: c.zapCount + 1, zapSats: c.zapSats + sats),
      );
    }

    return counts;
  }
}
