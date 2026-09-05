import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lightning/nwc_wallet_connection.dart';
import '../providers.dart';

/// Kept as a single instance for the app's lifetime — same reasoning as
/// the signer providers. The NIP-47 connection string's secret is a real
/// spending credential, so [WalletConnectionController] deliberately keeps
/// it in memory only rather than writing it to disk — see its doc comment.
final walletConnectionProvider = Provider<NwcWalletConnection>((ref) {
  return NwcWalletConnection(ref.watch(ndkProvider));
});

/// Reactive "is a wallet connected" flag for the settings UI. The
/// connection itself lives in [walletConnectionProvider] (a plain
/// singleton) — actions like paying an invoice read that directly, since
/// they don't need to trigger a rebuild.
class WalletConnectionController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> connect(String nwcUri) async {
    final ok = await ref.read(walletConnectionProvider).connect(nwcUri);
    if (ok) state = true;
    return ok;
  }

  Future<void> disconnect() async {
    await ref.read(walletConnectionProvider).disconnect();
    state = false;
  }
}

final walletConnectedProvider = NotifierProvider<WalletConnectionController, bool>(
  WalletConnectionController.new,
);
