import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/utils/heading_fusion.dart';

void main() {
  late DateTime now;
  late HeadingFusion fusion;

  setUp(() {
    now = DateTime(2026, 11, 24, 12);
    fusion = HeadingFusion(clock: () => now);
  });

  test('uses the compass when standing still', () {
    expect(fusion.onGps(null, 0), isNull);
    expect(fusion.onCompass(90), 90);
    expect(fusion.current, 90);
  });

  test('ignores compass turns smaller than 3 degrees', () {
    fusion.onCompass(90);
    expect(fusion.onCompass(92), isNull);
    expect(fusion.onCompass(94), 94);
  });

  test('treats 359 and 1 degrees as 2 degrees apart', () {
    fusion.onCompass(359);
    expect(fusion.onCompass(1), isNull);
  });

  test('prefers the GPS direction at driving speed', () {
    fusion.onCompass(90);
    expect(fusion.onGps(180, 10), 180);
    // The compass doesn't override a fresh GPS direction.
    expect(fusion.onCompass(45), isNull);
    expect(fusion.current, 180);
  });

  test('ignores the GPS direction when slow', () {
    fusion.onCompass(90);
    expect(fusion.onGps(180, 1), isNull);
    expect(fusion.current, 90);
  });

  test('falls back to the compass once the GPS direction is stale', () {
    fusion
      ..onCompass(90)
      ..onGps(180, 10);
    now = now.add(const Duration(seconds: 5));
    expect(fusion.current, 90);
  });

  test('uses the GPS direction when there is no compass', () {
    expect(fusion.onGps(200, 12), 200);
  });
}
