import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(Map<String, List<int>> assets)
    : _assets = <String, Uint8List>{
        for (final entry in assets.entries)
          entry.key: Uint8List.fromList(entry.value),
      };

  factory _MemoryAssetBundle.withStrings(Map<String, String> assets) =>
      _MemoryAssetBundle(<String, List<int>>{
        for (final entry in assets.entries) entry.key: utf8.encode(entry.value),
      });

  final Map<String, Uint8List> _assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = _assets[key];
    if (bytes == null) throw StateError('Missing test asset: $key');
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frame rectangles come from bundled pet_request metadata', () async {
    final loader = SpriteAtlasLoader(bundle: rootBundle);
    // choco ships as a rig pet since 015-E; its retained v2 atlas metadata
    // still exercises the atlas definition parser
    final atlas = await loader.loadDefinition(
      'assets/pets/choco/pet_request.json',
    );

    expect(atlas.columns, 8);
    expect(atlas.rows, 11);
    expect(atlas.sequence('idle').frameCount, 6);
    expect(
      atlas.frameRect('jumping', 4),
      const FrameRect(left: 768, top: 832, width: 192, height: 208),
    );
    expect(
      atlas.frameRect('review', 5),
      const FrameRect(left: 960, top: 1664, width: 192, height: 208),
    );
  });

  test('bundled manifest contains the complete preset roster', () async {
    final pets = await SpriteAtlasLoader(bundle: rootBundle).loadManifest();

    expect(pets.map((pet) => pet.id), <String>[
      'choco',
      'shiba',
      'golden',
      'corgi',
      'husky',
      'tabby',
      'blackcat',
      'ragdoll',
    ]);
    final expected = <String, (String, String, String, String)>{
      'shiba': ('Shiba', 'dog', 'Little Bone', '🦴'),
      'golden': ('Goldie', 'dog', 'Little Bone', '🦴'),
      'corgi': ('Corgi', 'dog', 'Little Bone', '🦴'),
      'husky': ('Husky', 'dog', 'Little Bone', '🦴'),
      'tabby': ('Tangerine', 'cat', 'Little Fish', '🐟'),
      'blackcat': ('Ink', 'cat', 'Little Fish', '🐟'),
      'ragdoll': ('Mochi', 'cat', 'Little Fish', '🐟'),
    };
    for (final entry in expected.entries) {
      final pet = pets.singleWhere((candidate) => candidate.id == entry.key);
      final root = 'assets/pets/${entry.key}';
      expect(pet.displayName, entry.value.$1, reason: entry.key);
      expect(pet.format, PetAssetFormat.rigV3, reason: entry.key);
      expect(pet.source, PetAssetSource.bundled, reason: entry.key);
      expect(pet.rig?.species, entry.value.$2, reason: entry.key);
      expect(pet.treatName, entry.value.$3, reason: entry.key);
      expect(pet.treatEmoji, entry.value.$4, reason: entry.key);
      expect(pet.metadataAsset, '$root/rig.json', reason: entry.key);
      expect(pet.spritesheetAsset, '$root/front-open.png', reason: entry.key);
      expect(pet.rig?.rigAsset, '$root/rig.json', reason: entry.key);
      expect(
        pet.rig?.frontOpenAsset,
        '$root/front-open.png',
        reason: entry.key,
      );
      expect(
        pet.rig?.frontClosedAsset,
        '$root/front-closed.png',
        reason: entry.key,
      );
      expect(pet.rig?.sleepAsset, '$root/sleep.png', reason: entry.key);
      expect(
        pet.rig?.sideAsset,
        entry.key == 'choco' ? isNull : '$root/side.png',
        reason: entry.key,
      );
    }
  });

  test('manifest parses a bundled rig pet descriptor', () async {
    final bundle = _MemoryAssetBundle.withStrings(<String, String>{
      'assets/pets/manifest.json': jsonEncode(<String, Object?>{
        'pets': <Object?>[
          <String, Object?>{
            'id': 'shiba',
            'display_name': 'Shiba',
            'format': 'rig',
            'species': 'dog',
            'treat': <String, Object?>{'name': 'Little Bone', 'emoji': '🦴'},
            'rig': 'assets/pets/shiba/rig.json',
            'front_open': 'assets/pets/shiba/front-open.png',
            'front_closed': 'assets/pets/shiba/front-closed.png',
            'sleep': 'assets/pets/shiba/sleep.png',
            'side': 'assets/pets/shiba/side.png',
          },
        ],
      }),
    });

    final pets = await SpriteAtlasLoader(bundle: bundle).loadManifest();

    expect(pets, hasLength(1));
    final shiba = pets.single;
    expect(shiba.id, 'shiba');
    expect(shiba.displayName, 'Shiba');
    expect(shiba.format, PetAssetFormat.rigV3);
    expect(shiba.source, PetAssetSource.bundled);
    expect(shiba.treatName, 'Little Bone');
    expect(shiba.treatEmoji, '🦴');
    expect(shiba.metadataAsset, 'assets/pets/shiba/rig.json');
    expect(shiba.spritesheetAsset, 'assets/pets/shiba/front-open.png');
    expect(shiba.rig?.species, 'dog');
    expect(shiba.rig?.rigAsset, 'assets/pets/shiba/rig.json');
    expect(shiba.rig?.frontOpenAsset, 'assets/pets/shiba/front-open.png');
    expect(shiba.rig?.frontClosedAsset, 'assets/pets/shiba/front-closed.png');
    expect(shiba.rig?.sleepAsset, 'assets/pets/shiba/sleep.png');
    expect(shiba.rig?.sideAsset, 'assets/pets/shiba/side.png');
  });

  test('manifest parses a bundled rig pet without a side asset', () async {
    final bundle = _MemoryAssetBundle.withStrings(<String, String>{
      'assets/pets/manifest.json': jsonEncode(<String, Object?>{
        'pets': <Object?>[
          <String, Object?>{
            'id': 'choco',
            'display_name': 'Choco',
            'format': 'rig',
            'species': 'dog',
            'rig': 'assets/pets/choco/rig.json',
            'front_open': 'assets/pets/choco/front-open.png',
            'front_closed': 'assets/pets/choco/front-closed.png',
            'sleep': 'assets/pets/choco/sleep.png',
          },
        ],
      }),
    });

    final pets = await SpriteAtlasLoader(bundle: bundle).loadManifest();

    expect(pets.single.rig?.sideAsset, isNull);
  });

  test('manifest still rejects a rig pet missing a required asset', () async {
    final bundle = _MemoryAssetBundle.withStrings(<String, String>{
      'assets/pets/manifest.json': jsonEncode(<String, Object?>{
        'pets': <Object?>[
          <String, Object?>{
            'id': 'shiba',
            'display_name': 'Shiba',
            'format': 'rig',
            'species': 'dog',
            'rig': 'assets/pets/shiba/rig.json',
            'front_open': 'assets/pets/shiba/front-open.png',
            'front_closed': 'assets/pets/shiba/front-closed.png',
          },
        ],
      }),
    });

    expect(
      () => SpriteAtlasLoader(bundle: bundle).loadManifest(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('sleep'),
        ),
      ),
    );
  });
}
