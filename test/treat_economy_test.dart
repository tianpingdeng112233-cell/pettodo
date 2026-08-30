import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/treat_economy.dart';

void main() {
  test('the third daily completion includes the two-treat theater bonus', () {
    expect(treatDropForCompletion(completesDailySet: false), 1);
    expect(treatDropForCompletion(completesDailySet: true), 3);
  });

  test('treats accumulate without a cap', () {
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
    expect(earned.bondXp, 87);
    expect(earned.feedingCountToday, 2);
    expect(earned.foodInventory, <String, int>{'biscuit': 3});
  });
}
