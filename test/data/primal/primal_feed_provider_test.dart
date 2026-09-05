import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:relay_gazette/data/primal/primal_cache_client.dart';
import 'package:relay_gazette/data/primal/primal_event_kinds.dart';
import 'package:relay_gazette/data/primal/primal_feed_provider.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';

/// Test data below has no real BIP-340 signatures attached, so a
/// stand-in verifier is injected almost everywhere: it isolates these
/// tests to the join/mapping logic. The one test that injects a *real*
/// [Bip340EventVerifier] (or a stub that rejects) exists specifically to
/// prove the signature check is actually wired in, not bypassable.
class _StubVerifier implements EventVerifier {
  final bool result;
  _StubVerifier(this.result);

  @override
  Future<bool> verify(Nip01Event event) async => result;
}

class _RejectKindVerifier implements EventVerifier {
  final int rejectedKind;
  _RejectKindVerifier({required this.rejectedKind});

  @override
  Future<bool> verify(Nip01Event event) async => event.kind != rejectedKind;
}

class _FakePrimalCacheClient implements PrimalCacheClient {
  // Every provider method now makes two calls (one for kind:1 notes, one
  // for kind:30023 long-form articles) rather than one, so tests that
  // care about *which* call got *which* params/response inspect [calls]
  // instead of a single last-call snapshot. `response` (the notes-call
  // fixture) and `articlesResponse` (the articles-call fixture) default
  // to empty so existing note-only tests don't get their fixture
  // double-counted through both calls.
  List<Map<String, dynamic>> response = const [];
  List<Map<String, dynamic>> articlesResponse = const [];
  final List<({String function, Map<String, dynamic> params})> calls = [];

  String? get lastFunction => calls.isEmpty ? null : calls.last.function;
  Map<String, dynamic>? get lastParams => calls.isEmpty ? null : calls.last.params;

  @override
  Future<List<Map<String, dynamic>>> fetchCacheEvents(
    String function,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    calls.add((function: function, params: params));
    return calls.length == 1 ? response : articlesResponse;
  }
}

Map<String, dynamic> _article(
  String id, {
  required String pubkey,
  required int createdAt,
  String title = '',
  String content = '',
}) {
  return {
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': 30023,
    'tags': [
      ['title', title],
    ],
    'content': content,
  };
}

Map<String, dynamic> _note(
  String id, {
  required String pubkey,
  required int createdAt,
  String content = '',
  List<List<String>> tags = const [],
}) {
  return {
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': 1,
    'tags': tags,
    'content': content,
  };
}

Map<String, dynamic> _metadata(String pubkey, {required int createdAt, String? displayName}) {
  return {
    'id': 'meta-$pubkey',
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': 0,
    'tags': <List<String>>[],
    'content': jsonEncode({if (displayName != null) 'display_name': displayName}),
  };
}

Map<String, dynamic> _stats(String eventId, {required int likes, required int zapSats}) {
  return {
    'id': 'stats-$eventId',
    'pubkey': 'p' * 64,
    'created_at': 0,
    'kind': PrimalEventKinds.eventStats,
    'tags': <List<String>>[],
    'content': jsonEncode({'event_id': eventId, 'likes': likes, 'satszapped': zapSats}),
  };
}

