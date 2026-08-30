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

  // V1 freeze (David 2026-08-30): focus screens render static frames only —
  // no drift, transition, or celebration motion.
  ({
    RigPetAction rigAction,
    Duration rigElapsed,
    String atlasState,
    int atlasFrame,
  })
  get _rendering => switch (pose) {
    FocusPetPose.awake => (
      rigAction: RigPetAction.breathing,
      rigElapsed: Duration.zero,
      atlasState: 'idle',
      atlasFrame: 0,
    ),
    FocusPetPose.napping => (
      // Past sleepTransitionSeconds, the driver holds the settled sleep pose.
      rigAction: RigPetAction.sleepTransition,
      rigElapsed: const Duration(seconds: 2),
      atlasState: 'waiting',
      atlasFrame: 0,
    ),
    FocusPetPose.celebrating => (
      rigAction: RigPetAction.breathing,
      rigElapsed: Duration.zero,
      atlasState: 'waving',
      atlasFrame: 0,
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
                    fixedElapsed: rendering.rigElapsed,
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
