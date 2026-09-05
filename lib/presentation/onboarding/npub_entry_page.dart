import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/nostr_public_key.dart';
import '../archive/edition_archive_page.dart';
import '../providers.dart';
import '../signing/signing_providers.dart';
import '../theme/gazette_colors.dart';

class NpubEntryPage extends ConsumerStatefulWidget {
  const NpubEntryPage({super.key});

  @override
  ConsumerState<NpubEntryPage> createState() => _NpubEntryPageState();
}

class _NpubEntryPageState extends ConsumerState<NpubEntryPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;
  bool _connectingAmber = false;
  bool _connectingBunker = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding(NostrPublicKey pubkey) async {
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings.setSavedPubkey(pubkey);
    ref.invalidate(savedPubkeyProvider);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EditionArchivePage()),
    );
  }

  /// Accepts either an npub or a NIP-05 identifier ("name@domain.com", or
  /// a bare domain for its root identifier).
  Future<void> _continueWithIdentifier() async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final input = _controller.text.trim();
    final parse = ref.read(parseUserIdentityProvider);

    NostrPublicKey? pubkey;
    try {
      pubkey = parse(input);
    } on InvalidPublicKeyException {
      // Not an npub/hex key — try it as a NIP-05 identifier instead, but
      // only when it actually looks like one ("name@domain" or a bare
      // domain): no point making a network request for obvious garbage.
      final looksLikeNip05 = input.contains('@') || input.contains('.');
      pubkey = looksLikeNip05 ? await ref.read(nip05ResolverProvider).resolve(input) : null;
    }

    if (pubkey == null) {
      setState(() {
        _error = 'That doesn\'t look like a valid npub or NIP-05 identifier.';
        _submitting = false;
      });
      return;
    }

    await _finishOnboarding(pubkey);
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _connectWithAmber() async {
    setState(() => _connectingAmber = true);
    final pubkey = await ref.read(signerConnectionProvider.notifier).connectWithAmber();
    if (!mounted) return;

    if (pubkey == null) {
      setState(() {
        _connectingAmber = false;
        _error = 'Amber didn\'t return a key — connection was cancelled or declined.';
      });
      return;
    }

    await _finishOnboarding(pubkey);
    if (mounted) setState(() => _connectingAmber = false);
  }

  Future<void> _connectWithBunker() async {
    final uri = await showDialog<String>(context: context, builder: (_) => const _BunkerUriDialog());
    if (uri == null || uri.trim().isEmpty) return;

    setState(() => _connectingBunker = true);
    final pubkey = await ref.read(signerConnectionProvider.notifier).connectWithBunker(uri.trim());
    if (!mounted) return;

    if (pubkey == null) {
      setState(() {
        _connectingBunker = false;
        _error = 'Could not connect — check the bunker:// URI and try again.';
      });
      return;
    }

    await _finishOnboarding(pubkey);
    if (mounted) setState(() => _connectingBunker = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    final amberAvailable = ref.watch(isAmberAvailableProvider);
    final anyConnecting = _submitting || _connectingAmber || _connectingBunker;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'The Relay Gazette',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 32),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nostr produces the stream.\nThe Relay Gazette produces the edition.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.inkFaded,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _HowItWorks(),
                  const SizedBox(height: 32),
                  Divider(color: colors.rule),
                  const SizedBox(height: 24),
                  Text('Read with your npub or NIP-05', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Public identity only — this unlocks reading. No account, no password.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.inkFaded),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(labelText: 'npub… or name@domain.com', errorText: _error),
                    onSubmitted: (_) => _continueWithIdentifier(),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: anyConnecting ? null : _continueWithIdentifier,
                    child: _submitting ? const _ButtonSpinner() : const Text('Continue'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.rule)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or')),
                      Expanded(child: Divider(color: colors.rule)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sign in with a signer to also react, reply, repost, highlight, and zap.',
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  amberAvailable.maybeWhen(
                    data: (available) => available
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton.icon(
                              onPressed: anyConnecting ? null : _connectWithAmber,
                              icon: _connectingAmber
                                  ? _ButtonSpinner(color: colors.ink)
                                  : const Icon(Icons.key_outlined, size: 18),
                              label: const Text('Connect with Amber'),
                            ),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  OutlinedButton.icon(
                    onPressed: anyConnecting ? null : _connectWithBunker,
                    icon: _connectingBunker
                        ? _ButtonSpinner(color: colors.ink)
                        : const Icon(Icons.vpn_key_outlined, size: 18),
                    label: const Text('Connect with a bunker (NIP-46)'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Reading never requires your private key. The Relay Gazette will never '
                    'ask for, or store, your nsec — on this screen or any other. A signer '
                    '(Amber or a bunker) holds your key and signs on your behalf instead.',
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BunkerUriDialog extends StatefulWidget {
  const _BunkerUriDialog();

  @override
  State<_BunkerUriDialog> createState() => _BunkerUriDialogState();
}

class _BunkerUriDialogState extends State<_BunkerUriDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect with a bunker'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'bunker://…'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Connect'),
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  final Color? color;
  const _ButtonSpinner({this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color ?? context.gazetteColors.paper),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (Icons.person_outline, 'Enter your npub', 'Read-only — no key ever leaves your device.'),
    (Icons.tune, 'Choose what counts', 'A time window, and optional minimum engagement.'),
    (Icons.auto_stories_outlined, 'Get an edition', 'A finite, once-generated snapshot, not a feed.'),
    (Icons.check_circle_outline, 'Finish it, close it', 'Read offline, then you\'re caught up.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    return Column(
      children: [
        for (final (icon, title, subtitle) in _steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.labelLarge),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: colors.inkFaded, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
