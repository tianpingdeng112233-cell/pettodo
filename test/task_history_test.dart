import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/event_log.dart';
import 'package:pettodo/domain/task_history.dart';

void main() {
  test(
    'history groups completion events by local Monday week and omits empty weeks',
    () {
      final weeks = aggregatePositiveHistory(<PetEvent>[
        PetEvent(
          type: PetEventType.taskComplete,
          timestamp: DateTime(2026, 7, 20, 9),
          data: const <String, Object?>{'taskId': 'a', 'title': 'Water'},
        ),
        PetEvent(
          type: PetEventType.oneoffComplete,
          timestamp: DateTime(2026, 7, 22, 18),
          data: const <String, Object?>{'taskId': 'b', 'title': 'Post letter'},
        ),
        PetEvent(
          type: PetEventType.taskAdd,
          timestamp: DateTime(2026, 7, 28),
          data: const <String, Object?>{'taskId': 'c', 'title': 'Not complete'},
        ),
        PetEvent(
          type: PetEventType.taskComplete,
          timestamp: DateTime(2026, 8, 3, 12),
          data: const <String, Object?>{'taskId': 'd', 'title': 'Stretch'},
        ),
      ]);

      expect(weeks, hasLength(2));
      expect(weeks.first.weekStart, DateTime(2026, 8, 3));
      expect(weeks.first.total, 1);
      expect(weeks.last.weekStart, DateTime(2026, 7, 20));
      expect(weeks.last.total, 2);
      expect(weeks.last.days, hasLength(2));
      expect(weeks.last.days.first.items.first.title, 'Post letter');
    },
  );

  test('legacy completion without a title is not shown as a blank item', () {
    final result = aggregatePositiveHistory(<PetEvent>[
      PetEvent(
        type: PetEventType.taskComplete,
        timestamp: DateTime(2026, 7, 20),
        data: const <String, Object?>{'taskIndex': 0},
      ),
    ]);
    expect(result, isEmpty);
  });
}
