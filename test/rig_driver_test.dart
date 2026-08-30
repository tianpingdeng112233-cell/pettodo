import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/pet_action.dart';
import 'package:pettodo/sprite/rig_driver.dart';

void main() {
  const driver = RigDriver(blinkSeed: 42);

  test('same action and time always produce the same quantized frame', () {
    final first = driver.sample(
      action: RigPetAction.headFollow,
      elapsed: const Duration(milliseconds: 875),
      target: const RigTarget(0.73, -0.41),
    );
    final second = driver.sample(
      action: RigPetAction.headFollow,
      elapsed: const Duration(milliseconds: 875),
      target: const RigTarget(0.73, -0.41),
    );

    expect(second.snapshot, first.snapshot);
    expect(first.translationX, isA<int>());
    expect(first.headTranslationX, isA<int>());
    expect(
      first.headRotationDegrees % RigDriverParameters.rotationStepDegrees,
      0,
    );
  });

  test('happy jump pose matches its deterministic snapshot', () {
    expect(
      driver
          .sample(
            action: RigPetAction.happyJump,
            elapsed: const Duration(milliseconds: 450),
          )
          .snapshot,
      <String, Object>{
        'translation': <int>[0, -72],
        'scale': <double>[1, 1],
        'bodyRotation': 0.0,
        'headTranslation': <int>[0, 0],
        'headRotation': 0.0,
        'tailRotation': 7.0,
        'frontLegRotation': 0.0,
        'hindLegRotation': 0.0,
        'sleepOpacity': 0.0,
        'garmentOpacity': 0.5,
        'usesSidePose': false,
        'blinkClosed': false,
      },
    );
  });

  test('running pose swings separate legs without horizontal displacement', () {
    expect(
      driver
          .sample(
            action: RigPetAction.running,
            elapsed: const Duration(milliseconds: 130),
            hasSide: true,
          )
          .snapshot,
      <String, Object>{
        'translation': <int>[0, -3],
        'scale': <double>[1, 1],
        'bodyRotation': 4.0,
        'headTranslation': <int>[0, 0],
        'headRotation': 0.0,
        'tailRotation': -7.0,
        'frontLegRotation': 18.0,
        'hindLegRotation': -18.0,
        'sleepOpacity': 0.0,
        'garmentOpacity': 0.0,
        'usesSidePose': true,
        'blinkClosed': false,
      },
    );
  });

  test('sideless running uses the deterministic front-pose fallback', () {
    expect(
      driver
          .sample(
            action: RigPetAction.running,
            elapsed: const Duration(milliseconds: 90),
            hasSide: false,
          )
          .snapshot,
      <String, Object>{
        'translation': <int>[8, -10],
        'scale': <double>[1, 1],
        'bodyRotation': 0.0,
        'headTranslation': <int>[0, 0],
        'headRotation': 0.0,
        'tailRotation': 0.0,
        'frontLegRotation': 0.0,
        'hindLegRotation': 0.0,
        'sleepOpacity': 0.0,
        'garmentOpacity': 0.9,
        'usesSidePose': false,
        'blinkClosed': false,
      },
    );
  });

  test('driver owns fitted garment visibility for every pose family', () {
    expect(
      driver
          .sample(
            action: RigPetAction.sleepTransition,
            elapsed: const Duration(milliseconds: 450),
          )
          .garmentOpacity,
      0.5,
    );
    expect(
      driver
          .sample(
            action: RigPetAction.happyJump,
            elapsed: const Duration(milliseconds: 450),
          )
          .garmentOpacity,
      0.5,
    );
    expect(
      driver
          .sample(
            action: RigPetAction.running,
            elapsed: Duration.zero,
            hasSide: true,
          )
          .garmentOpacity,
      0,
    );
    expect(
      driver
          .sample(
            action: RigPetAction.running,
            elapsed: const Duration(milliseconds: 450),
            hasSide: false,
          )
          .garmentOpacity,
      0.5,
    );
  });

  test('deterministic blink gaps stay inside the random timing contract', () {
    var wasClosed = false;
    var lastBlinkEnd = 0;
    final gaps = <int>[];
    for (var milliseconds = 0; milliseconds < 40000; milliseconds++) {
      final closed = driver
          .sample(
            action: RigPetAction.breathing,
            elapsed: Duration(milliseconds: milliseconds),
          )
          .blinkClosed;
      if (closed && !wasClosed) {
        gaps.add(milliseconds - lastBlinkEnd);
      } else if (!closed && wasClosed) {
        lastBlinkEnd = milliseconds;
      }
      wasClosed = closed;
    }

    expect(gaps.length, greaterThan(5));
    expect(
      gaps,
      everyElement(
        inInclusiveRange(
          RigDriverParameters.blinkMinimumMilliseconds,
          RigDriverParameters.blinkMaximumMilliseconds,
        ),
      ),
    );
    expect(gaps.toSet().length, greaterThan(1));
  });
}
