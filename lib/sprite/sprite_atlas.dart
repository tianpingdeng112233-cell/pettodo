import 'dart:convert';
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

class PetAssetDescriptor {
  const PetAssetDescriptor({
    required this.id,
    required this.displayName,
    required this.metadataAsset,
    required this.spritesheetAsset,
  });

  final String id;
  final String displayName;
  final String metadataAsset;
  final String spritesheetAsset;
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
          return PetAssetDescriptor(
            id: pet['id']! as String,
            displayName: pet['display_name']! as String,
            metadataAsset: pet['metadata']! as String,
            spritesheetAsset: pet['spritesheet']! as String,
          );
        })
        .toList(growable: false);
  }

  Future<SpriteAtlasDefinition> loadDefinition(String assetPath) async {
    final raw = jsonDecode(await _bundle.loadString(assetPath));
    return SpriteAtlasDefinition.fromJson(raw as Map<String, Object?>);
  }

  Future<LoadedSpriteAtlas> loadPet(PetAssetDescriptor descriptor) async {
    final definition = await loadDefinition(descriptor.metadataAsset);
    final bytes = await _bundle.load(descriptor.spritesheetAsset);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
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
}
