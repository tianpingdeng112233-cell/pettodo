import 'dart:math' as math;

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
  }) : scheduledAt = null;

  const TaskReminderSchedule.once({
    required this.taskId,
    required this.title,
    required this.scheduledAt,
  }) : hour = 0,
       minute = 0,
       skipToday = false;

  final String taskId;
  final String title;
  final int hour;
  final int minute;
  final bool skipToday;
  final DateTime? scheduledAt;
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

class OverlayBubbleInvitation {
  const OverlayBubbleInvitation({
    required this.scheduledAt,
    required this.copy,
  });

  final DateTime scheduledAt;
  final String copy;
}

const String overlayInvitationCopy = "Want to look at today's little things?";

List<OverlayBubbleInvitation> buildOverlayBubbleSchedule(
  List<ScheduledPetNotification> notificationWindow, {
  required DateTime now,
  int dailyCap = 1,
}) {
  if (dailyCap <= 0) return const <OverlayBubbleInvitation>[];
  final invitations =
      notificationWindow
          .where(
            (item) =>
                item.kind == PetNotificationKind.dailyInvitation &&
                item.scheduledAt.isAfter(now),
          )
          .toList(growable: false)
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  final countsByDay = <(int, int, int), int>{};
  final result = <OverlayBubbleInvitation>[];
  for (final invitation in invitations) {
    final at = invitation.scheduledAt;
    final day = (at.year, at.month, at.day);
    final count = countsByDay[day] ?? 0;
    if (count >= dailyCap) continue;
    countsByDay[day] = count + 1;
    result.add(
      OverlayBubbleInvitation(
        scheduledAt: invitation.scheduledAt,
        copy: overlayInvitationCopy,
      ),
    );
  }
  return List<OverlayBubbleInvitation>.unmodifiable(result);
}

const int notificationWindowSize = 32;

/// Minutes of random spread applied either side of the chosen invitation time.
const int invitationJitterMinutes = 10;

/// Jitter may never push an invitation outside these local hours.
const int invitationEarliestHour = 6;
const int invitationLatestHour = 23;

/// Days between invitations, as a function of how many days into the silence a
/// given day falls. The pet does not chase: after a few quiet days it settles
/// into its own rhythm rather than knocking daily.
///
/// Opening the app is the reset, and it needs no bookkeeping: the whole window
/// is rebuilt on every open, so day N of the freshly-built window is by
/// definition N days after the last time the user was here.
int invitationCadenceForAbsence(int daysAbsent) {
  if (daysAbsent >= 14) return 7;
  if (daysAbsent >= 7) return 4;
  if (daysAbsent >= 3) return 2;
  return 1;
}

/// After a week of silence, per-task reminders stop entirely until the user
/// comes back. A reminder about a task list nobody has seen in a week is pure
/// debt.
const int taskReminderAbsenceCutoff = 7;

/// How far ahead invitations are scheduled — deliberately decoupled from the
/// slot count. Once back-off thins the cadence to weekly, a 32-day calendar
/// would run out of invitations entirely and the pet would fall silent for good
/// after a month away. Reaching further ahead keeps a slow heartbeat going
/// without ever raising the per-day frequency. It does not fill all 32 slots,
/// and is not meant to: the budget is a ceiling, not a quota.
const int invitationHorizonDays = 120;

