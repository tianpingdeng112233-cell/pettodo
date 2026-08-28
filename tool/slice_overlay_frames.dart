import 'dart:convert';
import 'dart:io';

import 'package:pettodo/sprite/overlay_frame_slicer.dart';

export 'package:pettodo/sprite/overlay_frame_slicer.dart';

Future<void> main(List<String> arguments) async {
  final options = _options(arguments);
  final metadataFile = File(
    options['metadata'] ?? 'assets/pets/choco/pet_request.json',
  );
  final atlasFile = File(
    options['atlas'] ?? 'assets/pets/choco/spritesheet-extended.webp',
  );
  final output = Directory(
    options['output'] ?? 'android/app/src/main/res/drawable-nodpi',
  );
  final magick = options['magick'] ?? 'magick';
  final metadata =
      jsonDecode(await metadataFile.readAsString()) as Map<String, Object?>;
  final plan = buildOverlaySlicePlan(metadata);
  output.createSync(recursive: true);

  for (final slice in plan) {
    final result = await Process.run(magick, <String>[
      atlasFile.path,
      '-crop',
      '${slice.width}x${slice.height}+${slice.left}+${slice.top}',
      '+repage',
      '-define',
      'png:exclude-chunk=date,time',
      '${output.path}/${slice.resourceName}',
    ]);
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      exitCode = result.exitCode;
      return;
    }
  }
}

Map<String, String> _options(List<String> arguments) {
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (!argument.startsWith('--') || index + 1 >= arguments.length) {
      throw ArgumentError('Expected --name value arguments.');
    }
    result[argument.substring(2)] = arguments[++index];
  }
  return result;
}
