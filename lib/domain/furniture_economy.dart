import 'app_state.dart';
import 'furniture.dart';
import 'furniture_placement.dart';

AppState awardEarnedMilestoneFurniture(AppState state) {
  var result = state;
  for (final item in milestoneFurniture) {
    if (result.lifetimeCompletions >= item.threshold! &&
        !result.ownedFurnitureIds.contains(item.id)) {
      result = addFurnitureToRoom(result, item);
    }
  }
  return result;
}

AppState? purchaseFurniture(AppState state, FurnitureItem item) {
  final price = item.price;
  if (price == null || state.treats < price) return null;
  if (state.ownedFurnitureIds.contains(item.id)) return null;
  return addFurnitureToRoom(state.copyWith(treats: state.treats - price), item);
}
