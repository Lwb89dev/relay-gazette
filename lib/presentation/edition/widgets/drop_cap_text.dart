import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/gazette_colors.dart';

/// A newspaper-style drop cap on the first letter of [text]. This is an
/// inline oversized first character, not a true multi-line float wrap
/// (Flutter's text layout has no CSS-`float` equivalent without a custom
/// RenderObject) — the enlarged letter takes up one tall first line rather
/// than having 2-3 lines of body text wrap around it. Still a clear,
/// recognizable newspaper cue without that added complexity.
class DropCapText extends StatelessWidget {
  final String text;
  final TextStyle? bodyStyle;

  const DropCapText({super.key, required this.text, this.bodyStyle});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = context.gazetteColors;
    final effectiveBodyStyle = bodyStyle ?? theme.textTheme.bodyLarge;
    final bodyFontSize = effectiveBodyStyle?.fontSize ?? 17;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, 1),
            style: TextStyle(
              fontFamily: AppTheme.headlineFamily,
              fontSize: bodyFontSize * 2.6,
              fontWeight: FontWeight.w700,
              color: colors.accent,
              height: 0.85,
            ),
          ),
          TextSpan(text: text.substring(1), style: effectiveBodyStyle),
        ],
      ),
    );
  }
}
