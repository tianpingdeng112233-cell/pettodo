import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../domain/food.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';
import 'theme/pixel_background.dart';
import 'theme/stair_border.dart';
import 'widgets/food_item_view.dart';
import 'widgets/pixel_components.dart';
import 'widgets/pixel_icon.dart';
import 'widgets/treat_count.dart';

class SnacksScreen extends StatelessWidget {
  const SnacksScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: PetColors.transparent,
        systemNavigationBarColor: PetColors.screenBottom,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: PixelBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                PetSpacing.s20,
                PetSpacing.s14,
                PetSpacing.s20,
                PetSpacing.s24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const PxIcon(PxIconData.back),
                      ),
                      const SizedBox(width: PetSpacing.s8),
                      const Expanded(
                        child: Text('Snacks', style: PetTextStyles.display24),
                      ),
                      TreatCount(
                        '${controller.state.treats}',
                        style: PetTextStyles.body15Strong,
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      PetSpacing.s8,
                      PetSpacing.s8,
                      PetSpacing.s8,
                      PetSpacing.s14,
                    ),
                    child: Text(
                      'Every snack adds a little bond XP',
                      style: PetTextStyles.body15Soft,
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: foodCatalog.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: PetSpacing.s10),
                      itemBuilder: (context, index) => _SnackRow(
                        controller: controller,
                        item: foodCatalog[index],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SnackRow extends StatelessWidget {
  const _SnackRow({required this.controller, required this.item});

  final AppController controller;
  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    final owned = controller.state.foodInventory[item.id] ?? 0;
    final canBuy = controller.state.treats >= item.price;
    final VoidCallback? buy = canBuy
        ? () async {
            final bought = await controller.buyFood(item.id);
            if (bought) await HapticFeedback.lightImpact();
          }
        : null;
    return Semantics(
      container: true,
      label: '${item.name}, ${item.price} treats, owned $owned',
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          color: PetColors.white,
          shape: StairBorder.large(
            side: BorderSide(color: PetColors.stroke, width: 2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PetSpacing.s10),
          child: Row(
            children: <Widget>[
              FoodItemView(item: item, manifest: controller.foodAssets),
              const SizedBox(width: PetSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PetTextStyles.body16Strong,
                          ),
                        ),
                        DecoratedBox(
                          decoration: const ShapeDecoration(
                            color: PetColors.badgeFill,
                            shape: StairBorder.small(),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: PetSpacing.s8,
                              vertical: PetSpacing.s4,
                            ),
                            child: TreatCount(
                              '${item.price}',
                              style: PetTextStyles.chip,
                              iconSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PetSpacing.s4),
                    Text('Owned $owned', style: PetTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: PetSpacing.s10),
              // Buy and Feed are always two distinct, full-size buttons; Feed
              // only appears once there is inventory to feed from.
              if (owned > 0) ...<Widget>[
                SizedBox(
                  width: 62,
                  child: PxButton(
                    height: PetSpacing.s44,
                    style: PxButtonStyle.outline,
                    onPressed: buy,
                    label: const Text('Buy'),
                  ),
                ),
                const SizedBox(width: PetSpacing.s8),
                SizedBox(
                  width: 70,
                  child: PxButton(
                    height: PetSpacing.s44,
                    style: PxButtonStyle.primary,
                    onPressed: () async {
                      final fed = await controller.feedFood(item.id);
                      if (!context.mounted || !fed) return;
                      await HapticFeedback.lightImpact();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    label: const Text('Feed'),
                  ),
                ),
              ] else
                SizedBox(
                  width: 76,
                  child: PxButton(
                    height: PetSpacing.s44,
                    style: PxButtonStyle.outline,
                    onPressed: buy,
                    label: const Text('Buy'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
