import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/room_asset_manifest.dart';
import '../domain/accessory.dart';
import '../ui/widgets/accessory_item_view.dart';
import 'accessory_anchors.dart';
import 'fitted_canvas_transform.dart';
import 'sprite_atlas.dart';

class PetSprite extends StatefulWidget {
  const PetSprite({
    super.key,
    required this.atlas,
    this.stateName = 'idle',
    this.framesPerSecond = 8,
    this.fixedFrame,
    this.accessories = const <AccessoryItem>[],
    this.accessoryManifest,
  });

  final LoadedSpriteAtlas atlas;
  final String stateName;
  final double framesPerSecond;
  final int? fixedFrame;
  final List<AccessoryItem> accessories;
  final RoomAssetManifest? accessoryManifest;

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
    if (widget.fixedFrame != null) return;
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
  Widget build(BuildContext context) {
    final frame = widget.fixedFrame ?? _frame;
    final source = widget.atlas.definition
        .frameRect(widget.stateName, frame)
        .uiRect;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final fitted = FittedCanvasTransform.contain(
          canvasSize: size,
          contentWidth: source.width,
          contentHeight: source.height,
        );
        final poseScaleX = source.width / 192;
        final poseScaleY = source.height / 208;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _SpritePainter(
                  image: widget.atlas.image,
                  source: source,
                  fitted: fitted,
                ),
              ),
            ),
            if (widget.accessoryManifest case final manifest?)
              for (final item in widget.accessories)
                if (resolveV2AccessoryPose(
                      stateName: widget.stateName,
                      frame: frame,
                      anchor: item.anchor,
                    )
                    case final pose?)
                  AnchoredAccessoryItemView(
                    item: item,
                    manifest: manifest,
                    pose: _canvasAccessoryPose(
                      pose,
                      fitted: fitted,
                      poseScaleX: poseScaleX,
                      poseScaleY: poseScaleY,
                    ),
                    // v2 accessory art uses a 96px design width while its
                    // anchor table uses the full 192px sprite coordinate
                    // system. Keep positions in sprite pixels, but size the
                    // art from its own design grid.
                    scale:
                        fitted.scale *
                        source.width /
                        v2AccessoryDesignWidthInPixels,
                  ),
          ],
        );
      },
    );
  }
}

AccessoryPose _canvasAccessoryPose(
  AccessoryPose pose, {
  required FittedCanvasTransform fitted,
  required double poseScaleX,
  required double poseScaleY,
}) {
  final point = fitted.mapPoint(
    Offset(pose.x * poseScaleX, pose.y * poseScaleY),
  );
  return AccessoryPose(
    x: point.dx,
    y: point.dy,
    rotationDegrees: pose.rotationDegrees,
  );
}

class _SpritePainter extends CustomPainter {
  const _SpritePainter({
    required this.image,
    required this.source,
    required this.fitted,
  });

  final ui.Image image;
  final ui.Rect source;
  final FittedCanvasTransform fitted;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      source,
      fitted.destinationRect(source.width, source.height),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.source != source ||
      oldDelegate.fitted != fitted;
}
