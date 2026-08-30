import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Records only the calls scheduleWindow/cancelScheduled make; every other
/// plugin member is unused by those paths and answers with a completed future.
class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  /// Ordered log: ('cancel', id) and ('schedule', id) events as they happen.
  final List<(String, int)> events = <(String, int)>[];

  List<int> idsOf(String kind) => events
      .where((event) => event.$1 == kind)
      .map((event) => event.$2)
      .toList(growable: false);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #cancel) {
      events.add(('cancel', invocation.namedArguments[#id]! as int));
      return Future<void>.value();
    }
    if (invocation.memberName == #zonedSchedule) {
      events.add(('schedule', invocation.namedArguments[#id]! as int));
      return Future<void>.value();
    }
    return Future<void>.value();
  }
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('scheduleWindow cancels the full id range then schedules each item '
      'exactly once', () async {
    final plugin = _RecordingPlugin();
    final service = NotificationService(plugin: plugin);
    final now = DateTime(2026, 8, 30, 12);

    final window = await service.scheduleWindow(
      petName: 'Choco',
      includeDailyInvitation: false,
      invitationHour: 9,
      invitationMinute: 0,
      taskReminders: <TaskReminderSchedule>[
        TaskReminderSchedule.once(
          taskId: 'vet',
          title: 'Call the vet',
          scheduledAt: DateTime(2026, 8, 31, 15),
        ),
      ],
      now: now,
    );

    // Cancels cover the exact reserved id range, each id exactly once.
    final expectedCancelIds = List<int>.generate(
      NotificationService.maximumScheduledNotificationCount,
      (index) => NotificationService.firstNotificationId + index,
    );
    expect(plugin.idsOf('cancel'), expectedCancelIds);
    // Every cancel happens before the first schedule.
    final firstSchedule = plugin.events.indexWhere(
      (event) => event.$1 == 'schedule',
    );
    expect(
      plugin.events.take(firstSchedule).every((event) => event.$1 == 'cancel'),
      isTrue,
    );
    // Scheduled ids match the returned window one-to-one.
    expect(
      plugin.idsOf('schedule'),
      window.map((item) => item.id).toList(growable: false),
    );
    final timed = window.where(
      (item) => item.kind == PetNotificationKind.taskReminder,
    );
    expect(timed.map((item) => item.taskId), contains('vet'));

    // A second refresh cancels the full range again — no stale shot survives.
    plugin.events.clear();
    await service.scheduleWindow(
      petName: 'Choco',
      includeDailyInvitation: false,
      invitationHour: 9,
      invitationMinute: 0,
      taskReminders: const <TaskReminderSchedule>[],
      now: now,
    );
    expect(plugin.idsOf('cancel'), expectedCancelIds);
  });
}
