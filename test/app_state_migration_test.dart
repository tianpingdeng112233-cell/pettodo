import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/hatch_request_store.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/data/pet_pack_service.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';

class _MigrationPetLoader extends SpriteAtlasLoader {
  _MigrationPetLoader(this._images);

  final Map<String, ui.Image> _images;

  @override
  Future<List<PetAssetDescriptor>> loadManifest() async => const [
    PetAssetDescriptor(
      id: 'choco',
      displayName: 'Choco',
      metadataAsset: 'fake',
      spritesheetAsset: 'fake',
    ),
    PetAssetDescriptor(
      id: 'pip',
      displayName: 'Pip',
      metadataAsset: 'fake',
      spritesheetAsset: 'fake',
    ),
  ];

  @override
  Future<List<DecorAssetDescriptor>> loadDecorManifest() async => const [
    DecorAssetDescriptor(
      id: 'soft_ball',
      displayName: 'Bouncy Ball',
      emoji: '🧶',
      slot: 0,
    ),
  ];

  @override
  Future<LoadedSpriteAtlas> loadPet(
    PetAssetDescriptor descriptor, {
    String? growthStage,
  }) async => LoadedSpriteAtlas(
    descriptor: descriptor,
    definition: SpriteAtlasDefinition(
      petId: descriptor.id,
      columns: 8,
      rows: 11,
      cellWidth: 4,
      cellHeight: 4,
      imageWidth: 32,
      imageHeight: 44,
      sequences: {
        for (final entry in const [
          ('idle', 0, 6),
          ('jumping', 4, 5),
          ('waving', 3, 4),
          ('review', 8, 6),
          ('waiting', 6, 6),
          ('look-row-9', 9, 8),
          ('look-row-10', 10, 8),
        ])
          entry.$1: SpriteSequenceDefinition(
            state: entry.$1,
            row: entry.$2,
            frameCount: entry.$3,
            purpose: 'test',
          ),
      },
    ),
    image: _images[descriptor.id]!,
  );
}

class _MigrationNotifications extends NotificationService {
  @override
  Future<List<ScheduledPetNotification>> scheduleWindow({
    required String petName,
    required bool includeDailyInvitation,
    required int invitationHour,
    required int invitationMinute,
    required List<TaskReminderSchedule> taskReminders,
    DateTime? now,
  }) async => const <ScheduledPetNotification>[];
}

Future<ui.Image> _migrationImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 32, 44),
    ui.Paint()..color = const ui.Color(0xFF8A5A2E),
  );
  return recorder.endRecording().toImage(32, 44);
}

