# The Relay Gazette — Architecture

A personal, automatically generated newspaper built from Nostr. See the
product brief for the full vision; this document covers implementation
decisions for Phase 1 (MVP) and what's deliberately deferred.

## Layers

```
lib/
  domain/          protocol-independent core: entities, repository
                    interfaces (ports), usecases. No Flutter, no ndk import.
  data/
    nostr/          ndk-backed FeedProvider implementation, event mapping
    editions/       edition <-> JSON codec, Drift-backed repository
    settings/       SharedPreferences-backed settings repository
  storage/          Drift database + table definitions
  presentation/      Riverpod providers (composition root) + pages/widgets,
                      organized by feature (onboarding, configuration,
                      edition, archive, common, theme)
```

The dependency rule: `domain` defines interfaces (`FeedProvider`,
`EditionRepository`, `SettingsRepository`, `Bech32PublicKeyCodec`); `data`
implements them against a specific technology; `presentation` wires concrete
implementations to interfaces in `presentation/providers.dart` (the single
composition root) and otherwise only ever depends on `domain` types.
Nothing in `domain` or `presentation` imports `package:ndk` or `package:drift`
directly.

`FeedProvider` is the seam described in the brief: `RelayFeedProvider` talks
to relays; `PrimalFeedProvider` talks to Primal's cache instead;
`CompositeFeedProvider` combines them (personal network via relays, trending
via Primal) behind the single interface everything else depends on. The UI
renders `Story`/`Author`/`GazetteEdition` — it has never seen a `Nip01Event`.

## The edition model

A `GazetteEdition` is generated once (`GenerateEdition` usecase) and then
persisted as an immutable snapshot (`EditionRepository.save`). Reading a
past edition (`EditionRepository.getById`) never touches the network. This
is the "finite, readable newspaper-like edition" from the product brief, not
a live feed.

Storage: one `Editions` row per edition, in Drift/SQLite. Sections and
stories are serialized to a single JSON blob (`payloadJson`) rather than
normalized into their own tables — an edition is always written and read as
one atomic snapshot, never queried story-by-story, so full normalization
would add relational overhead for no benefit today. A few scalar columns
(`generatedAtUtcMillis`, `storyCount`, `source`, …) are kept alongside the
blob so the archive shelf can list editions without decoding every payload
(see spec §28, performance). Revisit this if a future feature needs to query
*into* stories across editions (e.g. a saved reading list, §24).

## Generating an edition

`GenerateEdition` (domain/usecases/generate_edition.dart):

1. Resolve the time window to `[windowStart, windowEnd)` in UTC
   (`EditionTimeWindow.resolve`).
2. Ask the configured `FeedProvider` for stories in that window (personal
   network or trending).
3. Dedupe by event id (relays commonly redeliver the same event).
4. Drop stories that don't meet the configured `EngagementThresholds` —
   deterministic, explainable filtering per spec §8, not an opaque
   algorithm.
5. Hand qualifying stories to `BuildEditionSections`, which sorts by
   `engagementWeight` (see below) and buckets them into "Top Stories" +
   "From Your Network" (personal) or a single "Trending" section — sections
   are only emitted when they actually have content.

`RelayFeedProvider.fetchPersonalNetworkStories` does the actual relay work:
resolve the contact list (kind 3), fetch kind 1 notes from those authors in
the window, then fetch engagement (reactions/reposts/replies/zap receipts)
in **four queries total**, filtered by `#e` tag membership across *all*
candidate note ids at once — not one query per note. This is the §28
performance requirement in practice: cost is bounded by "how many kinds of
engagement" rather than "how many notes."

### `engagementWeight` vs. `GazetteScore`

The brief describes an optional, more elaborate `GazetteScore` (social
proximity, engagement velocity, per-account normalization) as a later-phase
feature (§10, §34) — deliberately not core to Phase 1. `engagementWeight`
(domain/usecases/engagement_ranking.dart) is a much smaller, fully
documented function used only to order stories *within* a section: reactions
count once, replies/reposts count double, zap sats are weighted
logarithmically so one large zap can't dominate. It is not a replacement for
`GazetteScore` — the interface is intentionally left open so a real
`GazetteScore` implementation can be swapped in as an alternative ranking
strategy without touching `BuildEditionSections`'s shape.

## Editorial layout (front page, not a feed)

The reader (`EditionReaderPage`) renders a front page, not a scrollable
list of identical cards: one hero story (headline, image, byline, a
drop-capped body paragraph), a couple of runners-up below it, and
everything else folded into a bordered "brief" column — the newspaper
"in brief" convention, used here so a full edition still fits without
turning into an endless scroll.

