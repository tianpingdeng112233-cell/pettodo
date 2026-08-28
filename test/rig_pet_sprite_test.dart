import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/room_asset_manifest.dart';
import 'package:pettodo/domain/accessory.dart';
import 'package:pettodo/domain/pet_action.dart';
import 'package:pettodo/sprite/rig_definition.dart';
import 'package:pettodo/sprite/rig_pet.dart';
import 'package:pettodo/sprite/rig_pet_sprite.dart';
import 'package:pettodo/sprite/pet_sprite.dart';
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

Future<ui.Image> _makeV2Image() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 192, 208),
    ui.Paint()..color = const ui.Color(0xff8a5a2e),
  );
  return recorder.endRecording().toImage(192, 208);
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

Future<LoadedSpriteAtlas> _makeV2Pet() async => LoadedSpriteAtlas(
  descriptor: const PetAssetDescriptor(
    id: 'test-v2',
    displayName: 'Test V2',
    metadataAsset: 'test-v2.json',
    spritesheetAsset: 'test-v2.webp',
  ),
  definition: SpriteAtlasDefinition(
    petId: 'test-v2',
    columns: 1,
    rows: 1,
    cellWidth: 192,
    cellHeight: 208,
    imageWidth: 192,
    imageHeight: 208,
    sequences: const <String, SpriteSequenceDefinition>{
      'idle': SpriteSequenceDefinition(
        state: 'idle',
        row: 0,
        frameCount: 1,
        purpose: 'test',
      ),
    },
  ),
  image: await _makeV2Image(),
);

void main() {
  testWidgets('v2 accessories stay in the fitted pet head and neck bands', (
    tester,
  ) async {
    late final LoadedSpriteAtlas pet;
    await tester.runAsync(() async => pet = await _makeV2Pet());
    addTearDown(pet.image.dispose);
    const manifest =
        RoomAssetManifest(<String, RoomAsset>{}, <String, RoomAsset>{
          'wool_hat': RoomAsset(
            id: 'wool_hat',
            assetPath: 'assets/room/wool_hat.png',
            pixelWidth: 52,
            pixelHeight: 28,
            placeholderHex: '#B96D75',
          ),
          'red_scarf': RoomAsset(
            id: 'red_scarf',
            assetPath: 'assets/room/red_scarf.png',
            pixelWidth: 48,
            pixelHeight: 30,
            placeholderHex: '#BD5956',
          ),
        });

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: PetSprite(
              atlas: pet,
              fixedFrame: 0,
              accessories: const <AccessoryItem>[woolHat, redScarf],
              accessoryManifest: manifest,
            ),
          ),
        ),
      ),
    );

    AnchoredAccessoryItemView accessory(String id) =>
        tester.widget<AnchoredAccessoryItemView>(
          find.byWidgetPredicate(
            (widget) =>
                widget is AnchoredAccessoryItemView && widget.item.id == id,
          ),
        );

    final hat = accessory(woolHat.id);
    final scarf = accessory(redScarf.id);
    // A 192x208 frame fitted into 300x300 is 276.923px wide and horizontally
    // letterboxed by 11.538px. The anchors must follow that drawn rectangle,
    // not the surrounding card.
    const fittedTop = 0.0;
    const fittedHeight = 300.0;
    expect(hat.pose.x, closeTo(150, 0.001));
    expect(
      hat.pose.y,
      inInclusiveRange(
        fittedTop + fittedHeight * 0.15,
        fittedTop + fittedHeight * 0.32,
      ),
    );
    expect(scarf.pose.x, closeTo(150, 0.001));
    expect(
      scarf.pose.y,
      inInclusiveRange(
        fittedTop + fittedHeight * 0.45,
        fittedTop + fittedHeight * 0.65,
      ),
    );
    expect(hat.scale, closeTo(2.884615, 0.000001));
    expect(scarf.scale, closeTo(2.884615, 0.000001));
  });

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
