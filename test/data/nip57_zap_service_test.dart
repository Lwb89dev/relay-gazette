import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:relay_gazette/data/lightning/nip57_zap_service.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/nostr_event_draft.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/domain/repositories/nostr_signer.dart';

class _FakeSigner implements NostrSigner {
  final NostrPublicKey pubkey;
  bool connectedFlag = true;
  UnsignedNostrEvent? lastRequested;

  _FakeSigner(this.pubkey);

  @override
  bool get isConnected => connectedFlag;

  @override
  NostrPublicKey? get connectedPubkey => pubkey;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<NostrPublicKey?> connect() async => pubkey;

  @override
  Future<void> disconnect() async {}

  @override
  Future<SignedNostrEvent?> sign(UnsignedNostrEvent event) async {
    lastRequested = event;
    return SignedNostrEvent(
      id: 'zap-request-id',
      pubkeyHex: pubkey.hex,
      kind: event.kind,
      content: event.content,
      tags: event.tags,
      createdAt: event.createdAt,
      signature: 's' * 128,
    );
  }
}

Story _storyWithLightningAddress(String? address) {
  final pubkey = NostrPublicKey.fromHex('a' * 64);
  return Story(
    id: 'note-1',
    kind: Story.kTextNote,
    author: Author(pubkey: pubkey, npub: 'npub1author', lightningAddress: address),
    content: 'hello',
    createdAt: DateTime.utc(2026, 8, 23),
    engagement: EngagementCounts.zero,
  );
}

