# Implementation checklist

## Phase 1 — MVP

- [x] Flutter project scaffolded (Android + Linux desktop targets)
- [x] App icon wired from `assets/icons/icon.png` via `flutter_launcher_icons`
- [x] Editorial visual identity: warm-paper theme, Playfair
      Display/Source Serif 4/Inter, masthead
- [x] Domain layer: `NostrPublicKey`, `Story`, `Author`, `EngagementCounts`/
      `EngagementThresholds`, `EditionTimeWindow`, `FilterConfiguration`,
      `EditionSection`, `GazetteEdition`, `GazetteEditionSummary`
- [x] `FeedProvider` / `EditionRepository` / `SettingsRepository` interfaces
- [x] `ParseUserIdentity`, `engagementWeight`, `BuildEditionSections`,
      `GenerateEdition` usecases — unit tested
- [x] `RelayFeedProvider` (ndk-backed): contact list → notes → batched
      engagement queries (reactions/reposts/replies/zaps) → `Story`
- [x] npub validation/encode-decode via ndk's NIP-19, wrapped behind
      `Bech32PublicKeyCodec` so the domain layer stays ndk-free
- [x] Drift-backed `EditionRepositoryImpl` (JSON-blob snapshot + indexed
      listing columns) — unit tested incl. round-trip and upsert semantics
- [x] `SharedPrefsSettingsRepository` for the saved npub
- [x] Riverpod composition root (`presentation/providers.dart`)
- [x] Configuration page (time window chips, optional threshold fields)
- [x] Edition generation flow with loading/error states
- [x] Newspaper-style reader (masthead, sectioned `CustomScrollView`,
      lazy `SliverList`, subtle engagement footer, empty-edition state)
- [x] Edition archive (Today/Yesterday/date shelves, tap to reopen, swipe
      to delete)
- [x] Offline reading: archive/reader never call `FeedProvider`, only
      `EditionRepository`

### Before shipping Phase 1 for real use

- [ ] Run once against a real npub with real relay connectivity — this
      environment has no verified outbound access to test live relay/Primal
      queries end-to-end
- [ ] Android build: `flutter doctor` reports the Android `cmdline-tools`
      component missing on this machine; never installed without asking
      (touches outside the project directory) — run `flutter doctor
      --android-licenses` after installing command-line tools, then
      `flutter build apk`
- [ ] Sanity-check `flutter_launcher_icons`'s adaptive icon: it currently
      reuses the flat `icon.png` as both foreground and background source,
      a placeholder rather than a proper adaptive-icon foreground layer

## Phase 2 — Primal / trending

- [x] `PrimalFeedProvider` implementing `FeedProvider` against Primal's
      cache protocol (`explore` with `scope: global, timeframe: trending`),
      confirmed by reading `PrimalHQ/primal-server` source directly (no
      published spec exists for this protocol)
- [x] `CompositeFeedProvider` wires relay (personal network) + Primal
      (trending) behind the single `FeedProvider` the rest of the app uses
- [x] `EditionSource.trending` wired end-to-end in the configuration UI
- [x] Manual relay management: Settings → Relays lets the reader add/remove
      relays on top of the fixed default set (`SettingsRepository.get/setCustomRelayUrls`,
      `RelayListController`), reconnected via `ndk.relays.reconnectRelays`
      both on add and at startup. Also dropped `relay.nostr.band` from the
      defaults (flaky in practice) in favor of `nostr.wine`.
- [x] NIP-65 relay discovery for personal-network and NIP-51-list editions:
      NDK resolves followed authors' `kind:10002` lists, selects a compact
      shared set of their **write** relays (one coverage relay per author),
      and falls back to the bootstrap set if a list is absent. This is
      automatic discovery on top of the existing manual list; publishing or
      editing the reader's own NIP-65 list is intentionally still out of
      scope until there is an explicit signed-relay-management UX.
