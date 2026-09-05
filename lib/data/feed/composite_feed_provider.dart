import '../../domain/entities/author.dart';
import '../../domain/entities/nostr_list.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/feed_provider.dart';

/// Combines two single-purpose [FeedProvider]s behind one interface: a
/// relay-backed provider for the reader's own network, and a
/// discovery/trending provider (Primal today). This is the seam the
/// product brief asks for explicitly — "the UI should not care whether an
/// item came from a normal relay query or Primal discovery" — realized by
/// keeping that decision entirely inside the data layer.
class CompositeFeedProvider implements FeedProvider {
  final FeedProvider _personalNetwork;
  final FeedProvider _trending;

  const CompositeFeedProvider({
    required FeedProvider personalNetwork,
    required FeedProvider trending,
  }) : _personalNetwork = personalNetwork,
       _trending = trending;

  @override
  bool get supportsTrending => _trending.supportsTrending;

  @override
  Future<Author> resolveViewer(NostrPublicKey pubkey) {
    return _personalNetwork.resolveViewer(pubkey);
  }

  @override
  Future<List<Story>> fetchPersonalNetworkStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  }) {
    return _personalNetwork.fetchPersonalNetworkStories(
      pubkey: pubkey,
      since: since,
      until: until,
    );
  }

  @override
  Future<List<Story>> fetchTrendingStories({
    required DateTime since,
    required DateTime until,
  }) {
    return _trending.fetchTrendingStories(since: since, until: until);
  }

  // Lists are a personal-network concept (NIP-51 sets the reader curates
  // themselves) — always served by the relay-backed provider, regardless
  // of which one handles trending.
  @override
  bool get supportsLists => _personalNetwork.supportsLists;

  @override
  Future<List<NostrList>> fetchLists(NostrPublicKey owner) {
    return _personalNetwork.fetchLists(owner);
  }

  @override
  Future<List<Story>> fetchStoriesFromList({
    required NostrPublicKey owner,
    required String listId,
    required DateTime since,
    required DateTime until,
  }) {
    return _personalNetwork.fetchStoriesFromList(
      owner: owner,
      listId: listId,
      since: since,
      until: until,
    );
  }
}
