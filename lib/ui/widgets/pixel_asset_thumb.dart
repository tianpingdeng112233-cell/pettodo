import 'package:flutter/material.dart';

import '../../data/pixel_asset_manifest.dart';
import '../theme/pet_colors.dart';
import '../theme/pet_text_styles.dart';

/// Shared pixel-art thumbnail: crisp integer-scaled image with the
/// named-placeholder fallback both furniture and food views use.
class PixelAssetThumb extends StatelessWidget {
  const PixelAssetThumb({
    super.key,
    required this.asset,
    required this.name,
    this.scale = 1,
  });

  final PixelAsset? asset;
  final String name;
  final int scale;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
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
    final rgb = hex == null
        ? 0xF0DCC2
        : int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0xF0DCC2;
    return ColoredBox(
      color: Color(0xFF000000 | rgb),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            name,
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
}
