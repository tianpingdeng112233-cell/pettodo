import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/hatch_request_store.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/data/pet_pack_service.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/pet_action.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';
import 'package:pettodo/ui/app_theme.dart';
import 'package:pettodo/ui/home_screen.dart';
import 'package:pettodo/ui/widgets/bond_progress_bar.dart';

void main() {
  testWidgets('initial companion day XP crossing opens the bond theater', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 30, 12);
    final persistedState = AppState.initial(now).copyWith(
      onboardingComplete: true,
      bondXp: 20,
      lastCompanionDay: '2026-08-29',
    );

    final fixture = await _createController(
      tester,
      now: () => now,
      persistedState: persistedState,
    );
    await tester.runAsync(
      () => _waitFor(() => fixture.controller.theaterVisible),
    );

    expect(fixture.controller.state.bondXp, 30);
    expect(fixture.controller.bondCelebrationLevel, 2);
    expect(fixture.controller.theaterVisible, isTrue);
  });

  testWidgets('resumed companion day XP crossing opens the bond theater', (
    tester,
  ) async {
    var now = DateTime(2026, 8, 30, 12);
    final persistedState = AppState.initial(now).copyWith(
      onboardingComplete: true,
      bondXp: 20,
      lastCompanionDay: '2026-08-30',
    );
    final fixture = await _createController(
      tester,
      now: () => now,
      persistedState: persistedState,
    );

    now = DateTime(2026, 8, 31, 12);
    await tester.runAsync(() async {
      await fixture.controller.onResume();
      await _waitFor(() => fixture.controller.theaterVisible);
    });

    expect(fixture.controller.state.bondXp, 30);
    expect(fixture.controller.bondCelebrationLevel, 2);
    expect(fixture.controller.theaterVisible, isTrue);
  });

  testWidgets('feeding across a bond level opens the bond theater', (
    tester,
  ) async {
    final fixture = await _createController(tester);
    fixture.controller.state = fixture.controller.state.copyWith(
      bondXp: 22,
      foodInventory: const <String, int>{'biscuit': 1},
      feedingCountToday: 0,
    );

    await tester.runAsync(() async {
      expect(await fixture.controller.feedFood('biscuit'), isTrue);
      expect(fixture.controller.state.bondXp, 27);
      expect(fixture.controller.rigAction, RigPetAction.eatTreat);
      expect(fixture.controller.momentParticle, '+5');
      expect(fixture.controller.momentStatus, 'Choco munched happily');
      await Future<void>.delayed(const Duration(milliseconds: 950));
    });

    expect(fixture.controller.theaterVisible, isTrue);
    expect(fixture.controller.bondCelebrationLevel, 2);
    expect(fixture.controller.rigAction, RigPetAction.happyJump);

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

    expect(find.text('Bond Lv 2'), findsOneWidget);
    expect(find.text('Snack Buddies'), findsNWidgets(2));
    expect(find.text('You and Choco grew a little closer.'), findsOneWidget);
    expect(find.byType(BondProgressBar), findsNWidgets(2));
    expect(
      tester
          .widgetList<BondProgressBar>(find.byType(BondProgressBar))
          .map((progress) => progress.value),
      everyElement(closeTo(2 / 75, 0.001)),
    );
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(fixture.controller.theaterVisible, isFalse);
    expect(fixture.controller.bondCelebrationLevel, isNull);
  });
}

Future<({AppController controller, EventLogStore eventLog})> _createController(
  WidgetTester tester, {
  DateTime Function()? now,
  AppState? persistedState,
}) async {
  final directory = Directory.systemTemp.createTempSync('pettodo-bond-level');
  addTearDown(() => directory.deleteSync(recursive: true));
  if (persistedState != null) {
    File(
      '${directory.path}/pettodo-state.json',
    ).writeAsStringSync(jsonEncode(persistedState.toJson()));
  }

  late final EventLogStore eventLog;
  late final AppController controller;
  await tester.runAsync(() async {
    eventLog = EventLogStore(() async => directory);
    controller = AppController(
      stateStore: AppStateStore(() async => directory),
      eventLog: eventLog,
      notifications: NotificationService(),
      spriteLoader: SpriteAtlasLoader(),
      hatchRequestStore: HatchRequestStore(() async => directory),
      petPackService: PetPackService(() async => directory),
      now: now ?? () => DateTime(2026, 8, 30, 12),
    );
    await controller.initialize();
  });
  addTearDown(controller.dispose);
  return (controller: controller, eventLog: eventLog);
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}
