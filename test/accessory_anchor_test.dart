import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/accessory.dart';
import 'package:pettodo/sprite/accessory_anchors.dart';
import 'package:pettodo/sprite/rig_definition.dart';
import 'package:pettodo/sprite/rig_driver.dart';

void main() {
  test('the same rig pose frame resolves to the same accessory anchors', () {
    const frame = RigPoseFrame(
      translationX: 4,
      translationY: 5,
      scaleX: 0.9,
      scaleY: 1.1,
      bodyRotationDegrees: 0,
      headTranslationX: 3,
      headTranslationY: -2,
      headRotationDegrees: 0,
      tailRotationDegrees: 0,
      frontLegRotationDegrees: 0,
      hindLegRotationDegrees: 0,
      sleepOpacity: 0,
      blinkClosed: false,
    );

    final first = resolveRigAccessoryPose(
      anchor: AccessoryAnchor.head,
      headBox: const RigBox(20, 10, 60, 50),
      headPivot: const RigPoint(40, 40),
      groundY: 100,
      frame: frame,
    );
    final second = resolveRigAccessoryPose(
      anchor: AccessoryAnchor.head,
      headBox: const RigBox(20, 10, 60, 50),
      headPivot: const RigPoint(40, 40),
      groundY: 100,
      frame: frame,
    );

    expect(second, first);
    expect(first.x, closeTo(42.7, 0.0001));
    expect(first.y, closeTo(3.8, 0.0001));
  });

  test('head rotation does not move the neck anchor coordinates', () {
    const restingFrame = RigPoseFrame(
      translationX: 4,
      translationY: 5,
      scaleX: 0.9,
      scaleY: 1.1,
      bodyRotationDegrees: 0,
      headTranslationX: 0,
      headTranslationY: 0,
      headRotationDegrees: 0,
      tailRotationDegrees: 0,
      frontLegRotationDegrees: 0,
      hindLegRotationDegrees: 0,
      sleepOpacity: 0,
      blinkClosed: false,
    );
    const rotatedHeadFrame = RigPoseFrame(
      translationX: 4,
      translationY: 5,
      scaleX: 0.9,
      scaleY: 1.1,
      bodyRotationDegrees: 0,
      headTranslationX: 0,
      headTranslationY: 0,
      headRotationDegrees: 30,
      tailRotationDegrees: 0,
      frontLegRotationDegrees: 0,
      hindLegRotationDegrees: 0,
      sleepOpacity: 0,
      blinkClosed: false,
    );

    final resting = resolveRigAccessoryPose(
      anchor: AccessoryAnchor.neck,
      headBox: const RigBox(20, 10, 60, 50),
      headPivot: const RigPoint(40, 40),
      groundY: 100,
      frame: restingFrame,
    );
    final rotated = resolveRigAccessoryPose(
      anchor: AccessoryAnchor.neck,
      headBox: const RigBox(20, 10, 60, 50),
      headPivot: const RigPoint(40, 40),
      groundY: 100,
      frame: rotatedHeadFrame,
    );

    expect((rotated.x, rotated.y), (resting.x, resting.y));
  });

  test('the v2 fixed offset table covers every standard pose frame', () {
    const frameCounts = <String, int>{
      'idle': 6,
      'running-right': 8,
      'running-left': 8,
      'waving': 4,
      'jumping': 5,
      'failed': 8,
      'waiting': 6,
      'running': 6,
      'review': 6,
      'look-row-9': 8,
      'look-row-10': 8,
    };

    for (final entry in frameCounts.entries) {
      for (var frame = 0; frame < entry.value; frame++) {
        for (final anchor in AccessoryAnchor.values) {
          final pose = resolveV2AccessoryPose(
            stateName: entry.key,
            frame: frame,
            anchor: anchor,
          );
          expect(
            pose,
            isNotNull,
            reason: '${entry.key}[$frame] ${anchor.name}',
          );
          expect(pose!.x, inInclusiveRange(0, 192));
          expect(pose.y, inInclusiveRange(0, 208));
        }
      }
    }
  });
}
