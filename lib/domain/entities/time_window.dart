/// The lookback window an edition is built from. Backed by a plain
/// [Duration] rather than an enum so custom windows can be added later
/// without changing every call site — the presets are just convenient
/// factories.
class EditionTimeWindow {
  final Duration duration;
  final String label;

  const EditionTimeWindow._(this.duration, this.label);

  static const fourHours = EditionTimeWindow._(Duration(hours: 4), '4 hours');
  static const eightHours = EditionTimeWindow._(Duration(hours: 8), '8 hours');
  static const twelveHours = EditionTimeWindow._(
    Duration(hours: 12),
    '12 hours',
  );
  static const twentyFourHours = EditionTimeWindow._(
    Duration(hours: 24),
    '24 hours',
  );
  static const fortyEightHours = EditionTimeWindow._(
    Duration(hours: 48),
    '48 hours',
  );

  static const presets = [
    fourHours,
    eightHours,
    twelveHours,
    twentyFourHours,
    fortyEightHours,
  ];

  factory EditionTimeWindow.custom(Duration duration) {
    if (duration <= Duration.zero) {
      throw ArgumentError('Time window must be positive');
    }
    final hours = duration.inHours;
    return EditionTimeWindow._(duration, '$hours hours');
  }

  /// Resolves the [windowStart, windowEnd) range in UTC, anchored to now.
  ({DateTime start, DateTime end}) resolve({DateTime? now}) {
    final end = (now ?? DateTime.now()).toUtc();
    final start = end.subtract(duration);
    return (start: start, end: end);
  }

  @override
  bool operator ==(Object other) =>
      other is EditionTimeWindow && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => label;
}
