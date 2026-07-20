enum PetGrowthStage {
  puppy,
  junior,
  adult;

  String get label => switch (this) {
    puppy => 'Puppy',
    junior => 'Junior',
    adult => 'Adult',
  };
}

abstract final class GrowthThresholds {
  static const int puppy = 0;
  static const int junior = 40;
  static const int adult = 120;
}

PetGrowthStage growthStageFor(int lifetimeCompletions) {
  if (lifetimeCompletions >= GrowthThresholds.adult) {
    return PetGrowthStage.adult;
  }
  if (lifetimeCompletions >= GrowthThresholds.junior) {
    return PetGrowthStage.junior;
  }
  return PetGrowthStage.puppy;
}

List<PetGrowthStage> stagesCrossed(int before, int after) => PetGrowthStage
    .values
    .where(
      (stage) => before < _thresholdFor(stage) && after >= _thresholdFor(stage),
    )
    .toList(growable: false);

int _thresholdFor(PetGrowthStage stage) => switch (stage) {
  PetGrowthStage.puppy => GrowthThresholds.puppy,
  PetGrowthStage.junior => GrowthThresholds.junior,
  PetGrowthStage.adult => GrowthThresholds.adult,
};
