import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/hatch_request_store.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/data/pet_pack_service.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';
import 'package:pettodo/ui/app_theme.dart';
import 'package:pettodo/ui/onboarding_screen.dart';

/// Two pets in the registry — the shape a user lands in after hatching their
/// own pet. Before this was wired, onboarding rendered a hardcoded single
/// Choco card and always completed with `selectedPetId: 'choco'`, so a hatched
/// pet could only ever be reached from Collection.
class _TwoPetLoader extends SpriteAtlasLoader {
  _TwoPetLoader(this._images);

  /// One image per pet id. Sharing a single [ui.Image] across pets would make
  /// the controller's teardown double-dispose it — real packs each decode
  /// their own file, so the fixture matches that.
  final Map<String, ui.Image> _images;

  static const _choco = PetAssetDescriptor(
    id: 'choco',
    displayName: 'Choco',
    metadataAsset: 'fake',
    spritesheetAsset: 'fake',
  );

  static const _pip = PetAssetDescriptor(
    id: 'pip',
    displayName: 'Pip',
    metadataAsset: 'fake',
    spritesheetAsset: 'fake',
  );

  SpriteAtlasDefinition _definitionFor(String petId) => SpriteAtlasDefinition(
    petId: petId,
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
  Future<List<PetAssetDescriptor>> loadManifest() async => const [_choco, _pip];

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
    definition: _definitionFor(descriptor.id),
    image: _images[descriptor.id]!,
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

/// Poll a real-zone condition: the controller's persistence runs in the
/// ambient zone via runAsync, not on the fake test clock.
Future<void> _waitReal(bool Function() done, {int timeoutMs = 6000}) async {
  final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets(
    timeout: const Timeout(Duration(seconds: 30)),
    'onboarding lists every registered pet and finishes with the chosen one',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('pettodo-onboarding');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      late final AppController controller;
      // Stores MUST be constructed inside runAsync: their internal Future
      // chains bind to the ambient zone; fake-zone futures never complete.
      await tester.runAsync(() async {
        controller = AppController(
          stateStore: AppStateStore(() async => tempDir),
          eventLog: EventLogStore(() async => tempDir),
          notifications: NotificationService(),
          spriteLoader: _TwoPetLoader(<String, ui.Image>{
            'choco': await _makeImage(),
            'pip': await _makeImage(),
          }),
          hatchRequestStore: HatchRequestStore(() async => tempDir),
          petPackService: PetPackService(() async => tempDir),
        );
        await controller.initialize();
      });
      addTearDown(controller.dispose);

      expect(controller.pets, hasLength(2));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OnboardingScreen(controller: controller),
        ),
      );
      await tester.pump();

      // Both pets are offered, not just the bundled one.
      expect(find.text('Choco'), findsOneWidget);
      expect(find.text('Pip'), findsOneWidget);
      expect(find.text("Hi, I'm Choco!"), findsOneWidget);

      // Choosing the second pet moves the selection and the greeting.
      await tester.runAsync(() => controller.selectPet('pip'));
      await tester.pump();
      expect(controller.state.selectedPetId, 'pip');
      expect(find.text("Hi, I'm Pip!"), findsOneWidget);

      // The name step offers the chosen pet's name as its placeholder.
      await tester.tap(find.text("That's the one"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Pip'), findsOneWidget);

      await tester.tap(find.text("That's my name!"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('These three!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      // Finish through the UI — the bug being locked down lived in this
      // screen's call, not in the controller. Tap inside runAsync so the
      // handler's real IO completes; a fake-zone tap would hang on the
      // first await.
      await tester.runAsync(
        () => tester.tap(find.text("Not now, I'll come find you")),
      );
      await tester.runAsync(
        () => _waitReal(() => controller.state.onboardingComplete),
      );

      expect(controller.state.onboardingComplete, isTrue);
      expect(controller.state.selectedPetId, 'pip');
      expect(controller.state.petName, 'Pip');
    },
  );
}
