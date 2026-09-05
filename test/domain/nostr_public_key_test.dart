import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';

void main() {
  group('NostrPublicKey.fromHex', () {
    test('accepts a valid 64-char lowercase hex key', () {
      final hex = 'a' * 64;
      expect(NostrPublicKey.fromHex(hex).hex, hex);
    });

    test('normalizes uppercase hex to lowercase', () {
      final key = NostrPublicKey.fromHex('A' * 64);
      expect(key.hex, 'a' * 64);
    });

    test('rejects keys that are too short', () {
      expect(() => NostrPublicKey.fromHex('a' * 63), throwsA(isA<InvalidPublicKeyException>()));
    });

    test('rejects keys with non-hex characters', () {
      expect(() => NostrPublicKey.fromHex('g' * 64), throwsA(isA<InvalidPublicKeyException>()));
    });
  });

  test('two keys with the same hex are equal', () {
    final a = NostrPublicKey.fromHex('b' * 64);
    final b = NostrPublicKey.fromHex('B' * 64);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('looksLikeHex distinguishes hex keys from npub strings', () {
    expect(NostrPublicKey.looksLikeHex('c' * 64), isTrue);
    expect(NostrPublicKey.looksLikeHex('npub1something'), isFalse);
  });
}
