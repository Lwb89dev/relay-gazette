import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/usecases/parse_user_identity.dart';

class _FakeCodec implements Bech32PublicKeyCodec {
  final Map<String, String> npubToHex;
  _FakeCodec(this.npubToHex);

  @override
  NostrPublicKey decodeNpub(String npub) {
    final hex = npubToHex[npub];
    if (hex == null) throw InvalidPublicKeyException('unknown npub: $npub');
    return NostrPublicKey.fromHex(hex);
  }

  @override
  String encodeNpub(NostrPublicKey pubkey) => 'npub1${pubkey.hex}';

  @override
  bool isNpub(String value) => value.startsWith('npub1');
}

void main() {
  final hex = 'd' * 64;
  final parse = ParseUserIdentity(_FakeCodec({'npub1valid': hex}));

  test('decodes a valid npub via the injected codec', () {
    expect(parse('npub1valid').hex, hex);
  });

  test('trims whitespace around input', () {
    expect(parse('  npub1valid  ').hex, hex);
  });

  test('accepts a raw hex public key', () {
    expect(parse(hex).hex, hex);
  });

  test('rejects an empty string', () {
    expect(() => parse(''), throwsA(isA<InvalidPublicKeyException>()));
    expect(() => parse('   '), throwsA(isA<InvalidPublicKeyException>()));
  });

  test('rejects garbage input that is neither npub nor hex', () {
    expect(() => parse('not-a-key'), throwsA(isA<InvalidPublicKeyException>()));
  });

  test('rejects an npub the codec does not recognize', () {
    expect(() => parse('npub1bogus'), throwsA(isA<InvalidPublicKeyException>()));
  });
}
