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
  List<Map<String, dynamic>> response = const [];
  String? lastFunction;
  Map<String, dynamic>? lastParams;

  @override
  Future<List<Map<String, dynamic>>> fetchCacheEvents(
    String function,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    lastFunction = function;
    lastParams = params;
    return response;
  }
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

  test('requests the global trending explore feed with the resolved window', () async {
    final client = _FakePrimalCacheClient();
    final provider = PrimalFeedProvider(client, verifier: _StubVerifier(true));

    await provider.fetchTrendingStories(since: since, until: until);

    expect(client.lastFunction, 'explore');
    expect(client.lastParams!['scope'], 'global');
    expect(client.lastParams!['timeframe'], 'trending');
    expect(client.lastParams!['created_after'], since.millisecondsSinceEpoch ~/ 1000);
  });

  test('joins notes, author metadata, and engagement stats into Stories', () async {
    final client = _FakePrimalCacheClient()
      ..response = [
        _note('note-1', pubkey: author, createdAt: 1755900000, content: 'hello world'),
        _metadata(author, createdAt: 1755800000, displayName: 'Alice'),
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
      ..response = [_note('note-1', pubkey: author, createdAt: 1755900000)];
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
        _note('top-level', pubkey: author, createdAt: 1755900000),
        _note(
          'a-reply',
          pubkey: author,
          createdAt: 1755900000,
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
      ..response = [_note('note-1', pubkey: author, createdAt: 1755900000)];
    final provider = PrimalFeedProvider(client, verifier: _StubVerifier(false));

    final stories = await provider.fetchTrendingStories(since: since, until: until);

    expect(stories, isEmpty);
  });

  test('drops author metadata whose signature does not verify', () async {
    final client = _FakePrimalCacheClient()
      ..response = [
        _note('note-1', pubkey: author, createdAt: 1755900000),
        _metadata(author, createdAt: 1755800000, displayName: 'Alice'),
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
        _note('good-note', pubkey: author, createdAt: 1755900000),
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
}
