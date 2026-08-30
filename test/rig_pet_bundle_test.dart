import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/accessory.dart';
import 'package:pettodo/sprite/rig_pet.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(Map<String, List<int>> assets)
    : _assets = <String, Uint8List>{
        for (final entry in assets.entries)
          entry.key: Uint8List.fromList(entry.value),
      };

  final Map<String, Uint8List> _assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = _assets[key];
    if (bytes == null) throw StateError('Missing test asset: $key');
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RigPetLoader loads a bundled rig pack from an AssetBundle', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final poseBytes = await _makePosePng();
      final bundle = _MemoryAssetBundle(<String, List<int>>{
        'assets/pets/shiba/rig.json': utf8.encode(jsonEncode(_rigJson())),
        'assets/pets/shiba/front-open.png': poseBytes,
        'assets/pets/shiba/front-closed.png': poseBytes,
        'assets/pets/shiba/sleep.png': poseBytes,
        'assets/pets/shiba/side.png': poseBytes,
      });
      const descriptor = PetAssetDescriptor(
        id: 'shiba',
        displayName: 'Shiba',
        metadataAsset: 'assets/pets/shiba/rig.json',
        spritesheetAsset: 'assets/pets/shiba/front-open.png',
        source: PetAssetSource.bundled,
        format: PetAssetFormat.rigV3,
        rig: RigAssetDescriptor(
          species: 'dog',
          rigAsset: 'assets/pets/shiba/rig.json',
          frontOpenAsset: 'assets/pets/shiba/front-open.png',
          frontClosedAsset: 'assets/pets/shiba/front-closed.png',
          sleepAsset: 'assets/pets/shiba/sleep.png',
          sideAsset: 'assets/pets/shiba/side.png',
        ),
      );

      final pet = await RigPetLoader(bundle: bundle).load(descriptor);
      addTearDown(pet.dispose);

      expect(pet.descriptor.source, PetAssetSource.bundled);
      expect(pet.definition.rigVersion, 1);
      expect(pet.frontWidth, 64);
      expect(pet.frontHeight, 64);
      expect(pet.sideWidth, 64);
      expect(pet.sideHeight, 64);
      expect(pet.frontLayers.closedHead, isNotNull);
      expect(pet.sideLayers?.frontLeg, isNotNull);
      expect(pet.sideLayers?.hindLeg, isNotNull);
    });
  });

  testWidgets('RigPetLoader loads a bundled rig pack without side layers', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final poseBytes = await _makePosePng();
      final sidelessRig = _rigJson()..remove('side');
      final bundle = _MemoryAssetBundle(<String, List<int>>{
        'assets/pets/choco/rig.json': utf8.encode(jsonEncode(sidelessRig)),
        'assets/pets/choco/front-open.png': poseBytes,
        'assets/pets/choco/front-closed.png': poseBytes,
        'assets/pets/choco/sleep.png': poseBytes,
      });
      const descriptor = PetAssetDescriptor(
        id: 'choco',
        displayName: 'Choco',
        metadataAsset: 'assets/pets/choco/rig.json',
        spritesheetAsset: 'assets/pets/choco/front-open.png',
        source: PetAssetSource.bundled,
        format: PetAssetFormat.rigV3,
        rig: RigAssetDescriptor(
          species: 'dog',
          rigAsset: 'assets/pets/choco/rig.json',
          frontOpenAsset: 'assets/pets/choco/front-open.png',
          frontClosedAsset: 'assets/pets/choco/front-closed.png',
          sleepAsset: 'assets/pets/choco/sleep.png',
          sideAsset: null,
        ),
      );

      final pet = await RigPetLoader(bundle: bundle).load(descriptor);
      addTearDown(pet.dispose);

      expect(pet.definition.side, isNull);
      expect(pet.sideWidth, isNull);
      expect(pet.sideHeight, isNull);
      expect(pet.sideLayers, isNull);
    });
  });

  testWidgets('RigPetLoader loads fitted garment layers beside a rig pack', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final poseBytes = await _makePosePng();
      final bundle = _MemoryAssetBundle(<String, List<int>>{
        'assets/pets/choco/rig.json': utf8.encode(
          jsonEncode(_rigJson()..remove('side')),
        ),
        'assets/pets/choco/front-open.png': poseBytes,
        'assets/pets/choco/front-closed.png': poseBytes,
        'assets/pets/choco/sleep.png': poseBytes,
        'assets/pets/choco/garments/garments.json': utf8.encode(
          jsonEncode(<String, Object?>{
            'formatVersion': 1,
            'petId': 'choco',
            'canvas': <String, int>{'width': 64, 'height': 64},
            'garments': <Map<String, Object?>>[
              <String, Object?>{
                'id': woolHat.id,
                'anchor': woolHat.anchor.name,
                'asset': 'wool_hat.png',
              },
            ],
          }),
        ),
        'assets/pets/choco/garments/wool_hat.png': poseBytes,
      });
      const descriptor = PetAssetDescriptor(
        id: 'choco',
        displayName: 'Choco',
        metadataAsset: 'assets/pets/choco/rig.json',
        spritesheetAsset: 'assets/pets/choco/front-open.png',
        source: PetAssetSource.bundled,
        format: PetAssetFormat.rigV3,
        rig: RigAssetDescriptor(
          species: 'dog',
          rigAsset: 'assets/pets/choco/rig.json',
          frontOpenAsset: 'assets/pets/choco/front-open.png',
          frontClosedAsset: 'assets/pets/choco/front-closed.png',
          sleepAsset: 'assets/pets/choco/sleep.png',
          sideAsset: null,
        ),
      );

      final pet = await RigPetLoader(bundle: bundle).load(descriptor);
      addTearDown(pet.dispose);

      expect(pet.garments?.manifest.petId, 'choco');
      expect(pet.garments?.imagesById.keys, <String>{woolHat.id});
      expect(pet.garments?.imagesById[woolHat.id]?.width, 64);
    });
  });

  testWidgets(
    'RigPetLoader skips each unavailable garment image without losing the pet',
    (tester) async {
      late final LoadedRigPet pet;
      await tester.runAsync(() async {
        final poseBytes = await _makePosePng();
        final wrongSizeBytes = await _makePosePng(width: 32);
        final bundle = _MemoryAssetBundle(<String, List<int>>{
          'assets/pets/choco/rig.json': utf8.encode(
            jsonEncode(_rigJson()..remove('side')),
          ),
          'assets/pets/choco/front-open.png': poseBytes,
          'assets/pets/choco/front-closed.png': poseBytes,
          'assets/pets/choco/sleep.png': poseBytes,
          'assets/pets/choco/garments/garments.json': utf8.encode(
            jsonEncode(<String, Object?>{
              'formatVersion': 1,
              'petId': 'choco',
              'canvas': <String, int>{'width': 64, 'height': 64},
              'garments': <Map<String, Object?>>[
                <String, Object?>{
                  'id': woolHat.id,
                  'anchor': woolHat.anchor.name,
                  'asset': 'wool_hat.png',
                },
                <String, Object?>{
                  'id': strawHat.id,
                  'anchor': strawHat.anchor.name,
                  'asset': 'straw_hat.png',
                },
                <String, Object?>{
                  'id': partyHat.id,
                  'anchor': partyHat.anchor.name,
                  'asset': 'party_hat.png',
                },
                <String, Object?>{
                  'id': redScarf.id,
                  'anchor': redScarf.anchor.name,
                  'asset': 'red_scarf.png',
                },
              ],
            }),
          ),
          'assets/pets/choco/garments/wool_hat.png': poseBytes,
          // straw_hat.png is intentionally missing.
          'assets/pets/choco/garments/party_hat.png': <int>[0, 1, 2, 3],
          'assets/pets/choco/garments/red_scarf.png': wrongSizeBytes,
        });
        pet = await RigPetLoader(bundle: bundle).load(_chocoDescriptor);
      });
      addTearDown(pet.dispose);

      expect(pet.frontWidth, 64);
      expect(pet.garments?.manifest.garmentsById.keys, <String>{
        woolHat.id,
        strawHat.id,
        partyHat.id,
        redScarf.id,
      });
      expect(pet.garments?.imagesById.keys, <String>{woolHat.id});
    },
  );

  testWidgets('front layers at rest reconstruct every opaque source pixel', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final poseBytes = await _makePosePng();
      final bundle = _MemoryAssetBundle(<String, List<int>>{
        'assets/pets/shiba/rig.json': utf8.encode(jsonEncode(_rigJson())),
        'assets/pets/shiba/front-open.png': poseBytes,
        'assets/pets/shiba/front-closed.png': poseBytes,
        'assets/pets/shiba/sleep.png': poseBytes,
        'assets/pets/shiba/side.png': poseBytes,
      });
      const descriptor = PetAssetDescriptor(
        id: 'shiba',
        displayName: 'Shiba',
        metadataAsset: 'assets/pets/shiba/rig.json',
        spritesheetAsset: 'assets/pets/shiba/front-open.png',
        source: PetAssetSource.bundled,
        format: PetAssetFormat.rigV3,
        rig: RigAssetDescriptor(
          species: 'dog',
          rigAsset: 'assets/pets/shiba/rig.json',
          frontOpenAsset: 'assets/pets/shiba/front-open.png',
          frontClosedAsset: 'assets/pets/shiba/front-closed.png',
          sleepAsset: 'assets/pets/shiba/sleep.png',
          sideAsset: 'assets/pets/shiba/side.png',
        ),
      );
      final pet = await RigPetLoader(bundle: bundle).load(descriptor);
      addTearDown(pet.dispose);

      final codec = await ui.instantiateImageCodec(poseBytes);
      final source = (await codec.getNextFrame()).image;
      codec.dispose();
      addTearDown(source.dispose);
      final sourcePx = await _rawRgba(source);
      final layers = await Future.wait(<Future<Uint8List>>[
        _rawRgba(pet.frontLayers.tail!),
        _rawRgba(pet.frontLayers.body),
        _rawRgba(pet.frontLayers.head!),
      ]);

      // painter order at rest: tail, body, head — alpha-over per pixel must
      // give back the full sprite, or motion exposes the deficit as a hole
      var worst = 255;
      var worstAt = -1;
      for (var i = 3; i < sourcePx.length; i += 4) {
        if (sourcePx[i] < 250) continue;
        var alpha = 0.0;
        for (final layer in layers) {
          alpha = alpha + (layer[i] / 255) * (1 - alpha);
        }
        final combined = (alpha * 255).round();
        if (combined < worst) {
          worst = combined;
          worstAt = i ~/ 4;
        }
      }
      expect(
        worst,
        greaterThanOrEqualTo(242),
        reason:
            'opaque source pixel ${worstAt % 64},${worstAt ~/ 64} '
            'reconstructs to alpha $worst',
      );
    });
  });
}

