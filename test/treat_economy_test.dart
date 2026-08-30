import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/treat_economy.dart';

void main() {
  test('the third daily completion includes the two-treat theater bonus', () {
    expect(treatDropForCompletion(completesDailySet: false), 1);
    expect(treatDropForCompletion(completesDailySet: true), 3);
  });

  test('treats accumulate without a cap and feeding spends exactly one', () {
    final now = DateTime(2026, 7, 20, 12);
    final earned = awardTreats(
      AppState.initial(now).copyWith(
        bondXp: 87,
        feedingCountToday: 2,
        foodInventory: const <String, int>{'biscuit': 3},
      ),
      1000000,
    );
    expect(earned.treats, 1000000);

    final fed = spendTreatToFeed(earned, now)!;
    expect(fed.treats, 999999);
    expect(fed.fedToday, '2026-07-20');
    expect(fed.bondXp, 87);
    expect(fed.feedingCountToday, 2);
    expect(fed.foodInventory, <String, int>{'biscuit': 3});
  });

  test('feeding with no treats is a calm no-op', () {
    expect(
      spendTreatToFeed(
        AppState.initial(DateTime(2026, 7, 20)),
        DateTime(2026, 7, 20),
      ),
      isNull,
    );
  });
}
