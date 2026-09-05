import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/edition_summary.dart';
import '../../domain/entities/filter_configuration.dart';
import '../../domain/entities/gazette_edition.dart';
import '../../domain/entities/nostr_list.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../providers.dart';

const _uuid = Uuid();

/// The reader's NIP-51 follow sets, for choosing one as an edition's
/// author pool instead of their entire contact list.
final userListsProvider = FutureProvider.family<List<NostrList>, NostrPublicKey>((ref, owner) {
  return ref.watch(feedProviderProvider).fetchLists(owner);
});

/// Newest-first archive listing. Invalidated whenever a new edition is
/// generated or one is deleted, so the shelf stays in sync.
final archiveSummariesProvider = FutureProvider<List<GazetteEditionSummary>>((
  ref,
) async {
  final repository = ref.watch(editionRepositoryProvider);
  return repository.getAllSummaries();
});

/// A single persisted edition, looked up by id (used when opening an
/// archive entry, or the edition just generated).
final editionByIdProvider = FutureProvider.family<GazetteEdition?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(editionRepositoryProvider);
  return repository.getById(id);
});

class EditionGenerationController extends AsyncNotifier<GazetteEdition?> {
  @override
  Future<GazetteEdition?> build() async => null;

  Future<void> generate({
    required NostrPublicKey viewer,
    required FilterConfiguration configuration,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final generateEdition = ref.read(generateEditionProvider);
      final edition = await generateEdition(
        viewer: viewer,
        configuration: configuration,
        generateId: () => _uuid.v4(),
      );
      await ref.read(editionRepositoryProvider).save(edition);
      ref.invalidate(archiveSummariesProvider);
      return edition;
    });
  }

  void reset() => state = const AsyncData(null);
}

final editionGenerationControllerProvider =
    AsyncNotifierProvider<EditionGenerationController, GazetteEdition?>(
      EditionGenerationController.new,
    );
