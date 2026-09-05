# The Relay Gazette

A personal, automatically generated newspaper built from [Nostr](https://nostr.com/).
Instead of an infinite scroll, The Relay Gazette compiles a finite,
newspaper-style **edition** on demand — front page, sections, an "Off the
Wire" brief column — from whichever source you pick each time.

**Status: early / pre-release (v0.1.0).** Core reading, generation, and
signing flows work end-to-end and are covered by an automated test suite,
but this hasn't had real-world usage beyond development yet. Expect rough
edges. See [TASKS.md](TASKS.md) for the detailed, phase-by-phase build log
and [ARCHITECTURE.md](ARCHITECTURE.md) for the implementation.

## What it does

- **Generates an edition** from one of several sources, chosen per
  generation: Web of Trust (what your wider network engaged with),
  Trending (network-wide), From Your Network (your own contact list), or
  a NIP-51 list you curate.
- **Reads offline** — once generated, an edition is a saved snapshot; the
  archive and reader never hit the network again.
- Renders both short notes and long-form articles (NIP-23), with inline
  multi-image carousels and a full-screen image viewer.
- Lets you **heart**, **highlight** (NIP-84), and **zap** a story once
  signed in.
- **Sign in** without ever touching a private key: a bare npub or NIP-05
  identifier for read-only access, or a real signer — [Amber](https://github.com/greenart7c3/Amber)
  or a NIP-46 bunker — for the interactive bits. The app never asks for,
  or stores, an nsec.
- Editorial visual identity (warm-paper theme, serif/sans body font
  choice, dark and "sport" themes), with a masthead and column layout that
  adapts from phone to tablet width.
- A 3-page onboarding flow explains how an edition is built, what you can
  do with a story, and how to sign in, the first time the app runs.

## Building

```
flutter pub get
flutter run
```

Release builds need a signing key: copy `android/key.properties.template`
to `android/key.properties` and fill in your own keystore details (see the
comments in that file for the `keytool` command). Without it, Gradle
produces an unsigned release rather than silently falling back to the
debug key.

```
flutter build apk --release
```

## Development

```
flutter analyze
flutter test
```

Both are expected to be clean/green at every commit.
