import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/hatch_request_store.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/data/pet_pack_service.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/furniture.dart';
import 'package:pettodo/domain/onboarding_flow.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';
import 'package:pettodo/ui/app_theme.dart';
import 'package:pettodo/ui/home_screen.dart';
import 'package:pettodo/ui/hatch_request_screen.dart';
import 'package:pettodo/ui/onboarding_screen.dart';
import 'package:pettodo/ui/settings_screen.dart';
import 'package:pettodo/ui/widgets/furniture_item_view.dart';

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

class _GrantedNotifications extends NotificationService {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<List<ScheduledPetNotification>> scheduleWindow({
    required String petName,
    required bool includeDailyInvitation,
    required int invitationHour,
    required int invitationMinute,
    required List<TaskReminderSchedule> taskReminders,
    DateTime? now,
  }) async => const <ScheduledPetNotification>[];
}

Future<ui.Image> _makeImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 32, 44),
    ui.Paint()..color = const ui.Color(0xFF8A5A2E),
  );
  return recorder.endRecording().toImage(32, 44);
}

Future<
  ({AppController controller, EventLogStore eventLog, AppStateStore stateStore})
>
_createController(
  WidgetTester tester, {
  bool pendingRequest = false,
  Map<String, Object?>? persistedState,
  NotificationService? notifications,
}) async {
  final tempDir = Directory.systemTemp.createTempSync('pettodo-semantics');
  addTearDown(() => tempDir.deleteSync(recursive: true));

  if (persistedState != null) {
    File(
      '${tempDir.path}/pettodo-state.json',
    ).writeAsStringSync(jsonEncode(persistedState));
  }

  late final EventLogStore eventLog;
  late final AppStateStore stateStore;
  late final AppController controller;
  await tester.runAsync(() async {
    eventLog = EventLogStore(() async => tempDir);
    stateStore = AppStateStore(() async => tempDir);
    final hatchRequestStore = HatchRequestStore(() async => tempDir);
    if (pendingRequest) {
      final photo = File('${tempDir.path}/source.jpg')
        ..writeAsBytesSync(<int>[1, 2, 3]);
      await hatchRequestStore.create(photos: <File>[photo], petName: 'Pip');
    }
    controller = AppController(
      stateStore: stateStore,
      eventLog: eventLog,
      notifications: notifications ?? NotificationService(),
      spriteLoader: _FakeSpriteLoader(await _makeImage()),
      hatchRequestStore: hatchRequestStore,
      petPackService: PetPackService(() async => tempDir),
    );
    await controller.initialize();
  });
  addTearDown(controller.dispose);
  return (controller: controller, eventLog: eventLog, stateStore: stateStore);
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
        home: OnboardingScreen(
          controller: fixture.controller,
          showStayOnScreen: false,
        ),
      ),
    );
    await tester.pump();

    _expectButtonNode(tester, "That's the one");
    _expectButtonNode(
      tester,
      'Your real pet can live here too — start with 1–3 photos',
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text("That's the one"));
    await tester.pump();
    // Bounded pump: live sprite loops forever, pumpAndSettle never settles.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    _expectButtonNode(tester, 'Nice to meet you, Choco');

    await tester.tap(find.text('Nice to meet you, Choco'));
    await tester.pump();
    // Bounded pump: live sprite loops forever, pumpAndSettle never settles.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pick at least one'), findsOneWidget);
    await tester.ensureVisible(find.text('Get out of bed'));
    await tester.tap(find.text('Get out of bed'));
    await tester.pump();
    _expectButtonNode(tester, 'These three!');

    // The CTA's handler awaits store IO; a fake-zone tap strands its
    // continuation on the real loop (recurring zone trap), so the step's
    // domain effect is driven directly and S4 is assembled via the
    // deterministic initialStep seam.
    await tester.runAsync(
      () => fixture.controller.prepareOnboarding(
        selectedPetId: fixture.controller.state.selectedPetId,
        petName: 'Choco',
        taskTitles: const <String>['🛏️ Get out of bed'],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OnboardingScreen(
          key: const ValueKey<String>('seam-celebrate-semantics'),
          controller: fixture.controller,
          initialStep: OnboardingStep.celebrate,
          showStayOnScreen: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    _expectButtonNode(tester, "Let's go home");
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('hatch request UI exposes separate photo and lifecycle actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final newFixture = await _createController(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HatchRequestScreen(controller: newFixture.controller),
      ),
    );
    await tester.pump();
    _expectButtonNode(tester, 'Photo library');
    _expectButtonNode(tester, 'Camera');
    expect(find.text('Start the adoption'), findsOneWidget);

    final pendingFixture = await _createController(
      tester,
      pendingRequest: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HatchRequestScreen(controller: pendingFixture.controller),
      ),
    );
    await tester.pump();
    _expectButtonNode(tester, 'Send to the adoption center');
    _expectButtonNode(tester, 'Import pet pack');
    _expectButtonNode(tester, 'Cancel this request');
    semantics.dispose();
  });

  testWidgets('pending egg and Settings hatch actions have button boundaries', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final fixture = await _createController(tester, pendingRequest: true);
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
    _expectButtonNode(
      tester,
      'Your pet is on its way — no rush. Open adoption request',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: fixture.controller,
          eventLog: fixture.eventLog,
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Adopt your own pet'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    _expectButtonNode(tester, 'Adopt your own pet');
    _expectButtonNode(tester, 'Import pet pack');
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("Choco's collection"), findsOneWidget);
    // GridView.builder lazily renders only the visible cells, so assert the
    // domain truth rather than a fixed rendered count; the visible silhouettes
    // prove the unowned mapping.
    expect(furnitureCatalog, hasLength(12));
    expect(fixture.controller.state.ownedFurnitureIds, isEmpty);
    expect(find.text('Not owned'), findsAtLeastNWidgets(1));
    semantics.dispose();
  });

  testWidgets(
    'historical milestones all appear once on the first home screen',
    (tester) async {
      final fixture = await _createController(
        tester,
        persistedState: <String, Object?>{
          'schemaVersion': 3,
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
          'lifetimeCompletions': 120,
          'unlockedDecorIds': <String>[
            'soft_ball',
            'flower',
            'home',
            'blanket',
            'lamp',
            'window',
          ],
          'treats': 8,
        },
      );

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

      const expectedFurnitureIds = <String>[
        'rug',
        'plant',
        'bed',
        'bookshelf',
        'floor_lamp',
        'curtain_window',
      ];
      expect(find.byType(FurnitureItemView), findsNWidgets(6));
      for (final id in expectedFurnitureIds) {
        expect(
          find.byWidgetPredicate(
            (widget) => widget is FurnitureItemView && widget.item.id == id,
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'jot it down opens a focused one-off editor and saves a reminder',
    (tester) async {
      final fixture = await _createController(
        tester,
        notifications: _GrantedNotifications(),
      );
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

      await tester.runAsync(() async => tester.tap(find.text('Jot it down')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Add one little thing'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final titleField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Title',
      );
      final titleEditable = find.descendant(
        of: titleField,
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(titleEditable).focusNode.hasFocus,
        isTrue,
      );
      expect(
        tester
            .widget<SegmentedButton<TaskKind>>(
              find.byType(SegmentedButton<TaskKind>),
            )
            .selected,
        <TaskKind>{TaskKind.oneOff},
      );

      await tester.enterText(titleField, 'Call the vet');
      await tester.pump();
      await tester.tap(find.text('Remind me once'));
      await tester.pump();
      await tester.tap(find.text('Save this thing'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      late AppState persisted;
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        do {
          persisted = await fixture.stateStore.load(DateTime.now());
          if (persisted.tasks.any(
            (task) => task.title == 'Call the vet' && task.reminder != null,
          )) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        } while (DateTime.now().isBefore(deadline));
      });

      expect(tester.takeException(), isNull);
      expect(
        persisted.tasks.map((task) => task.title),
        contains('Call the vet'),
      );
      final added = persisted.tasks.firstWhere(
        (task) => task.title == 'Call the vet',
      );
      expect(added.kind, TaskKind.oneOff);
      expect(added.reminder?.enabled, isTrue);
      expect(added.reminder?.scheduledAt, isNotNull);
      expect(added.reminder!.scheduledAt!.isAfter(DateTime.now()), isTrue);
    },
  );
}
