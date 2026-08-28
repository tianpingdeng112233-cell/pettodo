import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../domain/pet_action.dart';
import 'overlay_frame_slicer.dart';
import 'rig_driver.dart';
import 'rig_pet.dart';
import 'rig_pet_renderer.dart';
import 'sprite_atlas.dart';

const int overlayFrameWidth = 192;
const int overlayFrameHeight = 208;
const int maxOverlayIdleFrames = 32;
const String _overlayBakeSchema = 'overlay-v2-hq-32';

typedef OverlaySupportDirectoryProvider = Future<Directory> Function();

class OverlayBakeGeneration {
  int _value = 0;

  int begin() => ++_value;

  void invalidate() => _value++;

  bool isCurrent(int generation) => generation == _value;
}

class BakedOverlayFrames {
  BakedOverlayFrames({
    required List<File> idleFiles,
    required List<File> jumpingFiles,
  }) : idleFiles = List<File>.unmodifiable(idleFiles),
       jumpingFiles = List<File>.unmodifiable(jumpingFiles);

  final List<File> idleFiles;
  final List<File> jumpingFiles;

  List<File> get allFiles => <File>[...idleFiles, ...jumpingFiles];
}

class OverlayFrameBaker {
  const OverlayFrameBaker(this._supportDirectory);

  factory OverlayFrameBaker.onDevice() =>
      OverlayFrameBaker(getApplicationSupportDirectory);

  final OverlaySupportDirectoryProvider _supportDirectory;

  Future<BakedOverlayFrames> bakeRig(
    LoadedRigPet pet, {
    String? contentFingerprint,
  }) async {
    final output = await _outputDirectory(pet.descriptor.id);
    final fingerprint =
        contentFingerprint ?? await _contentFingerprint(pet.descriptor);
    final cached = await _cachedFrames(output, fingerprint);
    if (cached != null) return cached;
    await _clearPngFrames(output);
    final driver = RigDriver(blinkSeed: stableRigSeed(pet.descriptor.id));
    final idle = <File>[];
    final jumping = <File>[];
    for (var index = 0; index < maxOverlayIdleFrames; index++) {
      final elapsed = Duration(milliseconds: index * 125);
      final frame = driver.sample(
        action: RigPetAction.breathing,
        elapsed: elapsed,
      );
      idle.add(
        await _renderRigFrame(
          pet: pet,
          action: RigPetAction.breathing,
          frame: frame,
          file: File('${output.path}/idle_$index.png'),
        ),
      );
      if (idle.length >= 24 && frame.blinkClosed) break;
    }
    for (var index = 0; index < 8; index++) {
      jumping.add(
        await _renderRigFrame(
          pet: pet,
          action: RigPetAction.happyJump,
          frame: driver.sample(
            action: RigPetAction.happyJump,
            elapsed: Duration(milliseconds: index * 125),
          ),
          file: File('${output.path}/jumping_$index.png'),
        ),
      );
    }
    final result = BakedOverlayFrames(idleFiles: idle, jumpingFiles: jumping);
    await _writeCache(output, fingerprint, result);
    return result;
  }

  Future<BakedOverlayFrames> bakeAtlas(
    LoadedSpriteAtlas atlas, {
    String? contentFingerprint,
  }) async {
    final plan = buildOverlaySlicePlan(<String, Object?>{
      'atlas': <String, Object?>{
        'columns': atlas.definition.columns,
        'rows': atlas.definition.rows,
        'cell_width': atlas.definition.cellWidth,
        'cell_height': atlas.definition.cellHeight,
        'width': atlas.definition.imageWidth,
        'height': atlas.definition.imageHeight,
      },
      'rows': atlas.definition.sequences.values
          .map(
            (sequence) => <String, Object?>{
              'state': sequence.state,
              'row': sequence.row,
              'frames': sequence.frameCount,
            },
          )
          .toList(growable: false),
    });
    final output = await _outputDirectory(atlas.descriptor.id);
    final fingerprint =
        contentFingerprint ?? await _contentFingerprint(atlas.descriptor);
    final cached = await _cachedFrames(output, fingerprint);
    if (cached != null) return cached;
    await _clearPngFrames(output);
    final idle = <File>[];
    final jumping = <File>[];
    for (final slice in plan) {
      if (slice.width != overlayFrameWidth ||
          slice.height != overlayFrameHeight) {
        throw const FormatException(
          'Overlay atlas cells must use the 192x208 canvas.',
        );
      }
      final image = await _crop(atlas.image, slice);
      try {
        final file = await _writePng(
          image,
          File('${output.path}/${slice.state}_${slice.frame}.png'),
        );
        (slice.state == 'idle' ? idle : jumping).add(file);
      } finally {
        image.dispose();
      }
    }
    final result = BakedOverlayFrames(idleFiles: idle, jumpingFiles: jumping);
    await _writeCache(output, fingerprint, result);
    return result;
  }

