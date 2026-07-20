class DecorUnlock {
  const DecorUnlock({
    required this.id,
    required this.threshold,
    required this.emoji,
    required this.name,
  });

  final String id;
  final int threshold;
  final String emoji;
  final String name;
}

const List<DecorUnlock> decorUnlocks = <DecorUnlock>[
  DecorUnlock(id: 'soft_ball', threshold: 5, emoji: '🧶', name: 'Bouncy Ball'),
  DecorUnlock(id: 'flower', threshold: 15, emoji: '🌼', name: 'Cozy Cushion'),
  DecorUnlock(id: 'home', threshold: 30, emoji: '🏡', name: 'Little House'),
  DecorUnlock(id: 'blanket', threshold: 50, emoji: '🧺', name: 'Sunny Blanket'),
  DecorUnlock(id: 'lamp', threshold: 80, emoji: '🏮', name: 'Warm Lantern'),
  DecorUnlock(id: 'window', threshold: 120, emoji: '🪟', name: 'Dreamy Window'),
];

List<DecorUnlock> unlocksCrossed(int before, int after) => decorUnlocks
    .where((unlock) => before < unlock.threshold && after >= unlock.threshold)
    .toList(growable: false);

List<DecorUnlock> unlocksEarnedAt(int lifetimeCompletions) => decorUnlocks
    .where((unlock) => lifetimeCompletions >= unlock.threshold)
    .toList(growable: false);

DecorUnlock? nextUnlock(int lifetimeCompletions) {
  for (final unlock in decorUnlocks) {
    if (lifetimeCompletions < unlock.threshold) return unlock;
  }
  return null;
}
