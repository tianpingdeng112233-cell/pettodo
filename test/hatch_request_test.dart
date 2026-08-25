import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/hatch_request_store.dart';

void main() {
  late Directory temporary;
  late HatchRequestStore store;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('pettodo-request-test');
    store = HatchRequestStore(() async => temporary);
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  test('request lifecycle creates, exports, and cancels', () async {
    final photo = File('${temporary.path}/source.jpg')
      ..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final created = await store.create(
      photos: <File>[photo],
      petName: 'Pip',
      now: DateTime.utc(2026, 8, 12, 10),
    );

    expect((await store.load())?.requestId, created.requestId);
    expect(
      () => store.create(photos: <File>[photo], petName: 'Another'),
      throwsA(isA<StateError>()),
    );
    final exported = await store.export();
    final archive = ZipDecoder().decodeBytes(exported.readAsBytesSync());
    expect(archive.files.map((entry) => entry.name).toSet(), <String>{
      'request.json',
      'photo-1.jpg',
    });
    final requestEntry = archive.files.singleWhere(
      (entry) => entry.name == 'request.json',
    );
    final requestJson =
        jsonDecode(utf8.decode(requestEntry.content as List<int>))
            as Map<String, Object?>;
    expect(requestJson['petName'], 'Pip');

    final attached = await store.attachHatchId('hatch-1');
    expect(attached.hatchId, 'hatch-1');
    expect((await store.load())?.hatchId, 'hatch-1');

    await store.cancel();
    expect(await store.load(), isNull);
    // Cancelling takes the exported zip with it — otherwise every request the
    // user ever sent stays in documents forever.
    expect(exported.existsSync(), isFalse);
  });

  test('request accepts at most three photos', () async {
    final photos = List<File>.generate(
      4,
      (index) =>
          File('${temporary.path}/source-$index.jpg')
            ..writeAsBytesSync(<int>[index]),
    );

    await expectLater(
      store.create(photos: photos, petName: 'Pip'),
      throwsArgumentError,
    );
  });

  test('exporting a second request leaves no stale zip behind', () async {
    final photo = File('${temporary.path}/source.jpg')
      ..writeAsBytesSync(<int>[1, 2, 3, 4]);

    await store.create(
      photos: <File>[photo],
      petName: 'Pip',
      now: DateTime.utc(2026, 8, 12, 10),
    );
    final first = await store.export();
    await store.cancel();

    await store.create(
      photos: <File>[photo],
      petName: 'Nib',
      now: DateTime.utc(2026, 8, 12, 12),
    );
    final second = await store.export();

    expect(first.path, isNot(second.path));
    expect(first.existsSync(), isFalse);
    expect(second.existsSync(), isTrue);
    expect(
      temporary
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.zip'))
          .length,
      1,
    );
  });

  test(
    'matching imported pack clears the request and another does not',
    () async {
      final photo = File('${temporary.path}/source.jpg')
        ..writeAsBytesSync(<int>[1]);
      final created = await store.create(
        photos: <File>[photo],
        petName: '',
        now: DateTime.utc(2026, 8, 12, 11),
      );

      expect(await store.clearIfMatching('somewhere-else'), isFalse);
      expect(await store.load(), isNotNull);
      expect(await store.clearIfMatching(created.requestId), isTrue);
      expect(await store.load(), isNull);
    },
  );
}
