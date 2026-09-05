import 'package:flutter/material.dart';

import '../theme/gazette_colors.dart';

/// A calm, wordy placeholder for empty/error states. This app deliberately
/// never shows a raw exception to the reader — see spec "Error states".
class GazetteStateView extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const GazetteStateView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.article_outlined,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.inkFaded),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.inkFaded,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Human-readable text for the errors this app expects to encounter, so
/// callers never have to interpolate an exception's toString() into the UI.
String describeGazetteError(Object error) {
  final message = error.toString();
  if (message.contains('InvalidPublicKeyException')) {
    return 'That doesn\'t look like a valid npub.';
  }
  if (message.contains('SocketException') ||
      message.contains('TimeoutException') ||
      message.contains('WebSocketException')) {
    return 'Couldn\'t reach any relays. Check your connection and try again.';
  }
  return 'Something went wrong generating this edition. Please try again.';
}
