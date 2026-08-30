import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/application/focus_session_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';
import 'package:pettodo/ui/app_theme.dart';
import 'package:pettodo/ui/focus_complete_screen.dart';
import 'package:pettodo/ui/widgets/pixel_components.dart';

class _FocusSpriteLoader extends SpriteAtlasLoader {
  _FocusSpriteLoader(this.image);

  final ui.Image image;

  static const descriptor = PetAssetDescriptor(
    id: 'choco',
    displayName: 'Choco',
    metadataAsset: 'fake',
    spritesheetAsset: 'fake',
  );

  @override
  Future<List<PetAssetDescriptor>> loadManifest() async => const [descriptor];

  @override
  Future<List<DecorAssetDescriptor>> loadDecorManifest() async => const [];

  @override
  Future<LoadedSpriteAtlas> loadPet(
    PetAssetDescriptor descriptor, {
    String? growthStage,
  }) async => LoadedSpriteAtlas(
    descriptor: descriptor,
    definition: SpriteAtlasDefinition(
      petId: 'choco',
      columns: 1,
      rows: 3,
      cellWidth: 1,
      cellHeight: 1,
      imageWidth: 1,
      imageHeight: 3,
      sequences: <String, SpriteSequenceDefinition>{
        for (final entry in const [('idle', 0), ('waving', 1), ('review', 2)])
          entry.$1: SpriteSequenceDefinition(
            state: entry.$1,
            row: entry.$2,
            frameCount: 1,
            purpose: 'test',
          ),
      },
    ),
    image: image,
  );
}

Future<ui.Image> _image() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 3),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  return recorder.endRecording().toImage(1, 3);
}

Future<void> _waitFor(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('Mark done uses the existing task completion flow', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('pettodo-focus-ui');
    addTearDown(() => directory.deleteSync(recursive: true));
    late AppController controller;
    late FocusSessionCompletion completion;

    await tester.runAsync(() async {
      controller = AppController(
        stateStore: AppStateStore(() async => directory),
        eventLog: EventLogStore(() async => directory),
        notifications: NotificationService(),
        spriteLoader: _FocusSpriteLoader(await _image()),
      );
      await controller.initialize();
      var now = DateTime(2026, 8, 30, 9);
      final session = controller.createFocusSession(
        durationMinutes: 15,
        taskId: controller.state.tasks.first.id,
        now: () => now,
        tickInterval: null,
      );
      session.start();
      now = now.add(const Duration(minutes: 15));
      await session.tick();
      completion = session.completion!;
      session.dispose();
    });
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FocusCompleteScreen(
          controller: controller,
          completion: completion,
        ),
      ),
    );

    expect(controller.state.tasks.first.isComplete, isFalse);
    expect(controller.state.lifetimeCompletions, 0);
    expect(controller.state.treats, 1);

    final button = tester.widget<PxButton>(
      find.widgetWithText(PxButton, 'Mark done'),
    );
    await tester.runAsync(() async {
      button.onPressed!();
      await _waitFor(() => controller.state.tasks.first.isComplete);
    });
    await tester.pump();

    expect(controller.state.tasks.first.isComplete, isTrue);
    expect(controller.state.lifetimeCompletions, 1);
    expect(controller.state.treats, 2);
  });
}
