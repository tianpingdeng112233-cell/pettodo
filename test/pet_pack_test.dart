import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/hatch_request_store.dart';
import 'package:pettodo/data/pet_pack_service.dart';
import 'package:pettodo/sprite/rig_pet.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporary;
  late Uint8List metadataBytes;
  late Uint8List spritesheetBytes;
  late Uint8List poseBytes;

  setUp(() async {
    temporary = Directory.systemTemp.createTempSync('pettodo-pack-test');
    metadataBytes = (await rootBundle.load(
      'assets/pets/choco/pet_request.json',
    )).buffer.asUint8List();
    spritesheetBytes = (await rootBundle.load(
      'assets/pets/choco/spritesheet-extended.webp',
    )).buffer.asUint8List();
    poseBytes = await _makePosePng();
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  test('pack validation rejects a missing required file', () async {
    final service = PetPackService(() async => temporary);
    final pack = _writePack(
      temporary,
      metadataBytes: metadataBytes,
      spritesheetBytes: spritesheetBytes,
      includeSpritesheet: false,
    );
    expect(service.validate(pack), throwsA(isA<PetPackException>()));
  });

  test('pack validation rejects an unsupported grid', () async {
    final metadata =
        jsonDecode(utf8.decode(metadataBytes)) as Map<String, Object?>;
    final atlas = metadata['atlas']! as Map<String, Object?>;
    atlas['columns'] = 7;
    atlas['width'] = 1344;
    final service = PetPackService(() async => temporary);
    final pack = _writePack(
      temporary,
      metadataBytes: Uint8List.fromList(utf8.encode(jsonEncode(metadata))),
      spritesheetBytes: spritesheetBytes,
    );
    expect(service.validate(pack), throwsA(isA<PetPackException>()));
  });

  test('pack validation rejects an unsafe id', () async {
    final service = PetPackService(() async => temporary);
    final pack = _writePack(
      temporary,
      id: '../choco2',
      metadataBytes: metadataBytes,
      spritesheetBytes: spritesheetBytes,
    );
    expect(service.validate(pack), throwsA(isA<PetPackException>()));
  });

  test('pack validation rejects a decoded dimension mismatch', () async {
    final service = PetPackService(() async => temporary);
    final tinyImage = Uint8List.fromList(<int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
      0x00,
      0x00,
      0x0d,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1f,
      0x15,
      0xc4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0d,
      0x49,
      0x44,
      0x41,
      0x54,
      0x08,
      0xd7,
      0x63,
      0xf8,
      0xcf,
      0xc0,
      0xf0,
      0x1f,
      0x00,
      0x05,
      0x00,
      0x01,
      0xff,
      0x89,
      0x99,
      0x3d,
      0x1d,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4e,
      0x44,
      0xae,
      0x42,
      0x60,
      0x82,
    ]);
    final pack = _writePack(
      temporary,
      metadataBytes: metadataBytes,
      spritesheetBytes: tinyImage,
    );
    expect(service.validate(pack), throwsA(isA<PetPackException>()));
  });

  test('same-id install replaces the existing pack', () async {
    final service = PetPackService(() async => temporary);
    final first = _writePack(
      temporary,
      displayName: 'First Choco',
      metadataBytes: metadataBytes,
      spritesheetBytes: spritesheetBytes,
    );
    await service.install(first);
    final second = _writePack(
      temporary,
      displayName: 'Second Choco',
      metadataBytes: metadataBytes,
      spritesheetBytes: spritesheetBytes,
    );
    final installed = await service.install(second);

    expect(installed.descriptor.id, 'choco2');
    final persisted =
        jsonDecode(
              File(
                '${temporary.path}/pets/choco2/pack.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    expect(persisted['display_name'], 'Second Choco');
    expect(
      Directory('${temporary.path}/pets').listSync().whereType<Directory>().map(
        (item) => item.path.split('/').last,
      ),
      <String>['choco2'],
    );
  });

  test(
    'rig pack validates, installs, and reloads through the v3 route',
    () async {
      final service = PetPackService(() async => temporary);
      final pack = _writeRigPack(temporary, poseBytes: poseBytes);

      final validated = await service.validate(pack);
      expect(validated.descriptor.format, PetAssetFormat.rigV3);
      expect(validated.descriptor.rig?.species, 'dog');
      expect(
        validated.files.keys,
        containsAll(<String>[
          'pack.json',
          'rig.json',
          'front-open.png',
          'front-closed.png',
          'sleep.png',
          'side.png',
        ]),
      );

      final installed = await service.install(pack);
      expect(
        installed.descriptor.rig?.rigAsset,
        endsWith('/pets/pip/rig.json'),
      );
      final loaded = await service.loadInstalledPets();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'pip');
      expect(loaded.single.isRig, isTrue);
    },
  );

  test(
    'rig pack rejects unsupported species and invalid coordinates',
    () async {
      final service = PetPackService(() async => temporary);
      final unsupported = _writeRigPack(
        temporary,
        poseBytes: poseBytes,
        species: 'rabbit',
        fileName: 'unsupported',
      );
      final invalidRig = _rigJson();
      final front = invalidRig['front']! as Map<String, Object?>;
      final boxes = front['boxes']! as Map<String, Object?>;
      boxes['tail'] = <int>[62, 24, 50, 50];
      final invalid = _writeRigPack(
        temporary,
        poseBytes: poseBytes,
        rig: invalidRig,
        fileName: 'invalid-rig',
      );

      expect(service.validate(unsupported), throwsA(isA<PetPackException>()));
      expect(service.validate(invalid), throwsA(isA<PetPackException>()));
    },
  );

  test('rig pack accepts missing side image and rig section', () async {
    final service = PetPackService(() async => temporary);
    final sidelessRig = _rigJson()..remove('side');
    final sideless = _writeRigPack(
      temporary,
      poseBytes: poseBytes,
      rig: sidelessRig,
      includeSide: false,
      fileName: 'sideless',
    );

    final validated = await service.validate(sideless);

    expect(validated.descriptor.rig?.sideAsset, isNull);
    expect(validated.files, isNot(contains('side.png')));

    final installed = await service.install(sideless);
    expect(installed.descriptor.rig?.sideAsset, isNull);
    final reloaded = await service.loadInstalledPets();
    expect(reloaded.single.rig?.sideAsset, isNull);
  });

  test('rig pack rejects an unpaired side image or rig section', () async {
    final service = PetPackService(() async => temporary);
    final sidelessRig = _rigJson()..remove('side');
    final imageOnly = _writeRigPack(
      temporary,
      poseBytes: poseBytes,
      rig: sidelessRig,
      fileName: 'image-only-side',
    );
    final rigOnly = _writeRigPack(
      temporary,
      poseBytes: poseBytes,
      includeSide: false,
      fileName: 'rig-only-side',
    );

    expect(service.validate(imageOnly), throwsA(isA<PetPackException>()));
    expect(service.validate(rigOnly), throwsA(isA<PetPackException>()));
  });

  test('rig pack still rejects another missing required pose file', () async {
    final service = PetPackService(() async => temporary);
    final missingSleep = _writeRigPack(
      temporary,
      poseBytes: poseBytes,
      includeSleep: false,
      fileName: 'missing-sleep',
    );

    expect(service.validate(missingSleep), throwsA(isA<PetPackException>()));
  });

  test('rig pack rejects directory-prefixed entries', () async {
    final service = PetPackService(() async => temporary);
    final nested = _writeRigPack(
      temporary,
      poseBytes: poseBytes,
      includeNestedEntry: true,
      fileName: 'nested-entry',
    );

    expect(service.validate(nested), throwsA(isA<PetPackException>()));
  });

  test(
    'rig loader precomposes front, closed-head, body, tail, and side legs',
    () async {
      final service = PetPackService(() async => temporary);
      final installed = await service.install(
        _writeRigPack(temporary, poseBytes: poseBytes),
      );

      final pet = await RigPetLoader().load(installed.descriptor);
      addTearDown(pet.dispose);
      expect(pet.frontLayers.body.width, 64);
      expect(pet.frontLayers.closedHead, isNotNull);
      expect(pet.frontLayers.tail?.height, 64);
      expect(pet.sideLayers?.frontLeg, isNotNull);
      expect(pet.sideLayers?.hindLeg, isNotNull);
    },
  );

  test(
    'rig loader degrades an ears-only front head box to full-pose blinking',
    () async {
      final rig = _rigJson();
      final front = rig['front']! as Map<String, Object?>;
      final boxes = front['boxes']! as Map<String, Object?>;
      boxes['head'] = <int>[18, 0, 46, 12];
      final service = PetPackService(() async => temporary);
      final installed = await service.install(
        _writeRigPack(temporary, poseBytes: poseBytes, rig: rig),
      );

      final pet = await RigPetLoader().load(installed.descriptor);
      addTearDown(pet.dispose);
      expect(pet.definition.front.head, isNull);
      expect(pet.frontLayers.head, isNull);
      expect(pet.frontLayers.tail, isNull);
      expect(pet.frontLayers.closedBody, isNotNull);
      expect(pet.frontLayers.body.width, 64);
    },
  );

  test('rig loader accepts a producer-null front head box', () async {
    final rig = _rigJson();
    final front = rig['front']! as Map<String, Object?>;
    final boxes = front['boxes']! as Map<String, Object?>;
    final pivots = front['pivots']! as Map<String, Object?>;
    boxes['head'] = null;
    pivots['head'] = null;
    final service = PetPackService(() async => temporary);
    final installed = await service.install(
      _writeRigPack(
        temporary,
        poseBytes: poseBytes,
        rig: rig,
        fileName: 'headless-rig',
      ),
    );

    final pet = await RigPetLoader().load(installed.descriptor);
    addTearDown(pet.dispose);
    expect(pet.definition.front.head, isNull);
    expect(pet.frontLayers.closedBody, isNotNull);
  });

  test('rig loader pre-downscales large composed layers once', () async {
    final largePose = await _makeLargePosePng();
    final service = PetPackService(() async => temporary);
    final installed = await service.install(
      _writeRigPack(
        temporary,
        poseBytes: largePose,
        rig: _largeRigJson(),
        fileName: 'large-rig',
      ),
    );

    final pet = await RigPetLoader().load(installed.descriptor);
    addTearDown(pet.dispose);
    expect(pet.frontWidth, 768);
    expect(pet.frontHeight, 1152);
    expect(pet.frontLayers.body.width, lessThanOrEqualTo(192));
    expect(pet.frontLayers.body.height, lessThanOrEqualTo(208));
    expect(pet.frontLayers.body.width, lessThan(pet.frontWidth));
  });

  test(
    'v2 and rig pets load together and registry replacement stays last-wins',
    () async {
      final service = PetPackService(() async => temporary);
      await service.install(
        _writePack(
          temporary,
          id: 'atlas-pet',
          metadataBytes: metadataBytes,
          spritesheetBytes: spritesheetBytes,
        ),
      );
      await service.install(
        _writeRigPack(temporary, id: 'rig-pet', poseBytes: poseBytes),
      );

      final installed = await service.loadInstalledPets();
      expect(installed.map((pet) => pet.id), <String>['atlas-pet', 'rig-pet']);
      expect(installed.map((pet) => pet.format), <PetAssetFormat>[
        PetAssetFormat.atlasV2,
        PetAssetFormat.rigV3,
      ]);
      final merged = mergePetRegistry(<PetAssetDescriptor>[
        installed.last.copyWith(
          metadataAsset: 'old-rig',
          spritesheetAsset: 'old-front',
        ),
      ], installed);
      // replacement wins by content; position stays stable (first insertion)
      // so a re-imported pet never jumps around the Collection
      expect(merged.map((pet) => pet.id), <String>['rig-pet', 'atlas-pet']);
      final overridden = merged.firstWhere((pet) => pet.id == 'rig-pet');
      expect(overridden.metadataAsset, endsWith('/rig-pet/rig.json'));
    },
  );

  test(
    'same-id rig install atomically replaces an atlas installation',
    () async {
      final service = PetPackService(() async => temporary);
      await service.install(
        _writePack(
          temporary,
          id: 'same-pet',
          metadataBytes: metadataBytes,
          spritesheetBytes: spritesheetBytes,
        ),
      );

      final installed = await service.install(
        _writeRigPack(
          temporary,
          id: 'same-pet',
          displayName: 'Rig Replacement',
          poseBytes: poseBytes,
        ),
      );

      expect(installed.descriptor.isRig, isTrue);
      expect(
        File(
          '${temporary.path}/pets/same-pet/spritesheet-extended.webp',
        ).existsSync(),
        isFalse,
      );
      expect(
        File('${temporary.path}/pets/same-pet/rig.json').existsSync(),
        isTrue,
      );
      final reloaded = await service.loadInstalledPets();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.formatVersion, 3);
    },
  );

  test('create then import matching pack clears the request', () async {
    final requests = HatchRequestStore(() async => temporary);
    final photo = File('${temporary.path}/source.jpg')
      ..writeAsBytesSync(<int>[1, 2, 3]);
    await requests.create(
      photos: <File>[photo],
      petName: 'Pip',
      now: DateTime.utc(2026, 8, 12),
    );
    final service = PetPackService(() async => temporary);
    final pack = _writePack(
      temporary,
      displayName: 'Pip',
      metadataBytes: metadataBytes,
      spritesheetBytes: spritesheetBytes,
    );

    final installed = await service.install(pack);
    expect(
      await requests.clearIfMatchingPack(
        requestId: installed.requestId,
        displayName: installed.descriptor.displayName,
      ),
      isTrue,
    );
    expect(await requests.load(), isNull);
  });

  test(
    'registry merges bundled and installed pets with same-id replacement',
    () {
      const bundled = <PetAssetDescriptor>[
        PetAssetDescriptor(
          id: 'choco',
          displayName: 'Choco',
          metadataAsset: 'bundled-json',
          spritesheetAsset: 'bundled-webp',
        ),
      ];
      const installed = <PetAssetDescriptor>[
        PetAssetDescriptor(
          id: 'choco2',
          displayName: 'Choco Two',
          metadataAsset: '/installed-json',
          spritesheetAsset: '/installed-webp',
          source: PetAssetSource.fileSystem,
        ),
      ];
      final merged = mergePetRegistry(bundled, installed);
      expect(merged.map((pet) => pet.id), <String>['choco', 'choco2']);
      expect(merged.last.source, PetAssetSource.fileSystem);
    },
  );

  test(
    'rig pack rejects a pose image without a transparent background',
    () async {
      final service = PetPackService(() async => temporary);
      final opaque = await _makeOpaquePosePng();
      final pack = _writeRigPack(
        temporary,
        poseBytes: opaque,
        fileName: 'opaque-pose',
      );
      expect(service.validate(pack), throwsA(isA<PetPackException>()));
    },
  );

  test(
    'body layer erases full width to the chin and keeps the neck strip',
    () async {
      final service = PetPackService(() async => temporary);
      final installed = await service.install(
        _writeRigPack(temporary, poseBytes: poseBytes),
      );
      final pet = await RigPetLoader().load(installed.descriptor);
      addTearDown(pet.dispose);
      final data = (await pet.frontLayers.body.toByteData())!;
      int alpha(int x, int y) =>
          data.getUint8((y * pet.frontWidth + x) * 4 + 3);
      // head box is [8,4,56,28]: full-width erase above the neck notch,
      // sides erased down to the chin line, protected neck strip kept
      expect(alpha(32, 20), 0);
      expect(alpha(18, 27), lessThan(40));
      expect(alpha(32, 27), greaterThan(200));
    },
  );
}

