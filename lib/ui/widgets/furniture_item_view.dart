import 'package:flutter/material.dart';

import '../../data/room_asset_manifest.dart';
import '../../domain/furniture.dart';
import '../theme/pet_colors.dart';
import '../theme/pet_text_styles.dart';

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
  Widget build(BuildContext context) {
    final asset = manifest.furnitureById[item.id];
    if (asset == null) return _placeholder(null);
    return SizedBox(
      width: asset.pixelWidth * scale.toDouble(),
      height: asset.pixelHeight * scale.toDouble(),
      child: Image.asset(
        asset.assetPath,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) => _placeholder(asset.placeholderHex),
      ),
    );
  }

  Widget _placeholder(String? hex) {
    final color = hex == null ? PetColors.inactive : _colorFromHex(hex);
    return ColoredBox(
      color: color,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            item.name,
            maxLines: 3,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
            style: PetTextStyles.small.copyWith(
              color: PetColors.bodyStrong,
              fontSize: 8,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFromHex(String hex) {
    final rgb = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0xF0DCC2;
    return Color(0xFF000000 | rgb);
  }
}
