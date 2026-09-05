import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:relay_gazette/data/lightning/nwc_wallet_connection.dart';

// Full connect() coverage would need a real relay/wallet round-trip (ndk.nwc
// isn't independently injectable) — see TASKS.md. What's covered here is
// everything reachable without a network.
void main() {
  Ndk buildNdk() => Ndk(NdkConfig(eventVerifier: Bip340EventVerifier(), cache: MemCacheManager()));

  test('starts disconnected', () {
    final wallet = NwcWalletConnection(buildNdk());
    expect(wallet.isConnected, isFalse);
  });

  test('payInvoice refuses before any wallet is connected', () async {
    final wallet = NwcWalletConnection(buildNdk());
    expect(await wallet.payInvoice('lnbc1...'), isFalse);
  });

  test('connect() returns false (not a thrown exception) for a malformed URI', () async {
    final wallet = NwcWalletConnection(buildNdk());
    expect(await wallet.connect('not a valid nwc uri'), isFalse);
    expect(wallet.isConnected, isFalse);
  });

  test('disconnect() is a no-op when nothing was ever connected', () async {
    final wallet = NwcWalletConnection(buildNdk());
    await wallet.disconnect();
    expect(wallet.isConnected, isFalse);
  });
}
