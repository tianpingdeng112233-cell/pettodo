import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../sprite/sprite_atlas.dart';
import 'theme/app_theme.dart';
import 'theme/pet_colors.dart';
import 'theme/pet_effects.dart';
import 'theme/pet_radii.dart';
import 'theme/pet_shadows.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: PetColors.transparent,
      systemNavigationBarColor: PetColors.screenBottom,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.screenGradient),
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
                        icon: const Icon(
                          Icons.arrow_back_rounded,
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
                          decoration: BoxDecoration(
                            color: unlocked
                                ? PetColors.white
                                : PetColors.futureCard,
                            borderRadius: PetRadii.cardBorder,
                            boxShadow: PetShadows.panel,
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
        : Icon(Icons.pets_rounded, size: size, color: PetColors.inactive),
  );
}
