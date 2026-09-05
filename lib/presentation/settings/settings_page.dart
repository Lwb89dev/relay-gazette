import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/nostr/relay_defaults.dart';
import '../../domain/entities/reading_preferences.dart';
import '../relays/relay_providers.dart';
import '../signing/signing_providers.dart';
import '../theme/gazette_colors.dart';
import '../theme/theme_providers.dart';
import '../wallet/wallet_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                _SectionLabel('Appearance'),
                SizedBox(height: 8),
                _ThemeSelector(),
                SizedBox(height: 20),
                _FontSelector(),
                SizedBox(height: 32),
                _SectionLabel('Signer'),
                SizedBox(height: 8),
                _SignerSection(),
                SizedBox(height: 32),
                _SectionLabel('Wallet'),
                SizedBox(height: 8),
                _WalletSection(),
                SizedBox(height: 32),
                _SectionLabel('Relays'),
                SizedBox(height: 8),
                _RelaysSection(),
                SizedBox(height: 32),
                _SectionLabel('Support'),
                SizedBox(height: 8),
                _DonationTile(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  static const _options = [
    (ThemePreference.system, 'Follow system'),
    (ThemePreference.light, 'Light — warm paper'),
    (ThemePreference.dark, 'Dark'),
    (ThemePreference.sport, 'Sport — pink pages'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(themePreferenceProvider).value ?? ThemePreference.system;
    return RadioGroup<ThemePreference>(
      groupValue: current,
      onChanged: (choice) {
        if (choice != null)
          ref.read(themePreferenceProvider.notifier).setPreference(choice);
      },
      child: Column(
        children: [
          for (final (value, label) in _options)
            RadioListTile<ThemePreference>(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value: value,
            ),
        ],
      ),
    );
  }
}

class _FontSelector extends ConsumerWidget {
  const _FontSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(bodyFontPreferenceProvider).value ?? BodyFontPreference.serif;
    return RadioGroup<BodyFontPreference>(
      groupValue: current,
      onChanged: (choice) {
        if (choice != null)
          ref.read(bodyFontPreferenceProvider.notifier).setPreference(choice);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionLabel('Body text'),
          SizedBox(height: 8),
          RadioListTile<BodyFontPreference>(
            contentPadding: EdgeInsets.zero,
            title: Text('Serif — editorial (default)'),
            value: BodyFontPreference.serif,
          ),
          RadioListTile<BodyFontPreference>(
            contentPadding: EdgeInsets.zero,
            title: Text('Sans-serif — plainer reading'),
            value: BodyFontPreference.sansSerif,
          ),
        ],
      ),
    );
  }
}

class _SignerSection extends ConsumerWidget {
  const _SignerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signer = ref.watch(signerConnectionProvider);
    final colors = context.gazetteColors;

    if (signer.isConnected) {
      final author = ref.watch(connectedSignerAuthorProvider).value;
      final label =
          author?.label ?? '${signer.connectedPubkey?.hex.substring(0, 12)}…';
      return Row(
        children: [
          Expanded(
            child: Text(
              'Connected — $label',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(signerConnectionProvider.notifier).disconnect(),
            child: const Text('Disconnect'),
          ),
        ],
      );
    }

    final amberAvailable = ref.watch(isAmberAvailableProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No signer connected — reading still works, but sending hearts needs one.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.inkFaded),
        ),
        const SizedBox(height: 12),
        amberAvailable.maybeWhen(
          data: (available) => available
              ? OutlinedButton(
                  onPressed: () => ref
                      .read(signerConnectionProvider.notifier)
                      .connectWithAmber(),
                  child: const Text('Connect with Amber'),
                )
              : const SizedBox.shrink(),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        const _BunkerConnectField(),
      ],
    );
  }
}

class _BunkerConnectField extends ConsumerStatefulWidget {
  const _BunkerConnectField();

  @override
  ConsumerState<_BunkerConnectField> createState() =>
      _BunkerConnectFieldState();
}

