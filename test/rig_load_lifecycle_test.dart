import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/app_controller.dart';
import 'package:pettodo/data/app_state_store.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/data/hatch_request_store.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/data/pet_pack_service.dart';
import 'package:pettodo/sprite/rig_definition.dart';
import 'package:pettodo/sprite/rig_pet.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';

class _BlockingRigLoader extends RigPetLoader {
  final Completer<void> gate = Completer<void>();
  int loads = 0;

  @override
  Future<LoadedRigPet> load(PetAssetDescriptor descriptor) async {
    loads++;
    await gate.future;
    Future<ui.Image> makeImage() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 4, 4),
        ui.Paint()..color = const ui.Color(0xff000000),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(4, 4);
      picture.dispose();
      return image;
    }

    return LoadedRigPet(
      descriptor: descriptor,
      definition: RigDefinition.fromJson(const <String, Object?>{
        'rigVersion': 1,
        'front': <String, Object?>{
          'groundY': 3,
          'boxes': <String, Object?>{
            'head': <int>[0, 0, 2, 2],
            'tail': <int>[2, 0, 4, 2],
            'leftFrontLeg': <int>[0, 2, 2, 4],
            'rightFrontLeg': <int>[2, 2, 4, 4],
          },
          'pivots': <String, Object?>{
            'head': <int>[1, 2],
            'tail': <int>[2, 1],
          },
        },
        'side': <String, Object?>{
          'groundY': 3,
          'facing': 'right',
          'boxes': <String, Object?>{
            'head': <int>[0, 0, 2, 2],
            'tail': <int>[2, 0, 4, 2],
            'frontLeg': <int>[0, 2, 2, 4],
            'hindLeg': <int>[2, 2, 4, 4],
          },
          'pivots': <String, Object?>{
            'head': <int>[1, 2],
            'tail': <int>[2, 1],
            'frontLeg': <int>[1, 2],
            'hindLeg': <int>[3, 2],
          },
        },
      }),
      frontWidth: 4,
      frontHeight: 4,
      sideWidth: 4,
      sideHeight: 4,
      sleepWidth: 4,
      sleepHeight: 4,
      frontLayers: RigLayerSet(
        body: await makeImage(),
        head: await makeImage(),
        closedHead: await makeImage(),
        tail: await makeImage(),
      ),
      sideLayers: RigLayerSet(
        body: await makeImage(),
        head: await makeImage(),
        tail: await makeImage(),
        frontLeg: await makeImage(),
        hindLeg: await makeImage(),
      ),
      sleepImage: await makeImage(),
    );
  }
}

PetAssetDescriptor _rigDescriptor() => const PetAssetDescriptor(
  id: 'ghost',
  displayName: 'Ghost',
  metadataAsset: '/tmp/none/rig.json',
  spritesheetAsset: '/tmp/none/front-open.png',
  source: PetAssetSource.fileSystem,
  format: PetAssetFormat.rigV3,
  rig: RigAssetDescriptor(
    species: 'cat',
    rigAsset: '/tmp/none/rig.json',
    frontOpenAsset: '/tmp/none/front-open.png',
    frontClosedAsset: '/tmp/none/front-closed.png',
    sleepAsset: '/tmp/none/sleep.png',
    sideAsset: '/tmp/none/side.png',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an in-flight rig load fails terminally after dispose '
      'instead of hanging or caching into a dead controller', (tester) async {
    await tester.runAsync(() async {
      final tempDir = Directory.systemTemp.createTempSync('pettodo-rig-life');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final loader = _BlockingRigLoader();
      final controller = AppController(
        stateStore: AppStateStore(() async => tempDir),
        eventLog: EventLogStore(() async => tempDir),
        notifications: NotificationService(),
        rigLoader: loader,
        hatchRequestStore: HatchRequestStore(() async => tempDir),
        petPackService: PetPackService(() async => tempDir),
      );
      await controller.initialize();

      final pending = controller.petRig(_rigDescriptor());
      // swallow errors through a plain await: expectLater's completion binds
      // to the fake-async test zone and would never fire inside runAsync
      final settled = pending.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      controller.dispose();
      loader.gate.complete();

      // the load must complete with an error — never hang (deadlock
      // regression) and never cache images into a disposed controller
      final outcome = await settled;
      expect(outcome, isA<StateError>());
      expect(loader.loads, 1);
    });
  });

  testWidgets('an import-replacement load interrupted by dispose fails '
      'terminally instead of caching into a dead controller', (tester) async {
    await tester.runAsync(() async {
      final tempDir = Directory.systemTemp.createTempSync('pettodo-rig-repl');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final loader = _BlockingRigLoader();
      final controller = AppController(
        stateStore: AppStateStore(() async => tempDir),
        eventLog: EventLogStore(() async => tempDir),
        notifications: NotificationService(),
        rigLoader: loader,
        hatchRequestStore: HatchRequestStore(() async => tempDir),
        petPackService: PetPackService(() async => tempDir),
      );
      await controller.initialize();

      final pack = await _writeMinimalRigPack(tempDir);
      final pending = controller.importPetPack(pack);
      final settled = pending.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      // wait until the import reaches the blocked rig load, then dispose
      while (loader.loads == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      controller.dispose();
      loader.gate.complete();

      final outcome = await settled;
      expect(outcome, isA<StateError>());
    });
  });
}

Future<File> _writeMinimalRigPack(Directory directory) async {
  Future<Uint8List> pose() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawColor(const ui.Color(0x00000000), ui.BlendMode.src)
      ..drawRect(
        const ui.Rect.fromLTWH(8, 4, 48, 56),
        ui.Paint()..color = const ui.Color(0xffb87333),
      );
    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  final poseBytes = await pose();
  final archive = Archive();
  void add(String name, List<int> bytes) =>
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
  add(
    'pack.json',
    utf8.encode(
      jsonEncode(<String, Object?>{
        'formatVersion': 3,
        'id': 'repl',
        'display_name': 'Repl',
        'species': 'cat',
        'treat': <String, String>{'name': 'Fish', 'emoji': '🐟'},
      }),
    ),
  );
  add(
    'rig.json',
    utf8.encode(
      jsonEncode(<String, Object?>{
        'rigVersion': 1,
        'front': <String, Object?>{
          'groundY': 60,
          'boxes': <String, Object?>{
            'head': <int>[16, 4, 48, 28],
            'tail': <int>[50, 24, 62, 50],
            'leftFrontLeg': <int>[18, 30, 30, 60],
            'rightFrontLeg': <int>[34, 30, 46, 60],
          },
          'pivots': <String, Object?>{
            'head': <int>[32, 28],
            'tail': <int>[50, 37],
          },
        },
        'side': <String, Object?>{
          'groundY': 60,
          'facing': 'right',
          'boxes': <String, Object?>{
            'head': <int>[36, 4, 60, 26],
            'tail': <int>[2, 20, 14, 44],
            'frontLeg': <int>[40, 30, 50, 60],
            'hindLeg': <int>[14, 30, 24, 60],
          },
          'pivots': <String, Object?>{
            'head': <int>[48, 26],
            'tail': <int>[14, 32],
            'frontLeg': <int>[45, 30],
            'hindLeg': <int>[19, 30],
          },
        },
      }),
    ),
  );
  for (final name in <String>[
    'front-open.png',
    'front-closed.png',
    'sleep.png',
    'side.png',
  ]) {
    add(name, poseBytes);
  }
  final file = File('${directory.path}/repl.pettodopet');
  file.writeAsBytesSync(ZipEncoder().encode(archive)!);
  return file;
}
