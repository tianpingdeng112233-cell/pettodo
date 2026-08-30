import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/accessory.dart';
import 'package:pettodo/domain/pet_action.dart';
import 'package:pettodo/sprite/rig_definition.dart';
import 'package:pettodo/sprite/rig_driver.dart';
import 'package:pettodo/sprite/rig_pet.dart';
import 'package:pettodo/sprite/rig_pet_renderer.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';

Future<ui.Image> _fill(ui.Color color) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(
    recorder,
  ).drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), ui.Paint()..color = color);
  return recorder.endRecording().toImage(4, 4);
}

void main() {
  testWidgets('a head garment still paints when the rig has no head layer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final body = await _fill(const ui.Color(0xff8a5a2e));
      final garment = await _fill(const ui.Color(0xff2e8a5a));
      final pet = LoadedRigPet(
        descriptor: const PetAssetDescriptor(
          id: 'headless',
          displayName: 'Headless',
          metadataAsset: 'rig.json',
          spritesheetAsset: 'front-open.png',
          format: PetAssetFormat.rigV3,
        ),
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
              'tail': <int>[2, 1],
            },
          },
        }),
        frontWidth: 4,
        frontHeight: 4,
        sideWidth: null,
        sideHeight: null,
        sleepWidth: 4,
        sleepHeight: 4,
        frontLayers: RigLayerSet(body: body),
        sideLayers: null,
        sleepImage: await _fill(const ui.Color(0xff8a5a2e)),
      );
      addTearDown(pet.dispose);
      final frame = const RigDriver(blinkSeed: 1).sample(
        action: RigPetAction.breathing,
        elapsed: const Duration(milliseconds: 100),
        target: const RigTarget(0, 0),
      );
      final recorder = ui.PictureRecorder();
      paintRigPetFrame(
        canvas: ui.Canvas(recorder),
        size: const ui.Size(8, 8),
        pet: pet,
        frame: frame,
        garmentLayers: <AccessoryAnchor, ui.Image>{
          AccessoryAnchor.head: garment,
        },
      );
      final image = await (recorder.endRecording()).toImage(8, 8);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final bytes = data.buffer.asUint8List();
      var greenish = 0;
      for (var i = 0; i < bytes.length; i += 4) {
        if (bytes[i + 1] > bytes[i] && bytes[i + 3] > 32) greenish++;
      }
      expect(greenish, greaterThan(0));
    });
  });
}