List<ScheduledPetNotification> buildNotificationWindow({
  required String petName,
  required DateTime now,
  required bool includeDailyInvitation,
  required int invitationHour,
  required int invitationMinute,
  required List<TaskReminderSchedule> taskReminders,
  int recurringLimit = notificationWindowSize,
  math.Random? random,
}) {
  if (recurringLimit <= 0) return const <ScheduledPetNotification>[];
  final rng = random ?? math.Random();
  final candidates = <ScheduledPetNotification>[];
  final timedCandidates = <ScheduledPetNotification>[];

  if (includeDailyInvitation) {
    var previousTemplate = -1;
    for (var dayOffset = 0; dayOffset <= invitationHorizonDays; dayOffset++) {
      // Silence accrues across the window, so the cadence thins out on its own
      // the longer the user stays away — and snaps back to daily the moment
      // they return, because returning rebuilds this window from day 0.
      if (dayOffset % invitationCadenceForAbsence(dayOffset) != 0) continue;

      final day = DateTime(now.year, now.month, now.day + dayOffset);
      final jitter =
          rng.nextInt(invitationJitterMinutes * 2 + 1) -
          invitationJitterMinutes;
      final at = _clampToInvitationHours(
        DateTime(
          day.year,
          day.month,
          day.day,
          invitationHour,
          invitationMinute + jitter,
        ),
        day,
      );
      if (!at.isAfter(now)) continue;

      // Random, never twice in a row: a fixed rotation is a pattern the brain
      // learns to filter out, which is how these become invisible.
      var pick = rng.nextInt(_invitationTemplates.length);
      if (pick == previousTemplate) {
        pick =
            (pick + 1 + rng.nextInt(_invitationTemplates.length - 1)) %
            _invitationTemplates.length;
      }
      previousTemplate = pick;
      final template = _invitationTemplates[pick];
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
    final scheduledAt = reminder.scheduledAt;
    if (scheduledAt != null) {
      if (scheduledAt.isAfter(now)) {
        timedCandidates.add(
          ScheduledPetNotification(
            id: 0,
            scheduledAt: scheduledAt,
            title: '$petName brought this along',
            body: '${reminder.title} is here for this one moment.',
            kind: PetNotificationKind.taskReminder,
            taskId: reminder.taskId,
          ),
        );
      }
      continue;
    }
    for (var dayOffset = 0; dayOffset <= recurringLimit; dayOffset++) {
      if (dayOffset == 0 && reminder.skipToday) continue;
      if (dayOffset >= taskReminderAbsenceCutoff) continue;
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
  timedCandidates.sort((a, b) {
    final time = a.scheduledAt.compareTo(b.scheduledAt);
    if (time != 0) return time;
    return (a.taskId ?? '').compareTo(b.taskId ?? '');
  });
  final selected =
      <ScheduledPetNotification>[
        ...candidates.take(recurringLimit),
        ...timedCandidates,
      ]..sort((a, b) {
        final time = a.scheduledAt.compareTo(b.scheduledAt);
        if (time != 0) return time;
        return (a.taskId ?? '').compareTo(b.taskId ?? '');
      });
  return List<ScheduledPetNotification>.unmodifiable(
    selected.indexed.map(
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

const int adoptionReadyNotificationId = 990001;

class NotificationService {
  /// Immediate local notification for a finished adoption; gentle wording,
  /// never a demand (zero-punishment line).
  Future<void> showHatchReady({required String petName}) async {
    try {
      await _plugin.show(
        id: adoptionReadyNotificationId,
        title: '$petName is ready to meet you',
        body: 'Your new friend has settled in whenever you are.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'pet_invitations',
            'Pet invitations',
          ),
        ),
      );
    } on Object {
      // notifications must never break the adoption flow
    }
  }

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int firstNotificationId = 2000;
  static const int maximumScheduledNotificationCount =
      notificationWindowSize + 7;
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

  Future<List<ScheduledPetNotification>> scheduleWindow({
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
    return window;
  }

  Future<void> cancelScheduled() async {
    for (var index = 0; index < maximumScheduledNotificationCount; index++) {
      await _plugin.cancel(id: firstNotificationId + index);
    }
  }
}

DateTime _clampToInvitationHours(DateTime at, DateTime day) {
  final earliest = DateTime(
    day.year,
    day.month,
    day.day,
    invitationEarliestHour,
  );
  final latest = DateTime(day.year, day.month, day.day, invitationLatestHour);
  if (at.isBefore(earliest)) return earliest;
  if (at.isAfter(latest)) return latest;
  return at;
}

/// The pet reports its own day. It never waits, never misses the user, never
/// asks them to come — opening the app is joining a good day already in
/// progress, not repaying a debt (red line 4, docs/PRODUCT-PRINCIPLES.md).
///
/// Copy rules these were written to: no "waiting for you / miss you / come back
/// / don't forget", and equally no pep talk ("you've got this"). One concrete
/// image each. See the forbidden-substring test in
/// test/notification_window_test.dart, which fails the build if this drifts.
const List<(String, String)> _invitationTemplates = <(String, String)>[
  (
    '{pet} found a sunbeam',
    'It kept moving across the floor. {pet} followed it the whole afternoon.',
  ),
  (
    'A bird visited the window',
    '{pet} watched it hop around the sill. Neither of them blinked much.',
  ),
  (
    'Big stretch report',
    'Front paws way out, tail up high. {pet} rates it a perfect ten.',
  ),
  (
    '{pet} guarded the couch today',
    'Nothing got past. The cushions are all accounted for.',
  ),
  (
    'Evening light is in',
    '{pet} is curled up in the warmest corner of the room.',
  ),
  (
    '{pet} did one little thing today',
    'Sniffed the whole hallway, twice. Very thorough work.',
  ),
  (
    'Nap update from {pet}',
    'Three naps, all excellent. The afternoon one was the best.',
  ),
  (
    '{pet} heard something outside',
    'Investigated bravely. It was leaves. Case closed.',
  ),
  (
    'The house is cozy tonight',
    '{pet} made a nest out of the soft blanket. Engineering at its finest.',
  ),
  ('{pet} practiced looking cute', 'No practice was needed, honestly.'),
  (
    'Small adventure today',
    '{pet} discovered a new smell by the door and thought about it a lot.',
  ),
  ('{pet} is watching the sky', 'Clouds today. Slow ones. Good watching.'),
];
