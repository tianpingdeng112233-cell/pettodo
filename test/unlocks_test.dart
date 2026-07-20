import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/unlocks.dart';

void main() {
  for (final edge in <(int, int, String)>[
    (4, 5, 'soft_ball'),
    (14, 15, 'flower'),
    (29, 30, 'home'),
  ]) {
    test('${edge.$1} to ${edge.$2} unlocks ${edge.$3}', () {
      expect(unlocksCrossed(edge.$1, edge.$2).map((item) => item.id), <String>[
        edge.$3,
      ]);
    });
  }

  test('does not re-unlock an earned decoration', () {
    expect(unlocksCrossed(5, 6), isEmpty);
    expect(unlocksCrossed(30, 31), isEmpty);
  });
}
