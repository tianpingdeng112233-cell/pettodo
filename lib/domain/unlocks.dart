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
];

List<DecorUnlock> unlocksCrossed(int before, int after) => decorUnlocks
    .where((unlock) => before < unlock.threshold && after >= unlock.threshold)
    .toList(growable: false);

DecorUnlock? nextUnlock(int lifetimeCompletions) {
  for (final unlock in decorUnlocks) {
    if (lifetimeCompletions < unlock.threshold) return unlock;
  }
  return null;
}