Future<Uint8List> _makeOpaquePosePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xfff2e5cf), ui.BlendMode.src)
    ..drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(8, 4, 48, 56),
        const ui.Radius.circular(8),
      ),
      ui.Paint()..color = const ui.Color(0xffb87333),
    );
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<Uint8List> _makePosePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawColor(const ui.Color(0x00000000), ui.BlendMode.src)
    ..drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(8, 4, 48, 56),
        const ui.Radius.circular(8),
      ),
      ui.Paint()..color = const ui.Color(0xffb87333),
    );
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<Uint8List> _makeLargePosePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawColor(const ui.Color(0x00000000), ui.BlendMode.src)
    ..drawOval(
      const ui.Rect.fromLTWH(190, 140, 388, 400),
      ui.Paint()..color = const ui.Color(0xff70452f),
    )
    ..drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(100, 450, 568, 600),
        const ui.Radius.circular(80),
      ),
      ui.Paint()..color = const ui.Color(0xff70452f),
    );
  final picture = recorder.endRecording();
  final image = await picture.toImage(768, 1152);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Map<String, Object?> _largeRigJson() => <String, Object?>{
  'rigVersion': 1,
  'front': <String, Object?>{
    'groundY': 1050,
    'boxes': <String, Object?>{
      'head': <int>[180, 130, 588, 560],
      'tail': <int>[600, 560, 700, 900],
      'leftFrontLeg': <int>[250, 650, 350, 1050],
      'rightFrontLeg': <int>[420, 650, 520, 1050],
    },
    'pivots': <String, Object?>{
      'head': <int>[384, 540],
      'tail': <int>[600, 730],
    },
  },
  'side': <String, Object?>{
    'groundY': 1050,
    'facing': 'right',
    'boxes': <String, Object?>{
      'head': <int>[430, 140, 680, 560],
      'tail': <int>[70, 500, 220, 850],
      'frontLeg': <int>[500, 650, 580, 1050],
      'hindLeg': <int>[220, 650, 300, 1050],
    },
    'pivots': <String, Object?>{
      'head': <int>[555, 540],
      'tail': <int>[220, 675],
      'frontLeg': <int>[540, 650],
      'hindLeg': <int>[260, 650],
    },
  },
};

