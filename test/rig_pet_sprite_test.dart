import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/room_asset_manifest.dart';
import 'package:pettodo/domain/accessory.dart';
import 'package:pettodo/domain/pet_action.dart';
import 'package:pettodo/sprite/rig_definition.dart';
import 'package:pettodo/sprite/rig_pet.dart';
import 'package:pettodo/sprite/rig_pet_sprite.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';
import 'package:pettodo/ui/widgets/accessory_item_view.dart';

Future<ui.Image> _makeImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xff8a5a2e),
  );
  return recorder.endRecording().toImage(4, 4);
}

Future<LoadedRigPet> _makeRigPet() async {
  final images = await Future.wait(
    List<Future<ui.Image>>.generate(9, (_) => _makeImage()),
  );
  return LoadedRigPet(
    descriptor: const PetAssetDescriptor(
      id: 'test-rig',
      displayName: 'Test Rig',
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
      body: images[0],
      head: images[1],
      closedHead: images[2],
      tail: images[3],
    ),
    sideLayers: RigLayerSet(
      body: images[4],
      head: images[5],
      tail: images[6],
      frontLeg: images[7],
      hindLeg: images[8],
    ),
    sleepImage: await _makeImage(),
  );
}

void main() {
  testWidgets('sleep transition fully fades out equipped accessories', (
    tester,
  ) async {
    late final LoadedRigPet pet;
    await tester.runAsync(() async => pet = await _makeRigPet());
    addTearDown(pet.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 192,
            height: 208,
            child: RigPetSprite(
              pet: pet,
              action: RigPetAction.sleepTransition,
              fixedElapsed: const Duration(milliseconds: 900),
              accessories: const <AccessoryItem>[woolHat],
              accessoryManifest: const RoomAssetManifest(<String, RoomAsset>{}),
            ),
          ),
        ),
      ),
    );

    final accessory = find.byType(AnchoredAccessoryItemView);
    final opacity = find.descendant(
      of: accessory,
      matching: find.byType(Opacity),
    );
    expect(accessory, findsOneWidget);
    expect(opacity, findsOneWidget);
    expect(tester.widget<Opacity>(opacity).opacity, 0);
  });
}
