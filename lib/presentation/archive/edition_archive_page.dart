import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/edition_summary.dart';
import '../common/state_views.dart';
import '../configuration/edition_configuration_page.dart';
import '../edition/edition_providers.dart';
import '../edition/edition_reader_page.dart';
import '../providers.dart';
import '../settings/settings_page.dart';
import '../theme/aged_paper_surface.dart';
import '../theme/gazette_colors.dart';

class EditionArchivePage extends ConsumerWidget {
  const EditionArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(archiveSummariesProvider);
    final viewer = ref.watch(savedPubkeyProvider);
    final colors = context.gazetteColors;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'The Relay Gazette',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontFamily: 'UnifrakturCook',
            fontWeight: FontWeight.normal,
            fontSize: 26,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: viewer.maybeWhen(
        data: (pubkey) => pubkey == null
            ? null
            : FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('New Edition'),
                backgroundColor: colors.ink,
                foregroundColor: colors.paper,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditionConfigurationPage(viewer: pubkey),
                  ),
                ),
              ),
        orElse: () => null,
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: readingSystemBars(context),
        child: AgedPaperSurface(
          child: SafeArea(
            child: summaries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => GazetteStateView(
                icon: Icons.wifi_off,
                title: 'Couldn\'t load your archive',
                message: describeGazetteError(error),
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(archiveSummariesProvider),
              ),
              data: (list) => list.isEmpty
                  ? GazetteStateView(
                      icon: Icons.newspaper,
                      title: 'No editions yet',
                      message: 'Generate your first edition to start reading.',
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _ArchiveList(summaries: list),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchiveList extends ConsumerStatefulWidget {
  final List<GazetteEditionSummary> summaries;

  const _ArchiveList({required this.summaries});

  @override
  ConsumerState<_ArchiveList> createState() => _ArchiveListState();
}

class _ArchiveListState extends ConsumerState<_ArchiveList> {
  // `Dismissible` requires the dismissed item to be gone from the list by
  // the very next build, but the actual removal (delete from the local
  // database, then re-fetching `archiveSummariesProvider`) is async and
  // takes longer than that — without this, Flutter throws "A dismissed
  // Dismissible widget is still part of the tree" the moment a rebuild
  // happens before that round trip finishes. Hidden immediately here,
  // independent of when the persisted delete actually completes.
  final _dismissedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final summaries = widget.summaries.where((s) => !_dismissedIds.contains(s.id)).toList();
    final grouped = _groupByShelf(summaries);
    final colors = context.gazetteColors;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(0, kToolbarHeight + 12, 0, 96),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped[index];
        if (entry.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              entry.header!,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          );
        }
        final summary = entry.summary!;
        return Dismissible(
          key: ValueKey(summary.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: colors.accent,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Icon(Icons.delete_outline, color: colors.paper),
          ),
          onDismissed: (_) {
            setState(() => _dismissedIds.add(summary.id));
            ref.read(editionRepositoryProvider).delete(summary.id).then((_) {
              ref.invalidate(archiveSummariesProvider);
            });
          },
          child: ListTile(
            title: Text(
              DateFormat('EEEE, MMMM d').format(summary.generatedAt.toLocal()),
            ),
            subtitle: Text(
              '${summary.storyCount} stories · ${summary.source.label}',
            ),
            trailing: Icon(Icons.chevron_right, color: colors.inkFaded),
            onTap: () async {
              final edition = await ref.read(
                editionByIdProvider(summary.id).future,
              );
              if (edition == null || !context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditionReaderPage(edition: edition),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ShelfEntry {
  final String? header;
  final GazetteEditionSummary? summary;
  _ShelfEntry.header(this.header) : summary = null;
  _ShelfEntry.item(this.summary) : header = null;
  bool get isHeader => header != null;
}

List<_ShelfEntry> _groupByShelf(List<GazetteEditionSummary> summaries) {
  final now = DateTime.now();
  String shelfFor(DateTime generatedAt) {
    final local = generatedAt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMMM d').format(local).toUpperCase();
  }

  final entries = <_ShelfEntry>[];
  String? currentShelf;
  for (final summary in summaries) {
    final shelf = shelfFor(summary.generatedAt);
    if (shelf != currentShelf) {
      entries.add(_ShelfEntry.header(shelf));
      currentShelf = shelf;
    }
    entries.add(_ShelfEntry.item(summary));
  }
  return entries;
}
