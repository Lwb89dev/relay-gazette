import 'package:flutter/material.dart';

import 'gazette_colors.dart';

/// Stretches a circular gradient into an ellipse matching the paint box's
/// own aspect ratio, so a gradient `radius` reaches every edge (not just
/// the shorter dimension, which is [RadialGradient]'s default behavior) —
/// see [AgedPaperSurface].
class _EllipticalGradientTransform extends GradientTransform {
  const _EllipticalGradientTransform();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final sx = bounds.width / bounds.shortestSide;
    final sy = bounds.height / bounds.shortestSide;
    return Matrix4.identity()
      ..translateByDouble(bounds.center.dx, bounds.center.dy, 0, 1)
      ..scaleByDouble(sx, sy, sx, 1)
      ..translateByDouble(-bounds.center.dx, -bounds.center.dy, 0, 1);
  }
}

/// The newspaper *page* itself, not the app shell around it: a broad,
/// soft radial aging effect — light ivory at the center, gradually more
/// yellowed/ochre toward the edges, a touch stronger right at the corners
/// — plus a very low-opacity tiled grain texture so the transition reads
/// as naturally printed stock rather than a flat digital gradient (a
/// perfectly smooth gradient bands visibly at this size; the grain is
/// what keeps it from looking synthetic, not a stylistic flourish).
///
/// Put the reading route's scroll view *inside* this — once, around the
/// whole page — not around its individual sections or story cards. The
/// surface then has the viewport's dimensions (rather than the potentially
/// enormous height of the scrollable edition), so its ivory centre and
/// aged margins are visible on screen at all times and never restart from
/// story to story. The antique theme has the strongest oxidation, the dark
/// theme a restrained vignette, and the sport theme the flatter pink stock
/// of a sports daily.
///
/// Deliberately built from a single [BoxDecoration] gradient plus one
/// tiled [Image] rather than a [CustomPainter]/shader: both are cheap,
/// GPU-composited draw operations sized once per layout, not recomputed
/// per frame, so scrolling stays smooth.
class AgedPaperSurface extends StatelessWidget {
  final Widget child;

  const AgedPaperSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.gazetteColors;
    final gradientCenter = colors.style == GazetteVisualStyle.nocturne
        ? colors.paperMuted
        : colors.paper;
    final gradientMid = colors.style == GazetteVisualStyle.nocturne
        ? colors.paper
        : colors.paperMuted;
    final grainOpacity = switch (colors.style) {
      GazetteVisualStyle.antique => 1.0,
      GazetteVisualStyle.nocturne => 0.28,
      GazetteVisualStyle.sport => 0.46,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          // Slightly off-center (not a perfectly centered circle) is part
          // of what keeps this from reading as a synthetic UI vignette.
          center: const Alignment(-0.04, -0.12),
          radius: 0.5,
          transform: const _EllipticalGradientTransform(),
          tileMode: TileMode.clamp,
          colors: [
            gradientCenter,
            gradientMid,
            colors.paperEdge,
            colors.paperCorner,
          ],
          stops: const [0.0, 0.52, 0.78, 1.0],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Keep the grain part of the paper, below the editorial content.
          // Besides preserving crisp text, this means it can never reduce
          // the contrast of links, selections, or platform text rendering.
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: grainOpacity,
                child: Image.asset(
                  'assets/textures/paper_grain.png',
                  repeat: ImageRepeat.repeat,
                  fit: BoxFit.none,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
