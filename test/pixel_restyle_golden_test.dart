import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:pettodo/ui/collection_screen.dart';
import 'package:pettodo/ui/home_screen.dart';
import 'package:pettodo/ui/onboarding_screen.dart';
import 'package:pettodo/ui/settings_screen.dart';

void main() {
  testWidgets('Cozy Pixel screens have deterministic 393pt baselines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _loadFonts();

    final fixture = await _createController(tester);
    final snapshotDate = DateTime(2026, 8, 24, 15);

    await _expectGolden(
      tester,
      HomeScreen(
        controller: fixture.controller,
        eventLog: fixture.eventLog,
        now: snapshotDate,
        visualTestMode: true,
      ),
      'goldens/pixel_home_393.png',
    );
    await _expectGolden(
      tester,
      SettingsScreen(
        controller: fixture.controller,
        eventLog: fixture.eventLog,
      ),
      'goldens/pixel_settings_393.png',
    );
    await _expectGolden(
      tester,
      CollectionScreen(controller: fixture.controller),
      'goldens/pixel_collection_393.png',
    );
    for (final entry in <(OnboardingStep, String)>[
      (OnboardingStep.choosePet, 'goldens/pixel_onboarding_s1_393.png'),
      (OnboardingStep.namePet, 'goldens/pixel_onboarding_s2_393.png'),
      (OnboardingStep.littleThings, 'goldens/pixel_onboarding_s3_393.png'),
      (OnboardingStep.celebrate, 'goldens/pixel_onboarding_s4_393.png'),
      (OnboardingStep.stayOnScreen, 'goldens/pixel_onboarding_s5_393.png'),
    ]) {
      await _expectGolden(
        tester,
        OnboardingScreen(
          key: ValueKey<OnboardingStep>(entry.$1),
          controller: fixture.controller,
          initialStep: entry.$1,
          showStayOnScreen: true,
          initialSelectedThingIndexes: const <int>{0, 1, 3},
        ),
        entry.$2,
      );
    }
  });
}

Future<void> _loadFonts() async {
  final body = FontLoader('Baloo 2')
    ..addFont(rootBundle.load('assets/fonts/Baloo2-VariableFont_wght.ttf'));
  final display = FontLoader('Pixelify Sans')
    ..addFont(
      rootBundle.load('assets/fonts/PixelifySans-VariableFont_wght.ttf'),
    );
  await Future.wait(<Future<void>>[body.load(), display.load()]);
}

Future<({AppController controller, EventLogStore eventLog})> _createController(
  WidgetTester tester,
) async {
  final tempDir = Directory.systemTemp.createTempSync('pettodo-pixel-golden');
  addTearDown(() => tempDir.deleteSync(recursive: true));

  late final EventLogStore eventLog;
  late final AppController controller;
  await tester.runAsync(() async {
    eventLog = EventLogStore(() async => tempDir);
    controller = AppController(
      stateStore: AppStateStore(() async => tempDir),
      eventLog: eventLog,
      notifications: NotificationService(),
      spriteLoader: SpriteAtlasLoader(),
      hatchRequestStore: HatchRequestStore(() async => tempDir),
      petPackService: PetPackService(() async => tempDir),
    );
    await controller.initialize();
  });
  addTearDown(controller.dispose);
  return (controller: controller, eventLog: eventLog);
}

Future<void> _expectGolden(
  WidgetTester tester,
  Widget screen,
  String path,
) async {
  const boundaryKey = ValueKey<String>('pixel-golden-boundary');
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(
        width: 393,
        height: 852,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: TickerMode(enabled: false, child: screen),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  await expectLater(find.byKey(boundaryKey), matchesGoldenFile(path));
}
