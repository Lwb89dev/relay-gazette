import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/nostr_event_draft.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/domain/repositories/event_broadcaster.dart';
import 'package:relay_gazette/domain/repositories/nostr_signer.dart';
import 'package:relay_gazette/presentation/edition/widgets/story_actions.dart';
import 'package:relay_gazette/presentation/providers.dart';
import 'package:relay_gazette/presentation/signing/signing_providers.dart';
import 'package:relay_gazette/presentation/theme/app_theme.dart';

class _FakeConnectedSigner implements NostrSigner {
  final NostrPublicKey pubkey;
  UnsignedNostrEvent? lastRequested;
  _FakeConnectedSigner(this.pubkey);

  @override
  bool get isConnected => true;

  @override
  NostrPublicKey? get connectedPubkey => pubkey;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<NostrPublicKey?> connect() async => pubkey;

  @override
  Future<void> disconnect() async {}

  @override
  Future<SignedNostrEvent?> sign(UnsignedNostrEvent event) async {
    lastRequested = event;
    return SignedNostrEvent(
      id: 'signed-highlight',
      pubkeyHex: pubkey.hex,
      kind: event.kind,
      content: event.content,
      tags: event.tags,
      createdAt: event.createdAt,
      signature: 's' * 128,
    );
  }
}

class _FakeSignerController extends SignerConnectionController {
  final NostrSigner signer;
  _FakeSignerController(this.signer);

  @override
  NostrSigner build() => signer;
}

class _FakeBroadcaster implements EventBroadcaster {
  final List<SignedNostrEvent> broadcasted = [];

  @override
  Future<void> broadcast(SignedNostrEvent event) async {
    broadcasted.add(event);
  }
}

Story _note() {
  final authorPubkey = NostrPublicKey.fromHex('b' * 64);
  return Story(
    id: 'note-1',
    kind: Story.kTextNote,
    author: Author.unknown(authorPubkey, npub: 'npub1author'),
    content: 'the whole note content, to be trimmed down in the dialog',
    createdAt: DateTime.utc(2026, 8, 23),
    engagement: EngagementCounts.zero,
  );
}

void main() {
  testWidgets(
    'tapping Highlight, editing the passage, and confirming publishes a NIP-84 highlight',
    (tester) async {
      final signer = _FakeConnectedSigner(NostrPublicKey.fromHex('d' * 64));
      final broadcaster = _FakeBroadcaster();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            signerConnectionProvider.overrideWith(() => _FakeSignerController(signer)),
            eventBroadcasterProvider.overrideWithValue(broadcaster),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: StoryActions(story: _note())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Highlight'), findsOneWidget);

      await tester.tap(find.text('Highlight'));
      await tester.pumpAndSettle();

      // The dialog opens prefilled with the note's content, editable down
      // to just the passage worth keeping.
      expect(find.text('Trim this down to just the passage worth keeping.'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'the whole note content, to be trimmed down in the dialog'),
          findsOneWidget);

      await tester.enterText(find.byType(TextField), 'just the good part');
      await tester.tap(find.widgetWithText(FilledButton, 'Highlight'));
      await tester.pumpAndSettle();

      expect(signer.lastRequested, isNotNull);
      expect(signer.lastRequested!.kind, 9802);
      expect(signer.lastRequested!.content, 'just the good part');
      expect(broadcaster.broadcasted, hasLength(1));
      expect(find.text('Highlight saved'), findsOneWidget);
    },
  );
}
