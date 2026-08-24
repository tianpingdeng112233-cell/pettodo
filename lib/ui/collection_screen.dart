import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../sprite/sprite_atlas.dart';
import '../sprite/pet_sprite.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_effects.dart';
import 'theme/pixel_background.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';
import 'theme/stair_border.dart';
import 'widgets/pixel_components.dart';
import 'widgets/pixel_icon.dart';

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
                      itemCount: controller.pets.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: PetSpacing.s10),
                      itemBuilder: (context, index) {
                        final pet = controller.pets[index];
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
                                        child: FutureBuilder<LoadedSpriteAtlas>(
                                          future: controller.petAtlas(pet),
                                          builder: (context, snapshot) =>
                                              snapshot.hasData
                                              // Still frame: a shelf of looping
                                              // pets is visual noise.
                                              ? PetSprite(
                                                  atlas: snapshot.data!,
                                                  fixedFrame: 0,
                                                )
                                              : const PxIcon(
                                                  PxIconData.paw,
                                                  color: PetColors.inactive,
                                                ),
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
                    child: Text('Keepsakes', style: PetTextStyles.caption),
                  ),
                  const SizedBox(height: PetSpacing.s8),
                  Expanded(
                    child: GridView.builder(
                      itemCount: controller.decorations.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: PetSpacing.s14,
                            mainAxisSpacing: PetSpacing.s14,
                            childAspectRatio: 1.05,
                          ),
                      itemBuilder: (context, index) {
                        final decor = controller.decorations[index];
                        final unlocked = controller.state.unlockedDecorIds
                            .contains(decor.id);
                        return Semantics(
                          container: true,
                          label: unlocked
                              ? decor.displayName
                              : 'A keepsake still tucked away',
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
                                  child: DecorItemView(
                                    decor: decor,
                                    unlocked: unlocked,
                                    size: PetSpacing.s54,
                                  ),
                                ),
                                const SizedBox(height: PetSpacing.s12),
                                Text(
                                  unlocked
                                      ? decor.displayName
                                      : 'A little mystery',
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

class DecorItemView extends StatelessWidget {
  const DecorItemView({
    super.key,
    required this.decor,
    required this.unlocked,
    this.size = PetSpacing.s36,
  });

  final DecorAssetDescriptor decor;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: unlocked
        ? PetEffects.fullOpacity
        : PetEffects.upcomingDecorOpacity,
    child: unlocked
        ? Text(decor.emoji, style: TextStyle(fontSize: size))
        : PxIcon(PxIconData.paw, size: size, color: PetColors.inactive),
  );
}
