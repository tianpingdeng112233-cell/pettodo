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
  DecorUnlock(id: 'soft_ball', threshold: 5, emoji: '🧶', name: '软软毛线球'),
  DecorUnlock(id: 'flower', threshold: 15, emoji: '🌼', name: '小雏菊'),
  DecorUnlock(id: 'home', threshold: 30, emoji: '🏡', name: '暖暖小屋'),
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
