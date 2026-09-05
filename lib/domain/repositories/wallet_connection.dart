/// A NIP-47 (Nostr Wallet Connect) session, letting the reader pay a zap
/// invoice directly through their own wallet (Alby, Mutiny, a self-hosted
/// LNbits, etc.) instead of handing off to an external wallet app via a
/// `lightning:` link. Optional — [ZapService] never depends on this; the
/// reader is offered whichever path is available when they zap.
abstract class WalletConnection {
  bool get isConnected;

  /// Establishes a session from a `nostr+walletconnect://...` connection
  /// string. Returns false if the string is malformed or the wallet never
  /// acknowledged the connection.
  Future<bool> connect(String nwcUri);

  Future<void> disconnect();

  /// Pays [bolt11] through the connected wallet. Returns false if nothing
  /// is connected or the wallet declined/failed the payment — never
  /// throws for an ordinary payment failure.
  Future<bool> payInvoice(String bolt11);
}
