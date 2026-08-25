import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';
import 'package:pettodo/domain/onboarding_flow.dart';

void main() {
  test('step order, four progress points, and S5 gating match the flow', () {
    expect(
      onboardingSteps(isAndroid: false, overlaySupported: true),
      <OnboardingStep>[
        OnboardingStep.choosePet,
        OnboardingStep.namePet,
        OnboardingStep.littleThings,
        OnboardingStep.celebrate,
      ],
    );
    expect(
      onboardingSteps(isAndroid: true, overlaySupported: false),
      isNot(contains(OnboardingStep.stayOnScreen)),
    );
    expect(
      onboardingSteps(isAndroid: true, overlaySupported: true).last,
      OnboardingStep.stayOnScreen,
    );
    expect(onboardingProgressStepCount, 4);
    expect(OnboardingStep.values.map(onboardingProgressIndex), <int>[
      0,
      1,
      2,
      3,
      3,
    ]);
  });

  test('pet naming starts from the preset and the die offers another name', () {
    expect(
      suggestedPetName(
        pool: const <String>['Choco', 'Pip'],
        current: 'Choco',
        roll: 42,
      ),
      'Pip',
    );
    expect(
      suggestedPetName(
        pool: const <String>['Choco'],
        current: 'Choco',
        roll: 42,
      ),
      'Choco',
    );
  });

  test('little-thing selection never exceeds three and can be undone', () {
    var selected = <int>{};
    selected = toggleOnboardingThing(selected, 0);
    selected = toggleOnboardingThing(selected, 1);
    selected = toggleOnboardingThing(selected, 2);
    selected = toggleOnboardingThing(selected, 3);
    expect(selected, <int>{0, 1, 2});
    selected = toggleOnboardingThing(selected, 1);
    expect(selected, <int>{0, 2});
    expect(onboardingThingLimit, 3);
  });

  test(
    'first win is one-off, positive-history ready, and total is protected',
    () {
      final tasks = buildOnboardingTasks(
        petName: 'Pip',
        littleThings: List<String>.generate(7, (index) => 'Thing $index'),
      );
      expect(tasks, hasLength(maximumTaskCount));
      expect(tasks.first.id, firstWinTaskId);
      expect(tasks.first.title, 'Give Pip a pat');
      expect(tasks.first.note, firstWinTaskNote);
      expect(tasks.first.kind, TaskKind.oneOff);
      expect(
        tasks.skip(1),
        everyElement(
          predicate<TodoTask>((task) {
            return task.kind == TaskKind.daily;
          }),
        ),
      );
    },
  );

  test('evening hello only appears inside 19:00-22:00 while pending', () {
    expect(
      shouldOfferEveningHello(
        pending: true,
        now: DateTime(2026, 8, 25, 18, 59),
      ),
      isFalse,
    );
    expect(
      shouldOfferEveningHello(pending: true, now: DateTime(2026, 8, 25, 19)),
      isTrue,
    );
    expect(
      shouldOfferEveningHello(
        pending: true,
        now: DateTime(2026, 8, 25, 21, 59),
      ),
      isTrue,
    );
    expect(
      shouldOfferEveningHello(pending: true, now: DateTime(2026, 8, 25, 22)),
      isFalse,
    );
    expect(
      shouldOfferEveningHello(pending: false, now: DateTime(2026, 8, 25, 20)),
      isFalse,
    );
  });
}
