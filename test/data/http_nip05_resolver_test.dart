import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:relay_gazette/data/nostr/http_nip05_resolver.dart';

void main() {
  final validHex = 'a' * 64;

  test('resolves "name@domain" to the pubkey listed under that name', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'names': {'alice': validHex},
        }),
        200,
      );
    });
    final resolver = HttpNip05Resolver(client);

    final pubkey = await resolver.resolve('alice@example.com');

    expect(pubkey?.hex, validHex);
    expect(requested?.host, 'example.com');
    expect(requested?.path, '/.well-known/nostr.json');
    expect(requested?.queryParameters['name'], 'alice');
  });

  test('a bare domain (no "@") resolves the root "_" identifier', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'names': {'_': validHex},
        }),
        200,
      );
    });
    final resolver = HttpNip05Resolver(client);

    final pubkey = await resolver.resolve('example.com');

    expect(pubkey?.hex, validHex);
    expect(requested?.queryParameters['name'], '_');
  });

  test('returns null when the domain does not list that name', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({'names': {}}), 200));
    final resolver = HttpNip05Resolver(client);

    expect(await resolver.resolve('nobody@example.com'), isNull);
  });

  test('returns null for a non-200 response', () async {
    final client = MockClient((_) async => http.Response('', 404));
    final resolver = HttpNip05Resolver(client);

    expect(await resolver.resolve('alice@example.com'), isNull);
  });

  test('returns null for malformed JSON instead of throwing', () async {
    final client = MockClient((_) async => http.Response('not json', 200));
    final resolver = HttpNip05Resolver(client);

    expect(await resolver.resolve('alice@example.com'), isNull);
  });

  test('returns null (and never issues a request) for a private-network domain', () async {
    final client = MockClient((_) => fail('must not request a private host'));
    final resolver = HttpNip05Resolver(client);

    expect(await resolver.resolve('name@192.168.1.1'), isNull);
  });

  test('returns null for an empty identifier', () async {
    final client = MockClient((_) => fail('must not make a request for empty input'));
    final resolver = HttpNip05Resolver(client);

    expect(await resolver.resolve(''), isNull);
    expect(await resolver.resolve('   '), isNull);
  });
}
