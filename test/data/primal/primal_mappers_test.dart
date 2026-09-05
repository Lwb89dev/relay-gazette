import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:relay_gazette/data/primal/primal_event_kinds.dart';
import 'package:relay_gazette/data/primal/primal_mappers.dart';

Nip01Event _statsEvent(Map<String, dynamic> content) {
  return Nip01Event(
    id: 'stats-1',
    pubKey: 'p' * 64,
    kind: PrimalEventKinds.eventStats,
    tags: const [],
    content: jsonEncode(content),
  );
}

void main() {
  test('parses a full EVENT_STATS payload', () {
    final result = engagementFromEventStats(_statsEvent({
      'event_id': 'note-1',
      'likes': 12,
      'replies': 3,
      'mentions': 1,
      'reposts': 2,
      'zaps': 4,
      'satszapped': 2100,
      'score': 5.4,
      'score24h': 5.4,
      'bookmarks': 0,
    }));

    expect(result, isNotNull);
    expect(result!.eventId, 'note-1');
    expect(result.counts.reactions, 12);
    expect(result.counts.replies, 3);
    expect(result.counts.reposts, 2);
    expect(result.counts.zapCount, 4);
    expect(result.counts.zapSats, 2100);
  });

  test('missing fields default to zero rather than throwing', () {
    final result = engagementFromEventStats(_statsEvent({'event_id': 'note-2'}));
    expect(result, isNotNull);
    expect(result!.counts.reactions, 0);
    expect(result.counts.zapSats, 0);
  });

  test('returns null when event_id is missing', () {
    expect(engagementFromEventStats(_statsEvent({'likes': 5})), isNull);
  });

  test('returns null for malformed JSON instead of throwing', () {
    final event = Nip01Event(
      id: 'stats-bad',
      pubKey: 'p' * 64,
      kind: PrimalEventKinds.eventStats,
      tags: const [],
      content: 'not json',
    );
    expect(engagementFromEventStats(event), isNull);
  });
}
