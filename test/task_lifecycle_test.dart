import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/event_log.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';

class _LifecycleSpriteLoader extends SpriteAtlasLoader {
  _LifecycleSpriteLoader(this.image);

  final ui.Image image;

  static const descriptor = PetAssetDescriptor(
    id: 'choco',
    displayName: 'Choco',
    metadataAsset: 'fake',
    spritesheetAsset: 'fake',
  );

  @override
  Future<List<PetAssetDescriptor>> loadManifest() async =>
      const <PetAssetDescriptor>[descriptor];

  @override
  Future<List<DecorAssetDescriptor>> loadDecorManifest() async =>
      const <DecorAssetDescriptor>[];

  @override
  Future<LoadedSpriteAtlas> loadPet(
    PetAssetDescriptor descriptor, {
    String? growthStage,
  }) async => LoadedSpriteAtlas(
    descriptor: descriptor,
    definition: SpriteAtlasDefinition(
      petId: 'choco',
      columns: 1,
      rows: 1,
      cellWidth: 1,
      cellHeight: 1,
      imageWidth: 1,
      imageHeight: 1,
      sequences: <String, SpriteSequenceDefinition>{},
    ),
    image: image,
  );
}

Future<ui.Image> _image() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  return recorder.endRecording().toImage(1, 1);
}

class _FakeNotifications extends NotificationService {
  _FakeNotifications({required this.grant});

  final bool grant;
  int permissionRequests = 0;
  int scheduleRefreshes = 0;
  int cancelRefreshes = 0;
  final List<List<TaskReminderSchedule>> scheduledTaskReminders =
      <List<TaskReminderSchedule>>[];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<List<ScheduledPetNotification>> scheduleWindow({
    required String petName,
    required bool includeDailyInvitation,
    required int invitationHour,
    required int invitationMinute,
    required List<TaskReminderSchedule> taskReminders,
    DateTime? now,
  }) async {
    await cancelScheduled();
    scheduleRefreshes++;
    scheduledTaskReminders.add(List<TaskReminderSchedule>.of(taskReminders));
    return const <ScheduledPetNotification>[];
  }

  @override
  Future<void> cancelScheduled() async {
    cancelRefreshes++;
  }
}

