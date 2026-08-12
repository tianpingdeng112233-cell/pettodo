import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

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
      for (final entry in decoded.files) {
        if (!entry.isFile) continue;
        if (entry.name.contains('/') || entry.name.contains(r'\')) continue;
        final content = entry.content;
        if (content is List<int>) {
          files[entry.name] = Uint8List.fromList(content);
        }
      }
      const required = <String>{
        'pack.json',
        'pet_request.json',
        'spritesheet-extended.webp',
      };
      if (!files.keys.toSet().containsAll(required)) {
        throw const PetPackException('A required file is missing.');
      }
      final pack = jsonDecode(utf8.decode(files['pack.json']!));
      if (pack is! Map<String, Object?> || pack['formatVersion'] != 1) {
        throw const PetPackException('The pack format is not supported.');
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
            (pack['requestId'] as String?) ??
            (metadata['request_id'] as String?),
        files: {for (final name in required) name: files[name]!},
      );
    } on PetPackException {
      rethrow;
    } on Object {
      throw const PetPackException();
    }
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
    return InstalledPetPack(
      descriptor: validated.descriptor.copyWith(
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
      final metadataFile = File('${entity.path}/pet_request.json');
      final spritesheetFile = File('${entity.path}/spritesheet-extended.webp');
      try {
        final pack = jsonDecode(await packFile.readAsString());
        if (pack is! Map<String, Object?> || pack['formatVersion'] != 1) {
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
            treat['emoji'] is! String ||
            !await metadataFile.exists() ||
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
      } on Object {
        continue;
      }
    }
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
