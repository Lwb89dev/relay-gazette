/// A note's content split into a headline and (optionally) a body, for
/// front-page-style rendering. Never invents text: a short note becomes a
/// headline with no body; a longer one is split at its first natural
/// break (a newline, or the end of its first sentence) rather than
/// summarized or rewritten.
class StoryHeadline {
  final String headline;
  final String? body;

  const StoryHeadline({required this.headline, this.body});
}

const int _kShortNoteThreshold = 100;
const int _kMaxHeadlineLength = 140;

StoryHeadline extractHeadline(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return const StoryHeadline(headline: '');

  if (trimmed.length <= _kShortNoteThreshold) {
    return StoryHeadline(headline: trimmed);
  }

  final breakIndex = _findBreakPoint(trimmed);
  if (breakIndex == null) {
    // `trimmed.length` is only guaranteed to be > _kShortNoteThreshold
    // (100) here, not >= _kMaxHeadlineLength (140) — a note with no
    // newline or sentence-ending punctuation and a length in that gap
    // (e.g. 139) made this substring(0, 140) throw a RangeError on every
    // render.
    final cutLength = trimmed.length < _kMaxHeadlineLength
        ? trimmed.length
        : _kMaxHeadlineLength;
    final cut = trimmed.substring(0, cutLength).trimRight();
    // The headline takes the first part, while the body supplies only what
    // follows it. That preserves the complete note without duplicating its
    // opening in full-column tablet layouts.
    final rest = trimmed.substring(cutLength).trimLeft();
    return StoryHeadline(headline: '$cut…', body: rest.isEmpty ? null : rest);
  }

  final headline = trimmed.substring(0, breakIndex + 1).trim();
  final rest = trimmed.substring(breakIndex + 1).trim();
  return StoryHeadline(headline: headline, body: rest.isEmpty ? null : rest);
}

/// Index of the last character to include in the headline: either just
/// before the first newline, or the first sentence-ending punctuation mark
/// — whichever comes first within [_kMaxHeadlineLength]. Null if neither
/// exists in range.
int? _findBreakPoint(String text) {
  final limit = text.length < _kMaxHeadlineLength
      ? text.length
      : _kMaxHeadlineLength;
  final newlineIndex = text.indexOf('\n');

  int? sentenceEnd;
  for (var i = 0; i < limit; i++) {
    final char = text[i];
    if (char == '.' || char == '!' || char == '?') {
      final isEndOfText = i == text.length - 1;
      final isFollowedBySpace = !isEndOfText && text[i + 1] == ' ';
      if (isEndOfText || isFollowedBySpace) {
        sentenceEnd = i;
        break;
      }
    }
  }

  final hasNewlineInRange = newlineIndex != -1 && newlineIndex < limit;
  if (hasNewlineInRange &&
      (sentenceEnd == null || newlineIndex < sentenceEnd)) {
    return newlineIndex - 1;
  }
  return sentenceEnd;
}
