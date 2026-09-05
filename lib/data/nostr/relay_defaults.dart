/// Default bootstrap relay set used regardless of what the reader has
/// configured — see `SettingsRepository.getCustomRelayUrls` for the
/// reader-added relays layered on top in the Settings "Relays" section.
/// A general-purpose, widely-peered mix so contact lists and notes resolve
/// for most accounts out of the box.
///
/// `relay.nostr.band` and `relay.snort.social` were in this list originally
/// but proved flaky enough in practice (slow/failed connects) to hold back
/// discovery of everything else, so they were dropped in favor of
/// `nostr.wine`.
const List<String> kDefaultBootstrapRelays = [
  'wss://relay.damus.io',
  'wss://relay.primal.net',
  'wss://nos.lol',
  'wss://nostr.wine',
];

/// Caps how many follows are placed in a single relay filter, so an account
/// following thousands of people can't produce an unbounded query.
const int kMaxAuthorsPerQuery = 800;

/// Caps how many candidate notes a single edition considers, bounding
/// memory/parsing work regardless of window size or network activity.
const int kMaxNotesPerEdition = 500;
