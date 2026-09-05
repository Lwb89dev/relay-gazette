/// A Nostr event not yet signed — everything needed to ask a [NostrSigner]
/// to sign it, without the domain layer knowing anything about ndk's event
/// model.
class UnsignedNostrEvent {
  final int kind;
  final String content;
  final List<List<String>> tags;
  final DateTime createdAt;

  const UnsignedNostrEvent({
    required this.kind,
    required this.content,
    this.tags = const [],
    required this.createdAt,
  });
}

/// A Nostr event after signing — ready to broadcast.
class SignedNostrEvent {
  final String id;
  final String pubkeyHex;
  final int kind;
  final String content;
  final List<List<String>> tags;
  final DateTime createdAt;
  final String signature;

  const SignedNostrEvent({
    required this.id,
    required this.pubkeyHex,
    required this.kind,
    required this.content,
    required this.tags,
    required this.createdAt,
    required this.signature,
  });
}
