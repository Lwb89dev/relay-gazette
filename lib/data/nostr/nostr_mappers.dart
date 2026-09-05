import 'dart:collection';
import 'dart:convert';

import 'package:ndk/ndk.dart';

import '../../domain/entities/author.dart';
import '../../domain/entities/engagement.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../../domain/entities/story.dart';
import 'ndk_public_key_codec.dart';

const _codec = NdkPublicKeyCodec();

final RegExp _imageUrlPattern = RegExp(
  r'https?://\S+\.(?:png|jpe?g|gif|webp|avif|bmp|tiff?|heic|heif|jxl|svg)',
  caseSensitive: false,
);

final RegExp _urlPattern = RegExp(r'https?://\S+', caseSensitive: false);

/// URLs in prose and Markdown often end immediately before `)`, a quote, or
/// sentence punctuation. Those characters are not part of the URL and would
/// otherwise make a NIP-92 `url` field fail its exact content match.
String _trimUrlPunctuation(String url) =>
    url.replaceFirst(RegExp(r'[)\]}>.,!;:]+$'), '');

List<String> _urlsInContent(String content) => _urlPattern
    .allMatches(content)
    .map((match) => _trimUrlPunctuation(match.group(0)!))
    .where((url) => url.isNotEmpty)
    .toList();

/// Finds images carried by NIP-92 `imeta` tags, then adds the older
/// extension-based URLs as a compatibility fallback. An imeta URL is only
/// trusted as media when it appears in the event content too: NIP-92 says a
/// client may ignore a tag that does not match content, and doing so avoids
/// rendering an unrelated URL a poster merely tucked into metadata.
///
/// `m image/...` is the authoritative signal here. It handles modern media
/// URLs without a `.jpg`/`.png` suffix (CDNs commonly serve those), where the
/// historical regex could never classify the post as an image post.
List<String> _imageUrlsFromContent(
  String content,
  List<List<String>> tags, {
  Iterable<String> additionalImages = const [],
}) {
  final urlsInContent = _urlsInContent(content).toSet();
  final imageUrls = LinkedHashSet<String>.from(additionalImages);

  for (final tag in tags) {
    if (tag.isEmpty || tag.first != 'imeta') continue;

    String? url;
    String? mimeType;
    for (final field in tag.skip(1)) {
      final firstSpace = field.indexOf(' ');
      if (firstSpace <= 0 || firstSpace == field.length - 1) continue;
      final key = field.substring(0, firstSpace);
      final value = field.substring(firstSpace + 1);
      if (key == 'url') url = value;
      if (key == 'm') mimeType = value;
    }

    if (url != null &&
        mimeType != null &&
        mimeType.toLowerCase().startsWith('image/') &&
        urlsInContent.contains(url)) {
      imageUrls.add(url);
    }
  }

  // Some older clients publish only a naked image URL, so retain the
  // extension heuristic as a fallback rather than making old editions lose
  // their media when NIP-92 is introduced.
  for (final url in urlsInContent) {
    if (_imageUrlPattern.hasMatch(url)) imageUrls.add(url);
  }
  return imageUrls.toList();
}

// npub always encodes a fixed 32-byte pubkey, so it's *exactly* 58 bech32
// characters after "npub1" (52 five-bit data groups + a 6-character
// checksum) — never a range. Getting this wrong was a real bug: with an
// open-ended `{20,}`, an npub immediately followed by more bech32-alphabet
// text (no separating space/punctuation) got swallowed into the same
// match, the extra characters broke the bech32 checksum, `Nip19.decode`
// failed, and the raw npub was left on screen — the exact "mentions still
// show as npub" symptom this was supposed to fix. nprofile has no fixed
// length (it can embed relay hints via TLV), so it keeps a bounded range
// instead — generous enough for real-world relay-hint counts, bounded so
// it can't run away the same way.
final RegExp _mentionPattern = RegExp(
  r'(?:nostr:)?(npub1[023456789acdefghjklmnpqrstuvwxyz]{58}|nprofile1[023456789acdefghjklmnpqrstuvwxyz]{20,300})',
);

/// Hex pubkeys of every inline npub/nprofile mention (NIP-27, and the bare
/// npub-in-text convention some clients still use) found in a note's
/// content — collected so a caller can batch-fetch their metadata
/// alongside the note authors', before calling [resolveMentions].
Set<String> mentionedPubkeysIn(String content) {
  final pubkeys = <String>{};
  for (final match in _mentionPattern.allMatches(content)) {
    final hex = Nip19.decode(match.group(1)!);
    if (hex.isNotEmpty) pubkeys.add(hex);
  }
  return pubkeys;
}

/// Replaces every inline npub/nprofile mention with "@DisplayName" (or
/// "@name", or a plain "@user" placeholder if nothing resolved) — the same
/// problem Settings' "Connected — [npub]" had, just inside note content: a
/// 60+ character bech32 string reads as noise, not as "this note mentions
/// someone".
String resolveMentions(String content, Map<String, Metadata> metadataByPubkey) {
  return content.replaceAllMapped(_mentionPattern, (match) {
    final hex = Nip19.decode(match.group(1)!);
    // Even something that merely *looks* like a mention but fails to
    // decode (a truncated/corrupted bech32 string) still gets replaced —
    // never leave a raw npub/nprofile-shaped blob on screen just because
    // it didn't resolve to a name.
    if (hex.isEmpty) return '@user';
    final metadata = metadataByPubkey[hex];
    final displayName = metadata?.displayName?.trim();
    final name = metadata?.name?.trim();
    final label = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (name != null && name.isNotEmpty)
        ? name
        : 'user';
    return '@$label';
  });
}

