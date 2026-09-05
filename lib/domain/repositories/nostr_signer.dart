import '../entities/nostr_event_draft.dart';
import '../entities/nostr_public_key.dart';

/// Signs Nostr events on the reader's behalf, without this app ever
/// holding a private key — see spec §19: "never ask for nsec; never
/// persist the user's private key; signing should happen externally."
///
/// [connect] and [sign] both return null (rather than throwing) when the
/// external signer declines: "no signer installed" and "user tapped
/// reject" are ordinary, expected outcomes, not exceptional ones.
abstract class NostrSigner {
  bool get isConnected;
  NostrPublicKey? get connectedPubkey;

  /// Whether a compatible external signer is installed at all (e.g. Amber
  /// on Android). Checked before showing "Connect" as an option.
  Future<bool> isAvailable();

  /// Asks the external signer for the reader's public key. Returns null if
  /// declined or unavailable.
  Future<NostrPublicKey?> connect();

  Future<void> disconnect();

  /// Asks the external signer to sign [event]. Returns null if the signer
  /// rejected the request.
  ///
  /// Contract implementers must uphold: a non-null result's id, pubkey, and
  /// signature must already be verified as internally consistent (e.g. via
  /// an [EventVerifier]) before returning it. The signer sits at the one
  /// boundary where data from an external, untrusted process (a separate
  /// signer app, possibly not even the intended one) becomes "this is
  /// authentically the reader's event" — [EventBroadcaster] and the
  /// interaction usecases rely on that having already been checked here,
  /// rather than re-verifying downstream.
  Future<SignedNostrEvent?> sign(UnsignedNostrEvent event);
}

/// Implemented by signers that connect via an explicit connection string
/// rather than [NostrSigner.connect]'s no-argument flow — currently just
/// NIP-46 (`bunker://...`). Kept as a separate interface rather than
/// widening [NostrSigner.connect]'s signature, since it's meaningless for
/// an Intent-based signer like Amber.
abstract class BunkerCapableSigner {
  /// Establishes a NIP-46 remote-signing session against [bunkerUri]
  /// (`bunker://<remote-pubkey>?relay=...&secret=...`). Returns null if the
  /// bunker never acknowledged the connection (bad URI, unreachable relay,
  /// or the request timed out).
  Future<NostrPublicKey?> connectWithBunkerUri(String bunkerUri);
}
