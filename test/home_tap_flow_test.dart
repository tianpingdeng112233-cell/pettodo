import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';
import 'package:pettodo/ui/app_theme.dart';
import 'package:pettodo/ui/home_screen.dart';
import 'package:pettodo/ui/widgets/pixel_components.dart';

class _FakeSpriteLoader extends SpriteAtlasLoader {
  _FakeSpriteLoader(this._image);

  final ui.Image _image;

  static const _descriptor = PetAssetDescriptor(
    id: 'choco',
    displayName: 'Choco',
    metadataAsset: 'fake',
    spritesheetAsset: 'fake',
  );

  SpriteAtlasDefinition get _definition => SpriteAtlasDefinition(
    petId: 'choco',
    columns: 8,
    rows: 11,
    cellWidth: 4,
    cellHeight: 4,
    imageWidth: 32,
    imageHeight: 44,
    sequences: {
      for (final entry in const [
        ('idle', 0, 6),
        ('jumping', 4, 5),
        ('waving', 3, 4),
        ('review', 8, 6),
        ('waiting', 6, 6),
        ('look-row-9', 9, 8),
        ('look-row-10', 10, 8),
      ])
        entry.$1: SpriteSequenceDefinition(
          state: entry.$1,
          row: entry.$2,
          frameCount: entry.$3,
          purpose: 'test',
        ),
    },
  );

  @override
  Future<List<PetAssetDescriptor>> loadManifest() async => const [_descriptor];

  @override
  Future<List<DecorAssetDescriptor>> loadDecorManifest() async => const [
    DecorAssetDescriptor(
      id: 'soft_ball',
      displayName: 'Bouncy Ball',
      emoji: '🧶',
      slot: 0,
    ),
  ];

  @override
  Future<LoadedSpriteAtlas> loadPet(
    PetAssetDescriptor descriptor, {
    String? growthStage,
  }) async => LoadedSpriteAtlas(
    descriptor: descriptor,
    definition: _definition,
    image: _image,
  );
}

Future<ui.Image> _makeImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 32, 44),
    ui.Paint()..color = const ui.Color(0xFF8A5A2E),
  );
  return recorder.endRecording().toImage(32, 44);
}

/// Poll a real-zone condition (used because the controller's animation timers
/// and IO run in the ambient zone via runAsync, not the fake test clock).
Future<void> _waitReal(bool Function() done, {int timeoutMs = 6000}) async {
  final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets(
    timeout: const Timeout(Duration(seconds: 30)),
    'completing a task marks it done, drops the check, and plays then clears the happy animation',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('pettodo-test');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      late final EventLogStore eventLog;
      late final AppController controller;
      await tester.runAsync(() async {
        // Stores MUST be constructed inside runAsync: their internal Future
        // chains bind to the ambient zone; fake-zone futures never complete.
        eventLog = EventLogStore(() async => tempDir);
        final img = await _makeImage();
        controller = AppController(
          stateStore: AppStateStore(() async => tempDir),
          eventLog: eventLog,
          notifications: NotificationService(),
          spriteLoader: _FakeSpriteLoader(img),
        );
        await controller.initialize();
      });
      addTearDown(controller.dispose);
      controller.state = controller.state.copyWith(
        foodInventory: const <String, int>{'biscuit': 1},
      );

      // Render smoke: HomeScreen builds with a real (fake-atlas) controller.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ListenableBuilder(
            listenable: controller,
            builder: (_, _) =>
                HomeScreen(controller: controller, eventLog: eventLog),
          ),
        ),
      );
      await tester.pump();
      expect(controller.state.completedToday, everyElement(isFalse));
      expect(controller.petAnimation, controller.currentSchedule.animation);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(
        tester
            .widget<PxButton>(find.widgetWithText(PxButton, 'Snacks · 0'))
            .onPressed,
        isNotNull,
      );

      await tester.runAsync(() async {
        await controller.touchPet(dx: 96, dy: 0);
        expect(controller.petAnimation, 'look-row-9');
        expect(controller.petAnimationFrame, 4);
        expect(controller.affectionateMessage, contains('Choco'));
      });
      await tester.runAsync(
        () => _waitReal(
          () => controller.petAnimation == controller.currentSchedule.animation,
        ),
      );

      // Drive the controller directly rather than through a UI tap: tap +
      // pump + runAsync interleaving is timing-fragile under a parallel
      // suite. "The card is a tappable button" is covered by
      // semantics_boundaries_test; here we verify the completion state machine.
      //
      // The 'jumping' assertion MUST live inside runAsync, synchronously after
      // completeTask resolves: the return-to-idle is a 2s macrotask Timer, so
      // reading here (before any pump drains the event loop) always observes
      // the freshly-set 'jumping'. Asserting it after an outer pump() is racy
      // under slow parallel IO — the timer can fire first and reset to 'idle'.
      await tester.runAsync(() async {
        await controller.completeTask(controller.state.tasks.first.id);
        expect(controller.state.completedToday[0], isTrue);
        expect(controller.state.lifetimeCompletions, 1);
        expect(controller.state.treats, 1);
        expect(controller.petAnimation, 'jumping');
      });
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // The celebration timer is a real-zone timer; wait it out by polling.
      await tester.runAsync(
        () => _waitReal(
          () => controller.petAnimation == controller.currentSchedule.animation,
        ),
      );
      await tester.pump();
      expect(controller.petAnimation, controller.currentSchedule.animation);
    },
  );
}
