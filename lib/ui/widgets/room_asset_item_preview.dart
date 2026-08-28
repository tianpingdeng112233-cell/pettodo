import 'package:flutter/material.dart';

import '../../data/room_asset_manifest.dart';
import '../theme/pet_colors.dart';
import '../theme/pet_text_styles.dart';

enum RoomAssetCollection { accessory, furniture }

class RoomAssetItemPreview extends StatelessWidget {
  const RoomAssetItemPreview({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.manifest,
    required this.collection,
    required this.scale,
    required this.missingSize,
    required this.placeholderMaxLines,
    required this.placeholderFontSize,
    this.placeholderPadding = EdgeInsets.zero,
  });

  final String itemId;
  final String itemName;
  final RoomAssetManifest manifest;
  final RoomAssetCollection collection;
  final double scale;
  final Size? missingSize;
  final int placeholderMaxLines;
  final double placeholderFontSize;
  final EdgeInsets placeholderPadding;

  RoomAsset? get _asset => switch (collection) {
    RoomAssetCollection.accessory => manifest.accessoryById[itemId],
    RoomAssetCollection.furniture => manifest.furnitureById[itemId],
  };

  Size? get displaySize => _displaySize(_asset);

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    final size = _displaySize(asset);
    if (asset == null) return _constrain(_placeholder(null), size);
    return SizedBox(
      width: size!.width,
      height: size.height,
      child: Image.asset(
        asset.assetPath,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) => _placeholder(asset.placeholderHex),
      ),
    );
  }

  Size? _displaySize(RoomAsset? asset) {
    if (asset == null) return missingSize;
    return Size(asset.pixelWidth * scale, asset.pixelHeight * scale);
  }

  Widget _constrain(Widget child, Size? size) {
    if (size == null) return child;
    return SizedBox(width: size.width, height: size.height, child: child);
  }

  Widget _placeholder(String? hex) {
    final text = Text(
      itemName,
      maxLines: placeholderMaxLines,
      overflow: TextOverflow.fade,
      textAlign: TextAlign.center,
      style: PetTextStyles.small.copyWith(
        color: PetColors.bodyStrong,
        fontSize: placeholderFontSize,
        height: 1,
      ),
    );
    return ColoredBox(
      color: hex == null ? PetColors.inactive : _colorFromHex(hex),
      child: Center(
        child: placeholderPadding == EdgeInsets.zero
            ? text
            : Padding(padding: placeholderPadding, child: text),
      ),
    );
  }
}

Color _colorFromHex(String hex) {
  final rgb = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0xF0DCC2;
  return Color(0xFF000000 | rgb);
}
