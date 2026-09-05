import 'package:ndk/ndk.dart';

import '../../domain/entities/highlight.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../../domain/repositories/highlights_repository.dart';
import 'event_kinds.dart';
import 'nostr_mappers.dart';

class RelayHighlightsRepository implements HighlightsRepository {
  final Ndk _ndk;

  RelayHighlightsRepository(this._ndk);

  @override
  Future<List<Highlight>> fetchHighlights(String storyEventId) async {
    final events = await _ndk.requests
        .query(filter: Filter(kinds: const [NostrEventKinds.highlight], eTags: [storyEventId]))
        .future;
    if (events.isEmpty) return const [];

    final authorPubkeys = events.map((e) => e.pubKey).toSet().toList();
    final metadataList = await _ndk.metadata.loadMetadatas(authorPubkeys, null);
    final metadataByPubkey = {for (final metadata in metadataList) metadata.pubKey: metadata};

    return events
        .where((e) => e.content.trim().isNotEmpty)
        .map((event) {
          final author = authorFromMetadata(
            NostrPublicKey.fromHex(event.pubKey),
            metadataByPubkey[event.pubKey],
          );
          return Highlight(
            id: event.id,
            text: event.content,
            author: author,
            createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000, isUtc: true),
          );
        })
        .toList();
  }
}
