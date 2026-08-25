import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'rig_definition.dart';
import 'rig_tuning.dart';
import 'sprite_atlas.dart';

class RigLayerSet {
  const RigLayerSet({
    required this.body,
    required this.head,
    required this.tail,
    this.closedHead,
    this.frontLeg,
    this.hindLeg,
  });

  final ui.Image body;
  final ui.Image head;
  final ui.Image tail;
  final ui.Image? closedHead;
  final ui.Image? frontLeg;
  final ui.Image? hindLeg;

  void dispose() {
    body.dispose();
    head.dispose();
    tail.dispose();
    closedHead?.dispose();
    frontLeg?.dispose();
    hindLeg?.dispose();
  }
}

class LoadedRigPet {
  const LoadedRigPet({
    required this.descriptor,
    required this.definition,
    required this.frontWidth,
    required this.frontHeight,
    required this.sideWidth,
    required this.sideHeight,
    required this.frontLayers,
    required this.sideLayers,
    required this.sleepImage,
  });

  final PetAssetDescriptor descriptor;
  final RigDefinition definition;
  final int frontWidth;
  final int frontHeight;
  final int sideWidth;
  final int sideHeight;
  final RigLayerSet frontLayers;
  final RigLayerSet sideLayers;
  final ui.Image sleepImage;

  void dispose() {
    frontLayers.dispose();
    sideLayers.dispose();
    sleepImage.dispose();
  }
}

class RigPetLoader {
  RigPetLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<LoadedRigPet> load(PetAssetDescriptor descriptor) async {
    final assets = descriptor.rig;
    if (!descriptor.isRig || assets == null) {
      throw ArgumentError.value(descriptor.id, 'descriptor', 'Not a rig pet');
    }
    final definition = RigDefinition.fromJson(
      jsonDecode(await _readString(assets.rigAsset)),
    );
    // decode results are collected so a partial failure can dispose the
    // images that did decode
    final decoded = await Future.wait(
      <Future<ui.Image>>[
        _decode(assets.frontOpenAsset),
        _decode(assets.frontClosedAsset),
        _decode(assets.sleepAsset),
        _decode(assets.sideAsset),
      ].map(
        (future) => future
            .then<ui.Image?>((image) => image)
            .catchError((Object _) => null),
      ),
    );
    if (decoded.any((image) => image == null)) {
      for (final image in decoded) {
        image?.dispose();
      }
      throw const FormatException('A pose image failed to decode.');
    }
    final frontOpen = decoded[0]!;
    final frontClosed = decoded[1]!;
    ui.Image? sleep = decoded[2];
    final side = decoded[3]!;
    RigLayerSet? frontLayers;
    try {
      if (frontOpen.width != frontClosed.width ||
          frontOpen.height != frontClosed.height) {
        throw const FormatException(
          'The front pose images must use the same canvas.',
        );
      }
      definition.front.validateForImage(frontOpen.width, frontOpen.height);
      definition.side.validateForImage(side.width, side.height);
      frontLayers = await _composeFront(
        frontOpen,
        frontClosed,
        definition.front,
      );
      final sideLayers = await _composeSide(side, definition.side);
      final pet = LoadedRigPet(
        descriptor: descriptor,
        definition: definition,
        frontWidth: frontOpen.width,
        frontHeight: frontOpen.height,
        sideWidth: side.width,
        sideHeight: side.height,
        frontLayers: frontLayers,
        sideLayers: sideLayers,
        sleepImage: sleep!,
      );
      // ownership transferred to LoadedRigPet
      frontLayers = null;
      sleep = null;
      return pet;
    } catch (_) {
      frontLayers?.dispose();
      sleep?.dispose();
      rethrow;
    } finally {
      frontOpen.dispose();
      frontClosed.dispose();
      side.dispose();
    }
  }

