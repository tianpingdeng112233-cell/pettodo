import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../domain/furniture.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';
import 'theme/pixel_background.dart';
import 'theme/stair_border.dart';
import 'widgets/furniture_item_view.dart';
import 'widgets/pixel_components.dart';
import 'widgets/pixel_icon.dart';
import 'widgets/treat_count.dart';

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
                        child: Text(
                          'Furniture shop',
                          style: PetTextStyles.display24,
                        ),
                      ),
                      TreatCount(
                        '${controller.state.treats}',
                        style: PetTextStyles.body15Strong,
                      ),
                    ],
                  ),
                  const SizedBox(height: PetSpacing.s18),
                  Expanded(
                    child: GridView.builder(
                      itemCount: storeFurniture.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: PetSpacing.s14,
                            mainAxisSpacing: PetSpacing.s14,
                            childAspectRatio: 0.78,
                          ),
                      itemBuilder: (context, index) {
                        final item = storeFurniture[index];
                        final owned = controller.state.ownedFurnitureIds
                            .contains(item.id);
                        final affordable =
                            controller.state.treats >= item.price!;
                        final enabled = !owned && affordable;
                        return Semantics(
                          container: true,
                          label: '${item.name}, ${item.price} treats',
                          enabled: enabled,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: enabled
                                  ? PetColors.white
                                  : PetColors.disabledFill,
                              shape: const StairBorder.large(),
                              shadows: PetShadows.panel,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(PetSpacing.s12),
                              child: Column(
                                children: <Widget>[
                                  Expanded(
                                    child: Center(
                                      child: FurnitureItemView(
                                        item: item,
                                        manifest: controller.roomAssets,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: PetSpacing.s8),
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    style: PetTextStyles.body15Strong,
                                  ),
                                  const SizedBox(height: PetSpacing.s8),
                                  PxButton(
                                    height: PetSpacing.s44,
                                    onPressed: enabled
                                        ? () async {
                                            await controller.buyFurniture(
                                              item.id,
                                            );
                                          }
                                        : null,
                                    label: owned
                                        ? const Text('Owned')
                                        : TreatCount('${item.price}'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
