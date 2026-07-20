import 'package:flutter/material.dart';

import '../../domain/growth.dart';
import 'pet_colors.dart';

class PetStageTreatment {
  const PetStageTreatment({
    required this.spriteScale,
    required this.frameColor,
    required this.frameWidth,
  });

  final double spriteScale;
  final Color frameColor;
  final double frameWidth;
}

abstract final class PetStageTheme {
  static PetStageTreatment treatment(PetGrowthStage stage) => switch (stage) {
    PetGrowthStage.puppy => const PetStageTreatment(
      spriteScale: 0.88,
      frameColor: PetColors.badgeFill,
      frameWidth: 2,
    ),
    PetGrowthStage.junior => const PetStageTreatment(
      spriteScale: 0.98,
      frameColor: PetColors.stroke,
      frameWidth: 2.5,
    ),
    PetGrowthStage.adult => const PetStageTreatment(
      spriteScale: 1.06,
      frameColor: PetColors.primary,
      frameWidth: 3,
    ),
  };
}
