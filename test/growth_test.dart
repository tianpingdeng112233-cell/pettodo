import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/growth.dart';

void main() {
  test('growth thresholds have stable inclusive edges', () {
    expect(growthStageFor(0), PetGrowthStage.puppy);
    expect(growthStageFor(39), PetGrowthStage.puppy);
    expect(growthStageFor(40), PetGrowthStage.junior);
    expect(growthStageFor(119), PetGrowthStage.junior);
    expect(growthStageFor(120), PetGrowthStage.adult);
  });

  test('stage crossings fire once at each configured threshold', () {
    expect(stagesCrossed(39, 40), <PetGrowthStage>[PetGrowthStage.junior]);
    expect(stagesCrossed(40, 41), isEmpty);
    expect(stagesCrossed(119, 120), <PetGrowthStage>[PetGrowthStage.adult]);
  });
}
