import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/accessory.dart';
import 'package:pettodo/domain/accessory_equipment.dart';
import 'package:pettodo/domain/app_state.dart';

void main() {
  test('equipping another item at an anchor replaces the previous item', () {
    final state = AppState.initial(
      DateTime(2026, 8, 28),
    ).copyWith(ownedAccessoryIds: <String>{woolHat.id, strawHat.id});

    final withWoolHat = equipAccessory(state, woolHat.id)!;
    final withStrawHat = equipAccessory(withWoolHat, strawHat.id)!;

    expect(withStrawHat.equippedAccessoryByAnchor, <String, String>{
      AccessoryAnchor.head.name: strawHat.id,
    });
  });

  test('head and neck accessories can be equipped together', () {
    final state = AppState.initial(
      DateTime(2026, 8, 28),
    ).copyWith(ownedAccessoryIds: <String>{woolHat.id, redScarf.id});

    final equipped = equipAccessory(
      equipAccessory(state, woolHat.id)!,
      redScarf.id,
    )!;

    expect(equipped.equippedAccessoryByAnchor, <String, String>{
      AccessoryAnchor.head.name: woolHat.id,
      AccessoryAnchor.neck.name: redScarf.id,
    });
  });

  test('unequipping clears only the selected anchor', () {
    final state = AppState.initial(DateTime(2026, 8, 28)).copyWith(
      ownedAccessoryIds: <String>{woolHat.id, redScarf.id},
      equippedAccessoryByAnchor: <String, String>{
        AccessoryAnchor.head.name: woolHat.id,
        AccessoryAnchor.neck.name: redScarf.id,
      },
    );

    final unequipped = unequipAccessory(state, AccessoryAnchor.head);

    expect(unequipped.equippedAccessoryByAnchor, <String, String>{
      AccessoryAnchor.neck.name: redScarf.id,
    });
  });

  test('an accessory that is not owned cannot be equipped', () {
    final state = AppState.initial(DateTime(2026, 8, 28));

    expect(equipAccessory(state, partyHat.id), isNull);
  });
}
