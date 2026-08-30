import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/food.dart';
import 'package:pettodo/domain/food_economy.dart';

void main() {
  test('buying food deducts treats and stacks the owned count', () {
    final state = AppState.initial(DateTime(2026, 8, 30)).copyWith(treats: 29);

    final first = purchaseFood(state, chickenBites)!;
    final second = purchaseFood(first, chickenBites)!;

    expect(second.treats, 5);
    expect(second.foodInventory, <String, int>{'chicken_bites': 2});
  });

  test(
    'buying food with too few treats returns null without changing state',
    () {
      final state = AppState.initial(DateTime(2026, 8, 30)).copyWith(treats: 4);

      expect(purchaseFood(state, biscuit), isNull);
      expect(state.treats, 4);
      expect(state.foodInventory, isEmpty);
    },
  );

  test('feeding consumes inventory and adds bond XP using the daily count', () {
    final state = AppState.initial(DateTime(2026, 8, 30)).copyWith(
      foodInventory: const <String, int>{'chicken_bites': 2},
      placedFurnitureBySlot: const <String, String>{'rug': 'rug'},
    );

    final fed = feedFood(state, chickenBites, DateTime(2026, 8, 30))!;

    expect(fed.foodInventory, <String, int>{'chicken_bites': 1});
    expect(fed.feedingCountToday, 1);
    expect(fed.bondXp, 13);
    expect(fed.fedToday, '2026-08-30');
  });

  test('feeding unavailable food returns null', () {
    final state = AppState.initial(DateTime(2026, 8, 30));

    expect(feedFood(state, biscuit, DateTime(2026, 8, 30)), isNull);
  });
}
