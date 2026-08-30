import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/accessory.dart';
import 'package:pettodo/sprite/rig_garment_manifest.dart';

void main() {
  const manifestAsset = 'assets/pets/choco/garments/garments.json';

  test('garments manifest resolves relative assets and fitted rendering', () {
    final manifest = parseRigGarmentManifest(
      source: '''
        {
          "formatVersion": 1,
          "petId": "choco",
          "canvas": {"width": 1024, "height": 1024},
          "garments": [
            {"id": "wool_hat", "anchor": "head", "asset": "wool_hat.png"},
            {"id": "red_scarf", "anchor": "neck", "asset": "red_scarf.png"}
          ]
        }
      ''',
      manifestAsset: manifestAsset,
    );

    expect(manifest.formatVersion, 1);
    expect(manifest.petId, 'choco');
    expect((manifest.canvasWidth, manifest.canvasHeight), (1024, 1024));
    expect(
      manifest.garmentsById[woolHat.id]?.assetPath,
      'assets/pets/choco/garments/wool_hat.png',
    );

    final selection = selectRigAccessoryRendering(
      accessory: woolHat,
      manifest: manifest,
    );
    expect(selection.mode, RigAccessoryRenderMode.fittedLayer);
    expect(selection.garment?.anchor, AccessoryAnchor.head);
  });

  test(
    'missing or mismatched garments select the anchored sticker fallback',
    () {
      final manifest = parseRigGarmentManifest(
        source: '''
        {
          "formatVersion": 1,
          "petId": "choco",
          "canvas": {"width": 1024, "height": 1024},
          "garments": [
            {"id": "wool_hat", "anchor": "neck", "asset": "wool_hat.png"}
          ]
        }
      ''',
        manifestAsset: manifestAsset,
      );

      expect(
        selectRigAccessoryRendering(
          accessory: woolHat,
          manifest: manifest,
        ).mode,
        RigAccessoryRenderMode.anchoredSticker,
      );
      expect(
        selectRigAccessoryRendering(
          accessory: redScarf,
          manifest: manifest,
        ).mode,
        RigAccessoryRenderMode.anchoredSticker,
      );
      expect(
        selectRigAccessoryRendering(accessory: woolHat, manifest: null).mode,
        RigAccessoryRenderMode.anchoredSticker,
      );
    },
  );
}
