import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';

void main() {
  test('v2 JSON migrates to v3 tasks while preserving raising state', () {
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
    expect(state.treats, 4);
    expect(state.fedToday, '2026-07-20');
    expect(state.toJson()['schemaVersion'], 4);
    expect(state.toJson(), isNot(contains('taskTitles')));
  });

  test('current JSON round-trips task and completion fields', () {
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
        )
        .toJson();
    final result = AppState.fromJson(json, DateTime(2026, 7, 20));

    expect(result.tasks, hasLength(2));
    expect(result.tasks.last.kind, TaskKind.oneOff);
    expect(result.tasks.last.note, 'Ask about Sunday');
    expect(result.tasks.last.reminder?.hour, 18);
    expect(result.tasks.last.reminder?.minute, 15);
  });

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
    expect(result.toJson()['schemaVersion'], 4);
  });

  test('v4 round-trips furniture ownership and slot placements', () {
    final source = AppState.initial(DateTime(2026, 8, 28)).copyWith(
      ownedFurnitureIds: <String>{'bookshelf', 'storage_cabinet'},
      placedFurnitureBySlot: <String, String>{'bookshelf': 'storage_cabinet'},
    );

    final result = AppState.fromJson(source.toJson(), DateTime(2026, 8, 28));

    expect(result.ownedFurnitureIds, <String>{'bookshelf', 'storage_cabinet'});
    expect(result.placedFurnitureBySlot, <String, String>{
      'bookshelf': 'storage_cabinet',
    });
  });
}
