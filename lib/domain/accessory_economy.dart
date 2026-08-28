import 'accessory.dart';
import 'app_state.dart';

AppState? purchaseAccessory(AppState state, AccessoryItem item) {
  if (state.treats < item.price) return null;
  if (state.ownedAccessoryIds.contains(item.id)) return null;
  return state.copyWith(
    treats: state.treats - item.price,
    ownedAccessoryIds: <String>{...state.ownedAccessoryIds, item.id},
  );
}