Map<String, Object?> _rigJson() => <String, Object?>{
  'rigVersion': 1,
  'front': <String, Object?>{
    'groundY': 60,
    'boxes': <String, Object?>{
      'head': <int>[8, 4, 56, 28],
      'tail': <int>[50, 24, 62, 50],
      'leftFrontLeg': <int>[18, 34, 28, 60],
      'rightFrontLeg': <int>[36, 34, 46, 60],
    },
    'pivots': <String, Object?>{
      'head': <int>[32, 26],
      'tail': <int>[52, 28],
    },
  },
  'side': <String, Object?>{
    'groundY': 60,
    'facing': 'right',
    'boxes': <String, Object?>{
      'head': <int>[38, 8, 62, 30],
      'tail': <int>[2, 16, 18, 36],
      'frontLeg': <int>[40, 30, 49, 60],
      'hindLeg': <int>[20, 30, 29, 60],
    },
    'pivots': <String, Object?>{
      'head': <int>[42, 28],
      'tail': <int>[16, 24],
      'frontLeg': <int>[44, 32],
      'hindLeg': <int>[24, 32],
    },
  },
};

File _writeRigPack(
  Directory directory, {
  String id = 'pip',
  String displayName = 'Pip',
  String species = 'dog',
  String fileName = 'Pip',
  required Uint8List poseBytes,
  Map<String, Object?>? rig,
  bool includeSide = true,
  bool includeSleep = true,
  bool includeNestedEntry = false,
}) {
  final packBytes = utf8.encode(
    jsonEncode(<String, Object?>{
      'formatVersion': 3,
      'id': id,
      'display_name': displayName,
      'species': species,
      'treat': <String, Object?>{'name': 'Tiny Biscuit', 'emoji': '🪴'},
    }),
  );
  final rigBytes = utf8.encode(jsonEncode(rig ?? _rigJson()));
  final archive = Archive()
    ..addFile(ArchiveFile('pack.json', packBytes.length, packBytes))
    ..addFile(ArchiveFile('rig.json', rigBytes.length, rigBytes));
  for (final name in const <String>[
    'front-open.png',
    'front-closed.png',
    'sleep.png',
    'side.png',
  ]) {
    if (name == 'side.png' && !includeSide) continue;
    if (name == 'sleep.png' && !includeSleep) continue;
    archive.addFile(ArchiveFile(name, poseBytes.length, poseBytes));
  }
  if (includeNestedEntry) {
    archive.addFile(
      ArchiveFile('nested/extra.png', poseBytes.length, poseBytes),
    );
  }
  final output = File('${directory.path}/$fileName.pettodopet');
  output.writeAsBytesSync(ZipEncoder().encode(archive)!);
  return output;
}

File _writePack(
  Directory directory, {
  String id = 'choco2',
  String displayName = 'Choco Two',
  required Uint8List metadataBytes,
  required Uint8List spritesheetBytes,
  bool includeSpritesheet = true,
}) {
  final packBytes = utf8.encode(
    jsonEncode(<String, Object?>{
      'formatVersion': 1,
      'id': id,
      'display_name': displayName,
      'treat': <String, Object?>{'name': 'Little Bone', 'emoji': '🦴'},
    }),
  );
  final archive = Archive()
    ..addFile(ArchiveFile('pack.json', packBytes.length, packBytes))
    ..addFile(
      ArchiveFile('pet_request.json', metadataBytes.length, metadataBytes),
    );
  if (includeSpritesheet) {
    archive.addFile(
      ArchiveFile(
        'spritesheet-extended.webp',
        spritesheetBytes.length,
        spritesheetBytes,
      ),
    );
  }
  final output = File('${directory.path}/$displayName.pettodopet');
  output.writeAsBytesSync(ZipEncoder().encode(archive)!);
  return output;
}
