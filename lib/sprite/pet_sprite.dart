import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'sprite_atlas.dart';

class PetSprite extends StatefulWidget {
  const PetSprite({
    super.key,
    required this.atlas,
    this.stateName = 'idle',
    this.framesPerSecond = 8,
  });

  final LoadedSpriteAtlas atlas;
  final String stateName;
  final double framesPerSecond;

  @override
  State<PetSprite> createState() => _PetSpriteState();
}

class _PetSpriteState extends State<PetSprite>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant PetSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stateName != widget.stateName ||
        oldWidget.atlas != widget.atlas) {
      _frame = 0;
      _ticker.stop();
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final sequence = widget.atlas.definition.sequence(widget.stateName);
    final next =
        (elapsed.inMicroseconds * widget.framesPerSecond ~/ 1000000) %
        sequence.frameCount;
    if (next != _frame && mounted) setState(() => _frame = next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SpritePainter(
      image: widget.atlas.image,
      source: widget.atlas.definition
          .frameRect(widget.stateName, _frame)
          .uiRect,
    ),
    child: const SizedBox.expand(),
  );
}

class _SpritePainter extends CustomPainter {
  const _SpritePainter({required this.image, required this.source});

  final ui.Image image;
  final ui.Rect source;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = mathMin(
      size.width / source.width,
      size.height / source.height,
    );
    final width = source.width * scale;
    final height = source.height * scale;
    final destination = Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.source != source;
}

double mathMin(double a, double b) => a < b ? a : b;
