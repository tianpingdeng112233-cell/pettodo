import 'package:flutter/material.dart';

import '../../data/food_asset_manifest.dart';
import '../../domain/food.dart';
import 'pixel_asset_thumb.dart';

class FoodItemView extends StatelessWidget {
  const FoodItemView({super.key, required this.item, required this.manifest});

  final FoodItem item;
  final FoodAssetManifest manifest;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: Center(
      child: PixelAssetThumb(
        asset: manifest.foodById[item.id],
        name: item.name,
      ),
    ),
  );
}
