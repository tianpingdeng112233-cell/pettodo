import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/room_asset_manifest.dart';
import '../domain/accessory.dart';
import '../domain/pet_action.dart';
import '../ui/widgets/accessory_item_view.dart';
import 'accessory_anchors.dart';
import 'fitted_canvas_transform.dart';
import 'rig_driver.dart';
import 'rig_garment_manifest.dart';
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
    this.accessories = const <AccessoryItem>[],
    this.accessoryManifest,
  });

  final LoadedRigPet pet;
  final RigPetAction action;
  final RigTarget target;
  final Offset externalOffset;
  final Duration? fixedElapsed;
  final List<AccessoryItem> accessories;
  final RoomAssetManifest? accessoryManifest;

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
    final elapsed = widget.fixedElapsed ?? _elapsed;
    final frame = _driver.sample(
      action: widget.action,
      elapsed: elapsed,
      target: widget.target,
      hasSide: widget.pet.definition.side != null,
    );
    final frontOpacity = 1 - frame.sleepOpacity;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final side = widget.pet.definition.side;
        final sidePose = frame.usesSidePose;
        final imageWidth = sidePose
            ? widget.pet.sideWidth!
            : widget.pet.frontWidth;
        final imageHeight = sidePose
            ? widget.pet.sideHeight!
            : widget.pet.frontHeight;
        final headBox = sidePose
            ? side!.head
            : widget.pet.definition.front.head;
        final headPivot = sidePose
            ? side!.headPivot
            : widget.pet.definition.front.headPivot;
        final groundY = sidePose
            ? side!.groundY
            : widget.pet.definition.front.groundY;
        final fitted = FittedCanvasTransform.contain(
          canvasSize: size,
          contentWidth: imageWidth.toDouble(),
          contentHeight: imageHeight.toDouble(),
        );
        final garmentLayers = <AccessoryAnchor, ui.Image>{};
        final stickerAccessories = <AccessoryItem>[];
        for (final item in widget.accessories) {
          final selection = selectRigAccessoryRendering(
            accessory: item,
            manifest: widget.pet.garments?.manifest,
          );
          final garment = selection.garment;
          final image = garment == null
              ? null
              : widget.pet.garments?.imagesById[garment.id];
          if (image != null) {
            final canPaintFitted =
                !sidePose &&
                (item.anchor != AccessoryAnchor.head || headPivot != null);
            if (canPaintFitted) {
              garmentLayers[item.anchor] = image;
            }
            continue;
          }
          stickerAccessories.add(item);
        }
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _RigPainter(
                  pet: widget.pet,
                  frame: frame,
                  externalOffset: widget.externalOffset,
                  garmentLayers: garmentLayers,
                ),
              ),
            ),
            if (widget.accessoryManifest case final manifest?
                when headBox != null && headPivot != null)
              for (final item in stickerAccessories)
                AnchoredAccessoryItemView(
                  item: item,
                  manifest: manifest,
                  pose: _canvasAccessoryPose(
                    resolveRigAccessoryPose(
                      anchor: item.anchor,
                      headBox: headBox,
                      headPivot: headPivot,
                      groundY: groundY,
                      frame: frame,
                      sidePose: sidePose,
                    ),
                    fitted: fitted,
                    externalOffset: widget.externalOffset,
                  ),
                  scale: fitted.scale * headBox.width / 96,
                  opacity: frontOpacity,
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
  required Offset externalOffset,
}) {
  final point = fitted.mapPoint(Offset(pose.x, pose.y));
  return AccessoryPose(
    x: point.dx + externalOffset.dx.round(),
    y: point.dy + externalOffset.dy.round(),
    rotationDegrees: pose.rotationDegrees,
  );
}

class _RigPainter extends CustomPainter {
  const _RigPainter({
    required this.pet,
    required this.frame,
    required this.externalOffset,
    required this.garmentLayers,
  });

  final LoadedRigPet pet;
  final RigPoseFrame frame;
  final Offset externalOffset;
  final Map<AccessoryAnchor, ui.Image> garmentLayers;

  @override
  void paint(Canvas canvas, Size size) => paintRigPetFrame(
    canvas: canvas,
    size: size,
    pet: pet,
    frame: frame,
    externalOffset: externalOffset,
    garmentLayers: garmentLayers,
  );

  @override
  bool shouldRepaint(covariant _RigPainter oldDelegate) => true;
}
