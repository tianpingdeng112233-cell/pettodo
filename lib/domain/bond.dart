import 'dart:math' as math;

abstract final class BondRules {
  static const int companionDayXp = 10;
  static const int cozinessPercentPerPlacedFurniture = 5;
  static const int maximumCozinessBonusPercent = 25;
  static const int levelCurveCoefficient = 25;
}

int cozinessBonusPercent(int placedFurnitureCount) {
  if (placedFurnitureCount < 0) {
    throw ArgumentError.value(placedFurnitureCount, 'placedFurnitureCount');
  }
  return math.min(
    placedFurnitureCount * BondRules.cozinessPercentPerPlacedFurniture,
    BondRules.maximumCozinessBonusPercent,
  );
}

int feedingBondXp({
  required int foodXp,
  required int feedsTodayBefore,
  required int placedFurnitureCount,
}) {
  if (foodXp < 0) throw ArgumentError.value(foodXp, 'foodXp');
  if (feedsTodayBefore < 0) {
    throw ArgumentError.value(feedsTodayBefore, 'feedsTodayBefore');
  }
  final diminishedPercent = switch (feedsTodayBefore) {
    < 3 => 100,
    3 => 50,
    _ => 25,
  };
  final diminishedXp = _roundPercentage(foodXp, diminishedPercent);
  return _withCozinessBonus(diminishedXp, placedFurnitureCount);
}

int companionDayBondXp({required int placedFurnitureCount}) =>
    _withCozinessBonus(BondRules.companionDayXp, placedFurnitureCount);

int bondXpThresholdForLevel(int level) {
  if (level < 1) throw ArgumentError.value(level, 'level');
  final completedLevels = level - 1;
  return BondRules.levelCurveCoefficient * completedLevels * completedLevels;
}

int bondLevelForXp(int xp) {
  if (xp < 0) throw ArgumentError.value(xp, 'xp');
  return math.sqrt(xp / BondRules.levelCurveCoefficient).floor() + 1;
}

List<int> bondLevelsCrossed(int beforeXp, int afterXp) {
  final beforeLevel = bondLevelForXp(beforeXp);
  final afterLevel = bondLevelForXp(afterXp);
  if (afterLevel <= beforeLevel) return const <int>[];
  return List<int>.generate(
    afterLevel - beforeLevel,
    (index) => beforeLevel + index + 1,
    growable: false,
  );
}

String bondTitleForLevel(int level) {
  if (level < 1) throw ArgumentError.value(level, 'level');
  return switch (level) {
    1 => 'New Friends',
    2 => 'Snack Buddies',
    3 => 'Close Pals',
    4 => 'Dear Companions',
    5 => 'Best Friends',
    6 => 'Kindred Spirits',
    7 => 'Inseparable Pals',
    _ => 'Forever Friends',
  };
}

double bondProgressForXp(int xp) {
  final level = bondLevelForXp(xp);
  final currentThreshold = bondXpThresholdForLevel(level);
  final nextThreshold = bondXpThresholdForLevel(level + 1);
  return (xp - currentThreshold) / (nextThreshold - currentThreshold);
}

int _withCozinessBonus(int baseXp, int placedFurnitureCount) {
  final bonusPercent = cozinessBonusPercent(placedFurnitureCount);
  return _roundPercentage(baseXp, 100 + bonusPercent);
}

int _roundPercentage(int value, int percent) => (value * percent + 50) ~/ 100;