  Future<String> _contentFingerprint(PetAssetDescriptor descriptor) async {
    final paths = descriptor.isRig
        ? <String>[
            descriptor.rig!.rigAsset,
            descriptor.rig!.frontOpenAsset,
            descriptor.rig!.frontClosedAsset,
            descriptor.rig!.sleepAsset,
            descriptor.rig!.sideAsset,
          ]
        : <String>[descriptor.metadataAsset, descriptor.spritesheetAsset];
    final parts = <String>[_overlayBakeSchema, descriptor.id];
    for (final path in paths) {
      if (path.startsWith('/')) {
        final stat = await File(path).stat();
        parts.add('$path:${stat.size}:${stat.modified.millisecondsSinceEpoch}');
      } else {
        parts.add(path);
      }
    }
    return parts.join('|');
  }

  Future<BakedOverlayFrames?> _cachedFrames(
    Directory output,
    String fingerprint,
  ) async {
    final manifest = File('${output.path}/bake-cache.json');
    if (!await manifest.exists()) return null;
    try {
      final json = jsonDecode(await manifest.readAsString());
      if (json is! Map<String, Object?> || json['fingerprint'] != fingerprint) {
        return null;
      }
      List<File>? files(String key) {
        final names = json[key];
        if (names is! List<Object?> ||
            names.isEmpty ||
            names.any((name) => name is! String)) {
          return null;
        }
        return names
            .cast<String>()
            .map((name) => File('${output.path}/$name'))
            .toList();
      }

      final idle = files('idle');
      final jumping = files('jumping');
      if (idle == null || jumping == null) return null;
      for (final file in <File>[...idle, ...jumping]) {
        if (!await file.exists()) return null;
      }
      return BakedOverlayFrames(idleFiles: idle, jumpingFiles: jumping);
    } on Object {
      return null;
    }
  }

  Future<void> _writeCache(
    Directory output,
    String fingerprint,
    BakedOverlayFrames frames,
  ) async {
    String name(File file) => file.uri.pathSegments.last;
    await File('${output.path}/bake-cache.json').writeAsString(
      jsonEncode(<String, Object?>{
        'fingerprint': fingerprint,
        'idle': frames.idleFiles.map(name).toList(growable: false),
        'jumping': frames.jumpingFiles.map(name).toList(growable: false),
      }),
      flush: true,
    );
  }

  Future<void> _clearPngFrames(Directory output) async {
    await for (final entity in output.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        await entity.delete();
      }
    }
  }

  Future<Directory> _outputDirectory(String petId) async {
    final root = await _supportDirectory();
    final output = Directory('${root.path}/overlay_frames/$petId');
    await output.create(recursive: true);
    return output;
  }

  Future<ui.Image> _crop(ui.Image atlas, OverlayFrameSlice slice) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawColor(const ui.Color(0x00000000), ui.BlendMode.src)
      ..drawImageRect(
        atlas,
        ui.Rect.fromLTWH(
          slice.left.toDouble(),
          slice.top.toDouble(),
          slice.width.toDouble(),
          slice.height.toDouble(),
        ),
        const ui.Rect.fromLTWH(0, 0, 192, 208),
        ui.Paint()
          ..isAntiAlias = false
          ..filterQuality = ui.FilterQuality.none,
      );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(overlayFrameWidth, overlayFrameHeight);
    } finally {
      picture.dispose();
    }
  }

  Future<File> _renderRigFrame({
    required LoadedRigPet pet,
    required RigPetAction action,
    required RigPoseFrame frame,
    required File file,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0x00000000), ui.BlendMode.src);
    paintRigPetFrame(
      canvas: canvas,
      size: const ui.Size(192, 208),
      pet: pet,
      action: action,
      frame: frame,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(overlayFrameWidth, overlayFrameHeight);
    picture.dispose();
    try {
      return await _writePng(image, file);
    } finally {
      image.dispose();
    }
  }

  Future<File> _writePng(ui.Image image, File file) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Overlay PNG encoding failed.');
    return file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }
}
