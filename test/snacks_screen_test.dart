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
import 'package:pettodo/ui/snacks_screen.dart';
import 'package:pettodo/ui/widgets/food_item_view.dart';
import 'package:pettodo/ui/widgets/treat_count.dart';
import 'package:pettodo/ui/widgets/pixel_components.dart';

void main() {
  for (final treats in <int>[1, 2, 3, 4]) {
    testWidgets('v4 save with $treats treats opens with Feed enabled', (
      tester,
    ) async {
      final controller = await _createController(
        tester,
        persistedJson: <String, Object?>{
          'schemaVersion': 4,
          'onboardingComplete': true,
          'tasks': <Object?>[
            <String, Object?>{'id': 'daily', 'title': 'Water', 'kind': 'daily'},
          ],
          'activeDay': '2026-08-30',
          'lifetimeCompletions': 0,
          'treats': treats,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SnacksScreen(controller: controller),
        ),
      );
      await tester.pump();

      expect(find.text('Owned 1'), findsOneWidget);
      expect(
        tester
            .widget<PxButton>(find.widgetWithText(PxButton, 'Feed'))
            .onPressed,
        isNotNull,
      );
    });
  }

  testWidgets('owned snacks can be fed and unowned snacks can be bought', (
    tester,
  ) async {
    // Tall test viewport so all 7 catalog rows build in the lazy list.
    tester.view.physicalSize = const Size(1170, 3900);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController(tester);
    controller.state = controller.state.copyWith(
      treats: 4,
      foodInventory: const <String, int>{'biscuit': 1},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SnacksScreen(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Snacks'), findsOneWidget);
    expect(find.widgetWithText(TreatCount, '4'), findsOneWidget);
    expect(find.text('Every snack adds a little bond XP'), findsOneWidget);
    expect(find.byType(FoodItemView), findsNWidgets(7));
    expect(find.text('Owned 1'), findsOneWidget);
    expect(find.widgetWithText(PxButton, 'Feed'), findsOneWidget);
    expect(find.widgetWithText(PxButton, 'Buy'), findsNWidgets(7));
    for (final buyButton in tester.widgetList<PxButton>(
      find.widgetWithText(PxButton, 'Buy'),
    )) {
      expect(buyButton.onPressed, isNull);
    }
  });

  testWidgets('buying then feeding updates treats, inventory, and bond XP', (
    tester,
  ) async {
    final controller = await _createController(tester);
    controller.state = controller.state.copyWith(
      treats: 5,
      foodInventory: const <String, int>{},
      bondXp: 10,
      feedingCountToday: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SnacksScreen(controller: controller),
      ),
    );
    await tester.pump();

    final enabledBuy = tester
        .widgetList<PxButton>(find.widgetWithText(PxButton, 'Buy'))
        .singleWhere((button) => button.onPressed != null);
    var purchaseNotified = false;
    controller.addListener(() => purchaseNotified = true);
    await tester.runAsync(() async {
      enabledBuy.onPressed!();
      await _waitFor(
        () =>
            purchaseNotified && controller.state.foodInventory['biscuit'] == 1,
      );
    });
    await tester.pump();

    expect(controller.state.treats, 0);
    expect(find.widgetWithText(TreatCount, '0'), findsOneWidget);
    expect(find.text('Owned 1'), findsOneWidget);

    final feed = tester.widget<PxButton>(find.widgetWithText(PxButton, 'Feed'));
    await tester.runAsync(() async {
      feed.onPressed!();
      await _waitFor(
        () =>
            controller.state.foodInventory.isEmpty &&
            controller.bondProgressHighlightStart != null,
      );
    });

    expect(controller.state.bondXp, 15);
    expect(controller.state.feedingCountToday, 1);
    expect(controller.bondProgressHighlightStart, closeTo(0.4, 0.001));
  });

  testWidgets('buying another owned snack increases inventory to two', (
    tester,
  ) async {
    final controller = await _createController(tester);
    controller.state = controller.state.copyWith(
      treats: 5,
      foodInventory: const <String, int>{'biscuit': 1},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SnacksScreen(controller: controller),
      ),
    );
    await tester.pump();

    final enabledBuy = tester
        .widgetList<PxButton>(find.widgetWithText(PxButton, 'Buy'))
        .singleWhere((button) => button.onPressed != null);
    var purchaseNotified = false;
    controller.addListener(() => purchaseNotified = true);
    await tester.runAsync(() async {
      enabledBuy.onPressed!();
      await _waitFor(
        () =>
            purchaseNotified && controller.state.foodInventory['biscuit'] == 2,
      );
    });
    await tester.pump();

    expect(controller.state.treats, 0);
    expect(find.text('Owned 2'), findsOneWidget);
    expect(
      tester.widget<PxButton>(find.widgetWithText(PxButton, 'Feed')).onPressed,
      isNotNull,
    );
  });
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

Future<AppController> _createController(
  WidgetTester tester, {
  Map<String, Object?>? persistedJson,
}) async {
  final directory = Directory.systemTemp.createTempSync('pettodo-snacks');
  addTearDown(() => directory.deleteSync(recursive: true));
  if (persistedJson != null) {
    File(
      '${directory.path}/pettodo-state.json',
    ).writeAsStringSync(jsonEncode(persistedJson));
  }

  late final AppController controller;
  await tester.runAsync(() async {
    controller = AppController(
      stateStore: AppStateStore(() async => directory),
      eventLog: EventLogStore(() async => directory),
      notifications: NotificationService(),
      spriteLoader: SpriteAtlasLoader(),
      hatchRequestStore: HatchRequestStore(() async => directory),
      petPackService: PetPackService(() async => directory),
      now: () => DateTime(2026, 8, 30, 12),
    );
    await controller.initialize();
  });
  addTearDown(controller.dispose);
  return controller;
}
