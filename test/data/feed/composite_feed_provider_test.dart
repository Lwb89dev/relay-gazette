import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/data/feed/composite_feed_provider.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/nostr_list.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/domain/repositories/feed_provider.dart';

class _StubFeedProvider implements FeedProvider {
  final String name;
  bool wasCalled = false;
  _StubFeedProvider(
    this.name, {
    this.supportsTrending = false,
    this.supportsWebOfTrust = false,
    this.supportsLists = false,
  });

  @override
  final bool supportsTrending;

  @override
  final bool supportsWebOfTrust;

  @override
  final bool supportsLists;

  @override
  Future<Author> resolveViewer(NostrPublicKey pubkey) async {
    wasCalled = true;
    return Author.unknown(pubkey, npub: 'npub1$name');
  }

  @override
  Future<List<Story>> fetchPersonalNetworkStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  }) async {
    wasCalled = true;
    return const [];
  }

  @override
  Future<List<Story>> fetchTrendingStories({required DateTime since, required DateTime until}) async {
    wasCalled = true;
    return const [];
  }

  @override
  Future<List<Story>> fetchWebOfTrustStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  }) async {
    wasCalled = true;
    return const [];
  }

  @override
  Future<List<NostrList>> fetchLists(NostrPublicKey owner) async {
    wasCalled = true;
    return const [];
  }

  @override
  Future<List<Story>> fetchStoriesFromList({
    required NostrPublicKey owner,
    required String listId,
    required DateTime since,
    required DateTime until,
  }) async {
    wasCalled = true;
    return const [];
  }
}

void main() {
  final pubkey = NostrPublicKey.fromHex('a' * 64);
  final since = DateTime.utc(2026, 8, 22);
  final until = DateTime.utc(2026, 8, 23);

  test('supportsTrending mirrors the trending delegate', () {
    final composite = CompositeFeedProvider(
      personalNetwork: _StubFeedProvider('relay'),
      trending: _StubFeedProvider('primal', supportsTrending: true),
    );
    expect(composite.supportsTrending, isTrue);
  });

  test('resolveViewer and fetchPersonalNetworkStories go to the personal-network delegate only', () async {
    final network = _StubFeedProvider('relay');
    final trending = _StubFeedProvider('primal', supportsTrending: true);
    final composite = CompositeFeedProvider(personalNetwork: network, trending: trending);

    await composite.resolveViewer(pubkey);
    await composite.fetchPersonalNetworkStories(pubkey: pubkey, since: since, until: until);

    expect(network.wasCalled, isTrue);
    expect(trending.wasCalled, isFalse);
  });

  test('fetchTrendingStories goes to the trending delegate only', () async {
    final network = _StubFeedProvider('relay');
    final trending = _StubFeedProvider('primal', supportsTrending: true);
    final composite = CompositeFeedProvider(personalNetwork: network, trending: trending);

    await composite.fetchTrendingStories(since: since, until: until);

    expect(trending.wasCalled, isTrue);
    expect(network.wasCalled, isFalse);
  });

  test('supportsWebOfTrust mirrors the trending delegate', () {
    final composite = CompositeFeedProvider(
      personalNetwork: _StubFeedProvider('relay'),
      trending: _StubFeedProvider('primal', supportsWebOfTrust: true),
    );
    expect(composite.supportsWebOfTrust, isTrue);
  });

  test('fetchWebOfTrustStories goes to the trending delegate only', () async {
    final network = _StubFeedProvider('relay');
    final trending = _StubFeedProvider('primal', supportsWebOfTrust: true);
    final composite = CompositeFeedProvider(personalNetwork: network, trending: trending);

    await composite.fetchWebOfTrustStories(pubkey: pubkey, since: since, until: until);

    expect(trending.wasCalled, isTrue);
    expect(network.wasCalled, isFalse);
  });

  test('lists (supportsLists, fetchLists, fetchStoriesFromList) always go to the '
      'personal-network delegate, even when trending is the one that supports them', () async {
    final network = _StubFeedProvider('relay', supportsLists: true);
    final trending = _StubFeedProvider('primal', supportsTrending: true, supportsLists: true);
    final composite = CompositeFeedProvider(personalNetwork: network, trending: trending);

    expect(composite.supportsLists, isTrue);
    await composite.fetchLists(pubkey);
    await composite.fetchStoriesFromList(owner: pubkey, listId: 'my-list', since: since, until: until);

    expect(network.wasCalled, isTrue);
    expect(trending.wasCalled, isFalse);
  });
}
