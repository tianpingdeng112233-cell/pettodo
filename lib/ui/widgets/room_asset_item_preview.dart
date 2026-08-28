import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/room_asset_manifest.dart';
import '../theme/pet_colors.dart';
import '../theme/pet_text_styles.dart';

enum RoomAssetCollection { accessory, furniture }

enum RoomAssetScaleMode { maxIntegerFit, fixed }

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
    this.scaleMode = RoomAssetScaleMode.maxIntegerFit,
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
  final RoomAssetScaleMode scaleMode;

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
    if (scaleMode == RoomAssetScaleMode.maxIntegerFit) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final integerScale = _largestIntegerScale(asset, constraints);
          return Center(child: _assetImage(asset, integerScale.toDouble()));
        },
      );
    }
    return _assetImage(asset, scale);
  }

  Widget _assetImage(RoomAsset asset, double imageScale) {
    final size = Size(
      asset.pixelWidth * imageScale,
      asset.pixelHeight * imageScale,
    );
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Image.asset(
        asset.assetPath,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) => _placeholder(asset.placeholderHex),
      ),
    );
  }

  int _largestIntegerScale(RoomAsset asset, BoxConstraints constraints) {
    final maxWidthScale = constraints.maxWidth.isFinite
        ? constraints.maxWidth / asset.pixelWidth
        : double.infinity;
    final maxHeightScale = constraints.maxHeight.isFinite
        ? constraints.maxHeight / asset.pixelHeight
        : double.infinity;
    final availableScale = math.min(maxWidthScale, maxHeightScale);
    if (!availableScale.isFinite) return math.max(1, scale.floor());
    return math.max(1, availableScale.floor());
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
