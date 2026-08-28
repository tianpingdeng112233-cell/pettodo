import 'furniture.dart';

final Map<String, String> legacyDecorToFurnitureIds =
    Map<String, String>.unmodifiable(<String, String>{
      for (final item in furnitureCatalog)
        if (item.legacyDecorId != null) item.legacyDecorId!: item.id,
    });

Set<String> migrateLegacyDecorToFurniture({
  required Iterable<String> unlockedDecorIds,
  required int lifetimeCompletions,
  Iterable<String> ownedFurnitureIds = const <String>[],
}) {
  final owned = <String>{
    ...ownedFurnitureIds.where((id) => furnitureById(id) != null),
  };
  for (final legacyId in unlockedDecorIds) {
    final furnitureId = legacyDecorToFurnitureIds[legacyId];
    if (furnitureId != null) owned.add(furnitureId);
  }
  owned.addAll(
    milestoneFurniture
        .where((item) => lifetimeCompletions >= item.threshold!)
        .map((item) => item.id),
  );
  return Set<String>.unmodifiable(owned);
}

Map<String, String> migrateFurniturePlacements({
  required Set<String> ownedFurnitureIds,
  Map<String, String> placedFurnitureBySlot = const <String, String>{},
}) {
  final placed = <String, String>{};
  for (final entry in placedFurnitureBySlot.entries) {
    final slot = FurnitureSlot.fromName(entry.key);
    final item = furnitureById(entry.value);
    if (slot != null &&
        item != null &&
        item.slot == slot &&
        ownedFurnitureIds.contains(item.id)) {
      placed[slot.name] = item.id;
    }
  }
  for (final item in furnitureCatalog) {
    if (ownedFurnitureIds.contains(item.id)) {
      placed.putIfAbsent(item.slot.name, () => item.id);
    }
  }
  return Map<String, String>.unmodifiable(placed);
}