class _BunkerConnectFieldState extends ConsumerState<_BunkerConnectField> {
  final _controller = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    final pubkey = await ref
        .read(signerConnectionProvider.notifier)
        .connectWithBunker(_controller.text.trim());
    if (!mounted) return;
    setState(() {
      _connecting = false;
      if (pubkey == null)
        _error = 'Could not connect — check the bunker:// URI and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'bunker://…',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _connecting ? null : _connect,
          child: _connecting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect with a bunker (NIP-46)'),
        ),
      ],
    );
  }
}

class _WalletSection extends ConsumerWidget {
  const _WalletSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(walletConnectedProvider);
    final colors = context.gazetteColors;

    if (connected) {
      return Row(
        children: [
          const Expanded(
            child: Text(
              'Wallet connected — zaps pay directly, no external app.',
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(walletConnectedProvider.notifier).disconnect(),
            child: const Text('Disconnect'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Optional — without this, zaps hand off to an external Lightning '
          'wallet app instead of paying directly.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.inkFaded),
        ),
        const SizedBox(height: 12),
        const _NwcConnectField(),
      ],
    );
  }
}

class _NwcConnectField extends ConsumerStatefulWidget {
  const _NwcConnectField();

  @override
  ConsumerState<_NwcConnectField> createState() => _NwcConnectFieldState();
}

class _NwcConnectFieldState extends ConsumerState<_NwcConnectField> {
  final _controller = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    final ok = await ref
        .read(walletConnectedProvider.notifier)
        .connect(_controller.text.trim());
    if (!mounted) return;
    setState(() {
      _connecting = false;
      if (!ok)
        _error =
            'Could not connect — check the connection string and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'nostr+walletconnect://…',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _connecting ? null : _connect,
          child: _connecting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect wallet'),
        ),
      ],
    );
  }
}

class _RelaysSection extends ConsumerWidget {
  const _RelaysSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.gazetteColors;
    final custom = ref.watch(relayListProvider).value ?? const [];
    final connected = ref.watch(connectedRelaysProvider).value ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The Relay Gazette always reads from a built-in default set. Add '
          'relays here to pull from more of the network — your own, or ones '
          'closer to accounts you follow.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.inkFaded),
        ),
        const SizedBox(height: 12),
        Text('Default', style: Theme.of(context).textTheme.labelMedium),
        for (final url in kDefaultBootstrapRelays)
          _RelayRow(url: url, connected: connected.contains(url)),
        if (custom.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Added by you', style: Theme.of(context).textTheme.labelMedium),
          for (final url in custom)
            _RelayRow(
              url: url,
              connected: connected.contains(url),
              onRemove: () =>
                  ref.read(relayListProvider.notifier).removeRelay(url),
            ),
        ],
        const SizedBox(height: 12),
        const _AddRelayField(),
      ],
    );
  }
}

class _RelayRow extends StatelessWidget {
  final String url;
  final bool connected;
  final VoidCallback? onRemove;

  const _RelayRow({required this.url, required this.connected, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = context.gazetteColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            connected ? Icons.circle : Icons.circle_outlined,
            size: 10,
            color: connected ? Colors.green : colors.inkFaded,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(url, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _AddRelayField extends ConsumerStatefulWidget {
  const _AddRelayField();

  @override
  ConsumerState<_AddRelayField> createState() => _AddRelayFieldState();
}

class _DonationTile extends StatelessWidget {
  static const _lnAddress = 'lwb89@blink.sv';
  const _DonationTile();

  Future<void> _tap(BuildContext context) async {
    // Try to hand off to a Lightning wallet directly; fall back to
    // clipboard, same as Roadstr's identical tile.
    final uri = Uri.parse('lightning:$_lnAddress');
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (launched) return;

    await Clipboard.setData(const ClipboardData(text: _lnAddress));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚡ $_lnAddress copied to clipboard'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gazetteColors;
    return InkWell(
      onTap: () => _tap(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: colors.rule),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, color: colors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support The Relay Gazette',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _lnAddress,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colors.inkFaded),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: colors.accent),
          ],
        ),
      ),
    );
  }
}

class _AddRelayFieldState extends ConsumerState<_AddRelayField> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final error = await ref
        .read(relayListProvider.notifier)
        .addRelay(_controller.text);
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'wss://relay.example.com',
            errorText: _error,
          ),
          onSubmitted: (_) => _add(),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _add, child: const Text('Add relay')),
      ],
    );
  }
}
