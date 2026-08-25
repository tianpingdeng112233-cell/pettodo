import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../domain/pet_action.dart';
import 'rig_definition.dart';
import 'rig_driver.dart';
import 'rig_pet.dart';

class RigPetSprite extends StatefulWidget {
  const RigPetSprite({
    super.key,
    required this.pet,
    this.action = RigPetAction.breathing,
    this.target = const RigTarget(0, 0),
    this.externalOffset = Offset.zero,
    this.fixedElapsed,
  });

  final LoadedRigPet pet;
  final RigPetAction action;
  final RigTarget target;
  final Offset externalOffset;
  final Duration? fixedElapsed;

  @override
  State<RigPetSprite> createState() => _RigPetSpriteState();
}

class _RigPetSpriteState extends State<RigPetSprite>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final RigDriver _driver;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _driver = RigDriver(blinkSeed: _stableSeed(widget.pet.descriptor.id));
    _ticker = createTicker((elapsed) {
      if (widget.fixedElapsed == null && mounted) {
        setState(() => _elapsed = elapsed);
      }
    });
    if (widget.fixedElapsed == null) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant RigPetSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action || oldWidget.pet != widget.pet) {
      _elapsed = Duration.zero;
      _ticker.stop();
      if (widget.fixedElapsed == null) _ticker.start();
    } else if (oldWidget.fixedElapsed != widget.fixedElapsed) {
      if (widget.fixedElapsed == null) {
        _ticker.start();
      } else {
        _ticker.stop();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _driver.sample(
      action: widget.action,
      elapsed: widget.fixedElapsed ?? _elapsed,
      target: widget.target,
    );
    return CustomPaint(
      painter: _RigPainter(
        pet: widget.pet,
        action: widget.action,
        frame: frame,
        externalOffset: widget.externalOffset,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RigPainter extends CustomPainter {
  const _RigPainter({
    required this.pet,
    required this.action,
    required this.frame,
    required this.externalOffset,
  });

  final LoadedRigPet pet;
  final RigPetAction action;
  final RigPoseFrame frame;
  final Offset externalOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final frontOpacity = 1 - frame.sleepOpacity;
    if (frontOpacity > 0) {
      if (action == RigPetAction.running) {
        _paintSide(canvas, size, frontOpacity);
      } else {
        _paintFront(canvas, size, frontOpacity);
      }
    }
    if (frame.sleepOpacity > 0) {
      _drawFitted(canvas, size, pet.sleepImage, frame.sleepOpacity);
    }
  }

  void _paintFront(Canvas canvas, Size size, double opacity) {
    final rig = pet.definition.front;
    final scale = _prepareCanvas(
      canvas,
      size,
      pet.frontWidth,
      pet.frontHeight,
      rig.groundY,
    );
    canvas.translate(
      externalOffset.dx.round() / scale,
      externalOffset.dy.round() / scale,
    );
    final paint = _opacityPaint(opacity);
    _drawAround(
      canvas,
      pet.frontLayers.tail,
      rig.tailPivot,
      frame.tailRotationDegrees,
      Offset.zero,
      paint,
    );
    canvas.drawImage(pet.frontLayers.body, Offset.zero, paint);
    _drawAround(
      canvas,
      frame.blinkClosed ? pet.frontLayers.closedHead! : pet.frontLayers.head,
      rig.headPivot,
      frame.headRotationDegrees,
      Offset(
        frame.headTranslationX.toDouble(),
        frame.headTranslationY.toDouble(),
      ),
      paint,
    );
    canvas.restore();
  }

  void _paintSide(Canvas canvas, Size size, double opacity) {
    final rig = pet.definition.side;
    final scale = _prepareCanvas(
      canvas,
      size,
      pet.sideWidth,
      pet.sideHeight,
      rig.groundY,
    );
    canvas.translate(
      externalOffset.dx.round() / scale,
      externalOffset.dy.round() / scale,
    );
    final paint = _opacityPaint(opacity);
    _drawAround(
      canvas,
      pet.sideLayers.tail,
      rig.tailPivot,
      frame.tailRotationDegrees,
      Offset.zero,
      paint,
    );
    _drawAround(
      canvas,
      pet.sideLayers.frontLeg!,
      rig.frontLegPivot,
      frame.frontLegRotationDegrees,
      Offset.zero,
      paint,
    );
    _drawAround(
      canvas,
      pet.sideLayers.hindLeg!,
      rig.hindLegPivot,
      frame.hindLegRotationDegrees,
      Offset.zero,
      paint,
    );
    _drawAround(
      canvas,
      pet.sideLayers.body,
      RigPoint(pet.sideWidth ~/ 2, rig.groundY),
      frame.bodyRotationDegrees,
      Offset.zero,
      paint,
    );
    _drawAround(
      canvas,
      pet.sideLayers.head,
      rig.headPivot,
      frame.bodyRotationDegrees + frame.headRotationDegrees,
      Offset(
        frame.headTranslationX.toDouble(),
        frame.headTranslationY.toDouble(),
      ),
      paint,
    );
    canvas.restore();
  }

  double _prepareCanvas(
    Canvas canvas,
    Size size,
    int imageWidth,
    int imageHeight,
    int groundY,
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

  static void _drawAround(
    Canvas canvas,
    ui.Image image,
    RigPoint pivot,
    double rotationDegrees,
    Offset translation,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(pivot.x + translation.dx, pivot.y + translation.dy);
    canvas.rotate(rotationDegrees * math.pi / 180);
    canvas.translate(-pivot.x.toDouble(), -pivot.y.toDouble());
    canvas.drawImage(image, Offset.zero, paint);
    canvas.restore();
  }

  static void _drawFitted(
    Canvas canvas,
    Size size,
    ui.Image image,
    double opacity,
  ) {
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final scale = math.min(
      size.width / image.width,
      size.height / image.height,
    );
    final destination = Rect.fromLTWH(
      (size.width - image.width * scale) / 2,
      (size.height - image.height * scale) / 2,
      image.width * scale,
      image.height * scale,
    );
    canvas.drawImageRect(image, source, destination, _opacityPaint(opacity));
  }

  static Paint _opacityPaint(double opacity) => Paint()
    ..filterQuality = FilterQuality.none
    ..color = Color.fromRGBO(255, 255, 255, opacity);

  @override
  bool shouldRepaint(covariant _RigPainter oldDelegate) => true;
}

int _stableSeed(String value) => value.codeUnits.fold<int>(
  17,
  (seed, unit) => ((seed * 37) + unit) & 0x7fffffff,
);
