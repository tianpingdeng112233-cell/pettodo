import 'accessory.dart';
import 'app_state.dart';

AppState? equipAccessory(AppState state, String accessoryId) {
  if (!state.ownedAccessoryIds.contains(accessoryId)) return null;
  final item = accessoryById(accessoryId);
  if (item == null) return null;
  return state.copyWith(
    equippedAccessoryByAnchor: <String, String>{
      ...state.equippedAccessoryByAnchor,
      item.anchor.name: item.id,
    },
  );
}

AppState unequipAccessory(AppState state, AccessoryAnchor anchor) {
  return state.copyWith(
    equippedAccessoryByAnchor: <String, String>{
      for (final entry in state.equippedAccessoryByAnchor.entries)
        if (entry.key != anchor.name) entry.key: entry.value,
    },
  );
}