  Future<ui.Image> _decode(String path) async {
    final bytes = await _readBytes(path);
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  Future<String> _readString(String path) => path.startsWith('/')
      ? File(path).readAsString()
      : _bundle.loadString(path);

  Future<Uint8List> _readBytes(String path) async {
    if (path.startsWith('/')) return File(path).readAsBytes();
    final data = await _bundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

Future<RigLayerSet> _composeFront(
  ui.Image open,
  ui.Image closed,
  FrontRigDefinition rig,
) async {
  final body = await _bodyLayer(
    open,
    head: rig.head,
    detached: <RigBox>[rig.tail],
  );
  final layers = await _partLayers(<Future<ui.Image>>[
    _partLayer(open, rig.head, expandTop: true),
    _partLayer(closed, rig.head, expandTop: true),
    _partLayer(open, rig.tail),
  ], onFailure: body.dispose);
  return RigLayerSet(
    body: body,
    head: layers[0],
    closedHead: layers[1],
    tail: layers[2],
  );
}

/// Awaits all part layers; on any failure every layer that did compose (and
/// the caller's body layer) is disposed before the error propagates.
Future<List<ui.Image>> _partLayers(
  List<Future<ui.Image>> futures, {
  required void Function() onFailure,
}) async {
  final settled = await Future.wait(
    futures.map(
      (future) => future
          .then<ui.Image?>((image) => image)
          .catchError((Object _) => null),
    ),
  );
  if (settled.any((image) => image == null)) {
    for (final image in settled) {
      image?.dispose();
    }
    onFailure();
    throw const FormatException('A rig layer failed to compose.');
  }
  return settled.cast<ui.Image>();
}

Future<RigLayerSet> _composeSide(ui.Image image, SideRigDefinition rig) async {
  final body = await _bodyLayer(
    image,
    head: rig.head,
    detached: <RigBox>[rig.tail, rig.frontLeg, rig.hindLeg],
  );
  final layers = await _partLayers(<Future<ui.Image>>[
    _partLayer(image, rig.head, expandTop: true),
    _partLayer(image, rig.tail),
    _partLayer(image, rig.frontLeg),
    _partLayer(image, rig.hindLeg),
  ], onFailure: body.dispose);
  return RigLayerSet(
    body: body,
    head: layers[0],
    tail: layers[1],
    frontLeg: layers[2],
    hindLeg: layers[3],
  );
}

Future<ui.Image> _partLayer(
  ui.Image source,
  RigBox box, {
  bool expandTop = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final bounds = ui.Rect.fromLTWH(
    0,
    0,
    source.width.toDouble(),
    source.height.toDouble(),
  );
  canvas.saveLayer(bounds, ui.Paint());
  canvas.drawImage(source, ui.Offset.zero, ui.Paint());
  final feather =
      (box.width < box.height ? box.width : box.height) *
      RigComposeTuning.featherFraction;
  final horizontalExpansion =
      box.width * RigComposeTuning.partHorizontalExpansion;
  final topExpansion =
      box.height *
      (expandTop
          ? RigComposeTuning.partHeadTopExpansion
          : RigComposeTuning.partTopExpansion);
  final mask = ui.RRect.fromRectAndRadius(
    ui.Rect.fromLTRB(
      box.x0 - horizontalExpansion,
      box.y0 - topExpansion,
      box.x1 + horizontalExpansion,
      box.y1 + box.height * RigComposeTuning.partBottomExpansion,
    ),
    ui.Radius.circular(box.width * RigComposeTuning.partCornerRadiusFraction),
  );
  canvas.drawRRect(
    mask,
    ui.Paint()
      ..color = const ui.Color(0xffffffff)
      ..blendMode = ui.BlendMode.dstIn
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, feather),
  );
  canvas.restore();
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(source.width, source.height);
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> _bodyLayer(
  ui.Image source, {
  required RigBox head,
  required List<RigBox> detached,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawImage(source, ui.Offset.zero, ui.Paint());
  final clear = ui.Paint()
    ..blendMode = ui.BlendMode.clear
    ..maskFilter = ui.MaskFilter.blur(
      ui.BlurStyle.normal,
      (head.width < head.height ? head.width : head.height) *
          RigComposeTuning.cutoutFeatherFraction,
    );
  final headExpansion = head.width * RigComposeTuning.headExpansionFraction;
  final chinY = head.y1.toDouble();
  final notchY = head.y1 - head.height * RigComposeTuning.neckOverlapFraction;
  final neckHalfWidth = head.width * RigComposeTuning.neckHalfWidthFraction;
  final centerX = (head.x0 + head.x1) / 2;
  // full-width erase all the way down to the chin line (kills ear remnants at
  // the sides), with a protected chest notch in the middle that stops above
  // the chin so the moving head always covers the hole
  final cutout = ui.Path()
    ..moveTo(
      head.x0 - headExpansion,
      head.y0 - head.height * RigComposeTuning.topExpansionFraction,
    )
    ..lineTo(
      head.x1 + headExpansion,
      head.y0 - head.height * RigComposeTuning.topExpansionFraction,
    )
    ..lineTo(head.x1 + headExpansion, chinY)
    ..lineTo(centerX + neckHalfWidth, chinY)
    ..lineTo(centerX + neckHalfWidth, notchY)
    ..lineTo(centerX - neckHalfWidth, notchY)
    ..lineTo(centerX - neckHalfWidth, chinY)
    ..lineTo(head.x0 - headExpansion, chinY)
    ..close();
  canvas.drawPath(cutout, clear);
  for (final box in detached) {
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTRB(
          box.x0.toDouble(),
          box.y0.toDouble(),
          box.x1.toDouble(),
          box.y1.toDouble(),
        ).inflate(
          (box.width < box.height ? box.width : box.height) *
              RigComposeTuning.detachedInflateFraction,
        ),
        ui.Radius.circular(
          box.width * RigComposeTuning.detachedCornerRadiusFraction,
        ),
      ),
      clear,
    );
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(source.width, source.height);
  } finally {
    picture.dispose();
  }
}
