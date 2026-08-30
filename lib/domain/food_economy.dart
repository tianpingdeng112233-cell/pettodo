import 'app_state.dart';
import 'bond_economy.dart';
import 'food.dart';

AppState? purchaseFood(AppState state, FoodItem item) {
  final catalogItem = foodById(item.id);
  if (catalogItem == null || state.treats < catalogItem.price) return null;
  return state.copyWith(
    treats: state.treats - catalogItem.price,
    foodInventory: <String, int>{
      ...state.foodInventory,
      catalogItem.id: (state.foodInventory[catalogItem.id] ?? 0) + 1,
    },
  );
}

AppState? feedFood(AppState state, FoodItem item, DateTime localNow) {
  final catalogItem = foodById(item.id);
  if (catalogItem == null) return null;
  final owned = state.foodInventory[catalogItem.id] ?? 0;
  if (owned < 1) return null;
  final inventory = <String, int>{...state.foodInventory};
  if (owned == 1) {
    inventory.remove(catalogItem.id);
  } else {
    inventory[catalogItem.id] = owned - 1;
  }
  return recordFeedingBondXp(
    state.copyWith(foodInventory: inventory),
    food: catalogItem,
    localNow: localNow,
  );
}
