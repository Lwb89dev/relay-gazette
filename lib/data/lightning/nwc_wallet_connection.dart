import 'package:ndk/ndk.dart';

import '../../domain/repositories/wallet_connection.dart';

/// [WalletConnection] backed by ndk's NIP-47 (Nostr Wallet Connect)
/// implementation. The connection string's `secret` is a real spending
/// credential for the reader's wallet — kept in memory only for this
/// session (see [WalletConnectionController]'s doc comment for why it
/// isn't persisted to disk the way the read-only npub is).
class NwcWalletConnection implements WalletConnection {
  final Ndk _ndk;
  NwcConnection? _connection;

  NwcWalletConnection(this._ndk);

  @override
  bool get isConnected => _connection != null;

  @override
  Future<bool> connect(String nwcUri) async {
    try {
      _connection = await _ndk.nwc.connect(nwcUri);
      return true;
    } catch (_) {
      _connection = null;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    if (connection != null) await _ndk.nwc.disconnect(connection);
  }

  @override
  Future<bool> payInvoice(String bolt11) async {
    final connection = _connection;
    if (connection == null) return false;
    try {
      final response = await _ndk.nwc.payInvoice(connection, invoice: bolt11);
      return response.errorCode == null;
    } catch (_) {
      return false;
    }
  }
}
