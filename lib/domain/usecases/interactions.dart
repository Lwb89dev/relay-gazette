import '../entities/nostr_event_draft.dart';
import '../entities/story.dart';
import '../repositories/event_broadcaster.dart';
import '../repositories/nostr_signer.dart';

/// NIP-01/18/25 kind numbers relevant to interacting with a story. These
/// are universal Nostr protocol constants (not ndk- or Primal-specific),
/// so the domain layer owns them directly rather than importing anything
/// from `data/`.
const _kReaction = 7;
const _kRepost = 6;
const _kTextNote = 1;

/// True if signing succeeded and the event was broadcast; false if the
/// external signer declined (e.g. the reader tapped "reject" in Amber).
/// Never throws for a plain decline — only for genuine failures
/// (broadcast/network errors propagate normally).
typedef InteractionResult = bool;

class ReactToStory {
  final NostrSigner _signer;
  final EventBroadcaster _broadcaster;

  const ReactToStory(this._signer, this._broadcaster);

  /// [reaction] follows NIP-25: "+" (like), "-" (dislike), or an emoji.
  Future<InteractionResult> call(Story story, {String reaction = '+'}) async {
    final signed = await _signer.sign(
      UnsignedNostrEvent(
        kind: _kReaction,
        content: reaction,
        tags: [
          ['e', story.id],
          ['p', story.author.pubkey.hex],
        ],
        createdAt: DateTime.now().toUtc(),
      ),
    );
    if (signed == null) return false;
    await _broadcaster.broadcast(signed);
    return true;
  }
}

class RepostStory {
  final NostrSigner _signer;
  final EventBroadcaster _broadcaster;

  const RepostStory(this._signer, this._broadcaster);

  Future<InteractionResult> call(Story story) async {
    final signed = await _signer.sign(
      UnsignedNostrEvent(
        kind: _kRepost,
        content: '',
        tags: [
          ['e', story.id],
          ['p', story.author.pubkey.hex],
        ],
        createdAt: DateTime.now().toUtc(),
      ),
    );
    if (signed == null) return false;
    await _broadcaster.broadcast(signed);
    return true;
  }
}

class ReplyToStory {
  final NostrSigner _signer;
  final EventBroadcaster _broadcaster;

  const ReplyToStory(this._signer, this._broadcaster);

  Future<InteractionResult> call(Story story, String replyContent) async {
    final trimmed = replyContent.trim();
    if (trimmed.isEmpty) return false;

    final signed = await _signer.sign(
      UnsignedNostrEvent(
        kind: _kTextNote,
        content: trimmed,
        // NIP-10: a reply with no thread root marks this e-tag "reply".
        tags: [
          ['e', story.id, '', 'reply'],
          ['p', story.author.pubkey.hex],
        ],
        createdAt: DateTime.now().toUtc(),
      ),
    );
    if (signed == null) return false;
    await _broadcaster.broadcast(signed);
    return true;
  }
}
