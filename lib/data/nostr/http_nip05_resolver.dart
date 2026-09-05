import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/nostr_public_key.dart';
import '../../domain/repositories/nip05_resolver.dart';
import '../lightning/ssrf_guard.dart';

/// NIP-05: resolves "name@domain.com" (or bare "domain.com", meaning the
/// root identifier "_") via `https://domain.com/.well-known/nostr.json?name=name`.
class HttpNip05Resolver implements Nip05Resolver {
  final http.Client _http;

  HttpNip05Resolver(this._http);

  @override
  Future<NostrPublicKey?> resolve(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;

    final atIndex = trimmed.indexOf('@');
    final name = atIndex == -1 ? '_' : trimmed.substring(0, atIndex);
    final domain = atIndex == -1 ? trimmed : trimmed.substring(atIndex + 1);
    if (domain.isEmpty || name.isEmpty) return null;

    final uri = Uri.https(domain, '/.well-known/nostr.json', {'name': name});
    if (!isSafeExternalRequestUri(uri)) return null;

    try {
      final response = await _http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final names = body['names'] as Map<String, dynamic>?;
      final hex = names?[name] as String?;
      if (hex == null) return null;

      return NostrPublicKey.fromHex(hex);
    } catch (_) {
      return null;
    }
  }
}
