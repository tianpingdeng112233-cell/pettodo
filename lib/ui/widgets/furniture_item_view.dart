import 'package:flutter/material.dart';

import '../../data/room_asset_manifest.dart';
import '../../domain/furniture.dart';
import 'pixel_asset_thumb.dart';

class FurnitureItemView extends StatelessWidget {
  const FurnitureItemView({
    super.key,
    required this.item,
    required this.manifest,
    this.scale = 1,
  });

  final FurnitureItem item;
  final RoomAssetManifest manifest;
  final int scale;

  @override
  Widget build(BuildContext context) => PixelAssetThumb(
    asset: manifest.furnitureById[item.id],
    name: item.name,
    scale: scale,
  );
}
