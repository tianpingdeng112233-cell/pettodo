import 'dart:math' as math;
import 'dart:ui' as ui;

import '../domain/pet_action.dart';
import 'rig_definition.dart';
import 'rig_driver.dart';
import 'rig_pet.dart';

void paintRigPetFrame({
  required ui.Canvas canvas,
  required ui.Size size,
  required LoadedRigPet pet,
  required RigPetAction action,
  required RigPoseFrame frame,
  ui.Offset externalOffset = ui.Offset.zero,
}) {
  final frontOpacity = 1 - frame.sleepOpacity;
  if (frontOpacity > 0) {
    if (action == RigPetAction.running && pet.definition.side != null) {
      _paintSide(canvas, size, pet, frame, externalOffset, frontOpacity);
    } else {
      _paintFront(canvas, size, pet, frame, externalOffset, frontOpacity);
    }
  }
  if (frame.sleepOpacity > 0) {
    _drawFitted(
      canvas,
      size,
      pet.sleepImage,
      pet.sleepWidth,
      pet.sleepHeight,
      frame.sleepOpacity,
    );
  }
}

void _paintFront(
  ui.Canvas canvas,
  ui.Size size,
  LoadedRigPet pet,
  RigPoseFrame frame,
  ui.Offset externalOffset,
  double opacity,
) {
  final rig = pet.definition.front;
  final scale = _prepareCanvas(
    canvas,
    size,
    pet.frontWidth,
    pet.frontHeight,
    rig.groundY,
    frame,
  );
  canvas.translate(
    externalOffset.dx.round() / scale,
    externalOffset.dy.round() / scale,
  );
  final paint = _opacityPaint(opacity);
  final head = pet.frontLayers.head;
  if (head == null) {
    _drawLayer(
      canvas,
      frame.blinkClosed
          ? pet.frontLayers.closedBody ?? pet.frontLayers.body
          : pet.frontLayers.body,
      pet.frontWidth,
      pet.frontHeight,
      paint,
    );
    canvas.restore();
    return;
  }
  _drawAround(
    canvas,
    pet.frontLayers.tail!,
    rig.tailPivot,
    frame.tailRotationDegrees,
    ui.Offset.zero,
    paint,
    pet.frontWidth,
    pet.frontHeight,
  );
  _drawLayer(
    canvas,
    pet.frontLayers.body,
    pet.frontWidth,
    pet.frontHeight,
    paint,
  );
  _drawAround(
    canvas,
    frame.blinkClosed ? pet.frontLayers.closedHead! : head,
    rig.headPivot!,
    frame.headRotationDegrees,
    ui.Offset(
      frame.headTranslationX.toDouble(),
      frame.headTranslationY.toDouble(),
    ),
    paint,
    pet.frontWidth,
    pet.frontHeight,
  );
  canvas.restore();
}

void _paintSide(
  ui.Canvas canvas,
  ui.Size size,
  LoadedRigPet pet,
  RigPoseFrame frame,
  ui.Offset externalOffset,
  double opacity,
) {
  final rig = pet.definition.side!;
  final scale = _prepareCanvas(
    canvas,
    size,
    pet.sideWidth!,
    pet.sideHeight!,
    rig.groundY,
    frame,
  );
  canvas.translate(
    externalOffset.dx.round() / scale,
    externalOffset.dy.round() / scale,
  );
  final paint = _opacityPaint(opacity);
  _drawAround(
    canvas,
    pet.sideLayers!.tail!,
    rig.tailPivot,
    frame.tailRotationDegrees,
    ui.Offset.zero,
    paint,
    pet.sideWidth!,
    pet.sideHeight!,
  );
  _drawAround(
    canvas,
    pet.sideLayers!.frontLeg!,
    rig.frontLegPivot,
    frame.frontLegRotationDegrees,
    ui.Offset.zero,
    paint,
    pet.sideWidth!,
    pet.sideHeight!,
  );
  _drawAround(
    canvas,
    pet.sideLayers!.hindLeg!,
    rig.hindLegPivot,
    frame.hindLegRotationDegrees,
    ui.Offset.zero,
    paint,
    pet.sideWidth!,
    pet.sideHeight!,
  );
  _drawAround(
    canvas,
    pet.sideLayers!.body,
    RigPoint(pet.sideWidth! ~/ 2, rig.groundY),
    frame.bodyRotationDegrees,
    ui.Offset.zero,
    paint,
    pet.sideWidth!,
    pet.sideHeight!,
  );
  _drawAround(
    canvas,
    pet.sideLayers!.head!,
    rig.headPivot,
    frame.bodyRotationDegrees + frame.headRotationDegrees,
    ui.Offset(
      frame.headTranslationX.toDouble(),
      frame.headTranslationY.toDouble(),
    ),
    paint,
    pet.sideWidth!,
    pet.sideHeight!,
  );
  canvas.restore();
}

double _prepareCanvas(
  ui.Canvas canvas,
  ui.Size size,
  int imageWidth,
  int imageHeight,
  int groundY,
  RigPoseFrame frame,
) {
  final scale = math.min(size.width / imageWidth, size.height / imageHeight);
  final left = (size.width - imageWidth * scale) / 2;
  final top = (size.height - imageHeight * scale) / 2;
  canvas.save();
  canvas.translate(left, top);
  canvas.scale(scale);
  canvas.translate(
    frame.translationX.toDouble(),
    frame.translationY.toDouble(),
  );
  canvas.translate(0, groundY.toDouble());
  canvas.scale(frame.scaleX, frame.scaleY);
  canvas.translate(0, -groundY.toDouble());
  return scale;
}

void _drawAround(
  ui.Canvas canvas,
  ui.Image image,
  RigPoint pivot,
  double rotationDegrees,
  ui.Offset translation,
  ui.Paint paint,
  int logicalWidth,
  int logicalHeight,
) {
  canvas.save();
  canvas.translate(pivot.x + translation.dx, pivot.y + translation.dy);
  canvas.rotate(rotationDegrees * math.pi / 180);
  canvas.translate(-pivot.x.toDouble(), -pivot.y.toDouble());
  _drawLayer(canvas, image, logicalWidth, logicalHeight, paint);
  canvas.restore();
}

void _drawLayer(
  ui.Canvas canvas,
  ui.Image image,
  int logicalWidth,
  int logicalHeight,
  ui.Paint paint,
) {
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, logicalWidth.toDouble(), logicalHeight.toDouble()),
    paint,
  );
}

void _drawFitted(
  ui.Canvas canvas,
  ui.Size size,
  ui.Image image,
  int logicalWidth,
  int logicalHeight,
  double opacity,
) {
  final source = ui.Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );
  final scale = math.min(
    size.width / logicalWidth,
    size.height / logicalHeight,
  );
  final destination = ui.Rect.fromLTWH(
    (size.width - logicalWidth * scale) / 2,
    (size.height - logicalHeight * scale) / 2,
    logicalWidth * scale,
    logicalHeight * scale,
  );
  canvas.drawImageRect(image, source, destination, _opacityPaint(opacity));
}

ui.Paint _opacityPaint(double opacity) => ui.Paint()
  ..filterQuality = ui.FilterQuality.none
  ..color = ui.Color.fromRGBO(255, 255, 255, opacity);

int stableRigSeed(String value) => value.codeUnits.fold<int>(
  17,
  (seed, unit) => ((seed * 37) + unit) & 0x7fffffff,
);
