import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/nostr_event_draft.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/domain/repositories/event_broadcaster.dart';
import 'package:relay_gazette/domain/repositories/nostr_signer.dart';
import 'package:relay_gazette/domain/usecases/interactions.dart';

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
      id: 'signed-${event.kind}',
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

Story _story() {
  final authorPubkey = NostrPublicKey.fromHex('b' * 64);
  return Story(
    id: 'note-1',
    kind: Story.kTextNote,
    author: Author.unknown(authorPubkey, npub: 'npub1author'),
    content: 'hello',
    createdAt: DateTime.utc(2026, 8, 23),
    engagement: EngagementCounts.zero,
  );
}

void main() {
  final signerPubkey = NostrPublicKey.fromHex('c' * 64);

  group('ReactToStory', () {
    test('signs a kind-7 reaction tagging the story and its author, then broadcasts it', () async {
      final signer = _FakeSigner(signerPubkey);
      final broadcaster = _FakeBroadcaster();
      final react = ReactToStory(signer, broadcaster);

      final ok = await react(_story());

      expect(ok, isTrue);
      expect(signer.lastRequested!.kind, 7);
      expect(signer.lastRequested!.content, '+');
      expect(signer.lastRequested!.tags, [
        ['e', 'note-1'],
        ['p', 'b' * 64],
      ]);
      expect(broadcaster.broadcasted, hasLength(1));
    });

    test('a custom reaction emoji is passed through as content', () async {
      final signer = _FakeSigner(signerPubkey);
      final react = ReactToStory(signer, _FakeBroadcaster());

      await react(_story(), reaction: '🔥');

      expect(signer.lastRequested!.content, '🔥');
    });

    test('returns false and broadcasts nothing when the signer declines', () async {
      final signer = _FakeSigner(signerPubkey)..rejectNext = true;
      final broadcaster = _FakeBroadcaster();
      final react = ReactToStory(signer, broadcaster);

      final ok = await react(_story());

      expect(ok, isFalse);
      expect(broadcaster.broadcasted, isEmpty);
    });
  });

  group('RepostStory', () {
    test('signs a kind-6 repost with empty content', () async {
      final signer = _FakeSigner(signerPubkey);
      final broadcaster = _FakeBroadcaster();
      final repost = RepostStory(signer, broadcaster);

      final ok = await repost(_story());

      expect(ok, isTrue);
      expect(signer.lastRequested!.kind, 6);
      expect(signer.lastRequested!.content, '');
      expect(broadcaster.broadcasted, hasLength(1));
    });
  });

  group('ReplyToStory', () {
    test('signs a kind-1 reply with a NIP-10 reply-marked e-tag', () async {
      final signer = _FakeSigner(signerPubkey);
      final broadcaster = _FakeBroadcaster();
      final reply = ReplyToStory(signer, broadcaster);

      final ok = await reply(_story(), 'nice post');

      expect(ok, isTrue);
      expect(signer.lastRequested!.kind, 1);
      expect(signer.lastRequested!.content, 'nice post');
      expect(signer.lastRequested!.tags, [
        ['e', 'note-1', '', 'reply'],
        ['p', 'b' * 64],
      ]);
    });

    test('rejects blank/whitespace-only replies before ever asking the signer', () async {
      final signer = _FakeSigner(signerPubkey);
      final reply = ReplyToStory(signer, _FakeBroadcaster());

      final ok = await reply(_story(), '   ');

      expect(ok, isFalse);
      expect(signer.lastRequested, isNull);
    });

    test('trims the reply content before signing', () async {
      final signer = _FakeSigner(signerPubkey);
      final reply = ReplyToStory(signer, _FakeBroadcaster());

      await reply(_story(), '  padded  ');

      expect(signer.lastRequested!.content, 'padded');
    });
  });
}
