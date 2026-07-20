import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/day_rollover.dart';

void main() {
  test(
    'crossing local midnight resets checks and preserves lifetime count',
    () {
      final beforeMidnight = DateTime(2026, 7, 20, 23, 59, 59);
      final state = AppState.initial(beforeMidnight).copyWith(
        completedToday: const <bool>[true, false, true],
        lifetimeCompletions: 14,
        fedToday: '2026-07-20',
      );

      final sameDay = rollOverIfNeeded(
        state,
        DateTime(2026, 7, 20, 23, 59, 59, 999),
      );
      expect(identical(sameDay, state), isTrue);

      final nextDay = rollOverIfNeeded(state, DateTime(2026, 7, 21));
      expect(nextDay.activeDay, '2026-07-21');
      expect(nextDay.completedToday, <bool>[false, false, false]);
      expect(nextDay.lifetimeCompletions, 14);
      expect(nextDay.fedToday, isNull);
      expect(nextDay.taskTitles, state.taskTitles);
    },
  );

  test('rolling over multiple missed days leaves no historical markers', () {
    final state = AppState.initial(DateTime(2026, 7, 1)).copyWith(
      completedToday: const <bool>[false, true, false],
      lifetimeCompletions: 6,
    );
    final result = rollOverIfNeeded(state, DateTime(2026, 8, 10, 9));
    expect(result.completedToday, everyElement(isFalse));
    expect(result.activeDay, '2026-08-10');
    expect(result.lifetimeCompletions, 6);
  });
}
