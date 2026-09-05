import '../entities/nostr_event_draft.dart';

/// Publishes an already-signed event to relays. Separate from [NostrSigner]
/// because signing and publishing are different concerns with different
/// failure modes (a rejected signature vs. an unreachable relay).
abstract class EventBroadcaster {
  Future<void> broadcast(SignedNostrEvent event);
}
