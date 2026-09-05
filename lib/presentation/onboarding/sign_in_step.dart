import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/nostr_public_key.dart';
import '../archive/edition_archive_page.dart';
import '../providers.dart';
import '../signing/signing_providers.dart';
import '../theme/gazette_colors.dart';

/// The third onboarding page: read-only via a raw npub/NIP-05 identifier,
/// or sign in with a signer (Amber, or a bunker over NIP-46) to also react,
/// highlight, and zap. No `Scaffold` of its own — embedded as one page of
/// `OnboardingFlow`'s `PageView`, which owns the shared chrome.
class SignInStep extends ConsumerStatefulWidget {
  const SignInStep({super.key});

  @override
  ConsumerState<SignInStep> createState() => _SignInStepState();
}

class _SignInStepState extends ConsumerState<SignInStep> {
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

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sign in',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(fontSize: 30),
                ),
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
