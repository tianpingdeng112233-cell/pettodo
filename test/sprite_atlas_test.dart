import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frame rectangles come from bundled pet_request metadata', () async {
    final loader = SpriteAtlasLoader(bundle: rootBundle);
    final pets = await loader.loadManifest();
    final choco = pets.singleWhere((pet) => pet.id == 'choco');
    final atlas = await loader.loadDefinition(choco.metadataAsset);

    expect(atlas.columns, 8);
    expect(atlas.rows, 11);
    expect(atlas.sequence('idle').frameCount, 6);
    expect(
      atlas.frameRect('jumping', 4),
      const FrameRect(left: 768, top: 832, width: 192, height: 208),
    );
    expect(
      atlas.frameRect('review', 5),
      const FrameRect(left: 960, top: 1664, width: 192, height: 208),
    );
  });
}