`_frontPage()` in `edition_reader_page.dart` builds this purely as a
presentation decision: the lead section's best story (already ranked by
`BuildEditionSections`) becomes the hero, its next two become runners-up,
and everything remaining — the rest of that section plus every subsequent
section — becomes the brief column. Which stories belong to which
*section* (Top Stories vs. From Your Network vs. Trending) is still
entirely the domain layer's call; this only decides how those
already-ordered stories get arranged on the page.

A note's content is split into a headline and an optional body by
`extractHeadline` (domain/usecases/story_headline.dart) — the first
sentence or line becomes the headline, the rest becomes the body, with a
hard-truncated fallback (original text preserved as the body) for a note
with no natural break. Never invents or summarizes text: what's shown is
always a subset of the note's actual content, split, not rewritten.

**Responsive**: `LayoutBuilder` picks between three arrangements at
`GazetteBreakpoints.tablet` (640) and `.wide` (1000) — a single stacked
column on a phone, 2 columns (stories + brief sidebar) on a tablet in
portrait, 3 (hero + runners-up + brief) on a tablet in landscape or a
desktop-sized window, closer to an actual newspaper front page once
there's room for it.

**Theming**: colors are carried by a `GazetteColors` `ThemeExtension`
(`presentation/theme/gazette_colors.dart`), read via a `context.gazetteColors`
accessor, rather than the hardcoded static constants Phase 1 originally
used — `MaterialApp.themeMode: system` switches between a light "paper"
palette and a dark one automatically. Every widget that touches a
semantic color goes through the extension now; nothing hardcodes "paper is
always light."

The drop cap (`DropCapText`) is an inline oversized first character, not a
true CSS-`float`-style multi-line wrap — Flutter's text layout has no
float equivalent without a custom `RenderObject`, so this is the
achievable approximation: a recognizable newspaper cue without that added
complexity.

## Primal integration (Phase 2)

Primal's cache server (`wss://cache2.primal.net/v1`, confirmed from
`PRIMAL_CACHE_URL` in `PrimalHQ/primal-web-app`'s own `.env`) speaks a
Nostr-shaped protocol that is **not** part of any NIP: a `REQ`'s filter is
`{"cache": [functionName, params]}` rather than a NIP-01 filter, though
responses still use standard `EVENT`/`EOSE`/`NOTICE` frames. There is no
published spec for this — `data/primal/primal_cache_client.dart`'s
behavior (the `explore` function, its `scope`/`timeframe` parameters, the
`EVENT_STATS` virtual kind `10000100` carrying `{likes, replies, reposts,
zaps, satszapped, ...}`) was confirmed by reading
`PrimalHQ/primal-server`'s Julia source directly (`app.jl`, `app_ext.jl`,
`cache_server_handlers.jl`), per the brief's instruction not to
reverse-engineer fragile behavior when the actual implementation is
available to read.

Kept as its own small protocol client rather than bolted onto ndk's relay
machinery, because it genuinely is a different protocol speaking a
different vocabulary — conflating the two would leak Primal's shape into
code that should only ever know NIP-01.

Unlike relay-sourced events (which ndk verifies as they arrive),
`PrimalFeedProvider` explicitly re-verifies every note and profile's
signature itself (`Bip340EventVerifier`) before trusting it, and parses
each record independently so one malformed one doesn't fail an entire
edition. See "Security" below.

## Signing, interactions, and zaps (Phase 3)

