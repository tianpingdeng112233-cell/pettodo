import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/room_asset_manifest.dart';
import 'package:pettodo/ui/widgets/room_asset_item_preview.dart';

const _manifest = RoomAssetManifest(<String, RoomAsset>{
  'wall_clock': RoomAsset(
    id: 'wall_clock',
    assetPath: 'assets/room/wall_clock.png',
    pixelWidth: 24,
    pixelHeight: 24,
    placeholderHex: '#8D7B72',
  ),
});

void main() {
  testWidgets('preview uses the largest whole-pixel scale that fits', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 70,
            child: Center(
              child: RoomAssetItemPreview(
                itemId: 'wall_clock',
                itemName: 'Wall clock',
                manifest: _manifest,
                collection: RoomAssetCollection.furniture,
                scale: 1,
                missingSize: null,
                placeholderMaxLines: 3,
                placeholderFontSize: 8,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(Image)), const Size(48, 48));
    expect(
      tester.widget<Image>(find.byType(Image)).filterQuality,
      FilterQuality.none,
    );
  });

  testWidgets('fixed room placement keeps its requested pixel scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 70,
            child: Center(
              child: RoomAssetItemPreview(
                itemId: 'wall_clock',
                itemName: 'Wall clock',
                manifest: _manifest,
                collection: RoomAssetCollection.furniture,
                scale: 1,
                missingSize: null,
                placeholderMaxLines: 3,
                placeholderFontSize: 8,
                scaleMode: RoomAssetScaleMode.fixed,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(Image)), const Size(24, 24));
  });
}
