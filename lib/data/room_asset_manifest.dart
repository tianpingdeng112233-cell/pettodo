import 'dart:convert';

import 'package:flutter/services.dart';

import 'pixel_asset_manifest.dart';

typedef RoomFurnitureAsset = PixelAsset;

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
    return RoomAssetManifest(parsePixelAssetSection(json, 'furniture'));
  }
}
