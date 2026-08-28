import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/sprite/overlay_frame_baker.dart';
import 'package:pettodo/sprite/rig_definition.dart';
import 'package:pettodo/sprite/rig_pet.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only the latest overlay bake generation can commit', () {
    final generations = OverlayBakeGeneration();
    final older = generations.begin();
    final latest = generations.begin();

    expect(generations.isCurrent(older), isFalse);
    expect(generations.isCurrent(latest), isTrue);
  });

  testWidgets(
    'the same atlas pet and bake parameters produce identical frame hashes',
    (tester) async {
      await tester.runAsync(() async {
        final support = Directory.systemTemp.createTempSync(
          'pettodo-overlay-bake',
        );
        addTearDown(() => support.deleteSync(recursive: true));
        final descriptor = (await SpriteAtlasLoader().loadManifest()).single;
        final atlas = await SpriteAtlasLoader().loadPet(descriptor);
        addTearDown(atlas.image.dispose);
        final baker = OverlayFrameBaker(() async => support);

        final first = await baker.bakeAtlas(atlas);
        final firstHashes = <String>[
          for (final file in first.allFiles)
            sha256.convert(await file.readAsBytes()).toString(),
        ];
        final second = await baker.bakeAtlas(atlas);
        final secondHashes = <String>[
          for (final file in second.allFiles)
            sha256.convert(await file.readAsBytes()).toString(),
        ];

        expect(first.idleFiles, hasLength(6));
        expect(first.jumpingFiles, hasLength(5));
        expect(secondHashes, firstHashes);
      });
    },
  );

  testWidgets(
    'the same rig pet and bake parameters produce identical frame hashes',
    (tester) async {
      await tester.runAsync(() async {
        final support = Directory.systemTemp.createTempSync(
          'pettodo-overlay-rig-bake',
        );
        addTearDown(() => support.deleteSync(recursive: true));
        final pet = await _makeRigPet();
        addTearDown(pet.dispose);
        final baker = OverlayFrameBaker(() async => support);

        final first = await baker.bakeRig(pet, contentFingerprint: 'pack-v1');
        final firstHashes = <String>[
          for (final file in first.allFiles)
            sha256.convert(await file.readAsBytes()).toString(),
        ];
        final second = await baker.bakeRig(pet, contentFingerprint: 'pack-v1');
        final secondHashes = <String>[
          for (final file in second.allFiles)
            sha256.convert(await file.readAsBytes()).toString(),
        ];

        expect(first.idleFiles.length, inInclusiveRange(24, 32));
        expect(first.jumpingFiles, hasLength(8));
        expect(secondHashes, firstHashes);
      });
    },
  );

  testWidgets('rig bake cache hits by fingerprint and misses when it changes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final support = Directory.systemTemp.createTempSync(
        'pettodo-overlay-rig-cache',
      );
      addTearDown(() => support.deleteSync(recursive: true));
      final pet = await _makeRigPet();
      addTearDown(pet.dispose);
      final baker = OverlayFrameBaker(() async => support);

      final first = await baker.bakeRig(pet, contentFingerprint: 'pack-v1');
      final frame = first.idleFiles.first;
      await frame.writeAsBytes(<int>[1, 2, 3], flush: true);

      final hit = await baker.bakeRig(pet, contentFingerprint: 'pack-v1');
      expect(await hit.idleFiles.first.readAsBytes(), <int>[1, 2, 3]);

      final miss = await baker.bakeRig(pet, contentFingerprint: 'pack-v2');
      final bytes = await miss.idleFiles.first.readAsBytes();
      expect(bytes.take(4), orderedEquals(<int>[137, 80, 78, 71]));
    });
  });
}

Future<LoadedRigPet> _makeRigPet() async {
  Future<ui.Image> image(ui.Color color) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawColor(const ui.Color(0x00000000), ui.BlendMode.src)
      ..drawRect(
        const ui.Rect.fromLTWH(8, 4, 48, 56),
        ui.Paint()
          ..isAntiAlias = false
          ..color = color,
      );
    final picture = recorder.endRecording();
    final result = await picture.toImage(64, 64);
    picture.dispose();
    return result;
  }

  const descriptor = PetAssetDescriptor(
    id: 'rig-pip',
    displayName: 'Pip',
    metadataAsset: '/rig-pip/rig.json',
    spritesheetAsset: '/rig-pip/front-open.png',
    source: PetAssetSource.fileSystem,
    format: PetAssetFormat.rigV3,
    rig: RigAssetDescriptor(
      species: 'dog',
      rigAsset: '/rig-pip/rig.json',
      frontOpenAsset: '/rig-pip/front-open.png',
      frontClosedAsset: '/rig-pip/front-closed.png',
      sleepAsset: '/rig-pip/sleep.png',
      sideAsset: '/rig-pip/side.png',
    ),
  );
  final definition = RigDefinition.fromJson(const <String, Object?>{
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
  });
  return LoadedRigPet(
    descriptor: descriptor,
    definition: definition,
    frontWidth: 64,
    frontHeight: 64,
    sideWidth: 64,
    sideHeight: 64,
    frontLayers: RigLayerSet(
      body: await image(const ui.Color(0xff9b653f)),
      head: await image(const ui.Color(0xffc58a5d)),
      closedHead: await image(const ui.Color(0xffb77b51)),
      tail: await image(const ui.Color(0xff8f5937)),
    ),
    sideLayers: RigLayerSet(
      body: await image(const ui.Color(0xff9b653f)),
      head: await image(const ui.Color(0xffc58a5d)),
      tail: await image(const ui.Color(0xff8f5937)),
      frontLeg: await image(const ui.Color(0xffaa7048)),
      hindLeg: await image(const ui.Color(0xffaa7048)),
    ),
    sleepImage: await image(const ui.Color(0xff9b653f)),
    sleepWidth: 64,
    sleepHeight: 64,
  );
}
