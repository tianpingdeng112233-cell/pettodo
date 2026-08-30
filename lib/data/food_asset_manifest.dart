import 'dart:convert';

import 'package:flutter/services.dart';

import 'pixel_asset_manifest.dart';

typedef FoodAsset = PixelAsset;

class FoodAssetManifest {
  const FoodAssetManifest(this.foodById);

  final Map<String, FoodAsset> foodById;
}

class FoodAssetManifestLoader {
  FoodAssetManifestLoader({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<FoodAssetManifest> load() async {
    final json =
        jsonDecode(await _bundle.loadString('assets/food/manifest.json'))
            as Map<String, Object?>;
    return FoodAssetManifest(parsePixelAssetSection(json, 'food'));
  }
}
