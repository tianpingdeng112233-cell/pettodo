import 'package:flutter/material.dart';

import '../../data/room_asset_manifest.dart';
import '../../domain/furniture.dart';
import 'room_asset_item_preview.dart';

class FurnitureItemView extends StatelessWidget {
  const FurnitureItemView({
    super.key,
    required this.item,
    required this.manifest,
    this.scale = 1,
    this.scaleMode = RoomAssetScaleMode.fixed,
  });

  final FurnitureItem item;
  final RoomAssetManifest manifest;
  final int scale;
  final RoomAssetScaleMode scaleMode;

  @override
  Widget build(BuildContext context) => RoomAssetItemPreview(
    itemId: item.id,
    itemName: item.name,
    manifest: manifest,
    collection: RoomAssetCollection.furniture,
    scale: scale.toDouble(),
    missingSize: null,
    placeholderMaxLines: 3,
    placeholderFontSize: 8,
    placeholderPadding: const EdgeInsets.all(2),
    scaleMode: scaleMode,
  );
}
