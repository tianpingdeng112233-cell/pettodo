import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/furniture.dart';
import 'package:pettodo/domain/furniture_placement.dart';

void main() {
  test('a slot contains at most one placed furniture item', () {
    final state = AppState.initial(DateTime(2026, 8, 28)).copyWith(
      ownedFurnitureIds: <String>{curtainWindow.id, starStringLights.id},
    );

    final withWindow = placeFurniture(state, curtainWindow.id)!;
    final withLights = placeFurniture(withWindow, starStringLights.id)!;

    expect(withLights.placedFurnitureBySlot, <String, String>{
      'window': 'star_string_lights',
    });
  });

  test('switching furniture replaces the previous item in the same slot', () {
    final state = AppState.initial(DateTime(2026, 8, 28)).copyWith(
      ownedFurnitureIds: <String>{bookshelf.id, storageCabinet.id},
      placedFurnitureBySlot: <String, String>{
        FurnitureSlot.bookshelf.name: bookshelf.id,
      },
    );

    final switched = placeFurniture(state, storageCabinet.id)!;

    expect(
      switched.placedFurnitureBySlot[FurnitureSlot.bookshelf.name],
      storageCabinet.id,
    );
    expect(switched.placedFurnitureBySlot, hasLength(1));
  });

  test('furniture that is not owned cannot be placed', () {
    final state = AppState.initial(DateTime(2026, 8, 28));

    expect(placeFurniture(state, wallClock.id), isNull);
  });
}
