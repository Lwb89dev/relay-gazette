import 'dart:convert';

import 'package:ndk/ndk.dart';

import '../../domain/entities/engagement.dart';

/// Parses one `EVENT_STATS` event's content into the engagement counts for
/// the note it refers to. Returns null for anything malformed rather than
/// throwing — a single bad stats record shouldn't fail an entire edition.
({String eventId, EngagementCounts counts})? engagementFromEventStats(
  Nip01Event event,
) {
  try {
    final json = jsonDecode(event.content) as Map<String, dynamic>;
    final eventId = json['event_id'] as String?;
    if (eventId == null) return null;
    return (
      eventId: eventId,
      counts: EngagementCounts(
        reactions: (json['likes'] as num?)?.toInt() ?? 0,
        replies: (json['replies'] as num?)?.toInt() ?? 0,
        reposts: (json['reposts'] as num?)?.toInt() ?? 0,
        zapCount: (json['zaps'] as num?)?.toInt() ?? 0,
        zapSats: (json['satszapped'] as num?)?.toInt() ?? 0,
      ),
    );
  } catch (_) {
    return null;
  }
}
