import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/task_grouping.dart';

TodoTask _task(
  String id, {
  TaskKind kind = TaskKind.oneOff,
  TaskReminder? reminder,
}) => TodoTask(id: id, title: id, kind: kind, reminder: reminder);

void main() {
  test('future timed one-offs move to Coming up in chronological order', () {
    final now = DateTime(2026, 8, 30, 12);
    final past = _task(
      'past',
      reminder: TaskReminder.once(scheduledAt: DateTime(2026, 8, 30, 11, 59)),
    );
    final noReminder = _task('plain');
    final daily = _task(
      'daily',
      kind: TaskKind.daily,
      reminder: const TaskReminder(hour: 9, minute: 0),
    );
    final later = _task(
      'later',
      reminder: TaskReminder.once(scheduledAt: DateTime(2026, 9, 2, 9)),
    );
    final sooner = _task(
      'sooner',
      reminder: TaskReminder.once(scheduledAt: DateTime(2026, 8, 31, 15)),
    );

    final result = groupTasksForHome(<TodoTask>[
      past,
      later,
      noReminder,
      sooner,
      daily,
    ], now: now);

    expect(result.regular.map((task) => task.id), <String>[
      'past',
      'plain',
      'daily',
    ]);
    expect(result.comingUp.map((task) => task.id), <String>['sooner', 'later']);
  });

  test('timed reminder crosses from Coming up back to its original place', () {
    final at = DateTime(2026, 8, 31, 15);
    final before = _task('before');
    final timed = _task('timed', reminder: TaskReminder.once(scheduledAt: at));
    final after = _task('after');
    final tasks = <TodoTask>[before, timed, after];

    final oneMomentBefore = groupTasksForHome(
      tasks,
      now: at.subtract(const Duration(microseconds: 1)),
    );
    final atTheMoment = groupTasksForHome(tasks, now: at);

    expect(oneMomentBefore.regular.map((task) => task.id), <String>[
      'before',
      'after',
    ]);
    expect(oneMomentBefore.comingUp.map((task) => task.id), <String>['timed']);
    expect(atTheMoment.regular.map((task) => task.id), <String>[
      'before',
      'timed',
      'after',
    ]);
    expect(atTheMoment.comingUp, isEmpty);
  });
}