void main() {
  testWidgets('crossing a milestone awards and places its furniture', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('pettodo-milestone');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/pettodo-state.json').writeAsStringSync(
      jsonEncode(<String, Object?>{
        'schemaVersion': 4,
        'onboardingComplete': true,
        'selectedPetId': 'choco',
        'petName': 'Choco',
        'tasks': <Object?>[
          <String, Object?>{
            'id': 'daily-water',
            'title': 'Water',
            'kind': 'daily',
          },
        ],
        'activeDay': '2026-08-28',
        'lifetimeCompletions': 4,
        'unlockedDecorIds': const <String>[],
        'ownedFurnitureIds': const <String>[],
        'placedFurnitureBySlot': const <String, String>{},
        'treats': 0,
      }),
    );
    late AppController controller;

    await tester.runAsync(() async {
      controller = AppController(
        stateStore: AppStateStore(() async => directory),
        eventLog: EventLogStore(() async => directory),
        notifications: _FakeNotifications(grant: false),
        spriteLoader: _LifecycleSpriteLoader(await _image()),
      );
      await controller.initialize();
      expect(await controller.completeTask('daily-water'), isTrue);
    });
    addTearDown(controller.dispose);

    expect(controller.state.lifetimeCompletions, 5);
    expect(controller.state.ownedFurnitureIds, <String>{'rug'});
    expect(controller.state.placedFurnitureBySlot, <String, String>{
      'rug': 'rug',
    });
  });

  testWidgets(
    'one-off completion drops a treat, archives the task, and logs history data',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'pettodo-lifecycle',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      late AppController controller;
      late EventLogStore log;

      await tester.runAsync(() async {
        log = EventLogStore(() async => directory);
        controller = AppController(
          stateStore: AppStateStore(() async => directory),
          eventLog: log,
          notifications: NotificationService(),
          spriteLoader: _LifecycleSpriteLoader(await _image()),
        );
        await controller.initialize();
        expect(await controller.addTask(title: 'Post the letter'), isTrue);
        final oneOff = controller.state.tasks.last;
        expect(oneOff.kind.name, 'oneOff');

        expect(await controller.completeTask(oneOff.id), isTrue);
        expect(controller.state.taskById(oneOff.id), isNull);
        expect(controller.state.lifetimeCompletions, 1);
        expect(controller.state.treats, 1);
        expect(controller.theaterVisible, isFalse);
      });
      addTearDown(controller.dispose);

      final events = await tester.runAsync(log.readAll) ?? const <PetEvent>[];
      final completion = events.singleWhere(
        (event) => event.type == PetEventType.oneoffComplete,
      );
      expect(completion.data?['title'], 'Post the letter');
      expect(completion.data?['treatDrop'], 1);
    },
  );

  testWidgets(
    'a denied reminder permission is remembered and never requested twice',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('pettodo-reminder');
      addTearDown(() => directory.deleteSync(recursive: true));
      final notifications = _FakeNotifications(grant: false);
      late AppController controller;

      await tester.runAsync(() async {
        controller = AppController(
          stateStore: AppStateStore(() async => directory),
          eventLog: EventLogStore(() async => directory),
          notifications: notifications,
          spriteLoader: _LifecycleSpriteLoader(await _image()),
        );
        await controller.initialize();
        final taskId = controller.state.tasks.first.id;
        expect(
          await controller.setTaskReminder(
            taskId: taskId,
            enabled: true,
            hour: 9,
            minute: 30,
          ),
          isFalse,
        );
        expect(
          await controller.setTaskReminder(
            taskId: taskId,
            enabled: true,
            hour: 10,
            minute: 0,
          ),
          isFalse,
        );
        expect(controller.state.notificationPermission.name, 'denied');
        expect(notifications.permissionRequests, 1);
        expect(notifications.scheduleRefreshes, 0);
      });
      addTearDown(controller.dispose);
    },
  );

  testWidgets(
    'timed reminder set, change, delete, and completion each refresh once',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'pettodo-timed-reminder',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final notifications = _FakeNotifications(grant: true);
      late AppController controller;

      await tester.runAsync(() async {
        controller = AppController(
          stateStore: AppStateStore(() async => directory),
          eventLog: EventLogStore(() async => directory),
          notifications: notifications,
          spriteLoader: _LifecycleSpriteLoader(await _image()),
          now: () => DateTime(2026, 8, 30, 12),
        );
        await controller.initialize();
        await controller.addTask(title: 'Meet Sam');
        final taskId = controller.state.tasks.last.id;
        final firstAt = DateTime(2026, 8, 31, 15);
        final changedAt = DateTime(2026, 9, 1, 16, 30);

        expect(
          await controller.setTaskReminder(
            taskId: taskId,
            enabled: true,
            hour: firstAt.hour,
            minute: firstAt.minute,
            scheduledAt: firstAt,
          ),
          isTrue,
        );
        expect(notifications.scheduleRefreshes, 1);
        expect(notifications.cancelRefreshes, 1);
        expect(
          notifications.scheduledTaskReminders.single.single.scheduledAt,
          firstAt,
        );

        await controller.setTaskReminder(
          taskId: taskId,
          enabled: true,
          hour: changedAt.hour,
          minute: changedAt.minute,
          scheduledAt: changedAt,
        );
        expect(notifications.scheduleRefreshes, 2);
        expect(notifications.cancelRefreshes, 2);
        expect(
          notifications.scheduledTaskReminders.last.single.scheduledAt,
          changedAt,
        );

        await controller.removeTask(taskId);
        expect(notifications.scheduleRefreshes, 3);
        expect(notifications.cancelRefreshes, 3);
        expect(notifications.scheduledTaskReminders.last, isEmpty);

        await controller.addTask(title: 'Post the letter');
        final completingTaskId = controller.state.tasks.last.id;
        await controller.setTaskReminder(
          taskId: completingTaskId,
          enabled: true,
          hour: firstAt.hour,
          minute: firstAt.minute,
          scheduledAt: firstAt,
        );
        expect(notifications.scheduleRefreshes, 4);
        expect(notifications.cancelRefreshes, 4);
        await controller.completeTask(completingTaskId);
        expect(notifications.scheduleRefreshes, 5);
        expect(notifications.cancelRefreshes, 5);
        expect(notifications.scheduledTaskReminders.last, isEmpty);
      });
      addTearDown(controller.dispose);
    },
  );

  testWidgets('legacy one-off reminder still enters the daily schedule path', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'pettodo-legacy-reminder',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final notifications = _FakeNotifications(grant: true);
    late AppStateStore store;
    late AppController controller;

    await tester.runAsync(() async {
      // Stores must be constructed inside runAsync (IMPLEMENTATION-NOTES:
      // their Future chains otherwise bind to the fake zone and deadlock).
      store = AppStateStore(() async => directory);
      await store.save(
        AppState.initial(DateTime(2026, 8, 30)).copyWith(
          notificationPermission: NotificationPermissionState.granted,
          tasks: const <TodoTask>[
            TodoTask(id: 'daily', title: 'Water', kind: TaskKind.daily),
            TodoTask(
              id: 'legacy',
              title: 'Old one-off',
              kind: TaskKind.oneOff,
              reminder: TaskReminder(hour: 10, minute: 30),
            ),
          ],
        ),
      );
      controller = AppController(
        stateStore: store,
        eventLog: EventLogStore(() async => directory),
        notifications: notifications,
        spriteLoader: _LifecycleSpriteLoader(await _image()),
        now: () => DateTime(2026, 8, 30, 12),
      );
      await controller.initialize();

      final scheduled = notifications.scheduledTaskReminders.single.single;
      expect(scheduled.taskId, 'legacy');
      expect(scheduled.scheduledAt, isNull);
      expect(scheduled.hour, 10);
      expect(scheduled.minute, 30);
    });
    addTearDown(controller.dispose);
  });

  testWidgets('focus completion awards once without changing task milestones', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('pettodo-focus');
    addTearDown(() => directory.deleteSync(recursive: true));
    var now = DateTime(2026, 8, 30, 9);
    late AppController controller;
    late EventLogStore log;

    await tester.runAsync(() async {
      log = EventLogStore(() async => directory);
      controller = AppController(
        stateStore: AppStateStore(() async => directory),
        eventLog: log,
        notifications: NotificationService(),
        spriteLoader: _LifecycleSpriteLoader(await _image()),
      );
      await controller.initialize();
      final beforeCompletions = controller.state.lifetimeCompletions;
      final beforeUnlocks = controller.state.unlockedDecorIds;
      final session = controller.createFocusSession(
        durationMinutes: 15,
        taskId: controller.state.tasks.first.id,
        now: () => now,
        tickInterval: null,
      );
      session.start();
      now = now.add(const Duration(minutes: 15));
      await session.tick();
      await session.tick();

      expect(controller.state.treats, 1);
      expect(controller.state.lifetimeCompletions, beforeCompletions);
      expect(controller.state.unlockedDecorIds, orderedEquals(beforeUnlocks));
      session.dispose();

      final abandoned = controller.createFocusSession(
        durationMinutes: 5,
        now: () => now,
        tickInterval: null,
      );
      abandoned.start();
      now = now.add(const Duration(minutes: 2));
      abandoned.abandon();
      await abandoned.tick();
      expect(controller.state.treats, 1);
      abandoned.dispose();
    });
    addTearDown(controller.dispose);

    final events = await tester.runAsync(log.readAll) ?? const <PetEvent>[];
    final focusEvents = events
        .where((event) => event.type == PetEventType.focusComplete)
        .toList(growable: false);
    expect(focusEvents, hasLength(1));
    expect(focusEvents.single.data, <String, Object?>{
      'minutes': 15,
      'treats': 1,
      'taskId': 'daily-1',
    });
  });
}
