import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/app_state.dart';

class AppStateStore {
  AppStateStore(this._directoryProvider);

  factory AppStateStore.onDevice() =>
      AppStateStore(getApplicationSupportDirectory);

  final Future<Directory> Function() _directoryProvider;
  Future<void> _pendingSave = Future<void>.value();

  Future<File> get _file async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File('${directory.path}/pettodo-state.json');
  }

  Future<AppState> load(DateTime now) async {
    final file = await _file;
    if (!await file.exists()) return AppState.initial(now);
    try {
      final decoded = jsonDecode(await file.readAsString());
      return AppState.fromJson(decoded as Map<String, Object?>, now);
    } on FormatException {
      return AppState.initial(now);
    } on TypeError {
      return AppState.initial(now);
    }
  }

  Future<void> save(AppState state) async {
    final operation = _pendingSave.then((_) => _saveNow(state));
    _pendingSave = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _saveNow(AppState state) async {
    final file = await _file;
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(state.toJson()), flush: true);
    await temporary.rename(file.path);
  }
}
