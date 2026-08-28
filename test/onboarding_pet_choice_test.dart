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
import 'package:pettodo/domain/onboarding_flow.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';
import 'package:pettodo/ui/app_theme.dart';
import 'package:pettodo/ui/onboarding_screen.dart';
import 'package:pettodo/ui/widgets/pixel_components.dart';

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

class _FakeNotifications extends NotificationService {
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

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

void main() {
  testWidgets(
    timeout: const Timeout(Duration(seconds: 30)),
    'onboarding v2 selects, prefills, limits chips, celebrates, and finishes',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('pettodo-onboarding');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      late final AppController controller;
      final notifications = _FakeNotifications();
      // Stores MUST be constructed inside runAsync: their internal Future
      // chains bind to the ambient zone; fake-zone futures never complete.
      await tester.runAsync(() async {
        controller = AppController(
          stateStore: AppStateStore(() async => tempDir),
          eventLog: EventLogStore(() async => tempDir),
          notifications: notifications,
          spriteLoader: _TwoPetLoader(<String, ui.Image>{
            'choco': await _makeImage(),
            'pip': await _makeImage(),
          }),
          hatchRequestStore: HatchRequestStore(() async => tempDir),
          petPackService: PetPackService(() async => tempDir),
          now: () => DateTime(2026, 8, 25, 20),
        );
        await controller.initialize();
      });
      addTearDown(controller.dispose);

      expect(controller.pets, hasLength(2));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OnboardingScreen(
            controller: controller,
            showStayOnScreen: false,
          ),
        ),
      );
      await tester.pump();

      // Both pets are offered, not just the bundled one.
      expect(find.text('Choco'), findsOneWidget);
      expect(find.text('Pip'), findsOneWidget);
      expect(find.text("Who's coming home?"), findsOneWidget);

      // Choosing the second pet moves the selection and the greeting. The
      // selection is driven through the controller inside runAsync: a tap's
      // handler awaits store IO, and fake-zone-initiated IO strands its
      // continuations on the real loop and poisons every later runAsync
      // (this suite's recurring zone trap). The tile wiring itself is a
      // one-line onSelect passthrough covered by the semantics test.
      await tester.runAsync(() => controller.selectPet('pip'));
      await tester.pump();
      expect(controller.state.selectedPetId, 'pip');

      // The chosen preset name is actual zero-typing input, not a placeholder.
      await tester.tap(find.text("That's the one"));
      await tester.pump();
      // Bounded pump: live sprite loops forever, pumpAndSettle never settles.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Pip'), findsOneWidget);
      expect(find.text('Nice to meet you, Pip'), findsOneWidget);

      // The die is the second zero-cost escape hatch, and remains live: it
      // draws from the preset-name pool, so the only guarantee is a change.
      await tester.tap(find.bySemanticsLabel('Try another name'));
      await tester.pump();
      final rolled = tester
          .widget<EditableText>(find.byType(EditableText))
          .controller
          .text;
      expect(rolled, isNot('Pip'));
      expect(rolled, isNotEmpty);
      expect(find.text('Nice to meet you, $rolled'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Pip');
      await tester.pump();

      await tester.tap(find.text('Nice to meet you, Pip'));
      await tester.pump();
      // Bounded pump: live sprite loops forever, pumpAndSettle never settles.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Pick at least one'), findsOneWidget);
      final disabled = tester.widget<PxButton>(
        find.ancestor(
          of: find.text('Pick at least one'),
          matching: find.byType(PxButton),
        ),
      );
      expect(disabled.onPressed, isNull);

      for (final label in <String>[
        'Get out of bed',
        'Drink some water',
        'Brush my teeth',
        'Take my meds',
      ]) {
        await tester.tap(find.text(label));
        await tester.pump();
      }
      expect(find.text('These three!'), findsOneWidget);

      // Tapping the IO-bound CTAs from the fake zone strands their handler
      // continuations on the real loop (this suite's recurring zone trap), so
      // the two IO steps are driven through the controller inside runAsync —
      // the same pattern as the other suites — with the exact arguments the
      // handler computes. The sync _goTo wiring is already proven by the
      // S1→S2 and S2→S3 taps; S4 rendering is asserted via the initialStep
      // seam the goldens use.
      await tester.runAsync(
        () => controller.prepareOnboarding(
          selectedPetId: controller.state.selectedPetId,
          petName: 'Pip',
          taskTitles: const <String>[
            '🛏️ Get out of bed',
            '💧 Drink some water',
            '💊 Take my meds',
          ],
        ),
      );
      expect(controller.state.onboardingRewardGranted, isTrue);
      expect(controller.state.tasks, hasLength(4));
      expect(controller.state.tasks.first.id, firstWinTaskId);
      expect(controller.state.tasks.first.title, 'Give Pip a pat');
      expect(controller.state.treats, 1);
      expect(controller.state.notificationPermission.name, 'notRequested');
      await tester.runAsync(
        () => controller.prepareOnboarding(
          selectedPetId: 'pip',
          petName: 'Pip',
          taskTitles: const <String>['💧 Drink some water'],
        ),
      );
      expect(controller.state.treats, 1);
      // S4 renders from the prepared state (seam: initialStep).
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OnboardingScreen(
            key: const ValueKey<String>('seam-celebrate'),
            controller: controller,
            initialStep: OnboardingStep.celebrate,
            showStayOnScreen: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Our little routine\nis ready!'), findsOneWidget);
      expect(find.textContaining('for getting us started'), findsOneWidget);
      expect(find.text("Let's go home"), findsOneWidget);

      // The CTA's _finish is a thin await over finishOnboarding; drive the
      // IO directly in the real zone, same pattern as the other suites.
      await tester.runAsync(() => controller.finishOnboarding());

      expect(controller.state.onboardingComplete, isTrue);
      expect(controller.state.selectedPetId, 'pip');
      expect(controller.state.petName, 'Pip');
      expect(controller.eveningHelloVisible, isTrue);
      expect(controller.state.eveningHelloPending, isTrue);
      expect(notifications.permissionRequests, 0);

      await tester.runAsync(() => controller.respondToEveningHello(false));
      expect(controller.eveningHelloVisible, isFalse);
      expect(controller.state.eveningHelloPending, isFalse);
      expect(notifications.permissionRequests, 0);
    },
  );
}
