import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/domain/app_state.dart';
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
    DecorAssetDescriptor(
      id: 'flower',
      displayName: 'Cozy Cushion',
      emoji: '🌼',
      slot: 1,
    ),
    DecorAssetDescriptor(
      id: 'home',
      displayName: 'Little House',
      emoji: '🏡',
      slot: 2,
    ),
    DecorAssetDescriptor(
      id: 'blanket',
      displayName: 'Sunny Blanket',
      emoji: '🧺',
      slot: 3,
    ),
    DecorAssetDescriptor(
      id: 'lamp',
      displayName: 'Warm Lantern',
      emoji: '🏮',
      slot: 4,
    ),
    DecorAssetDescriptor(
      id: 'window',
      displayName: 'Dreamy Window',
      emoji: '🪟',
      slot: 5,
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

/// [label] accepts a Pattern because some labels carry a schedule-dependent
/// suffix (the pet reads 'Touch Choco zzz' during the nap window), which made
/// exact-string assertions pass or fail depending on the clock.
void _expectButtonNode(WidgetTester tester, Pattern label) {
  final finder = find.bySemanticsLabel(label);
  expect(finder, findsOneWidget);
  final node = tester.getSemantics(finder);
  if (label is String) expect(node.label, label);
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

  testWidgets('home exposes task actions and a Settings button', (
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

    expect(fixture.controller.state.tasks, hasLength(3));
    // The task section is deliberately lazy/scrollable so 7 items never form
    // a wall. Verify the visible card boundary and the full domain count.
    _expectButtonNode(tester, fixture.controller.state.tasks.first.title);
    _expectButtonNode(tester, 'Settings');
    _expectButtonNode(tester, RegExp(r'^Touch Choco'));

    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    expect(find.text("Choco's collection"), findsOneWidget);
    // GridView.builder lazily renders only the visible cells, so assert the
    // domain truth (6 decorations, none unlocked at lifetime 0) rather than a
    // fixed rendered count; the visible silhouettes prove the locked mapping.
    expect(fixture.controller.decorations, hasLength(6));
    expect(fixture.controller.state.unlockedDecorIds, isEmpty);
    expect(find.text('A little mystery'), findsAtLeastNWidgets(1));
    semantics.dispose();
  });

  // Fleeting-thought capture is the core ADHD flow: it must survive the
  // dialog's exit animation. Disposing the field controller as soon as
  // showDialog resolved crashed the app here ('_dependents.isEmpty').
  testWidgets('quick capture saves a one-off task without crashing', (
    tester,
  ) async {
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

    // pumpAndSettle never returns on Home: the sprite frames and the sun-halo
    // twinkle are endless animations. Pump fixed durations instead.
    await tester.tap(find.text('Jot it down'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Call the vet');
    await tester.pump();
    await tester.tap(find.text('Keep it'));
    await tester.pump();
    // The crash window: the route is animating out while the TextField still
    // depends on the controller that used to be disposed right here.
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(
      fixture.controller.state.tasks.map((task) => task.title),
      contains('Call the vet'),
    );
    expect(
      fixture.controller.state.tasks
          .firstWhere((task) => task.title == 'Call the vet')
          .kind,
      TaskKind.oneOff,
    );
  });
}
