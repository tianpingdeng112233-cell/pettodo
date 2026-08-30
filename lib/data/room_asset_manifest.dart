import 'dart:convert';

import 'package:flutter/services.dart';

class RoomFurnitureAsset {
  const RoomFurnitureAsset({
    required this.id,
    required this.assetPath,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.placeholderHex,
  });

  final String id;
  final String assetPath;
  final int pixelWidth;
  final int pixelHeight;
  final String placeholderHex;
}

class RoomAssetManifest {
  const RoomAssetManifest(this.furnitureById);

  final Map<String, RoomFurnitureAsset> furnitureById;
}

class RoomAssetManifestLoader {
  RoomAssetManifestLoader({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<RoomAssetManifest> load() async {
    final json =
        jsonDecode(await _bundle.loadString('assets/room/manifest.json'))
            as Map<String, Object?>;
    final furniture = <String, RoomFurnitureAsset>{};
    for (final raw in json['furniture']! as List<Object?>) {
      final item = raw! as Map<String, Object?>;
      final asset = RoomFurnitureAsset(
        id: item['id']! as String,
        assetPath: item['asset']! as String,
        pixelWidth: item['pixel_width']! as int,
        pixelHeight: item['pixel_height']! as int,
        placeholderHex: item['placeholder']! as String,
      );
      furniture[asset.id] = asset;
    }
    return RoomAssetManifest(
      Map<String, RoomFurnitureAsset>.unmodifiable(furniture),
    );
  }
}
