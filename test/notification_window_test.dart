import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/notification_service.dart';

void main() {
  test('shared window is sorted and capped at 32 slots', () {
    final now = DateTime(2026, 7, 20, 8, 30);
    final result = buildNotificationWindow(
      petName: 'Choco',
      now: now,
      includeDailyInvitation: true,
      invitationHour: 20,
      invitationMinute: 0,
      taskReminders: const <TaskReminderSchedule>[
        TaskReminderSchedule(
          taskId: 'water',
          title: 'Drink water',
          hour: 9,
          minute: 0,
        ),
        TaskReminderSchedule(
          taskId: 'walk',
          title: 'Take a walk',
          hour: 18,
          minute: 30,
        ),
      ],
    );

    expect(result, hasLength(notificationWindowSize));
    expect(result.first.taskId, 'water');
    expect(result.first.body, 'Time for Drink water ~');
    expect(result.map((item) => item.id).toSet(), hasLength(32));
    for (var index = 1; index < result.length; index++) {
      expect(
        result[index].scheduledAt.isBefore(result[index - 1].scheduledAt),
        isFalse,
      );
    }
  });

  test(
    'each task fires at most once per local day and completed daily skips today',
    () {
      final result = buildNotificationWindow(
        petName: 'Choco',
        now: DateTime(2026, 7, 20, 8),
        includeDailyInvitation: false,
        invitationHour: 20,
        invitationMinute: 0,
        taskReminders: const <TaskReminderSchedule>[
          TaskReminderSchedule(
            taskId: 'water',
            title: 'Water',
            hour: 9,
            minute: 0,
            skipToday: true,
          ),
        ],
      );

      expect(result.first.scheduledAt, DateTime(2026, 7, 21, 9));
      final taskDays = result
          .map(
            (item) =>
                '${item.taskId}-${item.scheduledAt.year}-${item.scheduledAt.month}-${item.scheduledAt.day}',
          )
          .toSet();
      expect(taskDays, hasLength(result.length));
    },
  );
}
