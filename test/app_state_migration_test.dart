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
    expect(state.toJson()['schemaVersion'], 3);
    expect(state.toJson(), isNot(contains('taskTitles')));
  });

  test('v3 round-trips task kind, note, reminder, and completion fields', () {
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
}
