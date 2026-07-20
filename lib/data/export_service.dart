import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import 'event_log_store.dart';

class ExportService {
  const ExportService(this._eventLog);

  final EventLogStore _eventLog;

  Future<void> shareEvents({Rect? sharePositionOrigin}) async {
    final file = await _eventLog.ensureExportFile();
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'application/x-ndjson')],
        subject: 'PetTodo 数据导出',
        title: '导出 PetTodo 数据',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
