import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/focus_economy.dart';

void main() {
  for (final edge in <(int, int)>[
    (5, 0),
    (10, 0),
    (15, 1),
    (20, 1),
    (30, 2),
    (45, 3),
  ]) {
    test('${edge.$1} completed focus minutes drop ${edge.$2} treats', () {
      expect(treatDropForFocus(edge.$1), edge.$2);
    });
  }

  test('non-positive focus durations are rejected', () {
    expect(() => treatDropForFocus(0), throwsArgumentError);
    expect(() => treatDropForFocus(-5), throwsArgumentError);
  });
}
