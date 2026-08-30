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
import 'package:pettodo/sprite/sprite_atlas.dart';
import 'package:pettodo/ui/app_theme.dart';
import 'package:pettodo/ui/home_screen.dart';
import 'package:pettodo/ui/widgets/bond_progress_bar.dart';

void main() {
  testWidgets('home shows migrated bond level and within-level progress', (
    tester,
  ) async {
    final fixture = await _createLegacyController(tester);

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

    // junior floor 100 + companion day 10 with a 20% coziness bonus (4 placed)
    expect(fixture.controller.state.bondXp, 112);
    expect(find.text('Junior'), findsOneWidget);
    expect(find.text('Lv 3'), findsOneWidget);
    expect(find.text('Close Pals'), findsOneWidget);
    expect(find.text('Snacks · 17'), findsOneWidget);
    final progress = tester.widget<BondProgressBar>(
      find.byType(BondProgressBar),
    );
    expect(progress.value, closeTo(12 / 125, 0.001));
  });
}

Future<({AppController controller, EventLogStore eventLog})>
_createLegacyController(WidgetTester tester) async {
  final directory = Directory.systemTemp.createTempSync('pettodo-bond-home');
  addTearDown(() => directory.deleteSync(recursive: true));
  File('${directory.path}/pettodo-state.json').writeAsStringSync(
    jsonEncode(<String, Object?>{
      'schemaVersion': 4,
      'onboardingComplete': true,
      'selectedPetId': 'choco',
      'petName': 'Choco',
      'tasks': <Object?>[
        <String, Object?>{'id': 'daily', 'title': 'Water', 'kind': 'daily'},
      ],
      'activeDay': '2026-08-30',
      'lifetimeCompletions': 40,
      'treats': 17,
    }),
  );

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
      now: () => DateTime(2026, 8, 30, 12),
    );
    await controller.initialize();
  });
  addTearDown(controller.dispose);
  return (controller: controller, eventLog: eventLog);
}
