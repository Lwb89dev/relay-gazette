import 'package:flutter/material.dart';

/// Semantic colors for the editorial UI, resolved per-theme (light/dark)
/// via [ThemeExtension] so widgets never hardcode a color that only makes
/// sense on paper-colored backgrounds. Access via `context.gazetteColors`.
class GazetteColors extends ThemeExtension<GazetteColors> {
  final Color paper;
  final Color paperMuted;
  final Color ink;
  final Color inkFaded;
  final Color rule;
  final Color accent;

  /// The two extra, darker stops in the newspaper page's aged-paper
  /// gradient — [paper]/[paperMuted] are the center/mid tones, these are
  /// the edge and corner tones. For [dark]/[sport], both equal [paper]:
  /// the gradient this feeds (`AgedPaperSurface`) then paints as a flat,
  /// uniform fill — i.e. a no-op — since the aging treatment is specific
  /// to the light theme's reading surface, not every theme.
  final Color paperEdge;
  final Color paperCorner;

  const GazetteColors({
    required this.paper,
    required this.paperMuted,
    required this.ink,
    required this.inkFaded,
    required this.rule,
    required this.accent,
    required this.paperEdge,
    required this.paperCorner,
  });

  /// A cool, lightly aged newsprint — the center is a restrained ivory and
  /// the edges only gently deepen to warm grey, avoiding a yellow parchment
  /// cast while preserving the physical-paper character.
  static const light = GazetteColors(
    paper: Color(0xFFF7F3E7),
    paperMuted: Color(0xFFEEE7D7),
    ink: Color(0xFF1D1A17),
    inkFaded: Color(0xFF655E55),
    rule: Color(0xFFB9AE9F),
    accent: Color(0xFF7B372F),
    paperEdge: Color(0xFFE3D7C1),
    paperCorner: Color(0xFFD6C6AC),
  );

  static const dark = GazetteColors(
    paper: Color(0xFF100E14),
    paperMuted: Color(0xFF17131D),
    ink: Color(0xFFF1ECE7),
    inkFaded: Color(0xFFAAA1AF),
    rule: Color(0xFF38313F),
    accent: Color(0xFFC6A7E8),
    paperEdge: Color(0xFF100E14),
    paperCorner: Color(0xFF100E14),
  );

  /// The salmon-pink "sports pages" look (La Gazzetta dello Sport is the
  /// namesake) — a deliberately different mood from the two paper/ink
  /// options, still with dark-on-light contrast for reading.
  static const sport = GazetteColors(
    paper: Color(0xFFF7CFC1),
    paperMuted: Color(0xFFF0BEAC),
    ink: Color(0xFF241210),
    inkFaded: Color(0xFF6B4A42),
    rule: Color(0xFFD99C87),
    accent: Color(0xFFB5121B),
    paperEdge: Color(0xFFF7CFC1),
    paperCorner: Color(0xFFF7CFC1),
  );

  @override
  GazetteColors copyWith({
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
