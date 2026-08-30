import 'app_state.dart';
import 'bond.dart';
import 'day_rollover.dart';
import 'food.dart';
import 'local_day.dart';

AppState recordCompanionDay(AppState state, DateTime localNow) {
  final today = localDayKey(localNow);
  if (state.lastCompanionDay == today) return state;
  final earnedXp = companionDayBondXp(
    placedFurnitureCount: state.placedFurnitureBySlot.length,
  );
  return state.copyWith(
    bondXp: state.bondXp + earnedXp,
    lastCompanionDay: today,
  );
}

AppState recordFeedingBondXp(
  AppState state, {
  required FoodItem food,
  required DateTime localNow,
}) {
  final catalogItem = foodById(food.id);
  if (catalogItem == null) throw ArgumentError.value(food.id, 'food');
  final current = rollOverIfNeeded(state, localNow);
  final earnedXp = feedingBondXp(
    foodXp: catalogItem.xp,
    feedsTodayBefore: current.feedingCountToday,
    placedFurnitureCount: current.placedFurnitureBySlot.length,
  );
  return current.copyWith(
    bondXp: current.bondXp + earnedXp,
    feedingCountToday: current.feedingCountToday + 1,
    fedToday: localDayKey(localNow),
  );
}
