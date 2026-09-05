import 'package:flutter/widgets.dart';

/// Screen-class breakpoints for the edition layout. A phone gets a single
/// stacked column; a tablet gets an actual multi-column front page, closer to
/// the paper original — 2 columns in portrait, 3 once there's room for a
/// third in landscape.
class GazetteBreakpoints {
  GazetteBreakpoints._();

  /// A broadsheet should stop growing on desktop displays. Keeping this
  /// measure also gives its three editorial columns their intended reading
  /// width instead of turning them into a generic full-screen dashboard.
  static const double editionMaxWidth = 1320;

  /// Flutter exposes display dimensions in logical pixels, whose baseline is
  /// 160 pixels per inch. An eight-inch diagonal is therefore 1280 logical
  /// pixels. This keeps the reading rule tied to physical screen class rather
  /// than a portrait/landscape width alone.
  static const double _eightInchDiagonal = 8 * 160;

  static bool isTablet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width * size.width + size.height * size.height >
        _eightInchDiagonal * _eightInchDiagonal;
  }

  static const double tablet = 640;
  static const double wide = 1000;
}
