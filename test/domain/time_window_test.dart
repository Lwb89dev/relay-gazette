import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/time_window.dart';

void main() {
  test('presets cover the five specified windows', () {
    final hours = EditionTimeWindow.presets.map((w) => w.duration.inHours).toList();
    expect(hours, [4, 8, 12, 24, 48]);
  });

  test('resolve() anchors the window to the given now, in UTC', () {
    final now = DateTime.utc(2026, 8, 23, 12);
    final window = EditionTimeWindow.twentyFourHours.resolve(now: now);
    expect(window.end, now);
    expect(window.start, DateTime.utc(2026, 8, 22, 12));
  });

  test('resolve() converts a local now to UTC', () {
    final localNow = DateTime(2026, 8, 23, 12);
    final window = EditionTimeWindow.fourHours.resolve(now: localNow);
    expect(window.end.isUtc, isTrue);
    expect(window.start.isUtc, isTrue);
    expect(window.end.difference(window.start), const Duration(hours: 4));
  });

  test('custom() builds an arbitrary window', () {
    final window = EditionTimeWindow.custom(const Duration(hours: 6));
    expect(window.duration, const Duration(hours: 6));
  });

  test('custom() rejects a non-positive duration', () {
    expect(() => EditionTimeWindow.custom(Duration.zero), throwsArgumentError);
    expect(() => EditionTimeWindow.custom(const Duration(hours: -1)), throwsArgumentError);
  });
}
