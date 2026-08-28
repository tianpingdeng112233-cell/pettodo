import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'rig_definition.dart';
import 'rig_tuning.dart';
import 'sprite_atlas.dart';

class RigLayerSet {
  const RigLayerSet({
    required this.body,
    this.head,
    this.tail,
    this.closedBody,
    this.closedHead,
    this.frontLeg,
    this.hindLeg,
  });

  final ui.Image body;
  final ui.Image? head;
  final ui.Image? tail;
  final ui.Image? closedBody;
  final ui.Image? closedHead;
  final ui.Image? frontLeg;
  final ui.Image? hindLeg;

  void dispose() {
    body.dispose();
    head?.dispose();
    tail?.dispose();
    closedBody?.dispose();
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
    required this.sleepWidth,
    required this.sleepHeight,
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
  final int sleepWidth;
  final int sleepHeight;
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
    var definition = RigDefinition.fromJson(
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
    RigLayerSet? sideLayers;
    try {
      if (frontOpen.width != frontClosed.width ||
          frontOpen.height != frontClosed.height) {
        throw const FormatException(
          'The front pose images must use the same canvas.',
        );
      }
      definition.front.validateForImage(frontOpen.width, frontOpen.height);
      definition.side.validateForImage(side.width, side.height);
      final frontHead = definition.front.head;
      final frontPivot = definition.front.headPivot;
      final saneFrontHead =
          frontHead != null &&
          frontPivot != null &&
          frontHead.fits(frontOpen.width, frontOpen.height) &&
          frontPivot.x >= 0 &&
          frontPivot.y >= 0 &&
          frontPivot.x <= frontOpen.width &&
          frontPivot.y <= frontOpen.height &&
          await isSaneFrontHeadBox(frontOpen, frontHead);
      if (!saneFrontHead) {
        definition = RigDefinition(
          rigVersion: definition.rigVersion,
          front: definition.front.withoutHead(),
          side: definition.side,
        );
      }
      frontLayers = await _composeFront(
        frontOpen,
        frontClosed,
        definition.front,
      );
      sideLayers = await _composeSide(side, definition.side);
      frontLayers = await _downscaleLayerSet(
        frontLayers,
        _fitScale(frontOpen.width, frontOpen.height),
      );
      sideLayers = await _downscaleLayerSet(
        sideLayers,
        _fitScale(side.width, side.height),
      );
      final sleepWidth = sleep!.width;
      final sleepHeight = sleep.height;
      final scaledSleep = await _downscaleImage(
        sleep,
        _fitScale(sleepWidth, sleepHeight),
      );
      if (!identical(scaledSleep, sleep)) {
        sleep.dispose();
        sleep = scaledSleep;
      }
      final pet = LoadedRigPet(
        descriptor: descriptor,
        definition: definition,
        frontWidth: frontOpen.width,
        frontHeight: frontOpen.height,
        sideWidth: side.width,
        sideHeight: side.height,
        sleepWidth: sleepWidth,
        sleepHeight: sleepHeight,
        frontLayers: frontLayers,
        sideLayers: sideLayers,
        sleepImage: sleep,
      );
      // ownership transferred to LoadedRigPet
      frontLayers = null;
      sideLayers = null;
      sleep = null;
      return pet;
    } catch (_) {
      frontLayers?.dispose();
      sideLayers?.dispose();
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

double _fitScale(int width, int height) =>
    math.min(192 / width, 208 / height).clamp(0.0, 1.0);

Future<RigLayerSet> _downscaleLayerSet(RigLayerSet source, double scale) async {
  if (scale >= 0.5) return source;
  final created = <ui.Image>[];
  Future<ui.Image?> scaled(ui.Image? image) async {
    if (image == null) return null;
    final result = await _downscaleImage(image, scale);
    created.add(result);
    return result;
  }

  try {
    final result = RigLayerSet(
      body: (await scaled(source.body))!,
      head: await scaled(source.head),
      tail: await scaled(source.tail),
      closedBody: await scaled(source.closedBody),
      closedHead: await scaled(source.closedHead),
      frontLeg: await scaled(source.frontLeg),
      hindLeg: await scaled(source.hindLeg),
    );
    source.dispose();
    return result;
  } catch (_) {
    for (final image in created) {
      image.dispose();
    }
    rethrow;
  }
}

Future<ui.Image> _downscaleImage(ui.Image source, double scale) async {
  if (scale >= 0.5) return source;
  // CPU premultiplied box filter: the previous drawImageRect+toImage path
  // rasterizes on the device GPU backend, whose filtering of transparent
  // pixels shifted layer colours (see the note on CPU-side layer baking)
  final srcWidth = source.width;
  final srcHeight = source.height;
  final width = math.max(1, (srcWidth * scale).round());
  final height = math.max(1, (srcHeight * scale).round());
  final src = await _mutablePixels(source);
  final dst = Uint8List(width * height * 4);
  for (var dy = 0; dy < height; dy++) {
    final y0 = dy * srcHeight ~/ height;
    var y1 = ((dy + 1) * srcHeight / height).ceil();
    if (y1 > srcHeight) y1 = srcHeight;
    for (var dx = 0; dx < width; dx++) {
      final x0 = dx * srcWidth ~/ width;
      var x1 = ((dx + 1) * srcWidth / width).ceil();
      if (x1 > srcWidth) x1 = srcWidth;
      var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
      var count = 0;
      for (var sy = y0; sy < y1; sy++) {
        var i = (sy * srcWidth + x0) * 4;
        for (var sx = x0; sx < x1; sx++) {
          final pa = src[i + 3] / 255;
          r += src[i] * pa;
          g += src[i + 1] * pa;
          b += src[i + 2] * pa;
          a += pa;
          count++;
          i += 4;
        }
      }
      if (a > 0) {
        final o = (dy * width + dx) * 4;
        dst[o] = (r / a).round().clamp(0, 255);
        dst[o + 1] = (g / a).round().clamp(0, 255);
        dst[o + 2] = (b / a).round().clamp(0, 255);
        dst[o + 3] = (a * 255 / count).round().clamp(0, 255);
      }
    }
  }
  return _imageFromPixels(dst, width, height);
}

Future<RigLayerSet> _composeFront(
  ui.Image open,
  ui.Image closed,
  FrontRigDefinition rig,
) async {
  final head = rig.head;
  if (head == null) {
    final body = await _fullImageLayer(open);
    final closedBody = await _fullImageLayer(closed);
    return RigLayerSet(body: body, closedBody: closedBody);
  }
  final body = await _bodyLayer(open, head: head, detached: <RigBox>[rig.tail]);
  final layers = await _partLayers(<Future<ui.Image>>[
    _partLayer(open, head, expandTop: true),
    _partLayer(closed, head, expandTop: true),
    _partLayer(open, rig.tail),
  ], onFailure: body.dispose);
  return RigLayerSet(
    body: body,
    head: layers[0],
    closedHead: layers[1],
    tail: layers[2],
  );
}

Future<ui.Image> _fullImageLayer(ui.Image source) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImage(source, ui.Offset.zero, ui.Paint());
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(source.width, source.height);
  } finally {
    picture.dispose();
  }
}

Future<bool> isSaneFrontHeadBox(ui.Image image, RigBox? head) async {
  if (head == null || !head.fits(image.width, image.height)) return false;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bytes == null) return false;
  var left = image.width;
  var top = image.height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (bytes.getUint8((y * image.width + x) * 4 + 3) > 16) {
        left = left < x ? left : x;
        top = top < y ? top : y;
        right = right > x ? right : x;
        bottom = bottom > y ? bottom : y;
      }
    }
  }
  if (bottom < 0) return false;
  final contentWidth = right + 1 - left;
  final contentHeight = bottom + 1 - top;
  final topBandBottom =
      (top + (contentHeight * 0.03).ceil().clamp(3, contentHeight)).clamp(
        top + 1,
        bottom + 1,
      );
  var topLeft = image.width;
  var topRight = -1;
  for (var y = top; y < topBandBottom; y++) {
    for (var x = 0; x < image.width; x++) {
      if (bytes.getUint8((y * image.width + x) * 4 + 3) > 16) {
        topLeft = topLeft < x ? topLeft : x;
        topRight = topRight > x ? topRight : x;
      }
    }
  }
  final margin = (contentWidth * 0.01).ceil().clamp(2, contentWidth);
  final intersects =
      head.x0 < right + 1 &&
      head.x1 > left &&
      head.y0 < bottom + 1 &&
      head.y1 > top;
  final includesFace = head.y1 >= top + contentHeight * 0.3;
  final wideEnough = head.width >= contentWidth * 0.35;
  final containsTopRows =
      head.y0 <= (top + margin).clamp(0, image.height) &&
      head.x0 <= (topLeft + margin).clamp(0, image.width) &&
      head.x1 >= (topRight + 1 - margin).clamp(0, image.width);
  return intersects && includesFace && wideEnough && containsTopRows;
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

