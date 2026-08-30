import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/furniture_migration.dart';

void main() {
  test('legacy decor and earned thresholds migrate to furniture ownership', () {
    final owned = migrateLegacyDecorToFurniture(
      unlockedDecorIds: const <String>['soft_ball', 'flower'],
      lifetimeCompletions: 50,
    );

    expect(owned, <String>{'rug', 'plant', 'bed', 'bookshelf'});
  });

  test('copyWith does not infer furniture from completion progress', () {
    final state = AppState.initial(
      DateTime(2026, 8, 28),
    ).copyWith(lifetimeCompletions: 120);

    expect(state.ownedFurnitureIds, isEmpty);
    expect(state.placedFurnitureBySlot, isEmpty);
  });

  test(
    'a historical save upgrades with every earned item exactly once',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'pettodo-furniture-migration',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final legacyJson = <String, Object?>{
        'schemaVersion': 3,
        'onboardingComplete': true,
        'selectedPetId': 'choco',
        'petName': 'Choco',
        'tasks': <Object?>[
          <String, Object?>{
            'id': 'daily-water',
            'title': 'Water',
            'kind': 'daily',
          },
        ],
        'activeDay': '2026-08-28',
        'lifetimeCompletions': 120,
        'unlockedDecorIds': <String>[
          'soft_ball',
          'flower',
          'home',
          'blanket',
          'lamp',
          'window',
        ],
        'treats': 8,
      };
      await File(
        '${directory.path}/pettodo-state.json',
      ).writeAsString(jsonEncode(legacyJson));
      final store = AppStateStore(() async => directory);

      final state = await store.load(DateTime(2026, 8, 28));
      await store.save(state);
      final roundTripped = await store.load(DateTime(2026, 8, 28));

      expect(roundTripped.ownedFurnitureIds, <String>{
        'rug',
        'plant',
        'bed',
        'bookshelf',
        'floor_lamp',
        'curtain_window',
      });
      expect(roundTripped.ownedFurnitureIds, hasLength(6));
      expect(roundTripped.placedFurnitureBySlot.values.toSet(), hasLength(6));
    },
  );
}