void main() {
  final author = 'a' * 64;
  final since = DateTime.utc(2026, 8, 22);
  final until = DateTime.utc(2026, 8, 23);

  test('requests the global trending explore feed with the resolved window, '
      'plus a separate advanced_search call for long-form articles', () async {
    final client = _FakePrimalCacheClient();
    final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

    await provider.fetchTrendingStories(since: since, until: until);

    expect(client.calls, hasLength(2));
    expect(client.calls[0].function, 'explore');
    expect(client.calls[0].params['scope'], 'global');
    expect(client.calls[0].params['timeframe'], 'trending');
    expect(client.calls[0].params['created_after'], since.millisecondsSinceEpoch ~/ 1000);
    expect(client.calls[1].function, 'advanced_search');
    expect(client.calls[1].params['query'], 'kind:30023 since:2026-08-22');
  });

  test('joins notes, author metadata, and engagement stats into Stories', () async {
    final client = _FakePrimalCacheClient()
      ..response = [
        _note('note-1', pubkey: author, createdAt: 1787400000, content: 'hello world'),
        _metadata(author, createdAt: 1787360400, displayName: 'Alice'),
        _stats('note-1', likes: 42, zapSats: 2100),
      ];
    final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

    final stories = await provider.fetchTrendingStories(since: since, until: until);

    expect(stories, hasLength(1));
    final story = stories.single;
    expect(story.id, 'note-1');
    expect(story.author.displayName, 'Alice');
    expect(story.engagement.reactions, 42);
    expect(story.engagement.zapSats, 2100);
  });

  test('a note with no matching stats event gets zero engagement, not a crash', () async {
    final client = _FakePrimalCacheClient()
      ..response = [_note('note-1', pubkey: author, createdAt: 1787400000)];
    final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

    final stories = await provider.fetchTrendingStories(since: since, until: until);

    expect(stories.single.engagement.reactions, 0);
  });

  test('excludes notes published after the window end', () async {
    final withinWindow = until.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final afterWindow = until.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final client = _FakePrimalCacheClient()
      ..response = [
        _note('in-window', pubkey: author, createdAt: withinWindow),
        _note('too-late', pubkey: author, createdAt: afterWindow),
      ];
    final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

    final stories = await provider.fetchTrendingStories(since: since, until: until);

    expect(stories.map((s) => s.id), ['in-window']);
  });

  test('drops thread replies, keeping only standalone top-level notes', () async {
    final client = _FakePrimalCacheClient()
      ..response = [
        _note('top-level', pubkey: author, createdAt: 1787400000),
        _note(
          'a-reply',
          pubkey: author,
          createdAt: 1787400000,
          tags: [
            ['e', 'parent-note', '', 'reply'],
          ],
        ),
      ];
    final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

    final stories = await provider.fetchTrendingStories(since: since, until: until);

    expect(stories.map((s) => s.id), ['top-level']);
  });

  test('drops notes whose signature does not verify, unlike relay-sourced stories, '
      'nothing here has been checked yet by the time it arrives', () async {
    final client = _FakePrimalCacheClient()
      ..response = [_note('note-1', pubkey: author, createdAt: 1787400000)];
    final provider = PrimalFeedProvider(client, verifier: _StubVerifier(false));

    final stories = await provider.fetchTrendingStories(since: since, until: until);

    expect(stories, isEmpty);
  });

  test('drops author metadata whose signature does not verify', () async {
    final client = _FakePrimalCacheClient()
      ..response = [
        _note('note-1', pubkey: author, createdAt: 1787400000),
        _metadata(author, createdAt: 1787360400, displayName: 'Alice'),
      ];
    // The note itself is fine; only fabricated *metadata* should be
    // rejected, and the story should fall back to an unknown-author label
    // rather than trusting an unverified display name.
    final verifier = _RejectKindVerifier(rejectedKind: 0);
    final provider = PrimalFeedProvider(client, verifier: verifier);

    final stories = await provider.fetchTrendingStories(since: since, until: until);

    expect(stories, hasLength(1));
    expect(stories.single.author.displayName, isNull);
  });

  test('one malformed record from the cache does not take down the whole edition', () async {
    final client = _FakePrimalCacheClient()
      ..response = [
        {'kind': 1, 'this is': 'missing every required NIP-01 field'},
        _note('good-note', pubkey: author, createdAt: 1787400000),
      ];
    final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

    final stories = await provider.fetchTrendingStories(since: since, until: until);

    expect(stories.map((s) => s.id), ['good-note']);
  });

  test('supportsTrending is true, and network-only methods are unsupported', () {
    final provider = PrimalFeedProvider(_FakePrimalCacheClient(), verifier: _StubVerifier(true));
    expect(provider.supportsTrending, isTrue);
    expect(
      () => provider.fetchPersonalNetworkStories(
        pubkey: NostrPublicKey.fromHex(author),
        since: since,
        until: until,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => provider.resolveViewer(NostrPublicKey.fromHex(author)),
      throwsUnsupportedError,
    );
  });

  group('fetchWebOfTrustStories', () {
    test('supportsWebOfTrust is true', () {
      final provider = PrimalFeedProvider(_FakePrimalCacheClient(), verifier: _StubVerifier(true));
      expect(provider.supportsWebOfTrust, isTrue);
    });

    test('requests advanced_search with scope:mynetworkinteractions and a day-granularity '
        'since: keyword — confirmed live against Primal\'s real cache server that a raw '
        'unix timestamp there is rejected — plus a separate call for long-form articles', () async {
      final client = _FakePrimalCacheClient();
      final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));
      final viewer = NostrPublicKey.fromHex(author);

      await provider.fetchWebOfTrustStories(pubkey: viewer, since: since, until: until);

      expect(client.calls, hasLength(2));
      expect(client.calls[0].function, 'advanced_search');
      expect(client.calls[0].params['query'], 'kind:1 scope:mynetworkinteractions since:2026-08-22');
      expect(client.calls[0].params['user_pubkey'], author);
      expect(client.calls[1].function, 'advanced_search');
      expect(client.calls[1].params['query'], 'kind:30023 scope:mynetworkinteractions since:2026-08-22');
      expect(client.calls[1].params['user_pubkey'], author);
    });

    test('joins notes, author metadata, and engagement stats into Stories, same as trending', () async {
      final client = _FakePrimalCacheClient()
        ..response = [
          _note('note-1', pubkey: author, createdAt: 1787400000, content: 'hello network'),
          _metadata(author, createdAt: 1787360400, displayName: 'Alice'),
          _stats('note-1', likes: 7, zapSats: 500),
        ];
      final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

      final stories = await provider.fetchWebOfTrustStories(
        pubkey: NostrPublicKey.fromHex(author),
        since: since,
        until: until,
      );

      expect(stories, hasLength(1));
      final story = stories.single;
      expect(story.id, 'note-1');
      expect(story.author.displayName, 'Alice');
      expect(story.engagement.reactions, 7);
      expect(story.engagement.zapSats, 500);
    });

    test('excludes notes published before the window start, not just after the end', () async {
      final beforeWindow = since.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final withinWindow = since.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final client = _FakePrimalCacheClient()
        ..response = [
          _note('too-early', pubkey: author, createdAt: beforeWindow),
          _note('in-window', pubkey: author, createdAt: withinWindow),
        ];
      final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

      final stories = await provider.fetchWebOfTrustStories(
        pubkey: NostrPublicKey.fromHex(author),
        since: since,
        until: until,
      );

      expect(stories.map((s) => s.id), ['in-window']);
    });
  });

  group('long-form articles (kind:30023), fetched via the second advanced_search call', () {
    test('fetchTrendingStories includes long-form articles alongside notes', () async {
      final client = _FakePrimalCacheClient()
        ..response = [_note('note-1', pubkey: author, createdAt: 1787400000)]
        ..articlesResponse = [
          _article('article-1', pubkey: author, createdAt: 1787400000, title: 'A Proper Headline', content: 'Body.'),
        ];
      final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

      final stories = await provider.fetchTrendingStories(since: since, until: until);

      expect(stories.map((s) => s.id), containsAll(['note-1', 'article-1']));
      final article = stories.firstWhere((s) => s.id == 'article-1');
      expect(article.isLongFormArticle, isTrue);
      expect(article.title, 'A Proper Headline');
    });

    test('fetchWebOfTrustStories includes long-form articles alongside notes', () async {
      final client = _FakePrimalCacheClient()
        ..response = [_note('note-1', pubkey: author, createdAt: 1787400000)]
        ..articlesResponse = [
          _article('article-1', pubkey: author, createdAt: 1787400000, title: 'Network Read', content: 'Body.'),
        ];
      final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

      final stories = await provider.fetchWebOfTrustStories(
        pubkey: NostrPublicKey.fromHex(author),
        since: since,
        until: until,
      );

      expect(stories.map((s) => s.id), containsAll(['note-1', 'article-1']));
      final article = stories.firstWhere((s) => s.id == 'article-1');
      expect(article.isLongFormArticle, isTrue);
      expect(article.title, 'Network Read');
    });

    test('an unverifiable article is dropped, same as an unverifiable note', () async {
      final client = _FakePrimalCacheClient()
        ..articlesResponse = [_article('article-1', pubkey: author, createdAt: 1787400000, title: 'Fake')];
      final provider = PrimalFeedProvider(client, verifier: _StubVerifier(false));

      final stories = await provider.fetchTrendingStories(since: since, until: until);

      expect(stories, isEmpty);
    });
  });
}
