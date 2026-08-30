import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/bond.dart';
import 'package:pettodo/domain/bond_economy.dart';
import 'package:pettodo/domain/food.dart';

void main() {
  test('the first three feeding awards keep their base value', () {
    expect(
      [
        for (var feedsBefore = 0; feedsBefore < 5; feedsBefore++)
          feedingBondXp(
            foodXp: 12,
            feedsTodayBefore: feedsBefore,
            placedFurnitureCount: 0,
          ),
      ],
      <int>[12, 12, 12, 6, 3],
    );
  });

  test('companion day and feeding both receive the capped coziness bonus', () {
    expect(cozinessBonusPercent(0), 0);
    expect(cozinessBonusPercent(2), 10);
    expect(cozinessBonusPercent(99), 25);
    expect(companionDayBondXp(placedFurnitureCount: 2), 11);
    expect(
      feedingBondXp(foodXp: 30, feedsTodayBefore: 0, placedFurnitureCount: 99),
      38,
    );
  });

  test('bond level curve and every crossed level are deterministic', () {
    expect(
      [for (var level = 1; level <= 4; level++) bondXpThresholdForLevel(level)],
      <int>[0, 25, 100, 225],
    );
    expect(bondLevelForXp(0), 1);
    expect(bondLevelForXp(24), 1);
    expect(bondLevelForXp(25), 2);
    expect(bondLevelForXp(99), 2);
    expect(bondLevelForXp(100), 3);
    expect(bondLevelForXp(224), 3);
    expect(bondLevelForXp(225), 4);
    expect(bondLevelsCrossed(20, 230), <int>[2, 3, 4]);
    expect(bondLevelsCrossed(230, 20), isEmpty);
  });

  test('a companion day is recorded once per natural day without backfill', () {
    final initial = AppState.initial(DateTime(2026, 8, 28));

    final firstOpen = recordCompanionDay(initial, DateTime(2026, 8, 28));
    final sameDay = recordCompanionDay(firstOpen, DateTime(2026, 8, 28, 23));
    final laterOpen = recordCompanionDay(sameDay, DateTime(2026, 8, 31));

    expect(firstOpen.bondXp, 10);
    expect(identical(sameDay, firstOpen), isTrue);
    expect(laterOpen.bondXp, 20);
    expect(laterOpen.lastCompanionDay, '2026-08-31');
    expect(laterOpen.toJson().keys, isNot(anyElement(contains('streak'))));
  });

  test('feeding XP is derived from the matching catalog food', () {
    final state = AppState.initial(DateTime(2026, 8, 30));
    final forgedPrice = FoodItem(
      id: biscuit.id,
      name: biscuit.name,
      price: 999,
    );

    final fed = recordFeedingBondXp(
      state,
      food: forgedPrice,
      localNow: DateTime(2026, 8, 30),
    );

    expect(fed.bondXp, 5);
    expect(
      () => recordFeedingBondXp(
        state,
        food: const FoodItem(id: 'outside', name: 'Outside', price: 999),
        localNow: DateTime(2026, 8, 30),
      ),
      throwsArgumentError,
    );
  });
}
