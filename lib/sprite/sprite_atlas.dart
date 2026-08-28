import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class FrameRect {
  const FrameRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  ui.Rect get uiRect => ui.Rect.fromLTWH(left, top, width, height);

  @override
  bool operator ==(Object other) =>
      other is FrameRect &&
      left == other.left &&
      top == other.top &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

class SpriteSequenceDefinition {
  const SpriteSequenceDefinition({
    required this.state,
    required this.row,
    required this.frameCount,
    required this.purpose,
  });

  final String state;
  final int row;
  final int frameCount;
  final String purpose;
}

class SpriteAtlasDefinition {
  SpriteAtlasDefinition({
    required this.petId,
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.imageWidth,
    required this.imageHeight,
    required Map<String, SpriteSequenceDefinition> sequences,
  }) : sequences = Map<String, SpriteSequenceDefinition>.unmodifiable(
         sequences,
       );

  factory SpriteAtlasDefinition.fromJson(Map<String, Object?> json) {
    final atlas = json['atlas']! as Map<String, Object?>;
    final rowEntries = json['rows']! as List<Object?>;
    final sequences = <String, SpriteSequenceDefinition>{};
    for (final raw in rowEntries) {
      final row = raw! as Map<String, Object?>;
      final sequence = SpriteSequenceDefinition(
        state: row['state']! as String,
        row: row['row']! as int,
        frameCount: row['frames']! as int,
        purpose: row['purpose']! as String,
      );
      sequences[sequence.state] = sequence;
    }
    final definition = SpriteAtlasDefinition(
      petId: json['pet_id']! as String,
      columns: atlas['columns']! as int,
      rows: atlas['rows']! as int,
      cellWidth: atlas['cell_width']! as int,
      cellHeight: atlas['cell_height']! as int,
      imageWidth: atlas['width']! as int,
      imageHeight: atlas['height']! as int,
      sequences: sequences,
    );
    definition._validate();
    return definition;
  }

  final String petId;
  final int columns;
  final int rows;
  final int cellWidth;
  final int cellHeight;
  final int imageWidth;
  final int imageHeight;
  final Map<String, SpriteSequenceDefinition> sequences;

  SpriteSequenceDefinition sequence(String state) {
    final value = sequences[state];
    if (value == null) throw ArgumentError.value(state, 'state');
    return value;
  }

  FrameRect frameRect(String state, int frame) {
    final sequenceDefinition = sequence(state);
    if (frame < 0 || frame >= sequenceDefinition.frameCount) {
      throw RangeError.range(frame, 0, sequenceDefinition.frameCount - 1);
    }
    return FrameRect(
      left: (frame * cellWidth).toDouble(),
      top: (sequenceDefinition.row * cellHeight).toDouble(),
      width: cellWidth.toDouble(),
      height: cellHeight.toDouble(),
    );
  }

  void _validate() {
    if (columns * cellWidth != imageWidth || rows * cellHeight != imageHeight) {
      throw const FormatException('Atlas dimensions do not match its grid.');
    }
    for (final sequence in sequences.values) {
      if (sequence.row < 0 ||
          sequence.row >= rows ||
          sequence.frameCount < 1 ||
          sequence.frameCount > columns) {
        throw FormatException('Invalid sequence ${sequence.state}.');
      }
    }
  }
}

enum PetAssetSource { bundled, fileSystem }

enum PetAssetFormat { atlasV2, rigV3 }

class RigAssetDescriptor {
  const RigAssetDescriptor({
    required this.species,
    required this.rigAsset,
    required this.frontOpenAsset,
    required this.frontClosedAsset,
    required this.sleepAsset,
    required this.sideAsset,
  });

  final String species;
  final String rigAsset;
  final String frontOpenAsset;
  final String frontClosedAsset;
  final String sleepAsset;
  final String sideAsset;

  RigAssetDescriptor copyWithRoot(String root) => RigAssetDescriptor(
    species: species,
    rigAsset: '$root/rig.json',
    frontOpenAsset: '$root/front-open.png',
    frontClosedAsset: '$root/front-closed.png',
    sleepAsset: '$root/sleep.png',
    sideAsset: '$root/side.png',
  );
}

class PetAssetDescriptor {
  const PetAssetDescriptor({
    required this.id,
    required this.displayName,
    required this.metadataAsset,
    required this.spritesheetAsset,
    this.treatName = 'Treat',
    this.treatEmoji = '🦴',
    this.stageAssets = const <String, PetStageAssetDescriptor>{},
    this.source = PetAssetSource.bundled,
    this.format = PetAssetFormat.atlasV2,
    this.rig,
  });

  final String id;
  final String displayName;
  final String metadataAsset;
  final String spritesheetAsset;
  final String treatName;
  final String treatEmoji;
  final Map<String, PetStageAssetDescriptor> stageAssets;
  final PetAssetSource source;
  final PetAssetFormat format;
  final RigAssetDescriptor? rig;

  bool get isRig => format == PetAssetFormat.rigV3;
  int get formatVersion => isRig ? 3 : 1;

  PetAssetDescriptor copyWith({
    String? metadataAsset,
    String? spritesheetAsset,
    RigAssetDescriptor? rig,
  }) => PetAssetDescriptor(
    id: id,
    displayName: displayName,
    metadataAsset: metadataAsset ?? this.metadataAsset,
    spritesheetAsset: spritesheetAsset ?? this.spritesheetAsset,
    treatName: treatName,
    treatEmoji: treatEmoji,
    stageAssets: stageAssets,
    source: source,
    format: format,
    rig: rig ?? this.rig,
  );

  PetStageAssetDescriptor assetsForStage(String? stage) =>
      stageAssets[stage] ??
      PetStageAssetDescriptor(
        metadataAsset: metadataAsset,
        spritesheetAsset: spritesheetAsset,
      );
}

class PetStageAssetDescriptor {
  const PetStageAssetDescriptor({
    required this.metadataAsset,
    required this.spritesheetAsset,
  });

  final String metadataAsset;
  final String spritesheetAsset;
}

class DecorAssetDescriptor {
  const DecorAssetDescriptor({
    required this.id,
    required this.displayName,
    required this.emoji,
    required this.slot,
  });

  final String id;
  final String displayName;
  final String emoji;
  final int slot;
}

class LoadedSpriteAtlas {
  const LoadedSpriteAtlas({
    required this.descriptor,
    required this.definition,
    required this.image,
  });

  final PetAssetDescriptor descriptor;
  final SpriteAtlasDefinition definition;
  final ui.Image image;
}

class SpriteAtlasLoader {
  SpriteAtlasLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<List<PetAssetDescriptor>> loadManifest() async {
    final raw =
        jsonDecode(await _bundle.loadString('assets/pets/manifest.json'))
            as Map<String, Object?>;
    return (raw['pets']! as List<Object?>)
        .map((entry) {
          final pet = entry! as Map<String, Object?>;
          final treat = pet['treat'] as Map<String, Object?>?;
          if (pet['format'] == 'rig') {
            final rig = RigAssetDescriptor(
              species: _requiredRigField(pet, 'species'),
              rigAsset: _requiredRigField(pet, 'rig'),
              frontOpenAsset: _requiredRigField(pet, 'front_open'),
              frontClosedAsset: _requiredRigField(pet, 'front_closed'),
              sleepAsset: _requiredRigField(pet, 'sleep'),
              sideAsset: _requiredRigField(pet, 'side'),
            );
            return PetAssetDescriptor(
              id: pet['id']! as String,
              displayName: pet['display_name']! as String,
              metadataAsset: rig.rigAsset,
              spritesheetAsset: rig.frontOpenAsset,
              treatName: treat?['name'] as String? ?? 'Treat',
              treatEmoji: treat?['emoji'] as String? ?? '🦴',
              source: PetAssetSource.bundled,
              format: PetAssetFormat.rigV3,
              rig: rig,
            );
          }
          final rawStages = pet['stages'] as Map<String, Object?>?;
          return PetAssetDescriptor(
            id: pet['id']! as String,
            displayName: pet['display_name']! as String,
            metadataAsset: pet['metadata']! as String,
            spritesheetAsset: pet['spritesheet']! as String,
            treatName: treat?['name'] as String? ?? 'Treat',
            treatEmoji: treat?['emoji'] as String? ?? '🦴',
            stageAssets:
                rawStages?.map((key, value) {
                  final assets = value! as Map<String, Object?>;
                  return MapEntry(
                    key,
                    PetStageAssetDescriptor(
                      metadataAsset: assets['metadata']! as String,
                      spritesheetAsset: assets['spritesheet']! as String,
                    ),
                  );
                }) ??
                const <String, PetStageAssetDescriptor>{},
          );
        })
        .toList(growable: false);
  }

  Future<List<DecorAssetDescriptor>> loadDecorManifest() async {
    final raw =
        jsonDecode(await _bundle.loadString('assets/pets/manifest.json'))
            as Map<String, Object?>;
    return (raw['decor'] as List<Object?>? ?? const <Object?>[])
        .map((entry) {
          final decor = entry! as Map<String, Object?>;
          return DecorAssetDescriptor(
            id: decor['id']! as String,
            displayName: decor['display_name']! as String,
            emoji: decor['emoji']! as String,
            slot: decor['slot']! as int,
          );
        })
        .toList(growable: false);
  }

  Future<SpriteAtlasDefinition> loadDefinition(String assetPath) async {
    final raw = jsonDecode(await _readString(assetPath));
    return SpriteAtlasDefinition.fromJson(raw as Map<String, Object?>);
  }

  Future<LoadedSpriteAtlas> loadPet(
    PetAssetDescriptor descriptor, {
    String? growthStage,
  }) async {
    final assets = descriptor.assetsForStage(growthStage);
    final definition = await loadDefinition(assets.metadataAsset);
    final bytes = await _readBytes(assets.spritesheetAsset);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (frame.image.width != definition.imageWidth ||
        frame.image.height != definition.imageHeight) {
      frame.image.dispose();
      throw const FormatException(
        'Decoded image does not match atlas metadata.',
      );
    }
    return LoadedSpriteAtlas(
      descriptor: descriptor,
      definition: definition,
      image: frame.image,
    );
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

String _requiredRigField(Map<String, Object?> pet, String field) {
  final value = pet[field];
  if (value is String && value.isNotEmpty) return value;
  final id = pet['id'] is String ? pet['id'] as String : '<unknown>';
  throw FormatException('Rig pet $id is missing $field.');
}
