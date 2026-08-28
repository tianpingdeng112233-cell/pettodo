import 'dart:math' as math;

import '../domain/accessory.dart';
import 'rig_definition.dart';
import 'rig_driver.dart';

class AccessoryPose {
  const AccessoryPose({
    required this.x,
    required this.y,
    this.rotationDegrees = 0,
  });

  final double x;
  final double y;
  final double rotationDegrees;

  @override
  bool operator ==(Object other) =>
      other is AccessoryPose &&
      x == other.x &&
      y == other.y &&
      rotationDegrees == other.rotationDegrees;

  @override
  int get hashCode => Object.hash(x, y, rotationDegrees);
}

class AccessoryFrameAnchors {
  const AccessoryFrameAnchors({required this.head, required this.neck});

  AccessoryFrameAnchors.front(
    double x,
    double headY, {
    double rotationDegrees = 0,
  }) : head = AccessoryPose(x: x, y: headY, rotationDegrees: rotationDegrees),
       neck = AccessoryPose(
         x: x,
         y: headY + 76,
         rotationDegrees: rotationDegrees,
       );

  AccessoryFrameAnchors.right(
    double x,
    double headY, {
    double rotationDegrees = 0,
  }) : head = AccessoryPose(x: x, y: headY, rotationDegrees: rotationDegrees),
       neck = AccessoryPose(
         x: x - 14,
         y: headY + 62,
         rotationDegrees: rotationDegrees,
       );

  AccessoryFrameAnchors.left(
    double x,
    double headY, {
    double rotationDegrees = 0,
  }) : head = AccessoryPose(x: x, y: headY, rotationDegrees: rotationDegrees),
       neck = AccessoryPose(
         x: x + 14,
         y: headY + 62,
         rotationDegrees: rotationDegrees,
       );

  final AccessoryPose head;
  final AccessoryPose neck;

  AccessoryPose forAnchor(AccessoryAnchor anchor) => switch (anchor) {
    AccessoryAnchor.head => head,
    AccessoryAnchor.neck => neck,
  };
}

AccessoryPose resolveRigAccessoryPose({
  required AccessoryAnchor anchor,
  required RigBox headBox,
  required RigPoint headPivot,
  required int groundY,
  required RigPoseFrame frame,
  bool sidePose = false,
}) {
  final baseX = headBox.x0 + headBox.width / 2;
  if (anchor == AccessoryAnchor.neck) {
    final torsoTopX = headPivot.x.toDouble();
    final torsoTopY = headPivot.y.toDouble();
    final neckX = (baseX + torsoTopX) / 2;
    final neckY = (headBox.y1 + torsoTopY) / 2;
    return AccessoryPose(
      x: frame.translationX + neckX * frame.scaleX,
      y: frame.translationY + groundY + (neckY - groundY) * frame.scaleY,
      rotationDegrees: sidePose ? frame.bodyRotationDegrees : 0,
    );
  }

  final baseY = headBox.y0.toDouble();
  final rotationDegrees =
      frame.headRotationDegrees + (sidePose ? frame.bodyRotationDegrees : 0);
  final radians = rotationDegrees * math.pi / 180;
  final relativeX = baseX - headPivot.x;
  final relativeY = baseY - headPivot.y;
  final headX =
      headPivot.x +
      frame.headTranslationX +
      relativeX * math.cos(radians) -
      relativeY * math.sin(radians);
  final headY =
      headPivot.y +
      frame.headTranslationY +
      relativeX * math.sin(radians) +
      relativeY * math.cos(radians);
  return AccessoryPose(
    x: frame.translationX + headX * frame.scaleX,
    y: frame.translationY + groundY + (headY - groundY) * frame.scaleY,
    rotationDegrees: rotationDegrees,
  );
}

AccessoryPose? resolveV2AccessoryPose({
  required String stateName,
  required int frame,
  required AccessoryAnchor anchor,
}) {
  final frames = v2AccessoryAnchorTable[stateName];
  if (frames == null || frame < 0 || frame >= frames.length) return null;
  return frames[frame].forAnchor(anchor);
}

