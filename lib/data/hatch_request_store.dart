import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

class HatchRequest {
  HatchRequest({
    required this.requestId,
    required this.petName,
    required this.createdAt,
    required List<String> photoFiles,
  }) : photoFiles = List<String>.unmodifiable(photoFiles);

  factory HatchRequest.fromJson(Map<String, Object?> json) {
    final requestId = json['requestId'];
    final petName = json['petName'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final photos = (json['photos'] as List<Object?>? ?? const <Object?>[])
        .whereType<String>()
        .toList(growable: false);
    if (requestId is! String ||
        requestId.isEmpty ||
        petName is! String ||
        createdAt == null ||
        photos.isEmpty ||
        photos.length > 5 ||
        photos.toSet().length != photos.length ||
        photos.any(
          (photo) => !RegExp(r'^photo-[1-5]\.[a-z0-9]{1,5}$').hasMatch(photo),
        )) {
      throw const FormatException('Invalid hatch request.');
    }
    return HatchRequest(
      requestId: requestId,
      petName: petName,
      createdAt: createdAt,
      photoFiles: photos,
    );
  }

  final String requestId;
  final String petName;
  final DateTime createdAt;
  final List<String> photoFiles;

  Map<String, Object?> toJson() => <String, Object?>{
    'requestId': requestId,
    'petName': petName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'photos': photoFiles,
  };
}

class HatchRequestStore {
  HatchRequestStore(this._documentsProvider);

  factory HatchRequestStore.onDevice() =>
      HatchRequestStore(getApplicationDocumentsDirectory);

  final Future<Directory> Function() _documentsProvider;

  Future<Directory> get requestDirectory async =>
      Directory('${(await _documentsProvider()).path}/hatch_request');

  Future<HatchRequest?> load() async {
    final directory = await requestDirectory;
    final file = File('${directory.path}/request.json');
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      final request = HatchRequest.fromJson(decoded as Map<String, Object?>);
      for (final photo in request.photoFiles) {
        if (!await File('${directory.path}/$photo').exists()) return null;
      }
      return request;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<HatchRequest> create({
    required List<File> photos,
    required String petName,
    DateTime? now,
  }) async {
    if (photos.isEmpty || photos.length > 5) {
      throw ArgumentError('Choose between 1 and 5 photos.');
    }
    if (await load() != null) {
      throw StateError('Only one hatch request can wait at a time.');
    }
    final createdAt = now ?? DateTime.now();
    final requestId =
        'request-${createdAt.toUtc().microsecondsSinceEpoch.toString()}';
    final documents = await _documentsProvider();
    await documents.create(recursive: true);
    final destination = await requestDirectory;
    if (await destination.exists()) await destination.delete(recursive: true);
    final staging = Directory('${documents.path}/hatch_request.tmp');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    final names = <String>[];
    try {
      for (var index = 0; index < photos.length; index++) {
        final source = photos[index];
        if (!await source.exists()) {
          throw const FileSystemException('A chosen photo is unavailable.');
        }
        final extension = _safeExtension(source.path);
        final name = 'photo-${index + 1}$extension';
        await source.copy('${staging.path}/$name');
        names.add(name);
      }
      final request = HatchRequest(
        requestId: requestId,
        petName: petName.trim(),
        createdAt: createdAt,
        photoFiles: names,
      );
      await File(
        '${staging.path}/request.json',
      ).writeAsString(jsonEncode(request.toJson()), flush: true);
      await staging.rename(destination.path);
      return request;
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<File> export() async {
    final request = await load();
    if (request == null) throw StateError('There is no hatch request to send.');
    final directory = await requestDirectory;
    final output = File('${directory.parent.path}/${request.requestId}.zip');
    final archive = Archive();
    for (final name in <String>['request.json', ...request.photoFiles]) {
      final bytes = await File('${directory.path}/$name').readAsBytes();
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw const FileSystemException('Could not make zip.');
    await output.writeAsBytes(encoded, flush: true);
    return output;
  }

  Future<void> cancel() async {
    final directory = await requestDirectory;
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<bool> clearIfMatching(String? requestId) async {
    if (requestId == null) return false;
    final current = await load();
    if (current?.requestId != requestId) return false;
    await cancel();
    return true;
  }

  Future<bool> clearIfMatchingPack({
    String? requestId,
    required String displayName,
  }) async {
    final current = await load();
    if (current == null) return false;
    final name = current.petName.trim();
    final matches =
        (requestId != null && requestId == current.requestId) ||
        (name.isNotEmpty && name.toLowerCase() == displayName.toLowerCase());
    if (!matches) return false;
    await cancel();
    return true;
  }

  static String _safeExtension(String path) {
    final file = path.split(Platform.pathSeparator).last;
    final dot = file.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    final extension = file.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension)
        ? extension
        : '.jpg';
  }
}