const _chocoDescriptor = PetAssetDescriptor(
  id: 'choco',
  displayName: 'Choco',
  metadataAsset: 'assets/pets/choco/rig.json',
  spritesheetAsset: 'assets/pets/choco/front-open.png',
  source: PetAssetSource.bundled,
  format: PetAssetFormat.rigV3,
  rig: RigAssetDescriptor(
    species: 'dog',
    rigAsset: 'assets/pets/choco/rig.json',
    frontOpenAsset: 'assets/pets/choco/front-open.png',
    frontClosedAsset: 'assets/pets/choco/front-closed.png',
    sleepAsset: 'assets/pets/choco/sleep.png',
    sideAsset: null,
  ),
);

Future<Uint8List> _makePosePng({int width = 64, int height = 64}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawColor(const ui.Color(0x00000000), ui.BlendMode.src)
    ..drawRect(
      const ui.Rect.fromLTWH(8, 4, 48, 56),
      ui.Paint()..color = const ui.Color(0xffb87333),
    );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Map<String, Object?> _rigJson() => <String, Object?>{
  'rigVersion': 1,
  'front': <String, Object?>{
    'groundY': 60,
    'boxes': <String, Object?>{
      'head': <int>[8, 4, 56, 28],
      'tail': <int>[4, 30, 16, 52],
      'leftFrontLeg': <int>[20, 28, 28, 60],
      'rightFrontLeg': <int>[36, 28, 44, 60],
    },
    'pivots': <String, Object?>{
      'head': <int>[32, 28],
      'tail': <int>[16, 36],
    },
  },
  'side': <String, Object?>{
    'groundY': 60,
    'facing': 'right',
    'boxes': <String, Object?>{
      'head': <int>[34, 4, 58, 28],
      'tail': <int>[4, 20, 18, 36],
      'frontLeg': <int>[38, 28, 46, 60],
      'hindLeg': <int>[18, 28, 28, 60],
    },
    'pivots': <String, Object?>{
      'head': <int>[44, 28],
      'tail': <int>[18, 28],
      'frontLeg': <int>[42, 28],
      'hindLeg': <int>[23, 28],
    },
  },
};

Future<Uint8List> _rawRgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
