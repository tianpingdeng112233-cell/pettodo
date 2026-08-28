import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../domain/pet_action.dart';
import 'rig_driver.dart';
import 'rig_pet.dart';
import 'rig_pet_renderer.dart';

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
    _driver = RigDriver(blinkSeed: stableRigSeed(widget.pet.descriptor.id));
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
  void paint(Canvas canvas, Size size) => paintRigPetFrame(
    canvas: canvas,
    size: size,
    pet: pet,
    action: action,
    frame: frame,
    externalOffset: externalOffset,
  );

  @override
  bool shouldRepaint(covariant _RigPainter oldDelegate) => true;
}
