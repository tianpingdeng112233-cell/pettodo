import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/accessory.dart';
import 'package:pettodo/domain/accessory_economy.dart';
import 'package:pettodo/domain/app_state.dart';

void main() {
  test('buying an accessory deducts its fixed price and adds ownership', () {
    final state = AppState.initial(DateTime(2026, 8, 28)).copyWith(treats: 50);

    final purchased = purchaseAccessory(state, woolHat)!;

    expect(purchased.treats, 30);
    expect(purchased.ownedAccessoryIds, <String>{'wool_hat'});
    expect(purchased.equippedAccessoryByAnchor, isEmpty);
  });

  test('buying an accessory with too few treats returns null', () {
    final state = AppState.initial(DateTime(2026, 8, 28)).copyWith(treats: 19);

    expect(purchaseAccessory(state, woolHat), isNull);
  });

  test('buying an already-owned accessory returns null', () {
    final state = AppState.initial(
      DateTime(2026, 8, 28),
    ).copyWith(treats: 100, ownedAccessoryIds: <String>{woolHat.id});

    expect(purchaseAccessory(state, woolHat), isNull);
  });
}
