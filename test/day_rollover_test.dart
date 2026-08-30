import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/day_rollover.dart';

void main() {
  test('local midnight resets daily tasks and leaves one-offs untouched', () {
    final beforeMidnight = DateTime(2026, 7, 20, 23, 59, 59);
    final state = AppState.initial(beforeMidnight).copyWith(
      tasks: const <TodoTask>[
        TodoTask(
          id: 'daily-a',
          title: 'Water',
          kind: TaskKind.daily,
          completedToday: true,
        ),
        TodoTask(id: 'daily-b', title: 'Walk', kind: TaskKind.daily),
        TodoTask(id: 'once', title: 'Post letter', kind: TaskKind.oneOff),
      ],
      lifetimeCompletions: 14,
      feedingCountToday: 4,
      lastCompanionDay: '2026-07-20',
      fedToday: '2026-07-20',
    );

    final sameDay = rollOverIfNeeded(
      state,
      DateTime(2026, 7, 20, 23, 59, 59, 999),
    );
    expect(identical(sameDay, state), isTrue);

    final nextDay = rollOverIfNeeded(state, DateTime(2026, 7, 21));
    expect(nextDay.activeDay, '2026-07-21');
    expect(nextDay.taskById('daily-a')?.completedToday, isFalse);
    expect(nextDay.taskById('once')?.title, 'Post letter');
    expect(nextDay.taskById('once')?.completedAt, isNull);
    expect(nextDay.lifetimeCompletions, 14);
    expect(nextDay.feedingCountToday, 0);
    expect(nextDay.lastCompanionDay, '2026-07-20');
    expect(nextDay.fedToday, isNull);
  });

  test('rolling over multiple missed days leaves no historical markers', () {
    final state = AppState.initial(DateTime(2026, 7, 1)).copyWith(
      tasks: const <TodoTask>[
        TodoTask(
          id: 'daily',
          title: 'Stretch',
          kind: TaskKind.daily,
          completedToday: true,
        ),
        TodoTask(id: 'once', title: 'Buy stamps', kind: TaskKind.oneOff),
      ],
      lifetimeCompletions: 6,
    );
    final result = rollOverIfNeeded(state, DateTime(2026, 8, 10, 9));
    expect(result.taskById('daily')?.completedToday, isFalse);
    expect(result.taskById('once'), isNotNull);
    expect(result.activeDay, '2026-08-10');
    expect(result.lifetimeCompletions, 6);
  });

  test('rollover cannot retain a feeding count from another active day', () {
    final state = AppState.initial(
      DateTime(2026, 7, 20),
    ).copyWith(feedingCountToday: 3, fedToday: '2026-07-20');
    final now = DateTime(2026, 7, 21, 8);

    final result = rollOverIfNeeded(state, now);

    expect((result.activeDay, result.feedingCountToday), ('2026-07-21', 0));
    expect(result.fedToday, isNull);
  });
}
