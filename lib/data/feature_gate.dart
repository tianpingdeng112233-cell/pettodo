import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class FeatureGate {
  String get priceLabel;

  Future<bool> isUnlocked();

  Future<void> unlock();
}

class LocalFeatureGate implements FeatureGate {
  LocalFeatureGate(this._directoryProvider);

  factory LocalFeatureGate.onDevice() =>
      LocalFeatureGate(getApplicationSupportDirectory);

  final Future<Directory> Function() _directoryProvider;

  @override
  String get priceLabel => 'One-time price coming soon';

  Future<File> get _file async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File('${directory.path}/hatch-feature-gate.json');
  }

  @override
  Future<bool> isUnlocked() async {
    final file = await _file;
    if (!await file.exists()) return false;
    try {
      final value = jsonDecode(await file.readAsString());
      return value is Map<String, Object?> && value['unlocked'] == true;
    } on FormatException {
      return false;
    }
  }

  @override
  Future<void> unlock() async {
    final file = await _file;
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{'unlocked': true}),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}
