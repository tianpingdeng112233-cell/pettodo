import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../domain/accessory.dart';
import '../domain/furniture.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';
import 'theme/pixel_background.dart';
import 'theme/stair_border.dart';
import 'widgets/accessory_item_view.dart';
import 'widgets/furniture_item_view.dart';
import 'widgets/pixel_components.dart';
import 'widgets/pixel_icon.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key, required this.controller});

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
                        child: Text('Shop', style: PetTextStyles.display24),
                      ),
                      Text(
                        '${controller.state.treats} treats',
                        style: PetTextStyles.body15Strong,
                      ),
                    ],
                  ),
                  const SizedBox(height: PetSpacing.s18),
                  Expanded(
                    child: CustomScrollView(
                      slivers: <Widget>[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: PetSpacing.s10),
                            child: Text(
                              'Furniture',
                              style: PetTextStyles.body15Strong,
                            ),
                          ),
                        ),
                        SliverGrid.builder(
                          itemCount: storeFurniture.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: PetSpacing.s14,
                                mainAxisSpacing: PetSpacing.s14,
                                childAspectRatio: 0.78,
                              ),
                          itemBuilder: (context, index) => _FurnitureStoreCard(
                            controller: controller,
                            item: storeFurniture[index],
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              0,
                              PetSpacing.s24,
                              0,
                              PetSpacing.s10,
                            ),
                            child: Text(
                              'Accessories',
                              style: PetTextStyles.body15Strong,
                            ),
                          ),
                        ),
                        SliverGrid.builder(
                          itemCount: accessoryCatalog.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: PetSpacing.s14,
                                mainAxisSpacing: PetSpacing.s14,
                                childAspectRatio: 0.78,
                              ),
                          itemBuilder: (context, index) => _AccessoryStoreCard(
                            controller: controller,
                            item: accessoryCatalog[index],
                          ),
                        ),
                      ],
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

class _FurnitureStoreCard extends StatelessWidget {
  const _FurnitureStoreCard({required this.controller, required this.item});

  final AppController controller;
  final FurnitureItem item;

  @override
  Widget build(BuildContext context) {
    final owned = controller.state.ownedFurnitureIds.contains(item.id);
    final enabled = !owned && controller.state.treats >= item.price!;
    return _StoreCard(
      name: item.name,
      price: item.price!,
      owned: owned,
      enabled: enabled,
      preview: FurnitureItemView(item: item, manifest: controller.roomAssets),
      onBuy: () => controller.buyFurniture(item.id),
    );
  }
}

class _AccessoryStoreCard extends StatelessWidget {
  const _AccessoryStoreCard({required this.controller, required this.item});

  final AppController controller;
  final AccessoryItem item;

  @override
  Widget build(BuildContext context) {
    final owned = controller.state.ownedAccessoryIds.contains(item.id);
    final enabled = !owned && controller.state.treats >= item.price;
    return _StoreCard(
      name: item.name,
      price: item.price,
      owned: owned,
      enabled: enabled,
      preview: AccessoryItemView(
        item: item,
        manifest: controller.roomAssets,
        scale: 1.6,
      ),
      onBuy: () => controller.buyAccessory(item.id),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.name,
    required this.price,
    required this.owned,
    required this.enabled,
    required this.preview,
    required this.onBuy,
  });

  final String name;
  final int price;
  final bool owned;
  final bool enabled;
  final Widget preview;
  final Future<bool> Function() onBuy;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$name, $price treats',
    enabled: enabled,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: enabled ? PetColors.white : PetColors.disabledFill,
        shape: const StairBorder.large(),
        shadows: PetShadows.panel,
      ),
      child: Padding(
        padding: const EdgeInsets.all(PetSpacing.s12),
        child: Column(
          children: <Widget>[
            Expanded(child: Center(child: preview)),
            const SizedBox(height: PetSpacing.s8),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: PetTextStyles.body15Strong,
            ),
            const SizedBox(height: PetSpacing.s8),
            PxButton(
              height: PetSpacing.s44,
              onPressed: enabled
                  ? () async {
                      await onBuy();
                    }
                  : null,
              label: Text(owned ? 'Owned' : '$price treats'),
            ),
          ],
        ),
      ),
    ),
  );
}
