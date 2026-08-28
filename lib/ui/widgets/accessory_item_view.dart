import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/room_asset_manifest.dart';
import '../../domain/accessory.dart';
import '../../sprite/accessory_anchors.dart';
import 'room_asset_item_preview.dart';

class AccessoryItemView extends StatelessWidget {
  const AccessoryItemView({
    super.key,
    required this.item,
    required this.manifest,
    this.scale = 1,
  });

  final AccessoryItem item;
  final RoomAssetManifest manifest;
  final double scale;

  RoomAssetItemPreview get _preview => RoomAssetItemPreview(
    itemId: item.id,
    itemName: item.name,
    manifest: manifest,
    collection: RoomAssetCollection.accessory,
    scale: scale,
    missingSize: Size(40 * scale, 24 * scale),
    placeholderMaxLines: 2,
    placeholderFontSize: (7 * scale).clamp(5, 9),
  );

  Size get displaySize => _preview.displaySize!;

  @override
  Widget build(BuildContext context) => _preview;
}

class AnchoredAccessoryItemView extends StatelessWidget {
  const AnchoredAccessoryItemView({
    super.key,
    required this.item,
    required this.manifest,
    required this.pose,
    required this.scale,
    this.opacity = 1,
  });

  final AccessoryItem item;
  final RoomAssetManifest manifest;
  final AccessoryPose pose;
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final view = AccessoryItemView(
      item: item,
      manifest: manifest,
      scale: scale,
    );
    final size = view.displaySize;
    final alignment = item.anchor == AccessoryAnchor.head
        ? Alignment.bottomCenter
        : Alignment.center;
    final top = item.anchor == AccessoryAnchor.head
        ? pose.y - size.height
        : pose.y - size.height / 2;
    return Positioned(
      left: pose.x - size.width / 2,
      top: top,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: pose.rotationDegrees * math.pi / 180,
          alignment: alignment,
          child: view,
        ),
      ),
    );
  }
}
