import 'package:ndk/ndk.dart';

import 'relay_defaults.dart';

/// Builds the single [Ndk] instance the app talks to relays through.
///
/// Uses [Bip340EventVerifier], a pure-Dart signature verifier, instead of
/// ndk's Rust-backed verifier: the Rust one requires a `rustup` toolchain
/// at build time (via a Dart native-assets build hook) purely to produce a
/// faster verifier we don't need at this scale, and a rustup dependency
/// would leak into every contributor's and CI machine's setup. Documented
/// deviation from "use whatever ndk defaults to" — see ARCHITECTURE.md.
Ndk createNdk() {
  return Ndk(
    NdkConfig(
      eventVerifier: Bip340EventVerifier(),
      cache: MemCacheManager(),
      bootstrapRelays: kDefaultBootstrapRelays,
    ),
  );
}
