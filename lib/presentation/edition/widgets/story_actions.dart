import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/nostr_public_key.dart';
import '../../../domain/entities/story.dart';
import '../../signing/signing_providers.dart';
import '../../theme/gazette_colors.dart';
import '../../wallet/wallet_providers.dart';

// TODO: restore Reply and Repost actions — this file was rewritten
// elsewhere (a separate, non-assistant session) down to just Heart and
// Zap; NIP-84 Highlight is restored below since it was explicitly
// requested again, but Reply/Repost weren't and are left as a known gap
// rather than reintroduced speculatively.

/// A deliberately small interaction surface: heart a note with a signer,
/// or zap its author. A zap remains available to read-only readers whenever
/// the author publishes a Lightning address.
class StoryActions extends ConsumerWidget {
  final Story story;

  const StoryActions({super.key, required this.story});

  Future<NostrPublicKey?> _ensureConnected(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final signer = ref.read(signerConnectionProvider);
    if (signer.isConnected) return signer.connectedPubkey;

    final amberAvailable = await ref.read(isAmberAvailableProvider.future);
    if (!amberAvailable) {
      if (context.mounted) {
        _showMessage(
          context,
          'Connect a signer (Amber or a bunker) in Settings to interact.',
        );
      }
      return null;
    }

    final pubkey = await ref
        .read(signerConnectionProvider.notifier)
        .connectWithAmber();
    if (pubkey == null && context.mounted) {
      _showMessage(context, 'Connection to your signer was declined.');
    }
    return pubkey;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _react(BuildContext context, WidgetRef ref) async {
    if (await _ensureConnected(context, ref) == null) return;
    final ok = await ref.read(reactToStoryProvider)(story);
    if (context.mounted) {
      _showMessage(context, ok ? 'Reaction sent' : 'Reaction was declined');
    }
  }

  /// NIP-84 (Boris' convention — see the reader's own reference,
  /// github.com/dergigi/boris-android): tags the passage's source note via
  /// `e` (and `a` too for a long-form article, so the highlight survives
  /// the article being edited later) plus the original author, all
  /// already implemented in `CreateHighlight` — this dialog is the one
  /// piece that went missing when this file was rewritten elsewhere.
  Future<void> _highlight(BuildContext context, WidgetRef ref) async {
    if (await _ensureConnected(context, ref) == null) return;
    if (!context.mounted) return;

    final text = await showDialog<String>(
      context: context,
      builder: (_) => _HighlightDialog(initialText: story.content),
    );
    if (text == null || text.trim().isEmpty) return;

    final ok = await ref.read(createHighlightProvider)(story, text);
    if (context.mounted) {
      _showMessage(context, ok ? 'Highlight saved' : 'Highlight was declined');
    }
  }

  Future<void> _zap(BuildContext context, WidgetRef ref) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => const _ZapAmountDialog(),
    );
    if (amount == null) return;

    String? invoice;
    try {
      invoice = await ref
          .read(zapServiceProvider)
          .requestZapInvoice(story: story, amountSats: amount);
    } catch (_) {
      if (context.mounted) {
        _showMessage(
          context,
          'Could not create a zap invoice for this author.',
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (invoice == null) {
      _showMessage(context, 'Could not reach this author\'s Lightning wallet.');
      return;
    }

    // Pay directly through a connected NIP-47 wallet if there is one;
    // otherwise hand the invoice off to an external wallet app.
    final wallet = ref.read(walletConnectionProvider);
    if (wallet.isConnected) {
      final paid = await wallet.payInvoice(invoice);
      if (context.mounted) {
        _showMessage(context, paid ? 'Zap sent' : 'Payment failed');
      }
      return;
    }

    final launched = await launchUrl(
      Uri.parse('lightning:${invoice.trim()}'),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showMessage(
        context,
        'No Lightning wallet app found to handle the payment.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canZap = story.author.lightningAddress != null;
    // Wrap rather than Row: even the Wire News column can keep both actions
    // accessible without overflow.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ActionButton(
          icon: Icons.favorite_border,
          label: 'Heart',
          onTap: () => _react(context, ref),
        ),
        _ActionButton(
          icon: Icons.format_quote_outlined,
          label: 'Highlight',
          onTap: () => _highlight(context, ref),
        ),
        if (canZap)
          _ActionButton(
            icon: Icons.bolt,
            label: 'Zap',
            onTap: () => _zap(context, ref),
            accent: true,
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.gazetteColors;
    final color = accent ? colors.accent : colors.inkFaded;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}

class _ZapAmountDialog extends StatefulWidget {
  const _ZapAmountDialog();

  @override
  State<_ZapAmountDialog> createState() => _ZapAmountDialogState();
}

class _ZapAmountDialogState extends State<_ZapAmountDialog> {
  static const _presets = [21, 100, 500, 1000];
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('⚡ Zap'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sats in _presets)
                ActionChip(
                  label: Text('$sats sats'),
                  onPressed: () => Navigator.of(context).pop(sats),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Custom amount (sats)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = int.tryParse(_customController.text.trim());
            if (amount != null && amount > 0) Navigator.of(context).pop(amount);
          },
          child: const Text('Zap'),
        ),
      ],
    );
  }
}

class _HighlightDialog extends StatefulWidget {
  final String initialText;
  const _HighlightDialog({required this.initialText});

  @override
  State<_HighlightDialog> createState() => _HighlightDialogState();
}

class _HighlightDialogState extends State<_HighlightDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Highlight'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trim this down to just the passage worth keeping.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Highlight'),
        ),
      ],
    );
  }
}