final Map<String, List<AccessoryFrameAnchors>> v2AccessoryAnchorTable =
    Map<String, List<AccessoryFrameAnchors>>.unmodifiable(
      <String, List<AccessoryFrameAnchors>>{
        'idle': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.front(96, 15),
          AccessoryFrameAnchors.front(96, 17),
          AccessoryFrameAnchors.front(96, 15),
          AccessoryFrameAnchors.front(96, 16),
          AccessoryFrameAnchors.front(96, 15),
          AccessoryFrameAnchors.front(96, 16),
        ],
        'running-right': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.right(126, 32),
          AccessoryFrameAnchors.right(126, 29),
          AccessoryFrameAnchors.right(124, 19),
          AccessoryFrameAnchors.right(126, 24),
          AccessoryFrameAnchors.right(126, 33),
          AccessoryFrameAnchors.right(126, 18),
          AccessoryFrameAnchors.right(128, 24),
          AccessoryFrameAnchors.right(128, 29),
        ],
        'running-left': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.left(66, 32),
          AccessoryFrameAnchors.left(66, 29),
          AccessoryFrameAnchors.left(68, 19),
          AccessoryFrameAnchors.left(66, 24),
          AccessoryFrameAnchors.left(66, 33),
          AccessoryFrameAnchors.left(66, 18),
          AccessoryFrameAnchors.left(64, 24),
          AccessoryFrameAnchors.left(64, 29),
        ],
        'waving': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.front(96, 15),
          AccessoryFrameAnchors.front(96, 16),
          AccessoryFrameAnchors.front(96, 15),
          AccessoryFrameAnchors.front(96, 16),
        ],
        'jumping': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.front(91, 78),
          AccessoryFrameAnchors.front(116, 58, rotationDegrees: 8),
          AccessoryFrameAnchors.front(96, 75),
          AccessoryFrameAnchors.front(82, 67, rotationDegrees: -8),
          AccessoryFrameAnchors.front(90, 43),
        ],
        'failed': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.front(96, 22),
          AccessoryFrameAnchors.front(96, 5),
          AccessoryFrameAnchors.front(96, 1),
          AccessoryFrameAnchors.front(96, 1),
          AccessoryFrameAnchors.front(96, 1),
          AccessoryFrameAnchors.front(96, 1),
          AccessoryFrameAnchors.front(96, 19),
          AccessoryFrameAnchors.front(96, 24),
        ],
        'waiting': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.front(96, 18),
          AccessoryFrameAnchors.front(93, 18, rotationDegrees: -4),
          AccessoryFrameAnchors.front(96, 18),
          AccessoryFrameAnchors.front(99, 18, rotationDegrees: 4),
          AccessoryFrameAnchors.front(96, 18),
          AccessoryFrameAnchors.front(102, 19, rotationDegrees: 7),
        ],
        'running': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.front(96, 16),
          AccessoryFrameAnchors.front(96, 18),
          AccessoryFrameAnchors.front(96, 16),
          AccessoryFrameAnchors.front(74, 24, rotationDegrees: -9),
          AccessoryFrameAnchors.front(118, 23, rotationDegrees: 9),
          AccessoryFrameAnchors.front(96, 17),
        ],
        'review': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.front(96, 15),
          AccessoryFrameAnchors.front(96, 18),
          AccessoryFrameAnchors.front(96, 15),
          AccessoryFrameAnchors.front(72, 18, rotationDegrees: -10),
          AccessoryFrameAnchors.front(120, 18, rotationDegrees: 10),
          AccessoryFrameAnchors.front(96, 15),
        ],
        'look-row-9': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.front(96, 8),
          AccessoryFrameAnchors.front(103, 10, rotationDegrees: 4),
          AccessoryFrameAnchors.front(110, 14, rotationDegrees: 8),
          AccessoryFrameAnchors.front(116, 20, rotationDegrees: 10),
          AccessoryFrameAnchors.right(120, 27),
          AccessoryFrameAnchors.right(113, 35, rotationDegrees: 8),
          AccessoryFrameAnchors.front(106, 47, rotationDegrees: 6),
          AccessoryFrameAnchors.front(101, 55, rotationDegrees: 4),
        ],
        'look-row-10': <AccessoryFrameAnchors>[
          AccessoryFrameAnchors.front(96, 63),
          AccessoryFrameAnchors.front(87, 55, rotationDegrees: -4),
          AccessoryFrameAnchors.front(81, 47, rotationDegrees: -6),
          AccessoryFrameAnchors.left(78, 35, rotationDegrees: -8),
          AccessoryFrameAnchors.left(72, 27),
          AccessoryFrameAnchors.front(76, 20, rotationDegrees: -10),
          AccessoryFrameAnchors.front(82, 14, rotationDegrees: -8),
          AccessoryFrameAnchors.front(89, 10, rotationDegrees: -4),
        ],
      }.map(
        (state, frames) =>
            MapEntry(state, List<AccessoryFrameAnchors>.unmodifiable(frames)),
      ),
    );
