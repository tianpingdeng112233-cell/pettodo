import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/hatch_request_store.dart';
import 'package:pettodo/data/pet_pack_service.dart';
import 'package:pettodo/sprite/sprite_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporary;
  late Uint8List metadataBytes;
  late Uint8List spritesheetBytes;

  setUp(() async {
    temporary = Directory.systemTemp.createTempSync('pettodo-pack-test');
    metadataBytes = (await rootBundle.load(
      'assets/pets/choco/pet_request.json',
    )).buffer.asUint8List();
    spritesheetBytes = (await rootBundle.load(
      'assets/pets/choco/spritesheet-extended.webp',
    )).buffer.asUint8List();
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