- [x] NIP-92 `imeta` media parsing: image tags with `m image/...` now work
      even for extensionless CDN URLs, provided their URL also appears in
      the event content (per the NIP's matching requirement). The old
      filename-extension heuristic remains as a backwards-compatible
      fallback; video/other media stay ordinary links until the reader has
      an appropriate player.
- [ ] Bolt11 decoding for authoritative zap amounts (currently reads the
      amount tag from the embedded zap request instead — see
      ARCHITECTURE.md)

## Phase 3 — Amber, interactions, zaps

- [x] `NostrSigner` domain interface + `AmberNostrSigner` (NIP-55 via a
      native Android method channel in `MainActivity.kt`)
- [x] React / repost / reply usecases (`ReactToStory`, `RepostStory`,
      `ReplyToStory`) + `NdkEventBroadcaster`
- [x] Zap flow (`Nip57ZapService`): LUD-16 → LNURL-pay → optional signed
      zap request → bolt11 invoice → external wallet via `lightning:` URI
- [x] Interaction UI on each story (react/repost/reply/zap), gated on a
      connected signer where required
- [x] `BunkerNostrSigner` (NIP-46 remote signing via `bunker://` URIs) —
      works on every platform, not just Android, using ndk's built-in
      `Bunkers`/`Nip46EventSigner`. `SignerConnectionController` now holds
      whichever signer (Amber or bunker) the reader actually connected,
      exposed as one `NostrSigner` to every usecase.
- [x] NIP-84 highlights (`CreateHighlight`, kind 9802) — a "Highlight"
      action on every story; MVP simplification: the reader trims a
      pre-filled copy of the text rather than an inline text selection
      (Flutter has no built-in cross-widget selection capture) — see
      ARCHITECTURE.md.
- [x] NWC (NIP-47) direct wallet payment (`NwcWalletConnection`, via ndk's
      `Nwc`) as an alternative to handing a zap off to an external wallet
      app — `ZapService` now returns the raw bolt11 invoice so either path
      can consume it. Connection secret kept in memory only, not persisted
      — see "Security" below.
- [ ] **Not exercised against a real Amber install, bunker, NWC wallet, or
      a real relay/LNURL server** — this environment has no Android
      device/emulator and (per `flutter doctor`) no working Android build
      toolchain, so the native Kotlin side is unbuilt and untested beyond
      `flutter analyze`/reading. Nor does it have verified live network
      access to a relay, a bunker, or a wallet service. The Dart-side logic
      (parsing, signature verification, SSRF guarding, usecase
      orchestration) is unit tested wherever it can be exercised without a
      network; the actual round-trips are not. Treat all of Amber/bunker/NWC
      as reviewed-but-unverified until run for real.

## UI redesign — front page, not a feed

User feedback after Phase 5: the reader looked like a scrollable feed of
identical cards, not an actual newspaper front page. Redesigned:

- [x] `EditionReaderPage` rebuilt around a hero story (headline + image +
      byline + drop-capped body), 1-2 runners-up, and a bordered "brief"
      column for everything else — see ARCHITECTURE.md, "Editorial layout"
- [x] `extractHeadline` splits a note's content into headline/body without
      inventing or summarizing text — unit tested (9 tests)
- [x] Responsive: single column on phones, 2 columns on tablet portrait, 3
      (hero/runners-up/brief) on tablet landscape or wide windows —
      `GazetteBreakpoints` at 640/1000, verified with widget tests at
      390×844 (phone), 820×1180 (tablet portrait), 1194×834 (tablet
      landscape)
- [x] Adaptive light/dark theme via a `GazetteColors` `ThemeExtension`,
      `MaterialApp.themeMode: system` — every widget rewired off the old
      hardcoded static color constants
- [x] Masthead extended with vol/issue number, date, a standing motto, and
      an edition-stats rule (story/author counts, source, window)
- [x] Fixed a real overflow bug the new layout surfaced: `StoryActions`'
      four-button row overflowed in the narrow brief column (and, at
      default text scale, even on a phone) — changed `Row` to `Wrap`.
      Caught by `test/widget/edition_reader_page_test.dart`, which pumps
      the full front page at three viewport sizes specifically to catch
      layout overflows the analyzer can't.

## Phase 4 — partially done

- [x] Real `GazetteScore` (`domain/usecases/gazette_score.dart`): engagement
      + velocity + recency decay + network-proximity terms, all weights
      named and overridable, `explainGazetteScore` for a full breakdown —
      unit tested (9 tests). Documented known limitations: no per-account
      normalization (would need follower counts, not collected anywhere
      yet) and proximity is binary (personal-network vs. trending) rather
      than true graph distance.
- [x] `BuildEditionSections` accepts an injectable `StoryRanker`, so
      `gazetteScore` can be swapped in for `engagementWeight` without
      changing section-building logic
- [x] NIP-23 long-form content: fetched alongside notes (same query, kind
      30023 added), rendered as its own `ArticleReaderPage` with real
      Markdown (`flutter_markdown_plus` — `flutter_markdown` itself is
      discontinued by Google) rather than flattened to plain text. A
      "Read the full article →" link appears wherever an article shows up
      (hero, secondary, or brief).
- [x] NIP-51 lists: `FeedProvider.fetchLists`/`fetchStoriesFromList`
      resolve a reader's NIP-51 follow sets (kind 30000); a third edition
      source ("From a List") in the configuration UI lets a reader pick
      one as the author pool instead of their whole contact list.
- [ ] Scheduled/automatic editions — deliberately not attempted: background
      execution on Android (WorkManager or similar) needs a real device to
      verify and this environment has none: shipping unverified background
      scheduling code seemed worse than leaving it undone
- [ ] Thread rendering
- [ ] User-defined/multiple saved Gazette configurations
- [x] Manual relay editor UI (Settings → Relays) — see Phase 2 note above.
      Still missing: automatic NIP-65 discovery of each author's own relays.

## Phase 6 — user-requested extensions (this session)

Prompted by: "spieghiamo cos'è The Relay Gazette, invitiamo al login
tramite nsec/amber... liste personalizzate... temi... font." The "nsec"
part was explicitly declined and replaced with NIP-46 (see the
conversation) — this app still never sees, asks for, or stores a private
key, on principle, not just for Amber.

- [x] NIP-05 identifier resolution (`HttpNip05Resolver`) as an alternative
      to typing/pasting an npub during onboarding — "name@domain.com" or a
      bare domain (root identifier)
- [x] Three themes (`GazetteColors.light/dark/sport` — "sport" is the
      Gazzetta-dello-Sport-style salmon-pink palette) plus a serif/sans-serif
      body-text choice, both persisted (`ThemePreference`/`BodyFontPreference`
      in `SettingsRepository`) and switchable live from a new `SettingsPage`
- [x] `SettingsPage`: appearance (theme/font), signer (connect/disconnect
      Amber or a bunker, shows which is active), wallet (connect/disconnect
      NWC) — reachable from a gear icon on the archive page
- [x] Onboarding rewritten again: explains reading vs. signing explicitly,
      offers npub/NIP-05 for reading and Amber/bunker for signing side by
      side, with an explicit "why we'll never ask for your nsec" line

## Phase 5 — onboarding & explanation

- [x] Onboarding rewritten: a "how it works" section (4 steps: npub → what
      counts → generate → read/close) above the existing npub field
- [x] "Connect with Amber" as an alternative to typing an npub, shown only
      when `NostrSigner.isAvailable()` reports a signer is actually
      installed (always hidden outside Android, and hidden if none is
      installed on Android too — no dead-end button)
- [x] Explicit, repeated nsec reassurance on the same screen

## Security review (this session)

A manual review — no `security-review` skill run, since this isn't a git
repo with a diffable baseline — turned up 6 concrete issues, all fixed and
covered by new tests (`flutter test` count went from 92 to 123 across this
review; `flutter analyze` stayed clean throughout). See the conversation's
final summary for the full write-up with severity and reasoning; short form:

1. **Release builds had no INTERNET permission at all** — it was only ever
   declared in the debug/profile manifests Flutter generates, not `main`'s.
   A release APK would have had zero network access. Fixed in
   `AndroidManifest.xml`.
2. **Amber would silently appear "not installed" on Android 11+** — no
   `<queries>` entry for the `nostrsigner:` scheme, which package-visibility
   rules require for `Intent#resolveActivity` to see it. Fixed alongside #1.
3. **`AmberNostrSigner` trusted the signer app's response without checking
   it** — no verification that the returned pubkey matched the connected
   identity, and no cryptographic check that the signature was real, before
   treating an event as ready to publish under the reader's name. Fixed by
   validating the pubkey and running the response through `Bip340EventVerifier`
   before accepting it. Tests: `test/data/amber_nostr_signer_test.dart`.
4. **Client-side SSRF in the zap flow** — an LNURL domain comes straight
   from an author's profile (`lud16`), unvalidated; a crafted address could
   make the reader's device probe its own LAN/loopback/cloud-metadata
   address. Fixed with `ssrf_guard.dart`, applied to every outbound request
   in `Nip57ZapService`. Tests: `test/data/ssrf_guard_test.dart` +
   dedicated cases in `nip57_zap_service_test.dart`. Documented residual
   gap: no DNS-rebinding protection (would need a lower-level HTTP client
   than `package:http` exposes).
5. **`PrimalFeedProvider` never verified event signatures**, unlike the
   relay path (where ndk verifies automatically) — and one malformed
   record from Primal would throw and fail an entire edition. Fixed:
   per-event try/catch plus a `Bip340EventVerifier` check before a note or
   profile is trusted. Tests added to `primal_feed_provider_test.dart`.
6. **`PrimalCacheClient`'s WebSocket listener could hang forever** on a
   malformed frame — an exception thrown synchronously inside `.listen()`
   doesn't route to `onError`, so the completer would never resolve. Fixed
   with a try/catch around per-frame parsing. Not covered by an automated
   test (would need an in-process mock WebSocket server not currently
   wired into this project) — verified by code reading only; flagged here
   rather than silently left unverified.

Also confirmed clean, without needing changes: no nsec/private-key handling
anywhere in the codebase; no `print`/`debugPrint` of sensitive data; no
non-TLS (`http://`/`ws://`) endpoints; no analytics/telemetry SDKs in
`pubspec.yaml`; `NostrPublicKey.fromHex` strictly validates before any value
reaches a relay filter; SharedPreferences stores only the public key (never
anything sensitive).

### Additions in Phase 6 (NIP-46 / NWC)

Same trust posture applied consistently: `BunkerNostrSigner.sign()` and
`NwcWalletConnection` treat the bunker/wallet as an untrusted remote party
just like Amber — `BunkerNostrSigner` independently re-verifies every
signature (`Bip340EventVerifier`) and checks the returned pubkey matches
before accepting an event, exactly like `AmberNostrSigner` does.

- **NIP-46/NWC connection secrets are kept in memory only, never written to
  disk.** Both a bunker connection string and an NWC connection string
  embed a real credential — the bunker one authorizes signing as the
  reader, the NWC one authorizes spending from their wallet. Unlike the
  read-only npub (public by design, safe in plain SharedPreferences), these
  are deliberately not persisted: the reader reconnects each session rather
  than this app holding a spending/signing credential on disk
  unencrypted. Revisit with `flutter_secure_storage` if "stay connected
  across restarts" becomes a real requirement.
- **`ndk.nwc` is marked `@experimental`** by its own authors — its API
  could change in a future ndk release. Flagged (as an analyzer warning
  left visible, not suppressed) rather than silently relied upon.

Known, accepted (not fixed) residual risks, documented rather than silent:

- The local Drift database (past editions, i.e. what a reader chose to
  read) is unencrypted at rest, relying on OS app-sandbox isolation rather
  than an additional encryption layer. Reasonable for public Nostr content,
  but the *selection* of what a reader read is itself a bit of private
  behavioral data per spec §26 — worth revisiting with `sqlcipher_flutter_libs`
  (already a transitive dependency) if this ships broadly.
- Remote images (avatars, story media) load directly from whatever URL a
  note contains, with no proxy — standard for Nostr/social clients, but it
  does mean an image host can observe the reader's IP and the moment they
  read a given story. Not fixed: doing so would mean running a media proxy
  server, which the product brief explicitly rules out ("do not introduce
  unnecessary backend infrastructure").

## Phase 7 — reported bugs & relay management (this session)

- [x] **Sport theme text was unreadable in places** ("il font per il tema
      sport deve essere nero, altrimenti non si vede"). Root cause:
      `AppTheme._build()` constructed `ColorScheme(...)` directly, listing
      only 8 of Material 3's roles — every unlisted role (`onSurfaceVariant`,
      `outline`, `surfaceContainer`, ...) fell back to fixed defaults
      unrelated to `brightness`, so widgets using those secondary roles (hint
      text, for one) stayed unreadable even though `ink`/`paper` themselves
      were correct. Fixed by seeding with `ColorScheme.fromSeed(seedColor:
      colors.accent, brightness: brightness)` first, then `.copyWith(...)`
      the explicit overrides on top. Verified, not just eyeballed: new WCAG
      AA contrast-ratio test group in `app_theme_test.dart` (16 assertions
      across all three themes × 4 role pairs).
- [x] **No way back out of an edition** ("quando si apre l'edizione, non
      c'è un tasto 'torna indietro'"). `EditionReaderPage` has no `AppBar`
      by design (the masthead stands in for one visually), so Flutter never
      got the chance to add its usual automatic back button. Fixed with a
      `_ReaderBackButton` floated in a `Stack` above the scrolling content
      (both the populated and empty-edition branches), hidden via
      `Navigator.canPop()` when there's nothing to pop back to. Covered by
      the existing multi-viewport widget tests in
      `test/widget/edition_reader_page_test.dart` (still green, no layout
      errors from the added `Stack`).
- [x] **"è necessario impostare dei relay, perché al momento non ne trova
      di nuovi"** — manual relay management, see the Phase 2 entry above.
      `SettingsRepository.get/setCustomRelayUrls` persists reader-added
      relays; `RelayListController` (`presentation/relays/relay_providers.dart`)
      pushes them onto the already-running `Ndk` via
      `ndk.relays.reconnectRelays` both when added and at every app start;
      new "Relays" section in `SettingsPage` lists the fixed defaults
      read-only and lets the reader add/remove their own (`wss://` only —
      plaintext `ws://` is rejected by `normalizeRelayUrl`, since it would
      leak every query/event in cleartext). Also dropped the already
      user-flagged `relay.nostr.band` from the default set in favor of
      `nostr.wine`. Tests: `shared_prefs_settings_repository_test.dart`
      (persistence round-trip) and `relay_providers_test.dart`
      (`normalizeRelayUrl` edge cases). Note: this is manual relay
      management only — automatic NIP-65 discovery of each followed
      account's own relays is still open (see Phase 2).

`flutter analyze`: clean (same 14 pre-existing info/warnings as before this
session, nothing new). `flutter test`: 192 passed, 0 failed.

## Phase 8 — app icon, splash screen, and a real text-color bug (this session)

- [x] App icon and splash screen generated from `assets/icons/icon.png`
      (the reader's own illustration). `flutter_launcher_icons` produced
      the Android mipmap + adaptive icon set; added `flutter_native_splash`
      (new dev dependency) configured with light/dark backgrounds matching
      `GazetteColors.light/dark.paper`, including Android 12+'s splash API.
- [x] **Light theme background was pale off-white, not the requested
      "giallo antico" (antique yellow/ochre)** — reader supplied a vintage
      newsprint photo as a reference. `GazetteColors.light.paper` changed
      from `0xFFF7F2E9` to `0xFFE7D2A0` (`paperMuted`/`rule`/`inkFaded`
      adjusted to match); contrast against `ink` is ~12:1, comfortably past
      the 4.5:1 floor the WCAG test group already checks.
- [x] **Real bug: text rendered white/near-invisible on light and sport
      themes, in both editions and Settings** ("il font deve essere nero,
      non bianco, perché altrimenti non si vede una fava"). Root cause in
      `AppTheme._build()`: `base.textTheme.apply(bodyColor: colors.ink,
      displayColor: colors.ink).copyWith(displayLarge: TextStyle(...), ...)`
      — `.copyWith` *replaces* each listed role with a brand-new `TextStyle`
      rather than merging into the one `.apply()` had just colored, so
      `displayLarge`, `headlineLarge/Medium/Small`, `bodyLarge`, `bodyMedium`,
      and `labelLarge` all lost their color and fell back to Flutter's own
      Material light/dark heuristic instead of this theme's `ink` — most
      visibly on the masthead's "THE RELAY GAZETTE" (`displayLarge`).
      `labelMedium`/`labelSmall` were unaffected only because they happened
      to set `color: colors.inkFaded` inline already. Fixed by adding
      `color: colors.ink` to every listed role explicitly. Applies
      uniformly wherever `Theme.of(context).textTheme` is used, which is
      why the same fix also covers Settings — no widget-level colors are
      hardcoded there. New regression test group in `app_theme_test.dart`
      ("textTheme roles resolve a real color against paper") asserts every
      affected role has a non-null, >=4.5:1-contrast color in all three
      themes — 21 assertions, all failing before this fix (`color` was
      `null`) and passing after.
- [x] Masthead nameplate ("THE RELAY GAZETTE") first tried **Bevan**, a
      bold Clarendon-style slab serif — superseded the same session by
      Phase 9 below once the reader clarified the actual target was
      Blackletter/Old English, not a slab serif.

`flutter analyze`: clean (same 14 pre-existing info/warnings). `flutter
test`: 213 passed, 0 failed (192 prior + 21 new textTheme-color regression
tests).

## Phase 9 — Blackletter masthead (this session)

Prompted by a detailed spec: the masthead should read as an actual
19th-century (~1850–1900) newspaper nameplate — Blackletter/Old
English/Textura/Fraktur — explicitly *not* Western/cowboy, slab serif,
circus, steampunk, generic vintage serif, Art Nouveau, or medieval-fantasy.
Reserved for "THE RELAY GAZETTE" only; headlines/body/UI stay on the
existing PlayfairDisplay/SourceSerif4/Inter system.

- [x] Compared the three Blackletter families on Google Fonts (there are
      only three): rendered "THE RELAY GAZETTE" in each at masthead size,
      both title-case and the all-caps form actually used in the app, to
      check the specific failure mode of Blackletter capitals (many faces
      turn illegible or overly ornate in a run of all-caps).
  - **Pirata One** — reads as themed/theatrical ("pirate" is literally in
    Google's own description) — matches the brief's explicit exclusion,
    dropped.
  - **UnifrakturMaguntia** — elegant but calligraphic/flowing; in all-caps
    "GAZETTE" was hard to parse at a glance (curved strokes blur letter
    boundaries) — not what a masthead needs to do at arm's length.
  - **UnifrakturCook (Bold)** — compact, strong verticals, high
    stroke-contrast, reads cleanly even in all-caps — the closest match to
    a real dignified newspaper nameplate (e.g. the kind of lettering real
    Victorian-era mastheads used) rather than a decorative or gothic face.
    **Chosen.**
- [x] Font: **UnifrakturCook**, weight Bold (the family's only cut).
      Source: Google Fonts / the `google/fonts` GitHub repo,
      `ofl/unifrakturcook/UnifrakturCook-Bold.ttf`. License: SIL Open Font
      License 1.1 — full text bundled at
      `assets/fonts/LICENSE-UnifrakturCook.txt`. Bundled locally (no
      network font fetch at runtime), same as every other typeface in this
      app.
  - Removed **Bevan** (font file, license file, pubspec entry) — no longer
    used anywhere once superseded.
- [x] `Masthead`'s "THE RELAY GAZETTE" `Text` now sets
      `fontFamily: 'UnifrakturCook'` with `fontWeight: FontWeight.normal`
      (the loaded file *is* the bold cut already; requesting `w700` on top
      of it would trigger Flutter's synthetic-bold faux-embolden instead
      of using the real glyphs) and a touch more `letterSpacing` (1.0) than
      the slab-serif version needed, since Blackletter's angular strokes
      read better with slightly more room between letters. Scoped to this
      one `Text` widget's style — not a change to `AppTheme.headlineFamily`
      — so nothing else in the app (headlines, body, UI chrome) is affected.

`flutter analyze`: clean (same 14 pre-existing info/warnings, nothing new).
`flutter test`: 213 passed, 0 failed (no test asserts a specific
`fontFamily` string, so this swap needed no test changes — contrast/color
coverage from Phase 8 already covers the masthead `Text`'s color
independent of which family renders it).

## Phase 10 — masthead casing and reply filtering (this session)

- [x] **"The Relay Gazette" was hardcoded all-caps** everywhere it's
      typed out (`Masthead`, `NpubEntryPage`) — changed to title case in
      both. Updated the three tests asserting on the literal string
      (`widget_test.dart`, `edition_reader_page_test.dart`).
- [x] **Trending (24h) was slow to generate** ("ci mette una vita ad
      aprire i post... forse perché ce li metti tutti"). Confirmed: neither
      feed provider filtered out thread replies before treating a note as
      a candidate story — a huge share of what's "trending" globally is
      reply activity under a handful of viral notes, so `explore`'s
      `limit: kMaxNotesPerEdition` budget was routinely being spent on
      reply fragments instead of standalone stories. Added
      `isReplyNote(Nip01Event)` (`data/nostr/nostr_mappers.dart`) — true
      for any kind:1 note carrying an `e` tag (NIP-10 marked or the older
      positional convention), false for quote-reposts (NIP-18, tagged `q`
      not `e`) since those are new standalone commentary, not thread
      replies. Applied in both `PrimalFeedProvider.fetchTrendingStories`
      (checked before the expensive signature-verification call, so
      skipped replies don't even pay that cost) and
      `RelayFeedProvider._fetchStoriesForAuthors` — same filtering logic
      in both places, since the personal-network feed had the identical
      gap even though only trending was reported as slow. Tests:
      `isReplyNote` unit tests in `nostr_mappers_test.dart`, plus a
      dedicated case in `primal_feed_provider_test.dart`.
  - Ideas raised but not implemented this session (flagged for the
    reader to prioritize, not silently done): (1) the per-event
    `Bip340EventVerifier.verify()` calls run one at a time in a plain
    `for` loop rather than on a background isolate — pure-Dart Schnorr
    verification is CPU-bound, so up to `kMaxNotesPerEdition` (500)
    sequential verifications could itself be a real contributor to
    "takes forever", independent of the reply-volume fix above; (2)
    diversity capping (e.g. no more than N stories from the same author
    in one edition) as an editorial-quality filter, not a performance one.

`flutter analyze`: clean (same 14 pre-existing info/warnings, nothing new).
`flutter test`: 218 passed, 0 failed (213 prior + 5 new: 4 `isReplyNote`
unit tests + 1 Primal reply-exclusion test).

## Phase 11 — engagement grace period for young posts (this session)

Reader's framing: a followed account's 8am note with real engagement
shouldn't make its 2pm note (3 likes, 1 repost by 2:20pm) look weak by
comparison — the second one just hasn't had time yet. Asked for young
posts to bypass the engagement thresholds, explicitly scoped to the
followed/curated feeds, not trending (trending's whole premise is
already-observed engagement, so "give it more time" doesn't apply there).

- [x] `GenerateEdition.engagementGracePeriod` (1 hour, matching the
      reader's own example): a story younger than this at generation time
      qualifies even if it doesn't clear `EngagementThresholds`, as long as
      `configuration.source != EditionSource.trending`. Implemented as
      `_qualifies()` in `generate_edition.dart`, replacing the old
      `configuration.thresholds.isSatisfiedBy(...)` filter inline. Applies
      to `personalNetwork` *and* `customList` — both are "who I chose to
      read" feeds, not just literal "seguiti"; only `trending` is excluded.
      Tests: three new cases in `generate_edition_test.dart` (fresh
      low-engagement story kept, stale low-engagement story dropped, fresh
      low-engagement *trending* story still dropped).

Also answered, not a code change: whether signature verification
(`Bip340EventVerifier`) is actually necessary. Yes — it's the only thing
standing between "this event's `pubkey` field says X" and "X actually
signed this". Without it, a malicious relay or a compromised/malicious
Primal cache could inject fabricated events attributed to any pubkey,
undetected — this is the same reasoning already documented in the
"Security review" section above for why `AmberNostrSigner`/
`PrimalFeedProvider` independently re-verify instead of trusting either
source. Not related to the reply-filtering or slowness fix; it stays.

`flutter analyze`: clean (same 14 pre-existing info/warnings, nothing new).
`flutter test`: 221 passed, 0 failed (218 prior + 3 new grace-period
tests).

## Phase 12 — reported bugs, mentions, and the aged-paper masthead (this session)

- [x] **Back button "too discreet"** — `_ReaderBackButton` was a
      translucent paper-colored circle over a paper-colored page; changed
      to a solid, opaque `colors.ink` circle with a `colors.paper` icon
      (inverted from the page) plus real elevation/shadow, so it reads
      unambiguously as a floating control in every theme.
- [x] **Inline mentions showed a raw npub instead of a name.** Added
      `mentionedPubkeysIn`/`resolveMentions` (`data/nostr/nostr_mappers.dart`):
      finds `nostr:npub1...`/`nostr:nprofile1...` (NIP-27, plus the bare
      no-scheme convention some clients still use) in note content via
      `Nip19.decode`, replaces each with "@DisplayName" (falling back to
      "@name", then a plain "@user" placeholder). Wired into both
      `RelayFeedProvider` (batches mentioned pubkeys' metadata together
      with note authors' in one `loadMetadatas` call) and
      `PrimalFeedProvider` (reuses whatever kind:0 events were already in
      that batch — degrades gracefully, doesn't force an extra round trip
      to Primal). Resolved at fetch time into `Story.content` itself
      (consistent with "a plain snapshot" — no live resolution needed to
      reopen an old edition). Tests: `nostr_mappers_test.dart`.
- [x] **Settings' "Connected — [npub]" showed a raw hex/npub instead of a
      name** — same problem, just in Settings instead of note content.
      Added `connectedSignerAuthorProvider` (resolves the connected
      signer's `Author` via `RelayFeedProvider.resolveViewer`); `_SignerSection`
      now shows `Author.label` (display name → name → shortened npub, in
      that order) instead of a raw hex substring.
- [x] **Crash: `RangeError` in `extractHeadline`**, reported live from a
      `flutter run` session on a real device — every note between 101 and
      139 characters with no newline or sentence-ending punctuation threw
      trying to `substring(0, 140)` on a string shorter than 140. The
      140-char clamp was correctly applied inside `_findBreakPoint`'s own
      `limit` calculation but never re-applied at the actual `substring`
      call site in `extractHeadline` itself. Fixed by clamping there too.
      Regression test in `story_headline_test.dart` using the reported
      case (a 139-char note).
- [x] **Crash: "A dismissed Dismissible widget is still part of the
      tree"**, same session's log. `_ArchiveList`'s `onDismissed` awaited
      an async delete + provider invalidation before the item actually
      left the list backing `ListView.builder` — `Dismissible` requires
      the item gone by the very next build, well before that round trip
      finishes. Converted `_ArchiveList` to `ConsumerStatefulWidget` with
      local `_dismissedIds` state, added synchronously inside
      `onDismissed` (via `setState`) so the item is optimistically hidden
      immediately, independent of when the persisted delete completes.
- [x] **Aged-paper masthead background**, from a detailed design brief:
      the light theme's reading surface should look like genuinely aged
      19th-century newsprint — light ivory center, progressively more
      yellowed toward the edges, slightly darker corners, soft irregular
      transition, no hard boundary or "UI vignette" look — applied to the
      newspaper *page* only (masthead + front page + article reader), not
      to Settings/onboarding/every UI surface, and not restarting per
      story block while scrolling.
  - `GazetteColors` gained `paperEdge`/`paperCorner` (the two extra,
    darker stops beyond `paper`/`paperMuted`); light's `paper`/`paperMuted`
    retuned lighter/warmer to serve as the gradient's center/mid stops.
    For `dark`/`sport`, both new fields equal that theme's own flat
    `paper` — the gradient degrades to a uniform fill, i.e. a no-op,
    for themes this brief wasn't about.
  - New `AgedPaperSurface` widget
    (`presentation/theme/aged_paper_surface.dart`): a `RadialGradient`
    with a custom `GradientTransform` that stretches the circle into an
    ellipse matching the box's aspect ratio (so `radius` reaches every
    edge, not just the shorter side — Flutter's default behavior), an
    off-center focal point for organic asymmetry, plus a small (256×256)
    tiled low-opacity grain texture (`assets/textures/paper_grain.png`,
    generated locally, seamless by construction via wrap-mode blur) —
    without the grain, the smooth gradient visibly bands at this size,
    which is exactly the "looks like a synthetic UI gradient" failure
    mode the brief called out. Deliberately built from a `BoxDecoration`
    gradient + one tiled `Image`, not a `CustomPainter`/shader — both are
    cheap, GPU-composited, laid out once per size change, not recomputed
    per frame, so scrolling stays smooth.
  - Wrapped the *entire* scrollable content once — masthead through the
    front page through the "End of this edition" footer in
    `EditionReaderPage`, and the full body in `ArticleReaderPage` — not
    per-section, so the aging reads as one continuous physical sheet
    while scrolling rather than restarting per card. (Turned out
    `story_blocks.dart` never used `Card`/filled containers per story in
    the first place — `BriefsSection`'s bordered sidebar was already
    whitespace/rule-based, not a Material card — so no separate card
    refactor was needed there.)
  - Verified two ways: a Python replica of the same elliptical-distance
    math for fast visual iteration on the stop/opacity values before
    writing any Dart, then an actual `RenderRepaintBoundary.toImage()`
    capture from a real widget test (temporary, deleted after) to confirm
    the real Skia rendering matched — both matched the brief's reference
    closely. Tests kept: `aged_paper_surface_test.dart` (GazetteColors'
    dark/sport flat-equivalence and light's center-lightest-to-corner-darkest
    ordering, plus a render-without-exception smoke test per theme).
  - Also reused for the masthead nameplate's Blackletter font
    (`UnifrakturCook`, Phase 9) — no change there, just confirming it
    still renders correctly on the new background.

`flutter analyze`: clean (same 14 pre-existing info/warnings, nothing new).
`flutter test`: 235 passed, 0 failed.

## Phase 13 — mentions were still showing raw npub (this session)

Reader reported the Phase 12 mention-resolution fix didn't actually work —
mentions still rendered as npub. It did work for well-formed input; the
regex behind it had a real bug that made it silently fail on realistic
content.

- [x] **Root cause**: `_mentionPattern`'s npub branch was
      `npub1[bech32 charset]{20,}` — open-ended, no upper bound. An npub
      always encodes a fixed 32-byte pubkey, so it's *exactly* 58 bech32
      characters after `npub1`, never a range. If a mention was
      immediately followed by more bech32-alphabet text with no
      separating space or punctuation (e.g. `nostr:npub1...says hi` — every
      letter in "says" is itself a valid bech32 character), the greedy
      `{20,}` swallowed those extra characters into the same match. That
      broke the bech32 checksum, `Nip19.decode` returned `""`, and
      `resolveMentions`' failure branch returned the original matched text
      *unchanged* — leaving the raw npub on screen, silently.
- [x] Fixed the pattern to `npub1[charset]{58}` (exact, not open-ended) —
      matches only a real npub's length regardless of what follows.
      `nprofile` has no fixed length (it can embed relay hints via TLV) so
      it keeps a range, but now bounded (`{20,300}`) rather than unbounded.
- [x] Defense in depth: `resolveMentions` no longer returns the raw
      matched text on a decode failure at all — it falls back to the same
      `@user` placeholder used for "couldn't resolve to a name", so even a
      mention-shaped string that fails to decode for some *other* reason
      never leaks bech32 text into the rendered note.
- [x] Verified the actual failure mode wasn't hypothetical: confirmed via
      `dart:ndk`'s own `Nip19.encodePubKey` that a real npub is always
      exactly 63 characters total (58 after `npub1`), and added a
      regression test reproducing the no-space-before-following-text case
      that the old pattern mishandled, plus a second test that corrupts a
      valid npub's checksum character directly (still matches the
      pattern, still must never leak `npub1...` even when `Nip19.decode`
      itself throws). Both fail against the pre-fix pattern/logic, pass
      after. Tests: `nostr_mappers_test.dart`.

Also noted for context, not touched: `edition_reader_page.dart`,
`article_reader_page.dart`, `aged_paper_surface.dart`, and
`edition_reader_page_test.dart` changed on disk since Phase 12 (system
bars, `extendBodyBehindAppBar`, and `AgedPaperSurface` now sized to the
viewport rather than the full scroll content) — from a separate session
the reader ran directly. Left as-is per instructions; this phase only
touched the mention-resolution bug in the data layer, unrelated to that
visual work.

`flutter analyze`: clean (same 14 pre-existing info/warnings, nothing new).
`flutter test`: 238 passed, 0 failed.

## Phase 14 — articles vs. Off the Wire split by content type (this session)

Reader's read: too few full "articles", too many items landing in "Off
the Wire". Requested rule: a post carrying an image goes to Off the Wire
(and the image must actually render there, not just leave its link in the
text) — a written note becomes an article (hero/secondary).

- [x] `_frontPage()` (`edition_reader_page.dart`) previously split
      hero/secondary/brief purely by *position*: the primary section's
      first three stories, full stop — content type never factored in.
      Rewrote it to flatten every section's stories (preserving their
      existing rank order), partition into "written" (`imageUrls.isEmpty`)
      vs. everything else, and only draw hero/secondary from the written
      set; the brief column is now every image post plus whatever written
      stories didn't make the top three — regardless of which section they
      originally came from, so an edition with few written notes at the
      very top of "Top Stories" but plenty further down (or in "From Your
      Network") still gets a real hero instead of one forced from a
      three-item positional window.
  - Exception: a NIP-23 long-form article keeps its cover image and still
      counts as "written" — the image tag is decoration on substantial
      text content, not the point of the post the way it is for a plain
      photo note. Checked via `Story.isLongFormArticle`.
  - `heroKicker` now looks up whichever section the actual hero came from
      (previously hardcoded to the primary section's title, which broke
      once the hero could come from anywhere). `briefTitle` is now always
      "Off the Wire" rather than borrowing the second section's name,
      since the column is no longer "whatever's in section two" — it's a
      content-type bucket by definition now.
- [x] `_BriefItem` (`story_blocks.dart`) never rendered `story.imageUrls`
      at all — an image post landing there showed only text, with the
      image effectively invisible. Added a thumbnail (`_StoryImage`, same
      widget `HeroStoryBlock`/`StoryBlock` already use) above the headline
      when present.
- [x] Test: new case in `edition_reader_page_test.dart` — an image post
      with deliberately *higher* engagement than a written note still
      lands in `BriefsSection`, not `HeroStoryBlock`, proving the split is
      driven by content type rather than just re-sorting by score.

Also noted for context, not touched: same set of files changed outside
this session (Phase 13's note) continues to apply — this phase's edits to
`edition_reader_page.dart`/`story_blocks.dart` are additive to that prior
external work, not a reversion of it.

`flutter analyze`: clean (same 14 pre-existing info/warnings, nothing new).
`flutter test`: 239 passed, 0 failed.

## Phase 15 — 70% article floor (this session)

Phase 14's content-type split (written → article, image → Off the Wire)
wasn't enough on its own: the article slot was still capped at hero + 2
secondary regardless of edition size, so anything past 3 stories fell to
Off the Wire no matter what — the inverse of what was asked. Reader's
requirement: at least 70% of an edition's stories should read as
articles; at most 30% as Off the Wire.

- [x] Removed the `secondary.take(2)` cap entirely — `_frontPage()` now
      computes `minArticles = (allStories.length * 0.7).ceil()` and
      builds the article set as: every written story, then — *only if*
      that alone falls short of `minArticles` — the highest-ranked image
      posts, one at a time, until the floor is met. Written content is
      never capped or demoted just to make room; the floor is a minimum,
      not a target, so an edition that's mostly written stays 100%
      articles.
  - Hero/secondary are now derived by re-filtering the original,
    already-rank-ordered story list down to the promoted set (rather than
    concatenating the written and promoted-image lists separately), so
    the hero is genuinely the single best-ranked article — not just the
    best-ranked *written* one — once image posts are in the mix.
  - `_MobileFrontPage`/`_TabletFrontPage`/`_WideFrontPage` needed no
    changes — they already rendered `layout.secondary` as an unbounded
    `for` loop of `StoryBlock`s, not a fixed 2-slot layout.
- [x] Tests: replaced the prior Phase 14 test (which assumed the old
      always-demote-images rule, now superseded) with two cases in
      `edition_reader_page_test.dart` — 4 written + 1 image (written alone
      already clears 70%, image stays put despite outranking everything)
      and 2 written + 8 image (written alone is only 20%, so the 5
      highest-ranked image posts get promoted to reach the 7-of-10 floor,
      leaving exactly the 3 lowest-ranked in Off the Wire).

`flutter analyze`: clean (same 14 pre-existing info/warnings, nothing new).
`flutter test`: 240 passed, 0 failed.

## Phase 16 — home screen polish, launcher name, and the "nowhere to go" clip (this session)

- [x] **Home screen "too bland"**: `EditionArchivePage`'s title now renders
      in UnifrakturCook (the masthead's Blackletter face) instead of plain
      Material AppBar text, and the whole screen picked up
      `AgedPaperSurface` + the transparent-system-bars treatment
      `edition_reader_page.dart`/`article_reader_page.dart` already use —
      the home screen now reads as part of the same newspaper rather than
      a generic list screen bolted onto it.
- [x] **Android launcher name showed "relay_gazette"** instead of "The
      Relay Gazette" — `android:label` in `AndroidManifest.xml` was never
      updated from the Flutter project's default. Fixed.
- [x] **Long notes were clipped with no way to finish reading them**
      ("che senso ha? devono esserci i trafiletti esattamente come un
      quotidiano" — real papers say "continued on page 12", they don't
      just cut a story off). Root cause: the "Continue reading" link
      (`_ReadFullArticleLink`, renamed `_ContinueReadingLink`) only ever
      appeared for NIP-23 long-form articles (`if
      (story.isLongFormArticle)`) — a plain long note clipped to 4 lines
      in `StoryBlock`/`_BriefItem` had no link at all, just an ellipsis
      and nothing to click. This got much more visible after Phase 15
      uncapped `secondary`, since far more stories now render through
      `StoryBlock` than before. Fixed by gating the link on "is there a
      body being clipped" (`headline.body != null`) instead of "is this a
      long-form article" — `HeroStoryBlock` is unaffected (its body
      already renders in full via `DropCapText`, so a link there would
      have nowhere further to send the reader, except for a long-form
      article, whose hero body is only its summary — that case keeps the
      link).
  - `ArticleReaderPage` had a matching, previously-masked bug: its title
    was `article.title ?? article.content` — fine for a long-form article
    (which has a `title` tag), but for anything else this rendered the
    *entire* raw note as one giant headline, since a plain `Story` has no
    `title`. Made `_headlineFor` in `story_blocks.dart` public
    (`headlineFor`) and reused it for the reader page's title, so a
    clicked-through plain note gets a proper short headline instead.
  - Tests: `article_reader_page_test.dart` (new) — a plain note's title
    is the extracted headline, not the full dumped content, and its full
    body is reachable on the reader page.

`flutter analyze`: clean (same 14 pre-existing info/warnings, nothing new).
`flutter test`: 242 passed, 0 failed.
