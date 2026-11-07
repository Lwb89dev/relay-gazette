import 'package:flutter/material.dart';

/// The three editorial art directions share the same component system but
/// deliberately do not look like simple recolours of one another.
enum GazetteVisualStyle { antique, nocturne, sport }

/// Semantic colors for the editorial UI, resolved per-theme (light/dark)
/// via [ThemeExtension] so widgets never hardcode a color that only makes
/// sense on paper-colored backgrounds. Access via `context.gazetteColors`.
class GazetteColors extends ThemeExtension<GazetteColors> {
  final GazetteVisualStyle style;
  final Color paper;
  final Color paperMuted;
  final Color ink;
  final Color inkFaded;
  final Color rule;
  final Color accent;

  /// The two outer stops in the newspaper page's printed-stock gradient.
  /// Every art direction has its own treatment: aged edges for antique,
  /// a restrained vignette for nocturne, and subtle pink variation for sport.
  final Color paperEdge;
  final Color paperCorner;

  const GazetteColors({
    required this.style,
    required this.paper,
    required this.paperMuted,
    required this.ink,
    required this.inkFaded,
    required this.rule,
    required this.accent,
    required this.paperEdge,
    required this.paperCorner,
  });

  /// Warm, lightly aged newsprint with oxblood editorial details.
  static const light = GazetteColors(
    style: GazetteVisualStyle.antique,
    paper: Color(0xFFF3E9D2),
    paperMuted: Color(0xFFE6D7B9),
    ink: Color(0xFF251D16),
    inkFaded: Color(0xFF67594B),
    rule: Color(0xFFA88E6D),
    accent: Color(0xFF842E25),
    paperEdge: Color(0xFFDDC9A5),
    paperCorner: Color(0xFFCDB38A),
  );

  static const dark = GazetteColors(
    style: GazetteVisualStyle.nocturne,
    paper: Color(0xFF151513),
    paperMuted: Color(0xFF20201D),
    ink: Color(0xFFF0E9DB),
    inkFaded: Color(0xFFAAA293),
    rule: Color(0xFF4A463E),
    accent: Color(0xFFD1A85C),
    paperEdge: Color(0xFF10100F),
    paperCorner: Color(0xFF0B0B0A),
  );

  /// The salmon-pink "sports pages" look (La Gazzetta dello Sport is the
  /// namesake) — a deliberately different mood from the two paper/ink
  /// options, still with dark-on-light contrast for reading.
  static const sport = GazetteColors(
    style: GazetteVisualStyle.sport,
    paper: Color(0xFFF3BBC5),
    paperMuted: Color(0xFFECA9B5),
    ink: Color(0xFF171315),
    inkFaded: Color(0xFF65484E),
    rule: Color(0xFFBB7180),
    accent: Color(0xFF8C1833),
    paperEdge: Color(0xFFECAAB6),
    paperCorner: Color(0xFFE49AA8),
  );

  @override
  GazetteColors copyWith({
    GazetteVisualStyle? style,
    Color? paper,
    Color? paperMuted,
    Color? ink,
    Color? inkFaded,
    Color? rule,
    Color? accent,
    Color? paperEdge,
    Color? paperCorner,
  }) {
    return GazetteColors(
      style: style ?? this.style,
      paper: paper ?? this.paper,
      paperMuted: paperMuted ?? this.paperMuted,
      ink: ink ?? this.ink,
      inkFaded: inkFaded ?? this.inkFaded,
      rule: rule ?? this.rule,
      accent: accent ?? this.accent,
      paperEdge: paperEdge ?? this.paperEdge,
      paperCorner: paperCorner ?? this.paperCorner,
    );
  }

  @override
  GazetteColors lerp(ThemeExtension<GazetteColors>? other, double t) {
    if (other is! GazetteColors) return this;
    return GazetteColors(
      style: t < 0.5 ? style : other.style,
      paper: Color.lerp(paper, other.paper, t)!,
      paperMuted: Color.lerp(paperMuted, other.paperMuted, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkFaded: Color.lerp(inkFaded, other.inkFaded, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      paperEdge: Color.lerp(paperEdge, other.paperEdge, t)!,
      paperCorner: Color.lerp(paperCorner, other.paperCorner, t)!,
    );
  }
}

extension GazetteThemeX on BuildContext {
  GazetteColors get gazetteColors => Theme.of(this).extension<GazetteColors>()!;
}
