import 'app_state.dart';
import 'furniture.dart';

AppState addFurnitureToRoom(AppState state, FurnitureItem item) {
  return state.copyWith(
    ownedFurnitureIds: <String>{...state.ownedFurnitureIds, item.id},
    placedFurnitureBySlot: <String, String>{
      ...state.placedFurnitureBySlot,
      item.slot.name: item.id,
    },
  );
}

AppState? placeFurniture(AppState state, String furnitureId) {
  if (!state.ownedFurnitureIds.contains(furnitureId)) return null;
  final item = furnitureById(furnitureId);
  if (item == null) return null;
  return state.copyWith(
    placedFurnitureBySlot: <String, String>{
      ...state.placedFurnitureBySlot,
      item.slot.name: item.id,
    },
  );
}
