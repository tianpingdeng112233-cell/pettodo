import 'dart:math' as math;

import '../domain/pet_action.dart';

class RigDriverParameters {
  const RigDriverParameters._();

  static const double rotationStepDegrees = 0.5;
  static const double breathingPeriodSeconds = 2.8;
  static const double breathingScaleY = 0.018;
  static const double breathingScaleX = 0.006;
  static const int blinkMinimumMilliseconds = 2200;
  static const int blinkMaximumMilliseconds = 5700;
  static const int blinkClosedMilliseconds = 120;
  static const int blinkScheduleLength = 16;
  static const double headFollowDegrees = 5;
  static const int headFollowOffset = 12;
  static const int nuzzleOffset = 28;
  static const int eatingHeadDrop = 32;
  static const int jumpHeight = 72;
  static const double jumpPeriodSeconds = 0.9;
  static const double runPeriodSeconds = 0.52;
  static const double runLegDegrees = 18;
  static const double runBodyLeanDegrees = 4;
  static const double sidelessRunPeriodSeconds = 0.36;
  static const int sidelessRunHorizontalPixels = 8;
  static const int sidelessRunBobPixels = 10;
  static const double tailDegrees = 7;
  static const double sleepTransitionSeconds = 0.9;
  static const double garmentFadeSeconds = 0.9;
  static const double stretchDurationSeconds = 1.8;
  static const double nuzzlePulsePeriodSeconds = 1.2;
  static const double nuzzleVerticalBase = 0.45;
  static const double nuzzleVerticalGain = 0.35;
  static const double nuzzleHeadDegrees = 3;
  static const double eatPulsePeriodSeconds = 1.4;
  static const double eatHeadDegrees = 2;
  static const double jumpSquashX = 0.07;
  static const double jumpStretchY = 0.1;
  static const double stretchExpandX = 0.08;
  static const double stretchCompressY = 0.1;
  static const double stretchSinkPixels = 8;
  static const double stretchHeadLiftPixels = 12;
  static const double runBobPixels = 3;
}

class RigTarget {
  const RigTarget(this.x, this.y);

  final double x;
  final double y;
}

class RigPoseFrame {
  const RigPoseFrame({
    required this.translationX,
    required this.translationY,
    required this.scaleX,
    required this.scaleY,
    required this.bodyRotationDegrees,
    required this.headTranslationX,
    required this.headTranslationY,
    required this.headRotationDegrees,
    required this.tailRotationDegrees,
    required this.frontLegRotationDegrees,
    required this.hindLegRotationDegrees,
    required this.sleepOpacity,
    required this.garmentOpacity,
    required this.usesSidePose,
    required this.blinkClosed,
  });

  final int translationX;
  final int translationY;
  final double scaleX;
  final double scaleY;
  final double bodyRotationDegrees;
  final int headTranslationX;
  final int headTranslationY;
  final double headRotationDegrees;
  final double tailRotationDegrees;
  final double frontLegRotationDegrees;
  final double hindLegRotationDegrees;
  final double sleepOpacity;
  final double garmentOpacity;
  final bool usesSidePose;
  final bool blinkClosed;

  Map<String, Object> get snapshot => <String, Object>{
    'translation': <int>[translationX, translationY],
    'scale': <double>[scaleX, scaleY],
    'bodyRotation': bodyRotationDegrees,
    'headTranslation': <int>[headTranslationX, headTranslationY],
    'headRotation': headRotationDegrees,
    'tailRotation': tailRotationDegrees,
    'frontLegRotation': frontLegRotationDegrees,
    'hindLegRotation': hindLegRotationDegrees,
    'sleepOpacity': sleepOpacity,
    'garmentOpacity': garmentOpacity,
    'usesSidePose': usesSidePose,
    'blinkClosed': blinkClosed,
  };
}

class RigDriver {
  const RigDriver({this.blinkSeed = 1});

  final int blinkSeed;

  RigPoseFrame sample({
    required RigPetAction action,
    required Duration elapsed,
    RigTarget target = const RigTarget(0, 0),
    bool hasSide = true,
  }) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    var translationX = 0;
    var translationY = 0;
    var scaleX = 1.0;
    var scaleY = 1.0;
    var bodyRotation = 0.0;
    var headX = 0;
    var headY = 0;
    var headRotation = 0.0;
    var tailRotation = 0.0;
    var frontLegRotation = 0.0;
    var hindLegRotation = 0.0;
    var sleepOpacity = 0.0;
    var garmentOpacity = 1.0;
    final usesSidePose = action == RigPetAction.running && hasSide;

    if (action != RigPetAction.running) {
      final breath =
          (math.sin(
                seconds /
                    RigDriverParameters.breathingPeriodSeconds *
                    math.pi *
                    2,
              ) +
              1) /
          2;
      scaleY += RigDriverParameters.breathingScaleY * breath;
      scaleX -= RigDriverParameters.breathingScaleX * breath;
      tailRotation = _rotation(
        math.sin(seconds * math.pi) * RigDriverParameters.tailDegrees,
      );
    }