`NostrSigner` (domain) is the one interface standing between "this app" and
"a private key" — it is deliberately the *only* place that boundary exists.
`AmberNostrSigner` implements it via a NIP-55 Android Intent round-trip
(`MainActivity.kt`'s method channel): `get_public_key` and `sign_event`,
exactly as specified in nostr-protocol/nips/55.md. Reacting, reposting, and
replying (`domain/usecases/interactions.dart`) all go through the same
shape — build an `UnsignedNostrEvent`, ask the signer, broadcast the result
via `EventBroadcaster` (`NdkEventBroadcaster`) if signing succeeded.

`BunkerNostrSigner` (NIP-46) implements the same `NostrSigner` interface
over a relay instead of an Android Intent — ndk already ships a complete
NIP-46 implementation (`ndk.bunkers`), so this is an adapter, not a
protocol implementation. It works on every platform this app runs on, not
just Android, which is the main reason it exists alongside Amber. A reader
connects at most one signer at a time; `SignerConnectionController`
(presentation layer) holds whichever one is currently connected as a
plain `NostrSigner`, defaulting to a `NullNostrSigner` (a real object, not
`null`) so every consumer — the interaction usecases, `ZapService` — can
depend on a non-nullable signer and simply gets refused until one connects.

Zapping (`Nip57ZapService`, NIP-57) is intentionally *not* gated on a
connected signer: NIP-57's `nostr` callback parameter is optional, so a
reader with no signer can still resolve an invoice and pay — they just
can't attach a publicly-attributable signed zap request. `ZapService`
returns the raw bolt11 invoice (not a URI): the reader either pays it
through a connected NIP-47 wallet (`NwcWalletConnection`, via ndk's
already-implemented `ndk.nwc`) or hands it to an external wallet app via a
`lightning:` link — nothing here ever touches funds directly.

Everything an external signer or wallet returns is treated as untrusted
input from a separate process — see "Security" below for what that means
concretely.

### `engagementWeight` vs. `GazetteScore`

The brief describes an optional, more elaborate `GazetteScore` (social
proximity, engagement velocity, per-account normalization) — `engagementWeight`
(domain/usecases/engagement_ranking.dart) is a much smaller function used
by default to order stories *within* a section. `gazetteScore`
(domain/usecases/gazette_score.dart) is the real thing: engagement +
velocity (engagement/hour) + exponential recency decay + a network-proximity
bonus, every coefficient named on `GazetteScoreWeights` rather than buried
inline, and `explainGazetteScore` returns the per-component breakdown for
inspectability. `BuildEditionSections` takes an injectable `StoryRanker`, so
either function slots in without changing how sections get built.
Documented, known limitations (not silently shipped): no per-account
normalization (needs follower counts, which nothing in the app collects
yet) and proximity is binary — personal-network vs. trending — rather than
true second-degree graph distance.

## Long-form content, highlights, and lists (Phase 6)

**NIP-23 long-form articles** (kind 30023) are fetched in the exact same
relay query as plain notes — `RelayFeedProvider` just adds the kind to the
filter — and mapped by `articleFromEvent` into the same `Story` shape,
with `title`/`summary`/`dTag` populated from NIP-23's tags instead of
inferred. The reader UI treats an article as a story like any other for
layout purposes (it can be the hero, a runner-up, or a brief), but shows a
"Read the full article →" link that opens `ArticleReaderPage`, rendering
the Markdown body properly (`flutter_markdown_plus` — the original
`flutter_markdown` is discontinued by Google) rather than flattening it to
plain text.

**NIP-84 highlights** (kind 9802, `CreateHighlight`) let a reader mark a
passage as worth remembering, tagging the source (`e`, plus `a` for an
addressable article so the highlight survives an edit) and the original
author (`p`, role `author`). Confirmed against Boris
(github.com/dergigi/boris), the app the brief pointed at, which highlights
using exactly this NIP. Simplification: Flutter has no built-in way to
capture an arbitrary in-place text selection across widgets without a
custom selection handler, so the highlight dialog offers the story's full
text pre-filled and editable rather than true inline selection — the
reader trims it down to the passage they want.

**NIP-51 lists** (kind 30000, "follow sets") let a reader build an edition
from a curated subset of accounts instead of their whole contact list.
`FeedProvider.fetchLists`/`fetchStoriesFromList` are new interface
methods; `RelayFeedProvider` resolves a list's `d`/`title`/`p` tags and
then reuses the exact same "fetch stories for these authors" path
`fetchPersonalNetworkStories` already used (extracted into
`_fetchStoriesForAuthors` for that purpose). `EditionSource.customList` is
a third source alongside personal-network and trending; `GenerateEdition`
requires a `customListId` when it's selected — deliberately an
`ArgumentError` (a caller bug) rather than a silent no-op if the UI forgot
to supply one.

**Three palettes, one type system.** `GazetteColors` (a `ThemeExtension`)
now has `light`/`dark`/`sport` (a salmon-pink, Gazzetta-dello-Sport-style
palette) instead of just two, plus an independent serif/sans-serif choice
for body copy (`ThemePreference`/`BodyFontPreference`, persisted via
`SettingsRepository`). Headlines stay serif regardless — that's the
masthead's identity, not a readability knob. An explicit theme choice
pins `ThemeMode` so it overrides the OS setting; leaving it on "system"
keeps following light/dark live, as before.

## Security

A manual security review (no git history to diff against, so no automated
`security-review` skill run) found and fixed six concrete issues spanning
Android manifest configuration, trust boundaries around external input
(a separate signer app, Primal's cache server), and a client-side SSRF in
the zap flow. Full list with reasoning and the tests that demonstrate each
fix: see TASKS.md, "Security review (this session)".

The throughline worth keeping in mind when extending this app: **every
external signer response, every Primal record, and every URL built from a
Nostr profile field is untrusted input**, even though it arrives over a
protocol this app also trusts for other purposes. `AmberNostrSigner.sign()`
and `PrimalFeedProvider` both re-verify signatures themselves rather than
assuming "it came over the right channel, so it's fine"; `ssrf_guard.dart`
exists because a Lightning address is reader-facing data an author fully
controls, not a URL this app chose.

## Known simplifications (Phase 1)

Documented rather than silently shipped:

- **Zap amounts** are read from the `amount` tag (millisats) inside the zap
  request JSON embedded in a zap receipt's `description` tag — not from
  decoding the receipt's bolt11 invoice, which is authoritative but a
  meaningfully larger scope (a full BOLT11 decoder) for an MVP. Most clients
  display the same value. See `data/nostr/nostr_mappers.dart`.
- **Media detection** reads NIP-92 `imeta` tags first: an inline URL tagged
  with `m image/...` is treated as an image even when the CDN URL has no
  filename extension. The old image-extension heuristic
  (`.png/.jpg/.jpeg/.gif/.webp`) remains only as a compatibility fallback
  for older clients that do not publish NIP-92 metadata. Video and other
  media remain ordinary links for now; the editorial UI has image treatment
  but no video player.
- **Relay discovery** starts from a fixed bootstrap set
  (`data/nostr/relay_defaults.dart`) plus reader-managed relays. For personal
  and NIP-51-list editions, the app also resolves followed authors' NIP-65
  `kind:10002` lists and queries a compact, shared set of their advertised
  **write** relays (with bootstrap fallback when a list is absent). It does
  not yet publish or edit the reader's own NIP-65 list: that would require a
  connected signer and an explicit product decision about relay ownership.

## Dependency choices and deviations

- **ndk** (`relaystr/ndk`, MIT) over other Dart Nostr libraries: actively
  maintained, built specifically for constrained/mobile clients, ships a
  pure-Dart BIP-340 verifier so signature checking doesn't require FFI.
  **Pinned to `^0.7.1`, not the latest 0.9.x**: starting at 0.8, ndk added an
  optional Rust-accelerated verifier behind a Dart *native-assets build
  hook* — and that hook runs unconditionally for every consumer at build
  time (`dart run`/`flutter run`/`flutter build`), regardless of whether the
  app actually selects the Rust verifier. It hard-requires a `rustup`
  installation to succeed, which isn't installed on this machine and
  shouldn't become a project-wide contributor/CI requirement just to get a
  faster verifier this app doesn't need. 0.7.1 predates that hook entirely
  and has full parity for everything Phase 1 uses (`Filter`, `requests`,
  `follows`, `metadata`, `Nip19`, `Bip340EventVerifier`). Revisit if a later
  ndk version decouples the hook from the package, or if the Rust verifier's
  speed becomes worth requiring rustup for.
- **Drift** over Isar/Hive for local storage: current, actively maintained;
  Isar and (original) Hive are effectively unmaintained as of this writing.
  Uses `drift_flutter`'s `driftDatabase()` helper, which (drift ≥2.32,
  sqlite3 ≥3.x) bundles SQLite automatically — no `sqlite3_flutter_libs`
  dependency needed (that package is now an intentional no-op, kept only for
  compatibility).
- **Riverpod** (manual providers, no code generation) for DI/state. Chosen
  over Provider/Bloc for how naturally it expresses the interface-based
  composition root described above. Code generation (`riverpod_annotation`)
  was tried and dropped — not worth a second build_runner generator
  alongside Drift's for an app this size; revisit if provider boilerplate
  grows.
- **Fonts**: Playfair Display (masthead/headlines), Source Serif 4 (body),
  Inter (UI chrome) — all OFL-1.1, bundled as local assets
  (`assets/fonts/`, licenses alongside) rather than fetched from a font CDN
  at runtime, consistent with the offline-first/no-unnecessary-network-
  service posture (spec §26).

## What this app does not do (by design)

Per spec §35: no endless-scroll feed, no key storage ever (not even
Amber's grant — `AmberNostrSigner` re-asks each app launch rather than
caching an identity), no auth required to read, no Primal/Lightning
dependency for basic operation — `CompositeFeedProvider.fetchPersonalNetworkStories`
and reading a saved edition never touch Primal or a signer at all.
