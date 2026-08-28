import 'dart:convert';

import 'package:flutter/services.dart';

class RoomAsset {
  const RoomAsset({
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
  const RoomAssetManifest(
    this.furnitureById, [
    this.accessoryById = const <String, RoomAsset>{},
  ]);

  final Map<String, RoomAsset> furnitureById;
  final Map<String, RoomAsset> accessoryById;
}

class RoomAssetManifestLoader {
  RoomAssetManifestLoader({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<RoomAssetManifest> load() async {
    final json =
        jsonDecode(await _bundle.loadString('assets/room/manifest.json'))
            as Map<String, Object?>;
    final furniture = <String, RoomAsset>{};
    for (final raw in json['furniture']! as List<Object?>) {
      final asset = _parseAsset(raw);
      furniture[asset.id] = asset;
    }
    final accessories = <String, RoomAsset>{};
    for (final raw
        in json['accessories'] as List<Object?>? ?? const <Object?>[]) {
      final asset = _parseAsset(raw);
      accessories[asset.id] = asset;
    }
    return RoomAssetManifest(
      Map<String, RoomAsset>.unmodifiable(furniture),
      Map<String, RoomAsset>.unmodifiable(accessories),
    );
  }
}

RoomAsset _parseAsset(Object? raw) {
  final item = raw! as Map<String, Object?>;
  return RoomAsset(
    id: item['id']! as String,
    assetPath: item['asset']! as String,
    pixelWidth: item['pixel_width']! as int,
    pixelHeight: item['pixel_height']! as int,
    placeholderHex: item['placeholder']! as String,
  );
}
