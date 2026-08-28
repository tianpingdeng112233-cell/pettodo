import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/notification_service.dart';

/// Fixed-sequence RNG so jitter and template picks are reproducible.
class _SeqRandom implements math.Random {
  _SeqRandom(this._values);
  final List<int> _values;
  int _index = 0;

  @override
  int nextInt(int max) {
    final value = _values[_index++ % _values.length];
    return value % max;
  }

  @override
  bool nextBool() => nextInt(2) == 0;
  @override
  double nextDouble() => nextInt(1000) / 1000;
}

List<ScheduledPetNotification> _invitations(
  List<ScheduledPetNotification> window,
) => window
    .where((item) => item.kind == PetNotificationKind.dailyInvitation)
    .toList();

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

  // The pet does not chase. Silence thins the cadence out instead of knocking
  // every day; coming back rebuilds the window from day 0, which IS the reset.
  test('invitations back off the longer the app stays unopened', () {
    final now = DateTime(2026, 7, 20, 8);
    final window = buildNotificationWindow(
      petName: 'Choco',
      now: now,
      includeDailyInvitation: true,
      invitationHour: 20,
      invitationMinute: 0,
      taskReminders: const <TaskReminderSchedule>[],
      random: _SeqRandom(const <int>[5]),
    );
    final offsets = _invitations(window)
        .map(
          (item) => item.scheduledAt.difference(DateTime(2026, 7, 20)).inDays,
        )
        .toList();

    // Daily for the first three days, then every 2nd, 4th and finally weekly.
    expect(offsets.take(3), <int>[0, 1, 2]);
    expect(offsets.where((d) => d >= 3 && d < 7), <int>[4, 6]);
    expect(offsets.where((d) => d >= 7 && d < 14), <int>[8, 12]);
    expect(offsets.where((d) => d >= 14 && d < 36), <int>[14, 21, 28, 35]);
    // The 32 slots are a ceiling, not a quota: backing off is meant to use
    // fewer of them, and the leftovers stay available for task reminders.
    expect(window.length, lessThanOrEqualTo(notificationWindowSize));
    // Still reaches months ahead rather than going silent after the ladder
    // thins out — the weekly tier keeps scheduling.
    expect(offsets.last, greaterThan(90));
  });

  test('task reminders stop after a week of silence', () {
    final window = buildNotificationWindow(
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
        ),
      ],
    );
    final lastDay = window
        .map(
          (item) => item.scheduledAt.difference(DateTime(2026, 7, 20)).inDays,
        )
        .reduce(math.max);
    expect(lastDay, taskReminderAbsenceCutoff - 1);
  });

  test(
    'invitation times jitter within ten minutes and stay in waking hours',
    () {
      // Values chosen to exercise both extremes of the jitter range.
      final window = buildNotificationWindow(
        petName: 'Choco',
        now: DateTime(2026, 7, 20, 0, 1),
        includeDailyInvitation: true,
        invitationHour: 20,
        invitationMinute: 0,
        taskReminders: const <TaskReminderSchedule>[],
        random: _SeqRandom(const <int>[0, 20, 7, 13, 3]),
      );
      for (final item in _invitations(window)) {
        final minutes = item.scheduledAt.hour * 60 + item.scheduledAt.minute;
        expect(
          (minutes - 20 * 60).abs(),
          lessThanOrEqualTo(invitationJitterMinutes),
        );
      }

      // A late slot must not be pushed past the cutoff by jitter.
      final late = buildNotificationWindow(
        petName: 'Choco',
        now: DateTime(2026, 7, 20, 0, 1),
        includeDailyInvitation: true,
        invitationHour: invitationLatestHour,
        invitationMinute: 55,
        taskReminders: const <TaskReminderSchedule>[],
        random: _SeqRandom(const <int>[20]),
      );
      for (final item in _invitations(late)) {
        expect(item.scheduledAt.hour, lessThanOrEqualTo(invitationLatestHour));
        expect(
          item.scheduledAt.hour,
          greaterThanOrEqualTo(invitationEarliestHour),
        );
      }
    },
  );

  test('the same invitation never lands two scheduled days in a row', () {
    final window = buildNotificationWindow(
      petName: 'Choco',
      now: DateTime(2026, 7, 20, 8),
      includeDailyInvitation: true,
      invitationHour: 20,
      invitationMinute: 0,
      taskReminders: const <TaskReminderSchedule>[],
      // Always draws the same index, so the anti-repeat rule must do the work.
      random: _SeqRandom(const <int>[0]),
    );
    final bodies = _invitations(window).map((item) => item.body).toList();
    for (var index = 1; index < bodies.length; index++) {
      expect(bodies[index], isNot(bodies[index - 1]));
    }
  });

  // Red line 4: the pet reports its own day and never asks the user to come
  // back. This test is the guard rail — it fails the build if the copy drifts.
  test('no invitation copy puts the user in debt', () {
    const forbidden = <String>[
      'waiting for you',
      'miss you',
      'misses you',
      'come back',
      'come home',
      "don't forget",
      'see you',
      'you can do it',
      "you've got this",
      'why not',
      'are you there',
    ];
    final window = buildNotificationWindow(
      petName: 'Choco',
      now: DateTime(2026, 7, 20, 8),
      includeDailyInvitation: true,
      invitationHour: 20,
      invitationMinute: 0,
      taskReminders: const <TaskReminderSchedule>[],
      random: _SeqRandom(const <int>[3, 11, 5, 2, 9, 1, 7]),
    );
    for (final item in _invitations(window)) {
      final text = '${item.title} ${item.body}'.toLowerCase();
      for (final phrase in forbidden) {
        expect(
          text.contains(phrase),
          isFalse,
          reason: '"$phrase" found in: $text',
        );
      }
    }
  });

  test('overlay bubble schedule prunes past times and caps each local day', () {
    final now = DateTime(2026, 7, 20, 10);
    final window = <ScheduledPetNotification>[
      ScheduledPetNotification(
        id: 1,
        scheduledAt: DateTime(2026, 7, 20, 9),
        title: 'Past invitation',
        body: 'Past',
        kind: PetNotificationKind.dailyInvitation,
      ),
      ScheduledPetNotification(
        id: 2,
        scheduledAt: DateTime(2026, 7, 20, 18),
        title: 'First invitation',
        body: 'First',
        kind: PetNotificationKind.dailyInvitation,
      ),
      ScheduledPetNotification(
        id: 3,
        scheduledAt: DateTime(2026, 7, 20, 20),
        title: 'Second same-day invitation',
        body: 'Second',
        kind: PetNotificationKind.dailyInvitation,
      ),
      ScheduledPetNotification(
        id: 4,
        scheduledAt: DateTime(2026, 7, 21, 9),
        title: 'Task reminder',
        body: 'Task copy must not enter the overlay',
        kind: PetNotificationKind.taskReminder,
        taskId: 'water',
      ),
      ScheduledPetNotification(
        id: 5,
        scheduledAt: DateTime(2026, 7, 21, 18),
        title: 'Tomorrow invitation',
        body: 'Tomorrow',
        kind: PetNotificationKind.dailyInvitation,
      ),
    ];

    final result = buildOverlayBubbleSchedule(window, now: now);

    expect(result.map((item) => item.scheduledAt), <DateTime>[
      DateTime(2026, 7, 20, 18),
      DateTime(2026, 7, 21, 18),
    ]);
    expect(
      result.map((item) => item.copy),
      everyElement(overlayInvitationCopy),
    );
    expect(result, hasLength(2));
  });
}
