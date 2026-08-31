import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../domain/furniture.dart';
import '../sprite/sprite_atlas.dart';
import '../sprite/pet_sprite.dart';
import '../sprite/rig_pet.dart';
import '../sprite/rig_pet_sprite.dart';
import 'theme/pet_colors.dart';
import 'theme/pixel_background.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';
import 'theme/stair_border.dart';
import 'widgets/pixel_components.dart';
import 'widgets/pixel_icon.dart';
import 'widgets/furniture_item_view.dart';
import 'onboarding_screen.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.controller});

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
                      Semantics(
                        button: true,
                        label: 'Back',
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const PxIcon(
                            PxIconData.back,
                            color: PetColors.bodyStrong,
                          ),
                        ),
                      ),
                      const SizedBox(width: PetSpacing.s8),
                      Expanded(
                        child: Text(
                          "${controller.state.petName}'s collection",
                          style: PetTextStyles.display24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PetSpacing.s8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: PetSpacing.s8),
                    child: Text(
                      'Little treasures from your time together',
                      style: PetTextStyles.status,
                    ),
                  ),
                  const SizedBox(height: PetSpacing.s20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: PetSpacing.s8),
                    child: Text('Your pets', style: PetTextStyles.caption),
                  ),
                  const SizedBox(height: PetSpacing.s8),
                  SizedBox(
                    height: PetSpacing.s134,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      // With every preset adopted there is nothing to offer —
                      // hide the adopt slot instead of opening an empty roster.
                      itemCount:
                          controller.adoptedPets.length +
                          (controller.unadoptedPresetPets.isEmpty ? 0 : 1),
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: PetSpacing.s10),
                      itemBuilder: (context, index) {
                        final adoptedPets = controller.adoptedPets;
                        if (index == adoptedPets.length) {
                          return Semantics(
                            container: true,
                            button: true,
                            label: 'Adopt a preset pet',
                            child: InkWell(
                              customBorder: const StairBorder.large(),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PresetAdoptionScreen(
                                    controller: controller,
                                  ),
                                ),
                              ),
                              child: const SizedBox(
                                width: PetSpacing.s134,
                                child: PxCard(
                                  padding: EdgeInsets.all(PetSpacing.s8),
                                  shadows: PetShadows.panel,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      PxIcon(
                                        PxIconData.paw,
                                        size: PetSpacing.s54,
                                        color: PetColors.inactive,
                                      ),
                                      SizedBox(height: PetSpacing.s12),
                                      Text(
                                        'Adopt',
                                        style: PetTextStyles.body15Strong,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        final pet = adoptedPets[index];
                        final selected =
                            pet.id == controller.state.selectedPetId;
                        return Semantics(
                          container: true,
                          button: true,
                          checked: selected,
                          label:
                              '${pet.displayName}${selected ? ', selected' : ''}',
                          child: InkWell(
                            customBorder: const StairBorder.large(),
                            onTap: () => controller.selectPet(pet.id),
                            child: SizedBox(
                              width: PetSpacing.s134,
                              child: PxCard(
                                padding: const EdgeInsets.all(PetSpacing.s8),
                                selected: selected,
                                shadows: selected
                                    ? PetShadows.petChoice
                                    : PetShadows.panel,
                                child: Column(
                                  children: <Widget>[
                                    Expanded(
                                      child: ExcludeSemantics(
                                        child: FutureBuilder<Object>(
                                          future: pet.isRig
                                              ? controller.petRig(pet)
                                              : controller.petAtlas(pet),
                                          builder: (context, snapshot) {
                                            final visual = snapshot.data;
                                            if (visual is LoadedRigPet) {
                                              return RigPetSprite(
                                                pet: visual,
                                                fixedElapsed: Duration.zero,
                                              );
                                            }
                                            if (visual is LoadedSpriteAtlas) {
                                              // Still frame: a shelf of looping
                                              // pets is visual noise.
                                              return PetSprite(
                                                atlas: visual,
                                                fixedFrame: 0,
                                              );
                                            }
                                            return const PxIcon(
                                              PxIconData.paw,
                                              color: PetColors.inactive,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Text(
                                      pet.displayName,
                                      style: PetTextStyles.body15Strong,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: PetSpacing.s20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: PetSpacing.s8),
                    child: Text('Furniture', style: PetTextStyles.caption),
                  ),
                  const SizedBox(height: PetSpacing.s8),
                  Expanded(
                    child: GridView.builder(
                      itemCount: furnitureCatalog.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: PetSpacing.s14,
                            mainAxisSpacing: PetSpacing.s14,
                            childAspectRatio: 1.05,
                          ),
                      itemBuilder: (context, index) {
                        final furniture = furnitureCatalog[index];
                        final unlocked = controller.state.ownedFurnitureIds
                            .contains(furniture.id);
                        return Semantics(
                          container: true,
                          label: unlocked
                              ? furniture.name
                              : 'Furniture not owned',
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: unlocked
                                  ? PetColors.white
                                  : PetColors.futureCard,
                              shape: const StairBorder.large(),
                              shadows: PetShadows.panel,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                ExcludeSemantics(
                                  child: unlocked
                                      ? FurnitureItemView(
                                          item: furniture,
                                          manifest: controller.roomAssets,
                                          scale: 2,
                                        )
                                      : const PxIcon(
                                          PxIconData.paw,
                                          size: PetSpacing.s54,
                                          color: PetColors.inactive,
                                        ),
                                ),
                                const SizedBox(height: PetSpacing.s12),
                                Text(
                                  unlocked ? furniture.name : 'Not owned',
                                  style: unlocked
                                      ? PetTextStyles.body15Strong
                                      : PetTextStyles.body15Soft,
                                ),
                              ],
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
