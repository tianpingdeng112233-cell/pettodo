import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../tool/slice_overlay_frames.dart';

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

void main() {
  test('overlay frame slice plan is deterministic and matches pixel canon', () {
    final metadata =
        jsonDecode(
              File('assets/pets/choco/pet_request.json').readAsStringSync(),
            )
            as Map<String, Object?>;

    final first = buildOverlaySlicePlan(metadata);
    final second = buildOverlaySlicePlan(metadata);
    final atlas = metadata['atlas']! as Map<String, Object?>;

    expect(atlas['columns'], 8);
    expect(atlas['rows'], 11);
    expect(atlas['width'], 1536);
    expect(atlas['height'], 2288);
    expect(first, hasLength(11));
    expect(first.map((frame) => frame.width), everyElement(192));
    expect(first.map((frame) => frame.height), everyElement(208));
    expect(first.first.resourceName, 'overlay_idle_0.png');
    expect(first.first.left, 0);
    expect(first.first.top, 0);
    expect(first[5].left, 960);
    expect(first[6].resourceName, 'overlay_jumping_0.png');
    expect(first[6].top, 832);
    expect(first.last.left, 768);
    expect(
      encodeOverlaySliceManifest(first),
      encodeOverlaySliceManifest(second),
    );
  });

  testWidgets('committed overlay drawables match the pixel canon atlas', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final metadata =
          jsonDecode(
                File('assets/pets/choco/pet_request.json').readAsStringSync(),
              )
              as Map<String, Object?>;
      final plan = buildOverlaySlicePlan(metadata);
      final atlas = await _decode(
        File('assets/pets/choco/spritesheet-extended.webp').readAsBytesSync(),
      );
      final atlasBytes = (await atlas.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final atlasWidth = atlas.width;

      for (final slice in plan) {
        final file = File(
          'android/app/src/main/res/drawable-nodpi/${slice.resourceName}',
        );
        expect(file.existsSync(), isTrue, reason: slice.resourceName);
        final cell = await _decode(file.readAsBytesSync());
        expect(cell.width, slice.width, reason: slice.resourceName);
        expect(cell.height, slice.height, reason: slice.resourceName);
        final cellBytes = (await cell.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();

        // Allow a per-channel difference of 1: WebP and PNG reach rawRgba
        // through premultiplied storage, whose un-premultiply rounds
        // semi-transparent pixels slightly differently per codec. A stale or
        // hand-edited frame produces large diffs and still fails.
        for (var y = 0; y < slice.height; y++) {
          final atlasRowStart = ((slice.top + y) * atlasWidth + slice.left) * 4;
          final cellRowStart = y * slice.width * 4;
          for (var i = 0; i < slice.width * 4; i++) {
            final a = atlasBytes[atlasRowStart + i];
            final c = cellBytes[cellRowStart + i];
            if ((a - c).abs() > 1) {
              fail(
                '${slice.resourceName} pixel byte (row $y, offset $i) is $c '
                'vs atlas $a — regenerate with tool/slice_overlay_frames.dart',
              );
            }
          }
        }
      }
    });
  });
}
