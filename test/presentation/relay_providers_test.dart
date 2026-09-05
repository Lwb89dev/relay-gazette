import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/presentation/relays/relay_providers.dart';

void main() {
  group('normalizeRelayUrl', () {
    test('accepts a well-formed wss:// URL unchanged', () {
      expect(normalizeRelayUrl('wss://relay.example.com'), 'wss://relay.example.com');
    });

    test('trims surrounding whitespace', () {
      expect(normalizeRelayUrl('  wss://relay.example.com  '), 'wss://relay.example.com');
    });

    test('rejects plain ws:// (unencrypted)', () {
      expect(normalizeRelayUrl('ws://relay.example.com'), isNull);
    });

    test('rejects https:// and other non-relay schemes', () {
      expect(normalizeRelayUrl('https://relay.example.com'), isNull);
    });

    test('rejects a URL with no host', () {
      expect(normalizeRelayUrl('wss://'), isNull);
    });

    test('rejects garbage input', () {
      expect(normalizeRelayUrl('not a url'), isNull);
    });

    test('rejects an empty string', () {
      expect(normalizeRelayUrl(''), isNull);
    });
  });
}
