import 'growth.dart';

int legacyBondXpForCompletions(int lifetimeCompletions) =>
    switch (growthStageFor(lifetimeCompletions)) {
      PetGrowthStage.puppy => 25,
      PetGrowthStage.junior => 100,
      PetGrowthStage.adult => 225,
    };
