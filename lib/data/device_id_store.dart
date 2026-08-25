import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

class DeviceIdStore {
  DeviceIdStore(this._directoryProvider, {Random? random})
    : _random = random ?? Random.secure();

  factory DeviceIdStore.onDevice() =>
      DeviceIdStore(getApplicationSupportDirectory);

  final Future<Directory> Function() _directoryProvider;
  final Random _random;
  String? _cached;

  Future<String> loadOrCreate() async {
    final cached = _cached;
    if (cached != null) return cached;
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final file = File('${directory.path}/device-id');
    if (await file.exists()) {
      final stored = (await file.readAsString()).trim().toLowerCase();
      if (_uuidPattern.hasMatch(stored)) {
        _cached = stored;
        return stored;
      }
    }
    final created = _newUuidV4();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(created, flush: true);
    await temporary.rename(file.path);
    _cached = created;
    return created;
  }

  String _newUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
}
