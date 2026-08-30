import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/furniture.dart';
import 'package:pettodo/domain/furniture_economy.dart';

void main() {
  test('buying furniture deducts its fixed price and adds ownership', () {
    final state = AppState.initial(DateTime(2026, 8, 28)).copyWith(treats: 50);

    final purchased = purchaseFurniture(state, wallArt)!;

    expect(purchased.treats, 25);
    expect(purchased.ownedFurnitureIds, <String>{'wall_art'});
    expect(purchased.placedFurnitureBySlot, <String, String>{
      'wallArt': 'wall_art',
    });
  });

  test('buying furniture with too few treats returns null', () {
    final state = AppState.initial(DateTime(2026, 8, 28)).copyWith(treats: 24);

    expect(purchaseFurniture(state, wallArt), isNull);
  });

  test('buying already-owned furniture returns null', () {
    final state = AppState.initial(
      DateTime(2026, 8, 28),
    ).copyWith(treats: 100, ownedFurnitureIds: <String>{wallArt.id});

    expect(purchaseFurniture(state, wallArt), isNull);
  });
}
