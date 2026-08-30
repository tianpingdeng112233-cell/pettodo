import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../domain/pet_action.dart';
import '../sprite/pet_sprite.dart';
import '../sprite/rig_pet_sprite.dart';
import 'theme/pet_colors.dart';

enum FocusPetPose { awake, napping, celebrating }

class FocusPet extends StatelessWidget {
  const FocusPet({
    super.key,
    required this.controller,
    required this.pose,
    this.size = 150,
  });

  final AppController controller;
  final FocusPetPose pose;
  final double size;

  ({RigPetAction rigAction, String atlasState, int? atlasFrame})
  get _rendering => switch (pose) {
    FocusPetPose.awake => (
      rigAction: RigPetAction.breathing,
      atlasState: 'idle',
      atlasFrame: null,
    ),
    FocusPetPose.napping => (
      rigAction: RigPetAction.sleepTransition,
      atlasState: 'waiting',
      atlasFrame: 0,
    ),
    FocusPetPose.celebrating => (
      rigAction: RigPetAction.happyJump,
      atlasState: 'waving',
      atlasFrame: null,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final rendering = _rendering;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            bottom: 8,
            child: Container(
              width: size * 0.62,
              height: 12,
              decoration: const BoxDecoration(
                color: PetColors.groundShadow,
                borderRadius: BorderRadius.all(Radius.elliptical(70, 12)),
              ),
            ),
          ),
          Positioned.fill(
            child: controller.selectedPet.isRig
                ? RigPetSprite(
                    pet: controller.rigPet!,
                    action: rendering.rigAction,
                  )
                : PetSprite(
                    atlas: controller.spriteAtlas,
                    stateName: rendering.atlasState,
                    fixedFrame: rendering.atlasFrame,
                  ),
          ),
        ],
      ),
    );
  }
}
