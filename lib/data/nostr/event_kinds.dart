/// NIP-01 and related event kind numbers used when querying relays.
class NostrEventKinds {
  static const metadata = 0;
  static const textNote = 1;
  static const contacts = 3;
  static const repost = 6;
  static const reaction = 7;
  static const zapReceipt = 9735;

  /// NIP-51 "follow set" — a named, addressable group of accounts.
  static const followSet = 30000;

  /// NIP-23 long-form content.
  static const longFormArticle = 30023;

  /// NIP-84 highlight.
  static const highlight = 9802;

  const NostrEventKinds._();
}
