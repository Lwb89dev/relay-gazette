import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:relay_gazette/data/signing/amber_nostr_signer.dart';
import 'package:relay_gazette/domain/entities/nostr_event_draft.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';

class _StubVerifier implements EventVerifier {
  final bool result;
  Nip01Event? lastVerified;
  _StubVerifier(this.result);

  @override
  Future<bool> verify(Nip01Event event) async {
    lastVerified = event;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.relaygazette.relay_gazette/amber');
  final connectedPubkey = NostrPublicKey.fromHex('a' * 64);
  final unsignedEvent = UnsignedNostrEvent(kind: 1, content: 'hi', createdAt: DateTime.utc(2026, 8, 23));

  Future<void> connectSigner(AmberNostrSigner signer, {String? asPubkeyResult}) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getPublicKey') {
        return {'result': asPubkeyResult ?? connectedPubkey.hex, 'package': 'com.example.signer'};
      }
      return null;
    });
    await signer.connect();
  }

  Map<String, dynamic> signedEventJson({String? pubkeyOverride}) {
    return {
      'id': 'a' * 64,
      'pubkey': pubkeyOverride ?? connectedPubkey.hex,
      'kind': 1,
      'content': 'hi',
      'tags': <List<String>>[],
      'created_at': unsignedEvent.createdAt.millisecondsSinceEpoch ~/ 1000,
      'sig': 's' * 128,
    };
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('connect() decodes the hex pubkey returned by the channel', () async {
    final signer = AmberNostrSigner(verifier: _StubVerifier(true));
    await connectSigner(signer);

    expect(signer.isConnected, isTrue);
    expect(signer.connectedPubkey, connectedPubkey);
  });

  test('connect() returns null when the channel reports no result (declined)', () async {
    final signer = AmberNostrSigner(verifier: _StubVerifier(true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => {'result': null});

    final result = await signer.connect();

    expect(result, isNull);
    expect(signer.isConnected, isFalse);
  });

  test('sign() rejects an event when nothing is connected yet', () async {
    final signer = AmberNostrSigner(verifier: _StubVerifier(true));
    expect(await signer.sign(unsignedEvent), isNull);
  });

  test('sign() accepts a well-formed, verifier-approved response', () async {
    final verifier = _StubVerifier(true);
    final signer = AmberNostrSigner(verifier: verifier);
    await connectSigner(signer);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'signEvent') {
        return {'event': jsonEncode(signedEventJson())};
      }
      return null;
    });

    final signed = await signer.sign(unsignedEvent);

    expect(signed, isNotNull);
    expect(signed!.pubkeyHex, connectedPubkey.hex);
    expect(verifier.lastVerified, isNotNull); // the signer actually asked the verifier
  });

  test('sign() rejects a response whose pubkey does not match the connected identity', () async {
    final verifier = _StubVerifier(true);
    final signer = AmberNostrSigner(verifier: verifier);
    await connectSigner(signer);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'signEvent') {
        return {'event': jsonEncode(signedEventJson(pubkeyOverride: 'b' * 64))};
      }
      return null;
    });

    final signed = await signer.sign(unsignedEvent);

    expect(signed, isNull);
    // Must never reach signature verification for a spoofed identity —
    // the pubkey mismatch alone should short-circuit the request.
    expect(verifier.lastVerified, isNull);
  });

  test('sign() rejects a response whose signature does not verify', () async {
    final verifier = _StubVerifier(false); // simulates a forged/corrupt signature
    final signer = AmberNostrSigner(verifier: verifier);
    await connectSigner(signer);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'signEvent') {
        return {'event': jsonEncode(signedEventJson())};
      }
      return null;
    });

    final signed = await signer.sign(unsignedEvent);

    expect(signed, isNull);
    expect(verifier.lastVerified, isNotNull); // it did get as far as verification
  });

  test('sign() returns null (not a thrown exception) for malformed JSON from the channel', () async {
    final signer = AmberNostrSigner(verifier: _StubVerifier(true));
    await connectSigner(signer);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'signEvent') {
        return {'event': 'not valid json'};
      }
      return null;
    });

    expect(await signer.sign(unsignedEvent), isNull);
  });

  test('sign() returns null when required fields are missing from the response', () async {
    final signer = AmberNostrSigner(verifier: _StubVerifier(true));
    await connectSigner(signer);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'signEvent') {
        return {
          'event': jsonEncode({'pubkey': connectedPubkey.hex}), // missing id/kind/content/tags/sig
        };
      }
      return null;
    });

    expect(await signer.sign(unsignedEvent), isNull);
  });

  test('sign() returns null when the platform channel throws', () async {
    final signer = AmberNostrSigner(verifier: _StubVerifier(true));
    await connectSigner(signer);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'signEvent') {
        throw PlatformException(code: 'NOT_INSTALLED');
      }
      return null;
    });

    expect(await signer.sign(unsignedEvent), isNull);
  });

  test('isAvailable() is false on non-Android platforms regardless of the channel', () async {
    final signer = AmberNostrSigner(verifier: _StubVerifier(true));
    expect(await signer.isAvailable(), isFalse);
  });

  test('disconnect() clears the connected identity', () async {
    final signer = AmberNostrSigner(verifier: _StubVerifier(true));
    await connectSigner(signer);
    expect(signer.isConnected, isTrue);

    await signer.disconnect();

    expect(signer.isConnected, isFalse);
    expect(signer.connectedPubkey, isNull);
  });
}
