import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../sprite/rig_definition.dart';
import '../sprite/sprite_atlas.dart';

class PetPackException implements Exception {
  const PetPackException([this.message = 'This pack does not fit.']);

  final String message;

  @override
  String toString() => message;
}

class ValidatedPetPack {
  const ValidatedPetPack({
    required this.descriptor,
    required this.requestId,
    required this.files,
  });

  final PetAssetDescriptor descriptor;
  final String? requestId;
  final Map<String, Uint8List> files;
}

class InstalledPetPack {
  const InstalledPetPack({required this.descriptor, required this.requestId});

  final PetAssetDescriptor descriptor;
  final String? requestId;
}

class PetPackService {
  PetPackService(this._documentsProvider);

  factory PetPackService.onDevice() =>
      PetPackService(getApplicationDocumentsDirectory);

  final Future<Directory> Function() _documentsProvider;

  Future<ValidatedPetPack> validate(File source) async {
    try {
      final decoded = ZipDecoder().decodeBytes(await source.readAsBytes());
      final files = <String, Uint8List>{};
      var hasNestedFile = false;
      for (final entry in decoded.files) {
        if (!entry.isFile) continue;
        if (entry.name.contains('/') || entry.name.contains(r'\')) {
          hasNestedFile = true;
          continue;
        }
        final content = entry.content;
        if (content is List<int>) {
          files[entry.name] = Uint8List.fromList(content);
        }
      }
      if (!files.containsKey('pack.json')) {
        throw const PetPackException('A required file is missing.');
      }
      final pack = jsonDecode(utf8.decode(files['pack.json']!));
      if (pack is! Map<String, Object?>) {
        throw const PetPackException('The pack format is not supported.');
      }
      // await inside the try — returning the bare future would let a
      // downstream FormatException escape the PetPackException wrapper
      return await switch (pack['formatVersion']) {
        1 => _validateAtlasPack(pack, files),
        3 => _validateRigPack(pack, files, hasNestedFile: hasNestedFile),
        _ => throw const PetPackException('The pack format is not supported.'),
      };
    } on PetPackException {
      rethrow;
    } on Object {
      throw const PetPackException();
    }
  }

  Future<ValidatedPetPack> _validateAtlasPack(
    Map<String, Object?> pack,
    Map<String, Uint8List> files,
  ) async {
    const required = <String>{
      'pack.json',
      'pet_request.json',
      'spritesheet-extended.webp',
    };
    if (!files.keys.toSet().containsAll(required)) {
      throw const PetPackException('A required file is missing.');
    }
    final id = pack['id'];
    final displayName = pack['display_name'];
    final treat = pack['treat'];
    if (id is! String || !RegExp(r'^[a-z0-9_-]+$').hasMatch(id)) {
      throw const PetPackException('The pet id is not valid.');
    }
    if (displayName is! String || displayName.trim().isEmpty) {
      throw const PetPackException('The pet name is missing.');
    }
    if (treat is! Map<String, Object?> ||
        treat['name'] is! String ||
        (treat['name']! as String).trim().isEmpty ||
        treat['emoji'] is! String ||
        (treat['emoji']! as String).trim().isEmpty) {
      throw const PetPackException('The pet treat is not valid.');
    }
    final metadata = jsonDecode(utf8.decode(files['pet_request.json']!));
    if (metadata is! Map<String, Object?>) {
      throw const PetPackException('The atlas metadata is not valid.');
    }
    final definition = SpriteAtlasDefinition.fromJson(metadata);
    if (definition.columns != 8 ||
        definition.rows != 11 ||
        definition.cellWidth != 192 ||
        definition.cellHeight != 208) {
      throw const PetPackException('The atlas grid is not supported.');
    }
    final codec = await ui.instantiateImageCodec(
      files['spritesheet-extended.webp']!,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final dimensionsMatch =
        frame.image.width == definition.imageWidth &&
        frame.image.height == definition.imageHeight;
    frame.image.dispose();
    if (!dimensionsMatch) {
      throw const PetPackException(
        'The spritesheet does not match its metadata.',
      );
    }
    return ValidatedPetPack(
      descriptor: PetAssetDescriptor(
        id: id,
        displayName: displayName.trim(),
        metadataAsset: 'pet_request.json',
        spritesheetAsset: 'spritesheet-extended.webp',
        treatName: (treat['name']! as String).trim(),
        treatEmoji: (treat['emoji']! as String).trim(),
        source: PetAssetSource.fileSystem,
      ),
      requestId:
          (pack['requestId'] as String?) ?? (metadata['request_id'] as String?),
      files: {for (final name in required) name: files[name]!},
    );
  }

  Future<ValidatedPetPack> _validateRigPack(
    Map<String, Object?> pack,
    Map<String, Uint8List> files, {
    required bool hasNestedFile,
  }) async {
    const required = <String>{
      'pack.json',
      'front-open.png',
      'front-closed.png',
      'sleep.png',
      'rig.json',
    };
    if (hasNestedFile || !files.keys.toSet().containsAll(required)) {
      throw const PetPackException('A required file is missing.');
    }
    final id = pack['id'];
    final displayName = pack['display_name'];
    final species = pack['species'];
    final treat = pack['treat'];
    if (id is! String || !RegExp(r'^[a-z0-9_-]+$').hasMatch(id)) {
      throw const PetPackException('The pet id is not valid.');
    }
    if (displayName is! String || displayName.trim().isEmpty) {
      throw const PetPackException('The pet name is missing.');
    }
    if (species != 'cat' && species != 'dog') {
      throw const PetPackException('The pet species is not supported.');
    }
    if (treat is! Map<String, Object?> ||
        treat['name'] is! String ||
        (treat['name']! as String).trim().isEmpty ||
        treat['emoji'] is! String ||
        (treat['emoji']! as String).trim().isEmpty) {
      throw const PetPackException('The pet treat is not valid.');
    }
    final rig = RigDefinition.fromJson(
      jsonDecode(utf8.decode(files['rig.json']!)),
    );
    final hasSideImage = files.containsKey('side.png');
    final hasSideRig = rig.side != null;
    if (hasSideImage != hasSideRig) {
      throw const PetPackException(
        'The side pose image and rig section must be provided together.',
      );
    }
    for (final name in <String>[
      'front-open.png',
      'front-closed.png',
      'sleep.png',
      if (hasSideImage) 'side.png',
    ]) {
      if (!_isRgbaPng(files[name]!)) {
        throw const PetPackException('A pose image is not an RGBA PNG.');
      }
    }
    final frontOpenSize = await _validateSprite(files['front-open.png']!);
    final frontClosedSize = await _validateSprite(files['front-closed.png']!);
    if (frontOpenSize != frontClosedSize) {
      throw const PetPackException(
        'The front pose images must use the same canvas.',
      );
    }
    final sideSize = hasSideImage
        ? await _validateSprite(files['side.png']!)
        : null;
    await _validateSprite(files['sleep.png']!);
    rig.front.validateForImage(frontOpenSize.$1, frontOpenSize.$2);
    if (sideSize != null) {
      rig.side!.validateForImage(sideSize.$1, sideSize.$2);
    }
    return ValidatedPetPack(
      descriptor: PetAssetDescriptor(
        id: id,
        displayName: displayName.trim(),
        metadataAsset: 'rig.json',
        spritesheetAsset: 'front-open.png',
        treatName: (treat['name']! as String).trim(),
        treatEmoji: (treat['emoji']! as String).trim(),
        source: PetAssetSource.fileSystem,
        format: PetAssetFormat.rigV3,
        rig: RigAssetDescriptor(
          species: species as String,
          rigAsset: 'rig.json',
          frontOpenAsset: 'front-open.png',
          frontClosedAsset: 'front-closed.png',
          sleepAsset: 'sleep.png',
          sideAsset: hasSideImage ? 'side.png' : null,
        ),
      ),
      requestId: null,
      files: {
        for (final name in <String>[...required, if (hasSideImage) 'side.png'])
          name: files[name]!,
      },
    );
  }

  static Future<(int, int)> _validateSprite(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame;
    try {
      frame = await codec.getNextFrame();
    } finally {
      codec.dispose();
    }
    final image = frame.image;
    try {
      final data = await image.toByteData();
      if (data == null) {
        throw const PetPackException('A pose image could not be read.');
      }
      // the v3 contract requires a de-backgrounded sprite: an image with an
      // alpha channel but a fully opaque canvas is not acceptable
      var transparentBorder = 0;
      var borderSamples = 0;
      for (var x = 0; x < image.width; x++) {
        for (final y in <int>[0, image.height - 1]) {
          borderSamples++;
          if (data.getUint8((y * image.width + x) * 4 + 3) == 0) {
            transparentBorder++;
          }
        }
      }
      for (var y = 0; y < image.height; y++) {
        for (final x in <int>[0, image.width - 1]) {
          borderSamples++;
          if (data.getUint8((y * image.width + x) * 4 + 3) == 0) {
            transparentBorder++;
          }
        }
      }
      if (transparentBorder < borderSamples * 0.5) {
        throw const PetPackException(
          'A pose image does not have a transparent background.',
        );
      }
      return (image.width, image.height);
    } finally {
      image.dispose();
    }
  }

  static bool _isRgbaPng(Uint8List bytes) {
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 26) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return bytes[25] == 6;
  }

  Future<InstalledPetPack> install(File source) async {
    final validated = await validate(source);
    final documents = await _documentsProvider();
    final petsDirectory = Directory('${documents.path}/pets');
    await petsDirectory.create(recursive: true);
    final id = validated.descriptor.id;
    final destination = Directory('${petsDirectory.path}/$id');
    final staging = Directory('${petsDirectory.path}/.$id-installing');
    final backup = Directory('${petsDirectory.path}/.$id-backup');
    if (await staging.exists()) await staging.delete(recursive: true);
    if (await backup.exists()) await backup.delete(recursive: true);
    await staging.create();
    try {
      for (final entry in validated.files.entries) {
        await File(
          '${staging.path}/${entry.key}',
        ).writeAsBytes(entry.value, flush: true);
      }
      if (await destination.exists()) await destination.rename(backup.path);
      await staging.rename(destination.path);
      if (await backup.exists()) await backup.delete(recursive: true);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      if (!await destination.exists() && await backup.exists()) {
        await backup.rename(destination.path);
      }
      rethrow;
    }
    final descriptor = validated.descriptor;
    return InstalledPetPack(
      descriptor: descriptor.isRig
          ? descriptor.copyWith(
              metadataAsset: '${destination.path}/rig.json',
              spritesheetAsset: '${destination.path}/front-open.png',
              rig: descriptor.rig!.copyWithRoot(destination.path),
            )
          : descriptor.copyWith(
              metadataAsset: '${destination.path}/pet_request.json',
              spritesheetAsset: '${destination.path}/spritesheet-extended.webp',
            ),
      requestId: validated.requestId,
    );
  }

  Future<List<PetAssetDescriptor>> loadInstalledPets() async {
    final documents = await _documentsProvider();
    final root = Directory('${documents.path}/pets');
    if (!await root.exists()) return const <PetAssetDescriptor>[];
    final pets = <PetAssetDescriptor>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory || entity.path.split('/').last.startsWith('.')) {
        continue;
      }
      final packFile = File('${entity.path}/pack.json');
      try {
        final pack = jsonDecode(await packFile.readAsString());
        if (pack is! Map<String, Object?>) {
          continue;
        }
        final id = pack['id'];
        final displayName = pack['display_name'];
        final treat = pack['treat'];
        if (id is! String ||
            !RegExp(r'^[a-z0-9_-]+$').hasMatch(id) ||
            displayName is! String ||
            treat is! Map<String, Object?> ||
            treat['name'] is! String ||
            treat['emoji'] is! String) {
          continue;
        }
        switch (pack['formatVersion']) {
          case 1:
            final metadataFile = File('${entity.path}/pet_request.json');
            final spritesheetFile = File(
              '${entity.path}/spritesheet-extended.webp',
            );
            if (!await metadataFile.exists() ||
                !await spritesheetFile.exists()) {
              continue;
            }
            pets.add(
              PetAssetDescriptor(
                id: id,
                displayName: displayName,
                metadataAsset: metadataFile.path,
                spritesheetAsset: spritesheetFile.path,
                treatName: treat['name']! as String,
                treatEmoji: treat['emoji']! as String,
                source: PetAssetSource.fileSystem,
              ),
            );
            continue;
          case 3:
            final species = pack['species'];
            if (species != 'cat' && species != 'dog') continue;
            final rigAssets = RigAssetDescriptor(
              species: species! as String,
              rigAsset: '${entity.path}/rig.json',
              frontOpenAsset: '${entity.path}/front-open.png',
              frontClosedAsset: '${entity.path}/front-closed.png',
              sleepAsset: '${entity.path}/sleep.png',
              sideAsset: await File('${entity.path}/side.png').exists()
                  ? '${entity.path}/side.png'
                  : null,
            );
            final requiredFiles = <String>[
              rigAssets.rigAsset,
              rigAssets.frontOpenAsset,
              rigAssets.frontClosedAsset,
              rigAssets.sleepAsset,
              ?rigAssets.sideAsset,
            ];
            var allExist = true;
            for (final path in requiredFiles) {
              if (!await File(path).exists()) {
                allExist = false;
                break;
              }
            }
            if (!allExist) continue;
            final definition = RigDefinition.fromJson(
              jsonDecode(await File(rigAssets.rigAsset).readAsString()),
            );
            if ((rigAssets.sideAsset != null) != (definition.side != null)) {
              continue;
            }
            pets.add(
              PetAssetDescriptor(
                id: id,
                displayName: displayName,
                metadataAsset: rigAssets.rigAsset,
                spritesheetAsset: rigAssets.frontOpenAsset,
                treatName: treat['name']! as String,
                treatEmoji: treat['emoji']! as String,
                source: PetAssetSource.fileSystem,
                format: PetAssetFormat.rigV3,
                rig: rigAssets,
              ),
            );
            continue;
          default:
            continue;
        }
      } on Object {
        continue;
      }
    }
    // directory enumeration order is filesystem-dependent; without a sort the
    // Collection would reshuffle between launches
    pets.sort((a, b) => a.id.compareTo(b.id));
    return pets;
  }
}

List<PetAssetDescriptor> mergePetRegistry(
  List<PetAssetDescriptor> bundled,
  List<PetAssetDescriptor> installed,
) {
  final merged = <String, PetAssetDescriptor>{
    for (final pet in bundled) pet.id: pet,
    for (final pet in installed) pet.id: pet,
  };
  return merged.values.toList(growable: false);
}
