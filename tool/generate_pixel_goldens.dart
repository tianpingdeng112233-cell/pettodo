import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadFonts();
  final outputPath = Platform.environment['PIXEL_GOLDEN_DIR'];
  if (outputPath == null) {
    throw StateError('Set PIXEL_GOLDEN_DIR to the output directory.');
  }
  final tempDir = Directory.systemTemp.createTempSync(
    'pettodo-pixel-golden-generator',
  );
  final eventLog = EventLogStore(() async => tempDir);
  final controller = AppController(
    stateStore: AppStateStore(() async => tempDir),
    eventLog: eventLog,
    notifications: NotificationService(),
    spriteLoader: SpriteAtlasLoader(),
    hatchRequestStore: HatchRequestStore(() async => tempDir),
    petPackService: PetPackService(() async => tempDir),
  );
  await controller.initialize();
  runApp(
    _GoldenGenerator(
      controller: controller,
      eventLog: eventLog,
      tempDir: tempDir,
      outputDirectory: Directory(outputPath),
    ),
  );
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

class _GoldenGenerator extends StatefulWidget {
  const _GoldenGenerator({
    required this.controller,
    required this.eventLog,
    required this.tempDir,
    required this.outputDirectory,
  });

  final AppController controller;
  final EventLogStore eventLog;
  final Directory tempDir;
  final Directory outputDirectory;

  @override
  State<_GoldenGenerator> createState() => _GoldenGeneratorState();
}

class _GoldenGeneratorState extends State<_GoldenGenerator> {
  final GlobalKey _boundary = GlobalKey();
  var _index = 0;

  late final List<(String, Widget)> _screens = <(String, Widget)>[
    (
      'pixel_home_393.png',
      HomeScreen(
        controller: widget.controller,
        eventLog: widget.eventLog,
        now: DateTime(2026, 8, 24, 15),
        visualTestMode: true,
      ),
    ),
    (
      'pixel_settings_393.png',
      SettingsScreen(controller: widget.controller, eventLog: widget.eventLog),
    ),
    (
      'pixel_collection_393.png',
      CollectionScreen(controller: widget.controller),
    ),
    for (final entry in <(OnboardingStep, String)>[
      (OnboardingStep.choosePet, 'pixel_onboarding_s1_393.png'),
      (OnboardingStep.namePet, 'pixel_onboarding_s2_393.png'),
      (OnboardingStep.littleThings, 'pixel_onboarding_s3_393.png'),
      (OnboardingStep.celebrate, 'pixel_onboarding_s4_393.png'),
      (OnboardingStep.stayOnScreen, 'pixel_onboarding_s5_393.png'),
    ])
      (
        entry.$2,
        OnboardingScreen(
          key: ValueKey<OnboardingStep>(entry.$1),
          controller: widget.controller,
          initialStep: entry.$1,
          showStayOnScreen: true,
          initialSelectedThingIndexes: const <int>{0, 1, 3},
        ),
      ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final directory = widget.outputDirectory..createSync(recursive: true);
    File(
      '${directory.path}/${_screens[_index].$1}',
    ).writeAsBytesSync(bytes!.buffer.asUint8List(), flush: true);
    if (_index + 1 < _screens.length) {
      setState(() => _index += 1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
      return;
    }
    widget.controller.dispose();
    widget.tempDir.deleteSync(recursive: true);
    exit(0);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 393,
          maxWidth: 393,
          minHeight: 852,
          maxHeight: 852,
          child: RepaintBoundary(
            key: _boundary,
            child: SizedBox(
              width: 393,
              height: 852,
              child: MaterialApp(
                key: ValueKey<int>(_index),
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: const MediaQueryData(
                    size: Size(393, 852),
                    devicePixelRatio: 1,
                  ),
                  child: TickerMode(enabled: false, child: child!),
                ),
                home: _screens[_index].$2,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
