/// Primal-specific "virtual" event kinds returned alongside real Nostr
/// events in cache responses. Not part of any NIP — confirmed by reading
/// `EVENT_STATS` in github.com/PrimalHQ/primal-server (`src/app.jl`).
class PrimalEventKinds {
  /// content: `{"event_id", "likes", "replies", "mentions", "reposts",
  /// "zaps", "satszapped", "score", "score24h", "bookmarks"}` — Primal's
  /// server-aggregated engagement counters for one note.
  static const eventStats = 10000100;

  const PrimalEventKinds._();
}
