import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Primal's caching service speaks a Nostr-shaped protocol over a plain
/// WebSocket, but requests are not NIP-01 filters: the third element of a
/// `REQ` is `{"cache": [functionName, params]}`, where `functionName` is
/// one of the server's "exposed functions" (e.g. `explore`). The server
/// still replies with standard `EVENT`/`EOSE`/`NOTICE` frames. Confirmed by
/// reading github.com/PrimalHQ/primal-server (`cache_server_handlers.jl`,
/// `app_ext.jl`) directly, since this isn't part of any NIP.
///
/// Kept as its own small abstraction (rather than reusing ndk's relay
/// machinery) because it genuinely is a different protocol — see
/// ARCHITECTURE.md, "Primal-specific access" vs. "Nostr protocol access".
abstract class PrimalCacheClient {
  Future<List<Map<String, dynamic>>> fetchCacheEvents(
    String function,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 10),
  });
}

class PrimalCacheException implements Exception {
  final String message;
  const PrimalCacheException(this.message);

  @override
  String toString() => 'PrimalCacheException: $message';
}

/// Primal's public cache server, as configured by Primal's own official
/// clients (see `PRIMAL_CACHE_URL` in github.com/PrimalHQ/primal-web-app).
const String kDefaultPrimalCacheUrl = 'wss://cache2.primal.net/v1';

class WebSocketPrimalCacheClient implements PrimalCacheClient {
  final Uri _endpoint;
  static const _uuid = Uuid();

  WebSocketPrimalCacheClient({String endpoint = kDefaultPrimalCacheUrl})
    : _endpoint = Uri.parse(endpoint);

  @override
  Future<List<Map<String, dynamic>>> fetchCacheEvents(
    String function,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final channel = WebSocketChannel.connect(_endpoint);
    final subscriptionId = _uuid.v4().substring(0, 8);
    final events = <Map<String, dynamic>>[];
    final completer = Completer<void>();

    final subscription = channel.stream.listen(
      (raw) {
        if (completer.isCompleted) return;
        // Runs synchronously inside the stream callback, so a malformed
        // frame throwing here would otherwise become an unhandled
        // exception instead of reaching `onError` below — and the
        // completer would then never resolve, hanging the caller until
        // the outer timeout. One bad frame is dropped instead of taking
        // the whole request down with it.
        try {
          final message = jsonDecode(raw as String) as List<dynamic>;
          final type = message[0] as String;
          if (type == 'EVENT' &&
              message.length >= 3 &&
              message[1] == subscriptionId) {
            events.add(message[2] as Map<String, dynamic>);
          } else if (type == 'EOSE' &&
              message.length >= 2 &&
              message[1] == subscriptionId) {
            completer.complete();
          } else if (type == 'NOTICE') {
            final reason = message.length > 2
                ? message[2].toString()
                : message.toString();
            completer.completeError(PrimalCacheException(reason));
          }
        } catch (_) {
          // Malformed frame — ignore and keep listening for the rest.
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            const PrimalCacheException('Connection closed before EOSE'),
          );
        }
      },
    );

    try {
      channel.sink.add(
        jsonEncode([
          'REQ',
          subscriptionId,
          {
            'cache': [function, params],
          },
        ]),
      );
      await completer.future.timeout(timeout);
    } finally {
      await subscription.cancel();
      unawaited(channel.sink.close());
    }

    return events;
  }
}