    switch (action) {
      case RigPetAction.breathing:
        break;
      case RigPetAction.headFollow:
        headX = _pixel(target.x * RigDriverParameters.headFollowOffset);
        headY = _pixel(target.y * RigDriverParameters.headFollowOffset);
        headRotation = _rotation(
          target.x * RigDriverParameters.headFollowDegrees,
        );
        break;
      case RigPetAction.nuzzle:
        final ease = _pulse(
          seconds,
          RigDriverParameters.nuzzlePulsePeriodSeconds,
        );
        headX = _pixel(target.x * RigDriverParameters.nuzzleOffset * ease);
        headY = _pixel(
          (RigDriverParameters.nuzzleVerticalBase +
                  target.y * RigDriverParameters.nuzzleVerticalGain) *
              RigDriverParameters.nuzzleOffset *
              ease,
        );
        headRotation = _rotation(
          target.x * RigDriverParameters.nuzzleHeadDegrees * ease,
        );
        break;
      case RigPetAction.happyJump:
        garmentOpacity = _frontGarmentOpacity(seconds);
        final phase = _phase(seconds, RigDriverParameters.jumpPeriodSeconds);
        final lift = math.sin(phase * math.pi).clamp(0.0, 1.0);
        translationY = _pixel(-RigDriverParameters.jumpHeight * lift);
        final squash = math.sin(phase * math.pi * 2);
        scaleX = _scale(1 - squash * RigDriverParameters.jumpSquashX);
        scaleY = _scale(1 + squash * RigDriverParameters.jumpStretchY);
        break;
      case RigPetAction.eatTreat:
        garmentOpacity = _frontGarmentOpacity(seconds);
        final dip = _pulse(seconds, RigDriverParameters.eatPulsePeriodSeconds);
        headY = _pixel(RigDriverParameters.eatingHeadDrop * dip);
        headRotation = _rotation(RigDriverParameters.eatHeadDegrees * dip);
        break;
      case RigPetAction.morningStretch:
        garmentOpacity = _frontGarmentOpacity(seconds);
        final progress = (seconds / RigDriverParameters.stretchDurationSeconds)
            .clamp(0.0, 1.0);
        final stretch = math.sin(progress * math.pi);
        scaleX = _scale(1 + stretch * RigDriverParameters.stretchExpandX);
        scaleY = _scale(1 - stretch * RigDriverParameters.stretchCompressY);
        translationY = _pixel(RigDriverParameters.stretchSinkPixels * stretch);
        headY = _pixel(-RigDriverParameters.stretchHeadLiftPixels * stretch);
        break;
      case RigPetAction.sleepTransition:
        sleepOpacity = _scale(
          (seconds / RigDriverParameters.sleepTransitionSeconds).clamp(
            0.0,
            1.0,
          ),
        );
        garmentOpacity = 1 - sleepOpacity;
        break;
      case RigPetAction.running:
        // There are no side-pose fitted assets. Side running intentionally
        // hides them immediately; a fade would imply unavailable side art.
        garmentOpacity = usesSidePose ? 0 : _frontGarmentOpacity(seconds);
        if (!hasSide) {
          final hop = math.sin(
            seconds /
                RigDriverParameters.sidelessRunPeriodSeconds *
                math.pi *
                2,
          );
          translationX = _pixel(
            RigDriverParameters.sidelessRunHorizontalPixels * hop,
          );
          translationY = _pixel(
            -RigDriverParameters.sidelessRunBobPixels * hop.abs(),
          );
          break;
        }
        final stride = math.sin(
          seconds / RigDriverParameters.runPeriodSeconds * math.pi * 2,
        );
        bodyRotation = _rotation(RigDriverParameters.runBodyLeanDegrees);
        frontLegRotation = _rotation(
          stride * RigDriverParameters.runLegDegrees,
        );
        hindLegRotation = _rotation(
          -stride * RigDriverParameters.runLegDegrees,
        );
        tailRotation = _rotation(-stride * RigDriverParameters.tailDegrees);
        translationY = _pixel(-RigDriverParameters.runBobPixels * stride.abs());
        break;
    }

    return RigPoseFrame(
      translationX: translationX,
      translationY: translationY,
      scaleX: _scale(scaleX),
      scaleY: _scale(scaleY),
      bodyRotationDegrees: bodyRotation,
      headTranslationX: headX,
      headTranslationY: headY,
      headRotationDegrees: headRotation,
      tailRotationDegrees: tailRotation,
      frontLegRotationDegrees: frontLegRotation,
      hindLegRotationDegrees: hindLegRotation,
      sleepOpacity: sleepOpacity,
      garmentOpacity: _scale(garmentOpacity),
      usesSidePose: usesSidePose,
      blinkClosed:
          action != RigPetAction.sleepTransition &&
          _blinkClosed(elapsed.inMilliseconds),
    );
  }

  bool _blinkClosed(int elapsedMilliseconds) {
    var random = blinkSeed & 0x7fffffff;
    final intervals = <int>[];
    var cycleDuration = 0;
    for (
      var index = 0;
      index < RigDriverParameters.blinkScheduleLength;
      index++
    ) {
      random = (1103515245 * random + 12345) & 0x7fffffff;
      final interval =
          RigDriverParameters.blinkMinimumMilliseconds +
          random %
              (RigDriverParameters.blinkMaximumMilliseconds -
                  RigDriverParameters.blinkMinimumMilliseconds +
                  1);
      intervals.add(interval);
      cycleDuration += interval + RigDriverParameters.blinkClosedMilliseconds;
    }
    var cursor = elapsedMilliseconds % cycleDuration;
    for (final interval in intervals) {
      if (cursor < interval) return false;
      cursor -= interval;
      if (cursor < RigDriverParameters.blinkClosedMilliseconds) return true;
      cursor -= RigDriverParameters.blinkClosedMilliseconds;
    }
    return false;
  }
}

double _frontGarmentOpacity(double seconds) =>
    1 - (seconds / RigDriverParameters.garmentFadeSeconds).clamp(0.0, 1.0);

double _phase(double seconds, double period) => (seconds % period) / period;

double _pulse(double seconds, double period) =>
    math.sin(_phase(seconds, period) * math.pi).clamp(0.0, 1.0);

int _pixel(num value) => value.round();

double _rotation(double value) =>
    (value / RigDriverParameters.rotationStepDegrees).round() *
    RigDriverParameters.rotationStepDegrees;

double _scale(double value) => (value * 1000).round() / 1000;
