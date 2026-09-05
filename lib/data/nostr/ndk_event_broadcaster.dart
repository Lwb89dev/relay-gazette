import 'package:ndk/ndk.dart';

import '../../domain/entities/nostr_event_draft.dart';
import '../../domain/repositories/event_broadcaster.dart';

class NdkEventBroadcaster implements EventBroadcaster {
  final Ndk _ndk;

  NdkEventBroadcaster(this._ndk);

  @override
  Future<void> broadcast(SignedNostrEvent event) async {
    // `sig` is already set, so ndk publishes as-is rather than trying to
    // sign locally (this app never holds a private key to sign with).
    final nip01Event = Nip01Event(
      id: event.id,
      pubKey: event.pubkeyHex,
      kind: event.kind,
      tags: event.tags,
      content: event.content,
      sig: event.signature,
      createdAt: event.createdAt.millisecondsSinceEpoch ~/ 1000,
    );
    _ndk.broadcast.broadcast(nostrEvent: nip01Event);
  }
}