Author authorFromMetadata(NostrPublicKey pubkey, Metadata? metadata) {
  final npub = _codec.encodeNpub(pubkey);
  if (metadata == null) return Author.unknown(pubkey, npub: npub);
  return Author(
    pubkey: pubkey,
    npub: npub,
    displayName: metadata.displayName,
    name: metadata.name,
    pictureUrl: metadata.picture,
    nip05: metadata.cleanNip05,
    lightningAddress: metadata.lud16,
  );
}

Story storyFromEvent(
  Nip01Event event,
  Author author,
  EngagementCounts engagement, {
  Map<String, Metadata> mentionedAuthors = const {},
}) {
  final content = resolveMentions(event.content, mentionedAuthors);
  final imageUrls = _imageUrlsFromContent(content, event.tags);
  return Story(
    id: event.id,
    kind: event.kind,
    author: author,
    content: content,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      event.createdAt * 1000,
      isUtc: true,
    ),
    engagement: engagement,
    imageUrls: imageUrls,
    links: _urlsInContent(
      content,
    ).where((url) => !imageUrls.contains(url)).toList(),
  );
}

/// Same shape as [storyFromEvent], for a NIP-23 kind:30023 long-form
/// article instead of a kind:1 note: `content` is the article's Markdown
/// body, and [Story.title]/[Story.summary]/[Story.dTag] come from that
/// NIP's standardized tags rather than being inferred from plain text.
Story articleFromEvent(
  Nip01Event event,
  Author author,
  EngagementCounts engagement, {
  Map<String, Metadata> mentionedAuthors = const {},
}) {
  String? tag(String name) {
    for (final t in event.tags) {
      if (t.length >= 2 && t[0] == name) return t[1];
    }
    return null;
  }

  final content = resolveMentions(event.content, mentionedAuthors);
  final coverImages = event.tags
      .where((tag) => tag.length >= 2 && tag[0] == 'image')
      .map((tag) => tag[1]);
  final imageUrls = _imageUrlsFromContent(
    content,
    event.tags,
    additionalImages: coverImages,
  );
  return Story(
    id: event.id,
    kind: event.kind,
    author: author,
    content: content,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      event.createdAt * 1000,
      isUtc: true,
    ),
    engagement: engagement,
    imageUrls: imageUrls,
    title: tag('title'),
    summary: tag('summary'),
    dTag: tag('d'),
  );
}

/// Finds which of our candidate note ids this engagement event (a reaction,
/// repost, or zap receipt) actually refers to, by scanning its `e` tags.
/// Events can carry several `e` tags (thread context); we only care about
/// the one that identifies one of the stories we're scoring.
String? referencedStoryId(Nip01Event event, Set<String> candidateIds) {
  for (final tag in event.tags) {
    if (tag.length >= 2 && tag[0] == 'e' && candidateIds.contains(tag[1])) {
      return tag[1];
    }
  }
  return null;
}

/// True for a kind:1 note that is a reply/comment in a thread rather than a
/// standalone post — per NIP-10, any `e` tag (whichever marker convention
/// the client used: `root`/`reply` markers, or the older positional style)
/// means this note is replying to something. Editions are meant to read
/// like a front page of stories, not a pile of thread replies, so these
/// get filtered out before scoring/sectioning rather than after — which
/// also means an edition's story budget (`kMaxNotesPerEdition`) is spent on
/// candidates that can actually become front-page stories, instead of
/// being used up by reply traffic under one popular note.
///
/// Deliberately not applied to quote-reposts (NIP-18, tagged `q` rather
/// than `e`) — a quote is new standalone commentary, not a thread reply.
bool isReplyNote(Nip01Event event) {
  return event.tags.any((tag) => tag.isNotEmpty && tag[0] == 'e');
}

/// Best-effort sats amount for a NIP-57 zap receipt. The authoritative
/// amount lives in the receipt's bolt11 invoice, but decoding bolt11 is
/// substantial extra complexity for an MVP; instead this reads the amount
/// (millisats) from the embedded zap *request* in the `description` tag,
/// which is what most clients display. Documented simplification — see
/// ARCHITECTURE.md, "Known simplifications".
int zapSatsFromReceipt(Nip01Event zapReceipt) {
  try {
    final description = zapReceipt.tags.firstWhere(
      (tag) => tag.length >= 2 && tag[0] == 'description',
    )[1];
    final zapRequest = jsonDecode(description) as Map<String, dynamic>;
    final tags = (zapRequest['tags'] as List).cast<List<dynamic>>();
    final amountTag = tags.firstWhere(
      (tag) => tag.isNotEmpty && tag[0] == 'amount',
      orElse: () => const [],
    );
    if (amountTag.length < 2) return 0;
    final millisats = int.tryParse(amountTag[1].toString()) ?? 0;
    return millisats ~/ 1000;
  } catch (_) {
    return 0;
  }
}
