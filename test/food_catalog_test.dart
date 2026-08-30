import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/food.dart';

void main() {
  test(
    'the shared food catalog has the seven fixed foods with XP at price',
    () {
      expect(
        foodCatalog.map((item) => (item.id, item.price, item.xp)),
        <(String, int, int)>[
          ('biscuit', 5, 5),
          ('chicken_bites', 12, 12),
          ('salmon', 12, 12),
          ('soft_egg', 12, 12),
          ('drumstick', 30, 30),
          ('steak', 30, 30),
          ('shrimp', 30, 30),
        ],
      );
      expect(foodById('salmon'), same(salmon));
      expect(foodById('unknown'), isNull);
    },
  );
}
