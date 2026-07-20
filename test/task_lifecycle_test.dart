import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/notification_service.dart';
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

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> scheduleWindow({
    required String petName,
    required bool includeDailyInvitation,
    required int invitationHour,
    required int invitationMinute,
    required List<TaskReminderSchedule> taskReminders,
    DateTime? now,
  }) async {
    scheduleRefreshes++;
  }
}

void main() {
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
}
