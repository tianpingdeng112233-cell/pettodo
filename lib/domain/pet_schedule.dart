enum PetScheduleEffect { none, zzz }

class PetScheduleEntry {
  const PetScheduleEntry({
    required this.id,
    required this.startHour,
    required this.endHour,
    required this.animation,
    required this.statusTemplate,
    this.fixedFrame,
    this.effect = PetScheduleEffect.none,
  });

  final String id;
  final int startHour;
  final int endHour;
  final String animation;
  final int? fixedFrame;
  final String statusTemplate;
  final PetScheduleEffect effect;

  bool includesHour(int hour) => startHour < endHour
      ? hour >= startHour && hour < endHour
      : hour >= startHour || hour < endHour;

  String statusFor(String petName) =>
      statusTemplate.replaceAll('{petName}', petName);
}

/// Shared domain schedule. The iOS widget can consume this table directly.
const List<PetScheduleEntry> petDailySchedule = <PetScheduleEntry>[
  PetScheduleEntry(
    id: 'morning_stretch',
    startHour: 5,
    endHour: 11,
    animation: 'waving',
    statusTemplate: '{petName} is stretching into a gentle morning',
  ),
  PetScheduleEntry(
    id: 'midday_nap',
    startHour: 11,
    endHour: 14,
    animation: 'waiting',
    statusTemplate: '{petName} is having a cozy little nap',
    effect: PetScheduleEffect.zzz,
  ),
  PetScheduleEntry(
    id: 'afternoon_idle',
    startHour: 14,
    endHour: 18,
    animation: 'idle',
    statusTemplate: '{petName} is enjoying a quiet afternoon',
  ),
  PetScheduleEntry(
    id: 'evening_window',
    startHour: 18,
    endHour: 5,
    animation: 'look-row-10',
    fixedFrame: 7,
    statusTemplate: '{petName} is watching the evening by the window',
  ),
];

PetScheduleEntry petScheduleAt(DateTime localTime) =>
    petDailySchedule.firstWhere((entry) => entry.includesHour(localTime.hour));