void main() {
  test('v2 JSON migrates to current tasks while preserving raising state', () {
    final state = AppState.fromJson(<String, Object?>{
      'schemaVersion': 2,
      'onboardingComplete': true,
      'selectedPetId': 'choco',
      'petName': 'Cocoa',
      'taskTitles': const <String>['One', 'Two', 'Three'],
      'completedToday': const <bool>[true, false, false],
      'activeDay': '2026-07-20',
      'lifetimeCompletions': 39,
      'unlockedDecorIds': const <String>['soft_ball'],
      'treats': 4,
      'fedToday': '2026-07-20',
      'notificationPermission': 'notRequested',
      'notificationEnabled': false,
      'notificationHour': 20,
      'notificationMinute': 0,
    }, DateTime(2026, 7, 20));

    expect(state.petName, 'Cocoa');
    expect(state.adoptedPresetPetIds, isEmpty);
    expect(state.needsPresetAdoptionMigration, isTrue);
    expect(state.tasks.map((task) => task.id), <String>[
      'daily-1',
      'daily-2',
      'daily-3',
    ]);
    expect(state.tasks.map((task) => task.title), <String>[
      'One',
      'Two',
      'Three',
    ]);
    expect(
      state.tasks,
      everyElement(predicate<TodoTask>((task) => task.kind == TaskKind.daily)),
    );
    expect(state.tasks.first.completedToday, isTrue);
    expect(state.lifetimeCompletions, 39);
    expect(state.unlockedDecorIds, <String>['soft_ball', 'flower', 'home']);
    expect(state.ownedFurnitureIds, <String>{'rug', 'plant', 'bed'});
    expect(state.placedFurnitureBySlot.values.toSet(), <String>{
      'rug',
      'plant',
      'bed',
    });
    expect(state.treats, 4);
    expect(state.fedToday, '2026-07-20');
    expect(state.feedingCountToday, 1);
    expect(state.bondXp, 25);
    expect(state.foodInventory, <String, int>{'biscuit': 1});
    expect(state.toJson()['schemaVersion'], 6);
    expect(state.toJson(), isNot(contains('taskTitles')));
  });

  testWidgets(
    'v5 save with a non-Choco selection keeps every bundled preset on its shelf',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'pettodo-preset-migration',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      late final AppController controller;
      await tester.runAsync(() async {
        await File('${tempDir.path}/pettodo-state.json').writeAsString(
          jsonEncode(<String, Object?>{
            'schemaVersion': 5,
            'onboardingComplete': true,
            'selectedPetId': 'pip',
            'petName': 'Pip',
            'tasks': <Object?>[
              <String, Object?>{
                'id': 'daily-water',
                'title': 'Drink some water',
                'kind': 'daily',
              },
            ],
            'activeDay': '2026-08-30',
          }),
        );
        controller = AppController(
          stateStore: AppStateStore(() async => tempDir),
          eventLog: EventLogStore(() async => tempDir),
          notifications: _MigrationNotifications(),
          spriteLoader: _MigrationPetLoader(<String, ui.Image>{
            'choco': await _migrationImage(),
            'pip': await _migrationImage(),
          }),
          hatchRequestStore: HatchRequestStore(() async => tempDir),
          petPackService: PetPackService(() async => tempDir),
          now: () => DateTime(2026, 8, 30, 12),
        );
        await controller.initialize();
      });
      addTearDown(controller.dispose);

      expect(controller.state.selectedPetId, 'pip');
      expect(controller.state.adoptedPresetPetIds, <String>{'choco', 'pip'});
      expect(controller.adoptedPets.map((pet) => pet.id), <String>[
        'choco',
        'pip',
      ]);

      late final Map<String, Object?> persisted;
      await tester.runAsync(() async {
        persisted =
            jsonDecode(
                  await File(
                    '${tempDir.path}/pettodo-state.json',
                  ).readAsString(),
                )
                as Map<String, Object?>;
      });
      expect(
        (persisted['adoptedPresetPetIds']! as List<Object?>).toSet(),
        <String>{'choco', 'pip'},
      );
    },
  );

  testWidgets('selected-pet fallback also adopts a bundled fallback', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'pettodo-selected-fallback',
    );
    addTearDown(() => tempDir.deleteSync(recursive: true));

    late final AppController controller;
    await tester.runAsync(() async {
      await File('${tempDir.path}/pettodo-state.json').writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 6,
          'onboardingComplete': true,
          'selectedPetId': 'missing-pet',
          'petName': 'Missing',
          'adoptedPresetPetIds': <String>[],
          'tasks': <Object?>[
            <String, Object?>{
              'id': 'daily-water',
              'title': 'Drink some water',
              'kind': 'daily',
            },
          ],
          'activeDay': '2026-08-30',
        }),
      );
      controller = AppController(
        stateStore: AppStateStore(() async => tempDir),
        eventLog: EventLogStore(() async => tempDir),
        notifications: _MigrationNotifications(),
        spriteLoader: _MigrationPetLoader(<String, ui.Image>{
          'choco': await _migrationImage(),
          'pip': await _migrationImage(),
        }),
        hatchRequestStore: HatchRequestStore(() async => tempDir),
        petPackService: PetPackService(() async => tempDir),
        now: () => DateTime(2026, 8, 30, 12),
      );
      await controller.initialize();
    });
    addTearDown(controller.dispose);

    expect(controller.state.selectedPetId, 'choco');
    expect(controller.state.adoptedPresetPetIds, <String>{'choco'});
    expect(controller.adoptedPets.map((pet) => pet.id), <String>['choco']);
  });

  test('current schema round-trips task and bond domain fields', () {
    final json = AppState.initial(DateTime(2026, 7, 20))
        .copyWith(
          tasks: const <TodoTask>[
            TodoTask(id: 'daily', title: 'Water', kind: TaskKind.daily),
            TodoTask(
              id: 'once',
              title: 'Call Mum',
              kind: TaskKind.oneOff,
              note: 'Ask about Sunday',
              reminder: TaskReminder(hour: 18, minute: 15),
            ),
          ],
          bondXp: 137,
          foodInventory: const <String, int>{'biscuit': 2, 'steak': 1},
          feedingCountToday: 4,
          lastCompanionDay: '2026-07-20',
          fedToday: '2026-07-20',
          ownedFurnitureIds: const <String>{'rug'},
          placedFurnitureBySlot: const <String, String>{'rug': 'rug'},
          adoptedPresetPetIds: const <String>{'choco', 'pip'},
        )
        .toJson();
    final result = AppState.fromJson(json, DateTime(2026, 7, 20));

    expect(result.tasks, hasLength(2));
    expect(result.tasks.last.kind, TaskKind.oneOff);
    expect(result.tasks.last.note, 'Ask about Sunday');
    expect(result.tasks.last.reminder?.hour, 18);
    expect(result.tasks.last.reminder?.minute, 15);
    expect(result.bondXp, 137);
    expect(result.foodInventory, <String, int>{'biscuit': 2, 'steak': 1});
    expect(result.feedingCountToday, 4);
    expect(result.lastCompanionDay, '2026-07-20');
    expect(result.fedToday, '2026-07-20');
    expect(result.placedFurnitureBySlot, <String, String>{'rug': 'rug'});
    expect(result.adoptedPresetPetIds, <String>{'choco', 'pip'});
    expect(result.toJson()['schemaVersion'], 6);
  });

  test('legacy one-off reminder stays daily and round-trips unchanged', () {
    final task = TodoTask.fromJson(<String, Object?>{
      'id': 'legacy-once',
      'title': 'Call Mum',
      'kind': 'oneOff',
      'reminder': <String, Object?>{'hour': 18, 'minute': 15},
    });

    expect(task.reminder?.isDaily, isTrue);
    expect(task.reminder?.isTimed, isFalse);
    expect(task.reminder?.hour, 18);
    expect(task.reminder?.minute, 15);
    expect(task.toJson()['reminder'], <String, Object?>{
      'hour': 18,
      'minute': 15,
    });
  });

  test('timed reminder round-trips its one-off date without loss', () {
    final scheduledAt = DateTime(2026, 8, 31, 15);
    final task = TodoTask(
      id: 'timed-once',
      title: 'Meet Sam',
      kind: TaskKind.oneOff,
      reminder: TaskReminder.once(scheduledAt: scheduledAt),
    );

    final result = TodoTask.fromJson(task.toJson());

    expect(result.reminder?.isTimed, isTrue);
    expect(result.reminder?.isDaily, isFalse);
    expect(result.reminder?.scheduledAt, scheduledAt);
    expect(result.toJson(), task.toJson());
  });

  test(
    'mixed legacy and timed reminders load with their original behavior',
    () {
      final result = AppState.fromJson(<String, Object?>{
        ...AppState.initial(DateTime(2026, 8, 30)).toJson(),
        'tasks': <Object?>[
          <String, Object?>{
            'id': 'daily',
            'title': 'Water',
            'kind': 'daily',
            'reminder': <String, Object?>{
              'hour': 9,
              'minute': 0,
              'enabled': true,
            },
          },
          <String, Object?>{
            'id': 'legacy-once',
            'title': 'Old one-off',
            'kind': 'oneOff',
            'reminder': <String, Object?>{'hour': 10, 'minute': 30},
          },
          <String, Object?>{
            'id': 'timed-once',
            'title': 'New one-off',
            'kind': 'oneOff',
            'reminder': <String, Object?>{
              'scheduledAt': '2026-08-31T15:00:00.000',
              'enabled': true,
            },
          },
        ],
      }, DateTime(2026, 8, 30));

      expect(result.tasks[0].reminder?.isDaily, isTrue);
      expect(result.tasks[1].reminder?.isDaily, isTrue);
      expect(result.tasks[2].reminder?.isTimed, isTrue);
      expect(result.tasks[2].reminder?.scheduledAt, DateTime(2026, 8, 31, 15));
    },
  );

  test('v3 keeps choco and all progress while upgrading to v4', () {
    final result = AppState.fromJson(<String, Object?>{
      'schemaVersion': 3,
      'onboardingComplete': true,
      'selectedPetId': 'choco',
      'petName': 'Cocoa',
      'tasks': <Object?>[
        <String, Object?>{
          'id': 'daily-water',
          'title': 'Water',
          'kind': 'daily',
          'completedToday': true,
        },
        <String, Object?>{
          'id': 'call-vet',
          'title': 'Call the vet',
          'kind': 'oneOff',
          'note': 'Ask about Pip',
          'completedToday': false,
        },
      ],
      'activeDay': '2026-08-12',
      'lifetimeCompletions': 57,
      'unlockedDecorIds': <String>['soft_ball', 'flower', 'home'],
      'treats': 12,
      'fedToday': '2026-08-12',
      'notificationPermission': 'granted',
      'notificationEnabled': true,
      'notificationHour': 19,
      'notificationMinute': 45,
    }, DateTime(2026, 8, 12));

    expect(result.selectedPetId, 'choco');
    expect(result.petName, 'Cocoa');
    expect(result.tasks.map((task) => task.id), <String>[
      'daily-water',
      'call-vet',
    ]);
    expect(result.tasks.first.completedToday, isTrue);
    expect(result.tasks.last.note, 'Ask about Pip');
    expect(result.lifetimeCompletions, 57);
    expect(result.treats, 12);
    expect(result.fedToday, '2026-08-12');
    expect(result.notificationEnabled, isTrue);
    expect(result.foodInventory, <String, int>{'biscuit': 1});
    expect(result.toJson()['schemaVersion'], 6);
  });

  test(
    'current schema round-trips furniture ownership and slot placements',
    () {
      final source = AppState.initial(DateTime(2026, 8, 28)).copyWith(
        ownedFurnitureIds: <String>{'bookshelf', 'storage_cabinet'},
        placedFurnitureBySlot: <String, String>{'bookshelf': 'storage_cabinet'},
      );

      final result = AppState.fromJson(source.toJson(), DateTime(2026, 8, 28));

      expect(result.ownedFurnitureIds, <String>{
        'bookshelf',
        'storage_cabinet',
      });
      expect(result.placedFurnitureBySlot, <String, String>{
        'bookshelf': 'storage_cabinet',
      });
    },
  );

  test('legacy growth stages map to fixed non-zero bond XP floors', () {
    for (final fixture in <({int completions, int expectedBondXp})>[
      (completions: 0, expectedBondXp: 25),
      (completions: 40, expectedBondXp: 100),
      (completions: 120, expectedBondXp: 225),
    ]) {
      final result = AppState.fromJson(<String, Object?>{
        'schemaVersion': 4,
        'tasks': <Object?>[
          <String, Object?>{'id': 'daily', 'title': 'Water', 'kind': 'daily'},
        ],
        'lifetimeCompletions': fixture.completions,
        'activeDay': '2026-08-30',
        'treats': 17,
      }, DateTime(2026, 8, 30));

      expect(result.bondXp, fixture.expectedBondXp);
      expect(result.treats, 17);
    }
  });

  test('legacy migration never lowers an existing bond XP value', () {
    final result = AppState.fromJson(<String, Object?>{
      'schemaVersion': 4,
      'tasks': <Object?>[
        <String, Object?>{'id': 'daily', 'title': 'Water', 'kind': 'daily'},
      ],
      'lifetimeCompletions': 120,
      'bondXp': 400,
    }, DateTime(2026, 8, 30));

    expect(result.bondXp, 400);
  });

  test(
    'v4 history receives one biscuit exactly once when inventory is empty',
    () {
      for (final history in <({int completions, int treats})>[
        (completions: 1, treats: 0),
        (completions: 0, treats: 1),
      ]) {
        final migrated = AppState.fromJson(<String, Object?>{
          'schemaVersion': 4,
          'tasks': <Object?>[
            <String, Object?>{'id': 'daily', 'title': 'Water', 'kind': 'daily'},
          ],
          'lifetimeCompletions': history.completions,
          'treats': history.treats,
          'foodInventory': const <String, int>{},
        }, DateTime(2026, 8, 30));

        expect(migrated.foodInventory, <String, int>{'biscuit': 1});

        final reloaded = AppState.fromJson(
          migrated.toJson(),
          DateTime(2026, 8, 30),
        );
        expect(reloaded.foodInventory, <String, int>{'biscuit': 1});
      }
    },
  );

  test(
    'v5 saves and v4 saves without history receive no migration biscuit',
    () {
      final newSave = AppState.fromJson(
        AppState.initial(DateTime(2026, 8, 30)).toJson(),
        DateTime(2026, 8, 30),
      );
      final emptyLegacySave = AppState.fromJson(<String, Object?>{
        'schemaVersion': 4,
        'tasks': <Object?>[
          <String, Object?>{'id': 'daily', 'title': 'Water', 'kind': 'daily'},
        ],
        'lifetimeCompletions': 0,
        'treats': 0,
        'foodInventory': const <String, int>{},
      }, DateTime(2026, 8, 30));

      expect(newSave.foodInventory, isEmpty);
      expect(emptyLegacySave.foodInventory, isEmpty);
    },
  );

  test('a fedToday-only history still earns the greeting biscuit', () {
    final result = AppState.fromJson(<String, Object?>{
      'schemaVersion': 4,
      'onboardingComplete': true,
      'tasks': <Object?>[
        <String, Object?>{'id': 'daily', 'title': 'Water', 'kind': 'daily'},
      ],
      'activeDay': '2026-08-30',
      'lifetimeCompletions': 0,
      'treats': 0,
      'fedToday': '2026-08-29',
    }, DateTime(2026, 8, 30));

    expect(result.foodInventory, <String, int>{'biscuit': 1});
  });
}
