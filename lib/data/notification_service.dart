import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

typedef NotificationTapCallback = Future<void> Function();

enum PetNotificationKind { dailyInvitation, taskReminder }

class TaskReminderSchedule {
  const TaskReminderSchedule({
    required this.taskId,
    required this.title,
    required this.hour,
    required this.minute,
    this.skipToday = false,
  });

  final String taskId;
  final String title;
  final int hour;
  final int minute;
  final bool skipToday;
}

class ScheduledPetNotification {
  const ScheduledPetNotification({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.kind,
    this.taskId,
  });

  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final PetNotificationKind kind;
  final String? taskId;
}

const int notificationWindowSize = 32;

List<ScheduledPetNotification> buildNotificationWindow({
  required String petName,
  required DateTime now,
  required bool includeDailyInvitation,
  required int invitationHour,
  required int invitationMinute,
  required List<TaskReminderSchedule> taskReminders,
  int limit = notificationWindowSize,
}) {
  if (limit <= 0) return const <ScheduledPetNotification>[];
  final candidates = <ScheduledPetNotification>[];

  if (includeDailyInvitation) {
    for (var dayOffset = 0; dayOffset <= limit; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day + dayOffset);
      final at = DateTime(
        day.year,
        day.month,
        day.day,
        invitationHour,
        invitationMinute,
      );
      if (!at.isAfter(now)) continue;
      final template =
          _invitationTemplates[dayOffset % _invitationTemplates.length];
      candidates.add(
        ScheduledPetNotification(
          id: 0,
          scheduledAt: at,
          title: template.$1.replaceAll('{pet}', petName),
          body: template.$2.replaceAll('{pet}', petName),
          kind: PetNotificationKind.dailyInvitation,
        ),
      );
    }
  }

  for (final reminder in taskReminders) {
    for (var dayOffset = 0; dayOffset <= limit; dayOffset++) {
      if (dayOffset == 0 && reminder.skipToday) continue;
      final day = DateTime(now.year, now.month, now.day + dayOffset);
      final at = DateTime(
        day.year,
        day.month,
        day.day,
        reminder.hour,
        reminder.minute,
      );
      if (!at.isAfter(now)) continue;
      candidates.add(
        ScheduledPetNotification(
          id: 0,
          scheduledAt: at,
          title: '$petName reminds you',
          body: 'Time for ${reminder.title} ~',
          kind: PetNotificationKind.taskReminder,
          taskId: reminder.taskId,
        ),
      );
    }
  }

  candidates.sort((a, b) {
    final time = a.scheduledAt.compareTo(b.scheduledAt);
    if (time != 0) return time;
    return (a.taskId ?? '').compareTo(b.taskId ?? '');
  });
  return List<ScheduledPetNotification>.unmodifiable(
    candidates
        .take(limit)
        .indexed
        .map(
          (entry) => ScheduledPetNotification(
            id: NotificationService.firstNotificationId + entry.$1,
            scheduledAt: entry.$2.scheduledAt,
            title: entry.$2.title,
            body: entry.$2.body,
            kind: entry.$2.kind,
            taskId: entry.$2.taskId,
          ),
        ),
  );
}

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int firstNotificationId = 2000;
  static const String _payload = 'pettodo_invitation';

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize(NotificationTapCallback onTap) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload == _payload) await onTap();
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) await onTap();
  }

  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: false) ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return false;
  }

  Future<void> scheduleWindow({
    required String petName,
    required bool includeDailyInvitation,
    required int invitationHour,
    required int invitationMinute,
    required List<TaskReminderSchedule> taskReminders,
    DateTime? now,
  }) async {
    await cancelScheduled();
    final window = buildNotificationWindow(
      petName: petName,
      now: now ?? DateTime.now(),
      includeDailyInvitation: includeDailyInvitation,
      invitationHour: invitationHour,
      invitationMinute: invitationMinute,
      taskReminders: taskReminders,
    );
    for (final item in window) {
      final scheduled = tz.TZDateTime.from(item.scheduledAt.toUtc(), tz.UTC);
      await _plugin.zonedSchedule(
        id: item.id,
        title: item.title,
        body: item.body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'pet_invitations',
            'Pet invitations',
            channelDescription: 'Gentle one-time invitations from your pet',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _payload,
      );
    }
  }

  Future<void> cancelScheduled() async {
    for (var index = 0; index < notificationWindowSize; index++) {
      await _plugin.cancel(id: firstNotificationId + index);
    }
  }
}

const List<(String, String)> _invitationTemplates = <(String, String)>[
  (
    '{pet} is waiting by the window ~',
    'The evening light is warm. Come home and do one little thing with me?',
  ),
  (
    'A soft hello from {pet}',
    'No rush at all — I just wanted to see you. Even one little thing counts.',
  ),
  (
    '{pet} fluffed your cushion',
    'I saved you the sunniest spot on the couch. Come tell me about your day?',
  ),
];
