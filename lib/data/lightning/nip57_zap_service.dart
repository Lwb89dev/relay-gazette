import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/nostr_event_draft.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/nostr_signer.dart';
import '../../domain/repositories/zap_service.dart';
import 'ssrf_guard.dart';

const _kZapRequestKind = 9734;

/// NIP-57 zap flow: resolve the author's Lightning address (LUD-16) to an
/// LNURL-pay endpoint, optionally attach a signed zap request (kind 9734)
/// so the payment is publicly attributable on Nostr, then fetch a bolt11
/// invoice for the reader's wallet to pay.
///
/// A Nostr signer is optional: NIP-57's `nostr` callback parameter is
/// itself optional, so a reader with no signer connected can still zap —
/// they just can't attach a signed zap request, so the payment won't show
/// up as *their* zap in Nostr clients, only as a plain Lightning payment.
class Nip57ZapService implements ZapService {
  final http.Client _http;
  final NostrSigner? _signer;
  final List<String> _relayHints;

  Nip57ZapService(
    this._http, {
    NostrSigner? signer,
    List<String> relayHints = const [],
  }) : _signer = signer,
       _relayHints = relayHints;

  @override
  Future<String?> requestZapInvoice({
    required Story story,
    required int amountSats,
    String? comment,
  }) async {
    if (amountSats <= 0) return null;

    final lightningAddress = story.author.lightningAddress;
    final atIndex = lightningAddress?.indexOf('@') ?? -1;
    if (lightningAddress == null ||
        atIndex <= 0 ||
        atIndex == lightningAddress.length - 1) {
      return null;
    }
    final localPart = lightningAddress.substring(0, atIndex);
    final domain = lightningAddress.substring(atIndex + 1);

    final payInfo = await _getJson(
      Uri.https(domain, '/.well-known/lnurlp/$localPart'),
    );
    if (payInfo == null) return null;

    final callback = payInfo['callback'] as String?;
    if (callback == null) return null;

    final millisats = amountSats * 1000;
    final minSendable = (payInfo['minSendable'] as num?)?.toInt();
    final maxSendable = (payInfo['maxSendable'] as num?)?.toInt();
    if (minSendable != null && millisats < minSendable) return null;
    if (maxSendable != null && millisats > maxSendable) return null;

    final callbackUri = Uri.parse(callback);
    final queryParams = Map<String, String>.from(callbackUri.queryParameters);
    queryParams['amount'] = millisats.toString();

    final allowsNostr = payInfo['allowsNostr'] == true;
    final signer = _signer;
    if (allowsNostr && signer != null && signer.isConnected) {
      final signedZapRequest = await signer.sign(
        UnsignedNostrEvent(
          kind: _kZapRequestKind,
          content: comment ?? '',
          tags: [
            ['relays', ..._relayHints],
            ['amount', millisats.toString()],
            ['p', story.author.pubkey.hex],
            ['e', story.id],
          ],
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (signedZapRequest != null) {
        queryParams['nostr'] = jsonEncode(_zapRequestJson(signedZapRequest));
      }
    }

    final invoiceResponse = await _getJson(
      callbackUri.replace(queryParameters: queryParams),
    );
    return invoiceResponse?['pr'] as String?;
  }

  Map<String, dynamic> _zapRequestJson(SignedNostrEvent event) {
    return {
      'id': event.id,
      'pubkey': event.pubkeyHex,
      'created_at': event.createdAt.millisecondsSinceEpoch ~/ 1000,
      'kind': event.kind,
      'tags': event.tags,
      'content': event.content,
      'sig': event.signature,
    };
  }

  /// [domain] and the LNURL-pay `callback` it returns both come from an
  /// author's Nostr profile — untrusted input. [isSafeExternalRequestUri]
  /// blocks the obvious way that could be abused to make this device probe
  /// its own local network (see ssrf_guard.dart).
  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    if (!isSafeExternalRequestUri(uri)) return null;
    try {
      final response = await _http
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
