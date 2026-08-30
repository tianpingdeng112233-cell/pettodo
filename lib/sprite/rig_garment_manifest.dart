import 'dart:convert';

import '../domain/accessory.dart';

const int currentRigGarmentFormatVersion = 1;

class RigGarmentAsset {
  const RigGarmentAsset({
    required this.id,
    required this.anchor,
    required this.assetPath,
  });

  final String id;
  final AccessoryAnchor anchor;
  final String assetPath;
}

class RigGarmentManifest {
  const RigGarmentManifest({
    required this.formatVersion,
    required this.petId,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.garmentsById,
  });

  final int formatVersion;
  final String petId;
  final int canvasWidth;
  final int canvasHeight;
  final Map<String, RigGarmentAsset> garmentsById;
}

enum RigAccessoryRenderMode { fittedLayer, anchoredSticker }

class RigAccessoryRenderSelection {
  const RigAccessoryRenderSelection._({required this.mode, this.garment});

  const RigAccessoryRenderSelection.fitted(RigGarmentAsset garment)
    : this._(mode: RigAccessoryRenderMode.fittedLayer, garment: garment);

  const RigAccessoryRenderSelection.sticker()
    : this._(mode: RigAccessoryRenderMode.anchoredSticker);

  final RigAccessoryRenderMode mode;
  final RigGarmentAsset? garment;
}

RigGarmentManifest parseRigGarmentManifest({
  required String source,
  required String manifestAsset,
}) {
  final json = jsonDecode(source);
  if (json is! Map<String, Object?>) {
    throw const FormatException('The garments manifest must be an object.');
  }
  final version = json['formatVersion'];
  if (version is! int || version != currentRigGarmentFormatVersion) {
    throw FormatException('Unsupported garments format version: $version.');
  }
  final petId = json['petId'];
  final canvas = json['canvas'];
  if (petId is! String || petId.isEmpty || canvas is! Map<String, Object?>) {
    throw const FormatException('The garments manifest metadata is invalid.');
  }
  final width = canvas['width'];
  final height = canvas['height'];
  if (width is! int || height is! int || width <= 0 || height <= 0) {
    throw const FormatException('The garment canvas must be positive.');
  }
  final rawGarments = json['garments'];
  if (rawGarments is! List<Object?>) {
    throw const FormatException('The garments list is required.');
  }
  final base = _parentAsset(manifestAsset);
  final garments = <String, RigGarmentAsset>{};
  for (final raw in rawGarments) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('A garment entry must be an object.');
    }
    final id = raw['id'];
    final anchorName = raw['anchor'];
    final asset = raw['asset'];
    final anchor = anchorName is String
        ? AccessoryAnchor.fromName(anchorName)
        : null;
    if (id is! String ||
        id.isEmpty ||
        anchor == null ||
        asset is! String ||
        asset.isEmpty ||
        asset.startsWith('/') ||
        asset.contains('..')) {
      throw const FormatException('A garment entry is invalid.');
    }
    if (garments.containsKey(id)) {
      throw FormatException('Duplicate garment id: $id.');
    }
    garments[id] = RigGarmentAsset(
      id: id,
      anchor: anchor,
      assetPath: '$base/$asset',
    );
  }
  return RigGarmentManifest(
    formatVersion: version,
    petId: petId,
    canvasWidth: width,
    canvasHeight: height,
    garmentsById: Map<String, RigGarmentAsset>.unmodifiable(garments),
  );
}

RigAccessoryRenderSelection selectRigAccessoryRendering({
  required AccessoryItem accessory,
  required RigGarmentManifest? manifest,
}) {
  final garment = manifest?.garmentsById[accessory.id];
  if (garment == null || garment.anchor != accessory.anchor) {
    return const RigAccessoryRenderSelection.sticker();
  }
  return RigAccessoryRenderSelection.fitted(garment);
}

String _parentAsset(String asset) {
  final slash = asset.lastIndexOf('/');
  if (slash <= 0 || slash == asset.length - 1) {
    throw const FormatException('The garments manifest path is invalid.');
  }
  return asset.substring(0, slash);
}
