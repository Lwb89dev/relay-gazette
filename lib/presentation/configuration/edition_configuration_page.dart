import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/edition_source.dart';
import '../../domain/entities/engagement.dart';
import '../../domain/entities/filter_configuration.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../../domain/entities/time_window.dart';
import '../common/state_views.dart';
import '../edition/edition_providers.dart';
import '../edition/edition_reader_page.dart';
import '../theme/gazette_colors.dart';

class EditionConfigurationPage extends ConsumerStatefulWidget {
  final NostrPublicKey viewer;

  const EditionConfigurationPage({super.key, required this.viewer});

  @override
  ConsumerState<EditionConfigurationPage> createState() =>
      _EditionConfigurationPageState();
}

class _EditionConfigurationPageState
    extends ConsumerState<EditionConfigurationPage> {
  EditionSource _source = EditionSource.personalNetwork;
  String? _selectedListId;
  EditionTimeWindow _window = EditionTimeWindow.twentyFourHours;
  final _minReactions = TextEditingController();
  final _minReplies = TextEditingController();
  final _minReposts = TextEditingController();

  @override
  void dispose() {
    _minReactions.dispose();
    _minReplies.dispose();
    _minReposts.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController c) =>
      c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());

  Future<void> _generate() async {
    final controller = ref.read(editionGenerationControllerProvider.notifier);
    await controller.generate(
      viewer: widget.viewer,
      configuration: FilterConfiguration(
        source: _source,
        timeWindow: _window,
        customListId: _source == EditionSource.customList ? _selectedListId : null,
        thresholds: EngagementThresholds(
          minReactions: _parse(_minReactions),
          minReplies: _parse(_minReplies),
          minReposts: _parse(_minReposts),
        ),
      ),
    );

    final result = ref.read(editionGenerationControllerProvider);
    if (!mounted) return;
    result.whenOrNull(
      data: (edition) {
        if (edition == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditionReaderPage(edition: edition),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final generation = ref.watch(editionGenerationControllerProvider);
    final isGenerating = generation.isLoading;
    final missingListSelection = _source == EditionSource.customList && _selectedListId == null;

    final colors = context.gazetteColors;

    return Scaffold(
      appBar: AppBar(title: const Text('New Edition')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Source', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                _SourceSelector(
                  selected: _source,
                  onChanged: (source) => setState(() => _source = source),
                ),
                if (_source == EditionSource.customList) ...[
                  const SizedBox(height: 12),
                  _ListSelector(
                    viewer: widget.viewer,
                    selectedListId: _selectedListId,
                    onChanged: (listId) => setState(() => _selectedListId = listId),
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'Time window',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in EditionTimeWindow.presets)
                      ChoiceChip(
                        label: Text(preset.label),
                        selected: _window == preset,
                        onSelected: (_) => setState(() => _window = preset),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Minimum engagement (optional)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Leave blank for no minimum.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.inkFaded),
                ),
                const SizedBox(height: 12),
                _ThresholdField(label: 'Reactions', controller: _minReactions),
                const SizedBox(height: 12),
                _ThresholdField(label: 'Replies', controller: _minReplies),
                const SizedBox(height: 12),
                _ThresholdField(label: 'Reposts', controller: _minReposts),
                const SizedBox(height: 36),
                if (generation.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      describeGazetteError(generation.error!),
                      style: TextStyle(color: colors.accent),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (isGenerating || missingListSelection) ? null : _generate,
                    child: isGenerating
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.paper,
                            ),
                          )
                        : const Text('Generate Edition'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceSelector extends StatelessWidget {
  final EditionSource selected;
  final ValueChanged<EditionSource> onChanged;

  const _SourceSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Your Network'),
          selected: selected == EditionSource.personalNetwork,
          onSelected: (_) => onChanged(EditionSource.personalNetwork),
        ),
        ChoiceChip(
          label: const Text('Trending'),
          selected: selected == EditionSource.trending,
          onSelected: (_) => onChanged(EditionSource.trending),
        ),
        ChoiceChip(
          label: const Text('Web of Trust'),
          selected: selected == EditionSource.webOfTrust,
          onSelected: (_) => onChanged(EditionSource.webOfTrust),
        ),
        ChoiceChip(
          label: const Text('From a List'),
          selected: selected == EditionSource.customList,
          onSelected: (_) => onChanged(EditionSource.customList),
        ),
      ],
    );
  }
}

class _ListSelector extends ConsumerWidget {
  final NostrPublicKey viewer;
  final String? selectedListId;
  final ValueChanged<String?> onChanged;

  const _ListSelector({required this.viewer, required this.selectedListId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(userListsProvider(viewer));
    final colors = context.gazetteColors;

    return lists.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => Text(
        'Couldn\'t load your lists.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.accent),
      ),
      data: (userLists) {
        if (userLists.isEmpty) {
          return Text(
            'You don\'t have any NIP-51 lists yet — create one in another '
            'Nostr client, then come back here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.inkFaded),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: selectedListId,
          decoration: const InputDecoration(labelText: 'Which list?'),
          items: [
            for (final list in userLists)
              DropdownMenuItem(value: list.id, child: Text('${list.title} (${list.members.length})')),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _ThresholdField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _ThresholdField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: 'At least N $label'),
    );
  }
}
