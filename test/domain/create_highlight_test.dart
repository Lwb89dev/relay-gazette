import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/nostr_event_draft.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/domain/repositories/event_broadcaster.dart';
import 'package:relay_gazette/domain/repositories/nostr_signer.dart';
import 'package:relay_gazette/domain/usecases/create_highlight.dart';

class _FakeSigner implements NostrSigner {
  bool rejectNext = false;
  UnsignedNostrEvent? lastRequested;
  final NostrPublicKey signerPubkey;
  _FakeSigner(this.signerPubkey);

  @override
  bool get isConnected => true;

  @override
  NostrPublicKey? get connectedPubkey => signerPubkey;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<NostrPublicKey?> connect() async => signerPubkey;

  @override
  Future<void> disconnect() async {}

  @override
  Future<SignedNostrEvent?> sign(UnsignedNostrEvent event) async {
    lastRequested = event;
    if (rejectNext) return null;
    return SignedNostrEvent(
      id: 'signed-highlight',
      pubkeyHex: signerPubkey.hex,
      kind: event.kind,
      content: event.content,
      tags: event.tags,
      createdAt: event.createdAt,
      signature: 's' * 128,
    );
  }
}

class _FakeBroadcaster implements EventBroadcaster {
  final List<SignedNostrEvent> broadcasted = [];

  @override
  Future<void> broadcast(SignedNostrEvent event) async {
    broadcasted.add(event);
  }
}

Story _note() {
  final authorPubkey = NostrPublicKey.fromHex('b' * 64);
  return Story(
    id: 'note-1',
    kind: Story.kTextNote,
    author: Author.unknown(authorPubkey, npub: 'npub1author'),
    content: 'hello world',
    createdAt: DateTime.utc(2026, 8, 23),
    engagement: EngagementCounts.zero,
  );
}

Story _article() {
  final authorPubkey = NostrPublicKey.fromHex('c' * 64);
  return Story(
    id: 'article-1',
    kind: Story.kLongFormArticle,
    author: Author.unknown(authorPubkey, npub: 'npub1author2'),
    content: 'the whole article body',
    createdAt: DateTime.utc(2026, 8, 23),
    engagement: EngagementCounts.zero,
    title: 'A Title',
    dTag: 'my-slug',
  );
}

void main() {
  final signerPubkey = NostrPublicKey.fromHex('d' * 64);

  test('signs a kind-9802 highlight tagging the source note and its author', () async {
    final signer = _FakeSigner(signerPubkey);
    final broadcaster = _FakeBroadcaster();
    final highlight = CreateHighlight(signer, broadcaster);

    final ok = await highlight(_note(), 'the highlighted passage');

    expect(ok, isTrue);
    expect(signer.lastRequested!.kind, 9802);
    expect(signer.lastRequested!.content, 'the highlighted passage');
    expect(signer.lastRequested!.tags, contains(equals(['e', 'note-1'])));
    expect(signer.lastRequested!.tags, contains(equals(['p', 'b' * 64, '', 'author'])));
    expect(broadcaster.broadcasted, hasLength(1));
  });

  test('also tags an addressable "a" reference for a long-form article', () async {
    final signer = _FakeSigner(signerPubkey);
    final highlight = CreateHighlight(signer, _FakeBroadcaster());

    await highlight(_article(), 'a great point');

    expect(signer.lastRequested!.tags, contains(equals(['a', '30023:${'c' * 64}:my-slug'])));
  });

  test('does not add an "a" tag for a plain note (nothing addressable to reference)', () async {
    final signer = _FakeSigner(signerPubkey);
    final highlight = CreateHighlight(signer, _FakeBroadcaster());

    await highlight(_note(), 'a great point');

    expect(signer.lastRequested!.tags.any((t) => t[0] == 'a'), isFalse);
  });

  test('includes an optional context tag when provided', () async {
    final signer = _FakeSigner(signerPubkey);
    final highlight = CreateHighlight(signer, _FakeBroadcaster());

    await highlight(_note(), 'the passage', context: 'surrounding text for context');

    expect(signer.lastRequested!.tags, contains(equals(['context', 'surrounding text for context'])));
  });

  test('rejects blank highlighted text before ever asking the signer', () async {
    final signer = _FakeSigner(signerPubkey);
    final highlight = CreateHighlight(signer, _FakeBroadcaster());

    final ok = await highlight(_note(), '   ');

    expect(ok, isFalse);
    expect(signer.lastRequested, isNull);
  });

  test('returns false and broadcasts nothing when the signer declines', () async {
    final signer = _FakeSigner(signerPubkey)..rejectNext = true;
    final broadcaster = _FakeBroadcaster();
    final highlight = CreateHighlight(signer, broadcaster);

    final ok = await highlight(_note(), 'the passage');

    expect(ok, isFalse);
    expect(broadcaster.broadcasted, isEmpty);
  });
}
