import '../entities/nostr_event_draft.dart';
import '../entities/story.dart';
import '../repositories/event_broadcaster.dart';
import '../repositories/nostr_signer.dart';

const _kHighlightKind = 9802;

/// Publishes a NIP-84 highlight for a passage of [story]. Tags the source
/// via `e` (and `a` too, for an addressable NIP-23 article, so the
/// highlight survives the article being edited) and attributes the
/// original author via a `p` tag with the "author" role.
class CreateHighlight {
  final NostrSigner _signer;
  final EventBroadcaster _broadcaster;

  const CreateHighlight(this._signer, this._broadcaster);

  Future<bool> call(Story story, String highlightedText, {String? context}) async {
    final text = highlightedText.trim();
    if (text.isEmpty) return false;

    final tags = <List<String>>[
      ['e', story.id],
      if (story.isLongFormArticle && story.dTag != null)
        ['a', '${Story.kLongFormArticle}:${story.author.pubkey.hex}:${story.dTag}'],
      ['p', story.author.pubkey.hex, '', 'author'],
      if (context != null && context.trim().isNotEmpty) ['context', context.trim()],
    ];

    final signed = await _signer.sign(UnsignedNostrEvent(
      kind: _kHighlightKind,
      content: text,
      tags: tags,
      createdAt: DateTime.now().toUtc(),
    ));
    if (signed == null) return false;

    await _broadcaster.broadcast(signed);
    return true;
  }
}