/// CPU-side layer baking.
///
/// Earlier versions baked layers with canvas blend modes
/// (BlendMode.clear / dstIn, MaskFilter feathering) rasterized through
/// Picture.toImage. That rasterization runs on the device's GPU backend, and
/// Impeller does not honour those erase paths the way the software Skia used
/// by tests does — the head cutout silently no-ops and the moving head ghosts
/// over its baked-in twin. Layers are therefore composed with plain pixel
/// arithmetic: deterministic, identical across backends and tests.
Future<Uint8List> _mutablePixels(ui.Image source) async {
  final data = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) {
    throw const FormatException('A rig layer failed to compose.');
  }
  return Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

Future<ui.Image> _imageFromPixels(Uint8List pixels, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// Zeroes the alpha of every pixel whose centre lies OUTSIDE the rounded
/// rect (keep=false) or INSIDE it (keep=true), using per-row span arithmetic —
/// no per-pixel calls, so debug-mode baking stays fast.
void _applyRoundedRect(
  Uint8List pixels,
  int width,
  int height, {
  required double left,
  required double top,
  required double right,
  required double bottom,
  required double radius,
  required bool keep,
}) {
  void zero(int row, int fromX, int toX) {
    final lo = fromX < 0 ? 0 : fromX;
    final hi = toX >= width ? width - 1 : toX;
    for (var x = lo; x <= hi; x++) {
      pixels[(row * width + x) * 4 + 3] = 0;
    }
  }

  for (var y = 0; y < height; y++) {
    final cy = y + 0.5;
    if (cy < top || cy > bottom) {
      if (keep) zero(y, 0, width - 1);
      continue;
    }
    var rowLeft = left;
    var rowRight = right;
    final dy = cy < top + radius
        ? (top + radius) - cy
        : cy > bottom - radius
        ? cy - (bottom - radius)
        : 0.0;
    if (dy > 0) {
      final span = radius * radius - dy * dy;
      final dx = span > 0 ? math.sqrt(span) : 0.0;
      rowLeft = left + radius - dx;
      rowRight = right - radius + dx;
    }
    // pixel centres in [rowLeft, rowRight] are inside the shape
    final firstInside = (rowLeft - 0.5).ceil();
    final lastInside = (rowRight - 0.5).floor();
    if (keep) {
      zero(y, 0, firstInside - 1);
      zero(y, lastInside + 1, width - 1);
    } else {
      zero(y, firstInside, lastInside);
    }
  }
}

Future<ui.Image> _partLayer(
  ui.Image source,
  RigBox box, {
  bool expandTop = false,
}) async {
  final horizontalExpansion =
      box.width *
      (expandTop
          ? RigComposeTuning.headMaskHorizontalExpansion
          : RigComposeTuning.partHorizontalExpansion);
  final topExpansion =
      box.height *
      (expandTop
          ? RigComposeTuning.partHeadTopExpansion
          : RigComposeTuning.partTopExpansion);
  final pixels = await _mutablePixels(source);
  _applyRoundedRect(
    pixels,
    source.width,
    source.height,
    left: box.x0 - horizontalExpansion,
    top: box.y0 - topExpansion,
    right: box.x1 + horizontalExpansion,
    bottom: box.y1 + box.height * RigComposeTuning.partBottomExpansion,
    radius: box.width * RigComposeTuning.partCornerRadiusFraction,
    keep: true,
  );
  return _imageFromPixels(pixels, source.width, source.height);
}

Future<ui.Image> _bodyLayer(
  ui.Image source, {
  required RigBox head,
  required List<RigBox> detached,
}) async {
  final headExpansion = head.width * RigComposeTuning.headExpansionFraction;
  final chinY = head.y1.toDouble();
  final notchY = head.y1 - head.height * RigComposeTuning.neckOverlapFraction;
  final neckHalfWidth = head.width * RigComposeTuning.neckHalfWidthFraction;
  final centerX = (head.x0 + head.x1) / 2;
  final cutoutLeft = head.x0 - headExpansion;
  final cutoutTop =
      head.y0 - head.height * RigComposeTuning.topExpansionFraction;
  final cutoutRight = head.x1 + headExpansion;

  final pixels = await _mutablePixels(source);
  final width = source.width;
  void zero(int row, double fromX, double toX) {
    var lo = (fromX - 0.5).ceil();
    var hi = (toX - 0.5).floor();
    if (lo < 0) lo = 0;
    if (hi >= width) hi = width - 1;
    for (var x = lo; x <= hi; x++) {
      pixels[(row * width + x) * 4 + 3] = 0;
    }
  }

  // full-width erase all the way down to the chin line (kills ear remnants at
  // the sides), with a protected chest notch in the middle that stops above
  // the chin so the moving head always covers the hole
  for (var y = 0; y < source.height; y++) {
    final cy = y + 0.5;
    if (cy < cutoutTop || cy > chinY) continue;
    if (cy >= notchY) {
      zero(y, cutoutLeft, centerX - neckHalfWidth - 1);
      zero(y, centerX + neckHalfWidth + 1, cutoutRight);
    } else {
      zero(y, cutoutLeft, cutoutRight);
    }
  }
  for (final box in detached) {
    final inflate =
        (box.width < box.height ? box.width : box.height) *
        RigComposeTuning.detachedInflateFraction;
    _applyRoundedRect(
      pixels,
      width,
      source.height,
      left: box.x0 - inflate,
      top: box.y0 - inflate,
      right: box.x1 + inflate,
      bottom: box.y1 + inflate,
      radius: box.width * RigComposeTuning.detachedCornerRadiusFraction,
      keep: false,
    );
  }
  return _imageFromPixels(pixels, width, source.height);
}
