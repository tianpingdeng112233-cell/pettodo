import 'app_state.dart';

enum OnboardingStep {
  choosePet,
  namePet,
  littleThings,
  celebrate,
  stayOnScreen,
}

const int onboardingProgressStepCount = 4;
const int onboardingThingLimit = 3;
const String firstWinTaskId = 'onboarding-first-win';
const String firstWinTaskNote = 'A free one, to see how it feels';

class OnboardingThing {
  const OnboardingThing(this.emoji, this.label);

  final String emoji;
  final String label;

  String get taskTitle => '$emoji $label';
}

const List<OnboardingThing> onboardingThings = <OnboardingThing>[
  OnboardingThing('🛏️', 'Get out of bed'),
  OnboardingThing('💧', 'Drink some water'),
  OnboardingThing('🪥', 'Brush my teeth'),
  OnboardingThing('💊', 'Take my meds'),
  OnboardingThing('🌬️', 'Three deep breaths'),
  OnboardingThing('🚶', 'Step outside for a minute'),
];

List<OnboardingStep> onboardingSteps({
  required bool isAndroid,
  required bool overlaySupported,
}) => List<OnboardingStep>.unmodifiable(<OnboardingStep>[
  OnboardingStep.choosePet,
  OnboardingStep.namePet,
  OnboardingStep.littleThings,
  OnboardingStep.celebrate,
  if (isAndroid && overlaySupported) OnboardingStep.stayOnScreen,
]);

int onboardingProgressIndex(OnboardingStep step) => switch (step) {
  OnboardingStep.choosePet => 0,
  OnboardingStep.namePet => 1,
  OnboardingStep.littleThings => 2,
  OnboardingStep.celebrate => 3,
  OnboardingStep.stayOnScreen => 3,
};

Set<int> toggleOnboardingThing(Set<int> selected, int index) {
  final next = <int>{...selected};
  if (!next.remove(index) && next.length < onboardingThingLimit) {
    next.add(index);
  }
  return next;
}

/// Preset-name pool for the naming dice. Registry pet names join this at the
/// call site; these are the adoption-center roster names (placeholders until
/// the preset pets land) so the dice stays a real escape hatch even when the
/// registry holds a single pet.
const List<String> onboardingNamePool = <String>[
  'Choco',
  'Maple',
  'Sunny',
  'Misty',
  'Rusty',
  'Ember',
  'Biscuit',
  'Mochi',
  'Bean',
];

String suggestedPetName({
  required List<String> pool,
  required String current,
  required int roll,
}) {
  final choices = pool
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty && name != current.trim())
      .toSet()
      .toList(growable: false);
  if (choices.isEmpty) return current.trim();
  return choices[roll.abs() % choices.length];
}

List<TodoTask> buildOnboardingTasks({
  required String petName,
  required List<String> littleThings,
}) {
  final normalized = littleThings
      .map((title) => title.trim())
      .where((title) => title.isNotEmpty)
      .take(maximumTaskCount - 1)
      .toList(growable: false);
  if (normalized.isEmpty) {
    throw ArgumentError('Pick at least one little thing.');
  }
  return <TodoTask>[
    TodoTask(
      id: firstWinTaskId,
      title: 'Give ${petName.trim()} a pat',
      kind: TaskKind.oneOff,
      note: firstWinTaskNote,
    ),
    ...List<TodoTask>.generate(
      normalized.length,
      (index) => TodoTask(
        id: 'daily-${index + 1}',
        title: normalized[index],
        kind: TaskKind.daily,
      ),
      growable: false,
    ),
  ];
}

bool isFirstWinTask(TodoTask task) => task.id == firstWinTaskId;

bool shouldOfferEveningHello({required bool pending, required DateTime now}) =>
    pending && now.hour >= 19 && now.hour < 22;
