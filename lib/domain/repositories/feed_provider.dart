import '../entities/author.dart';
import '../entities/nostr_list.dart';
import '../entities/nostr_public_key.dart';
import '../entities/story.dart';

/// Source of edition content, independent of how it's actually fetched.
/// [RelayFeedProvider] talks to Nostr relays directly; a future
/// `PrimalFeedProvider` would talk to Primal's caching API instead. The
/// domain and presentation layers only ever see [Story]/[Author], never
/// relay responses or Primal-specific payloads.
abstract class FeedProvider {
  /// Whether [fetchTrendingStories] is meaningfully implemented by this
  /// provider. A plain relay provider has no trending algorithm of its own.
  bool get supportsTrending;

  /// Resolves profile info for the signed-in reader (read-only; no keys
  /// required), used to confirm "is this you?" during onboarding.
  Future<Author> resolveViewer(NostrPublicKey pubkey);

  /// Stories authored by [pubkey]'s follows, published within
  /// `[since, until)`, with engagement counts already attached.
  Future<List<Story>> fetchPersonalNetworkStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  });

  /// Stories trending across the wider network within `[since, until)`.
  /// Throws [UnsupportedError] when [supportsTrending] is false.
  Future<List<Story>> fetchTrendingStories({
    required DateTime since,
    required DateTime until,
  });

  /// Whether [fetchWebOfTrustStories] is meaningfully implemented by this
  /// provider. A plain relay provider has no way to compute this without
  /// crawling the follow graph itself.
  bool get supportsWebOfTrust;

  /// Stories [pubkey]'s wider network — not just their direct follows —
  /// has engaged with, within `[since, until)`. Distinct from
  /// [fetchPersonalNetworkStories] (direct follows only, exact contact
  /// list) and [fetchTrendingStories] (global, no personalization at all):
  /// this is the practical middle ground reader-facing Nostr apps call
  /// "Web of Trust". Throws [UnsupportedError] when [supportsWebOfTrust]
  /// is false.
  Future<List<Story>> fetchWebOfTrustStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  });

  /// Whether [fetchLists] and [fetchStoriesFromList] are meaningfully
  /// implemented by this provider.
  bool get supportsLists;

  /// The NIP-51 follow sets [owner] has published, for choosing one as an
  /// edition's author pool. Throws [UnsupportedError] when [supportsLists]
  /// is false.
  Future<List<NostrList>> fetchLists(NostrPublicKey owner);

  /// Stories authored by the members of the list identified by [listId]
  /// (see [fetchLists]), published within `[since, until)`. Throws
  /// [UnsupportedError] when [supportsLists] is false.
  Future<List<Story>> fetchStoriesFromList({
    required NostrPublicKey owner,
    required String listId,
    required DateTime since,
    required DateTime until,
  });
}