void main() {
  test('never issues a request for a Lightning address pointing at a private/local host', () async {
    final client = MockClient((_) => fail('must not make an HTTP request to a private host'));
    final service = Nip57ZapService(client);

    final invoice = await service.requestZapInvoice(
      story: _storyWithLightningAddress('attacker@192.168.1.1'),
      amountSats: 21,
    );

    expect(invoice, isNull);
  });

  test('never issues a request for a Lightning address pointing at the cloud metadata address', () async {
    final client = MockClient((_) => fail('must not make an HTTP request to 169.254.169.254'));
    final service = Nip57ZapService(client);

    final invoice = await service.requestZapInvoice(
      story: _storyWithLightningAddress('attacker@169.254.169.254'),
      amountSats: 21,
    );

    expect(invoice, isNull);
  });

  test('returns null when the author has no Lightning address', () async {
    final client = MockClient((_) async => http.Response('', 404));
    final service = Nip57ZapService(client);

    final invoice = await service.requestZapInvoice(story: _storyWithLightningAddress(null), amountSats: 21);

    expect(invoice, isNull);
  });

  test('returns null for a malformed Lightning address', () async {
    final client = MockClient((_) async => http.Response('', 404));
    final service = Nip57ZapService(client);

    final invoice = await service.requestZapInvoice(
      story: _storyWithLightningAddress('not-an-address'),
      amountSats: 21,
    );

    expect(invoice, isNull);
  });

  test('resolves LUD-16 to the right well-known LNURL-pay endpoint', () async {
    Uri? requestedLnurlpUri;
    final client = MockClient((request) async {
      if (request.url.path.contains('.well-known')) {
        requestedLnurlpUri = request.url;
        return http.Response(
          jsonEncode({'callback': 'https://ln.example.com/cb', 'allowsNostr': false}),
          200,
        );
      }
      return http.Response(jsonEncode({'pr': 'lnbc1...'}), 200);
    });
    final service = Nip57ZapService(client);

    await service.requestZapInvoice(story: _storyWithLightningAddress('alice@example.com'), amountSats: 21);

    expect(requestedLnurlpUri?.host, 'example.com');
    expect(requestedLnurlpUri?.path, '/.well-known/lnurlp/alice');
  });

  test('rejects an amount below minSendable', () async {
    final client = MockClient((request) async {
      if (request.url.path.contains('.well-known')) {
        return http.Response(
          jsonEncode({'callback': 'https://ln.example.com/cb', 'minSendable': 100000}),
          200,
        );
      }
      return http.Response(jsonEncode({'pr': 'lnbc1...'}), 200);
    });
    final service = Nip57ZapService(client);

    final invoice = await service.requestZapInvoice(story: _storyWithLightningAddress('alice@example.com'), amountSats: 21);

    expect(invoice, isNull);
  });

  test('returns the raw bolt11 invoice from the callback response', () async {
    final client = MockClient((request) async {
      if (request.url.path.contains('.well-known')) {
        return http.Response(jsonEncode({'callback': 'https://ln.example.com/cb'}), 200);
      }
      expect(request.url.queryParameters['amount'], '21000');
      return http.Response(jsonEncode({'pr': 'lnbc210n1p...'}), 200);
    });
    final service = Nip57ZapService(client);

    final invoice = await service.requestZapInvoice(
      story: _storyWithLightningAddress('alice@example.com'),
      amountSats: 21,
    );

    expect(invoice, 'lnbc210n1p...');
  });

  test('attaches a signed NIP-57 zap request when the server allows it and a signer is connected', () async {
    final signer = _FakeSigner(NostrPublicKey.fromHex('c' * 64));
    Uri? invoiceRequestUri;
    final client = MockClient((request) async {
      if (request.url.path.contains('.well-known')) {
        return http.Response(
          jsonEncode({'callback': 'https://ln.example.com/cb', 'allowsNostr': true}),
          200,
        );
      }
      invoiceRequestUri = request.url;
      return http.Response(jsonEncode({'pr': 'lnbc1...'}), 200);
    });
    final service = Nip57ZapService(client, signer: signer, relayHints: const ['wss://relay.example.com']);

    await service.requestZapInvoice(story: _storyWithLightningAddress('alice@example.com'), amountSats: 21);

    expect(signer.lastRequested, isNotNull);
    expect(signer.lastRequested!.kind, 9734);
    final nostrParam = invoiceRequestUri!.queryParameters['nostr'];
    expect(nostrParam, isNotNull);
    final decoded = jsonDecode(nostrParam!) as Map<String, dynamic>;
    expect(decoded['kind'], 9734);
  });

  test('does not attach a zap request when the server does not allow Nostr', () async {
    final signer = _FakeSigner(NostrPublicKey.fromHex('c' * 64));
    final client = MockClient((request) async {
      if (request.url.path.contains('.well-known')) {
        return http.Response(
          jsonEncode({'callback': 'https://ln.example.com/cb', 'allowsNostr': false}),
          200,
        );
      }
      return http.Response(jsonEncode({'pr': 'lnbc1...'}), 200);
    });
    final service = Nip57ZapService(client, signer: signer);

    await service.requestZapInvoice(story: _storyWithLightningAddress('alice@example.com'), amountSats: 21);

    expect(signer.lastRequested, isNull);
  });

  test('still resolves a payment with no signer connected at all (anonymous zap)', () async {
    final client = MockClient((request) async {
      if (request.url.path.contains('.well-known')) {
        return http.Response(
          jsonEncode({'callback': 'https://ln.example.com/cb', 'allowsNostr': true}),
          200,
        );
      }
      return http.Response(jsonEncode({'pr': 'lnbc1...'}), 200);
    });
    final service = Nip57ZapService(client); // no signer injected

    final invoice = await service.requestZapInvoice(story: _storyWithLightningAddress('alice@example.com'), amountSats: 21);

    expect(invoice, isNotNull);
  });

  test('returns null if the LNURL server is unreachable', () async {
    final client = MockClient((_) async => throw Exception('network down'));
    final service = Nip57ZapService(client);

    final invoice = await service.requestZapInvoice(story: _storyWithLightningAddress('alice@example.com'), amountSats: 21);

    expect(invoice, isNull);
  });
}
