import '../entities/story.dart';

/// Resolves a Lightning payment for zapping a story, per NIP-57. Never
/// touches funds itself — it hands back a bolt11 invoice for the reader to
/// pay however they choose (an external wallet app via a `lightning:`
/// link, or a connected NIP-47 wallet), exactly as spec §21 requires
/// ("prefer handing payment to an external compatible wallet... do not
/// implement custodial Lightning").
abstract class ZapService {
  /// Returns null if the author has no Lightning address, the amount is
  /// outside what they accept, or the request otherwise failed — all
  /// ordinary, expected outcomes for a reader-facing zap button.
  Future<String?> requestZapInvoice({
    required Story story,
    required int amountSats,
    String? comment,
  });
}
