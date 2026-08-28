import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('RigPetLoader loads a bundled rig pack from an AssetBundle', () async {
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
    expect(pet.sideLayers.frontLeg, isNotNull);
    expect(pet.sideLayers.hindLeg, isNotNull);
  });
}

Future<Uint8List> _makePosePng() async {
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

Map<String, Object?> _rigJson() => <String, Object?>{
  'rigVersion': 1,
  'front': <String, Object?>{
    'groundY': 60,
    'boxes': <String, Object?>{
      'head': <int>[16, 4, 48, 28],
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
