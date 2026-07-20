import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';
import 'package:pettodo/ui/app_theme.dart';
import 'package:pettodo/ui/home_screen.dart';
import 'package:pettodo/ui/onboarding_screen.dart';

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
  Future<LoadedSpriteAtlas> loadPet(PetAssetDescriptor descriptor) async =>
      LoadedSpriteAtlas(
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

Future<({AppController controller, EventLogStore eventLog})> _createController(
  WidgetTester tester,
) async {
  final tempDir = Directory.systemTemp.createTempSync('pettodo-semantics');
  addTearDown(() => tempDir.deleteSync(recursive: true));

  late final EventLogStore eventLog;
  late final AppController controller;
  await tester.runAsync(() async {
    eventLog = EventLogStore(() async => tempDir);
    controller = AppController(
      stateStore: AppStateStore(() async => tempDir),
      eventLog: eventLog,
      notifications: NotificationService(),
      spriteLoader: _FakeSpriteLoader(await _makeImage()),
    );
    await controller.initialize();
  });
  addTearDown(controller.dispose);
  return (controller: controller, eventLog: eventLog);
}

void _expectButtonNode(WidgetTester tester, String label) {
  final finder = find.bySemanticsLabel(label);
  expect(finder, findsOneWidget);
  final node = tester.getSemantics(finder);
  expect(node.label, label);
  expect(node.flagsCollection.isButton, isTrue);
  expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
}

void main() {
  testWidgets('onboarding keeps each action separate and never overflows', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = await _createController(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OnboardingScreen(controller: fixture.controller),
      ),
    );
    await tester.pump();

    _expectButtonNode(tester, "That's the one");
    expect(tester.takeException(), isNull);

    for (final transition in <(String, String)>[
      ("That's the one", "That's my name!"),
      ("That's my name!", 'These three!'),
      ('These three!', 'Sure! See you at 8:00 PM'),
    ]) {
      await tester.tap(find.text(transition.$1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      _expectButtonNode(tester, transition.$2);
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });

  testWidgets('home exposes three task buttons and a Settings button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final fixture = await _createController(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          controller: fixture.controller,
          eventLog: fixture.eventLog,
        ),
      ),
    );
    await tester.pump();

    final taskNodes = <SemanticsNode>[];
    for (final title in fixture.controller.state.taskTitles) {
      _expectButtonNode(tester, title);
      taskNodes.add(tester.getSemantics(find.bySemanticsLabel(title)));
    }
    expect(taskNodes.map((node) => node.id).toSet(), hasLength(3));
    _expectButtonNode(tester, 'Settings');
    semantics.dispose();
  });
}
