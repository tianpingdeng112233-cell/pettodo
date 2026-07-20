import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/event_log.dart';

class EventLogStore {
  EventLogStore(this._directoryProvider);

  factory EventLogStore.onDevice() =>
      EventLogStore(getApplicationDocumentsDirectory);

  final Future<Directory> Function() _directoryProvider;
  Future<void> _pendingAppend = Future<void>.value();

  Future<File> get file async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File('${directory.path}/pettodo-events.jsonl');
  }

  Future<void> append(PetEvent event) async {
    final operation = _pendingAppend.then((_) => _appendNow(event));
    _pendingAppend = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _appendNow(PetEvent event) async {
    final target = await file;
    await target.writeAsString(
      '${encodeEventLine(event)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<List<PetEvent>> readAll() async {
    await _pendingAppend;
    final target = await file;
    if (!await target.exists()) return const <PetEvent>[];
    return decodeEventJsonl(await target.readAsString());
  }

  Future<File> ensureExportFile() async {
    await _pendingAppend;
    final target = await file;
    if (!await target.exists()) await target.create(recursive: true);
    return target;
  }
}
