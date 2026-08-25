import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'device_id_store.dart';

const String defaultHatchApiBaseUrl = 'https://hatch-api.pawside.example';

enum HatchRemoteStatus { incubating, ready, failed }

class HatchSubmission {
  const HatchSubmission({required this.hatchId});

  final String hatchId;
}

class HatchStatusResponse {
  const HatchStatusResponse({required this.status, this.packUrl});

  final HatchRemoteStatus status;
  final Uri? packUrl;
}

abstract interface class HatchApi {
  Future<HatchSubmission> submitHatch({
    required List<File> photos,
    required String petName,
  });

  Future<HatchStatusResponse> getHatchStatus(String hatchId);

  Future<void> submitSpeciesWish(String speciesText);

  Future<File> downloadPack(Uri url);
}

sealed class HatchApiException implements Exception {
  const HatchApiException(this.userMessage);

  final String userMessage;

  @override
  String toString() => '$runtimeType: $userMessage';
}

class HatchQuotaExhausted extends HatchApiException {
  const HatchQuotaExhausted()
    : super(
        'This device has used its 3 included hatches. You can still import a pet pack below.',
      );
}

class HatchSpeciesUnsupported extends HatchApiException {
  const HatchSpeciesUnsupported(this.detectedSpecies)
    : super(
        'This little companion is outside our cat-and-dog nursery for now.',
      );

  final String detectedSpecies;
}

class HatchInvalidPhotos extends HatchApiException {
  const HatchInvalidPhotos()
    : super('Choose 1–3 JPEG or PNG photos when you are ready.');
}

class HatchConnectionIssue extends HatchApiException {
  const HatchConnectionIssue()
    : super(
        'The adoption center is quiet right now. Your request is safe here to try again.',
      );
}

class HatchServiceIssue extends HatchApiException {
  const HatchServiceIssue()
    : super('The adoption center needs a little more time. Please try again.');
}

typedef HttpClientFactory = HttpClient Function();
typedef DeviceIdProvider = Future<String> Function();
typedef DirectoryProvider = Future<Directory> Function();

class HatchApiClient implements HatchApi {
  HatchApiClient({
    Uri? baseUrl,
    required DeviceIdProvider deviceIdProvider,
    HttpClientFactory? httpClientFactory,
    DirectoryProvider? temporaryDirectoryProvider,
  }) : baseUrl = baseUrl ?? Uri.parse(defaultHatchApiBaseUrl),
       // ignore: prefer_initializing_formals
       _deviceIdProvider = deviceIdProvider,
       _httpClientFactory = httpClientFactory ?? HttpClient.new,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

  factory HatchApiClient.onDevice({Uri? baseUrl}) {
    final deviceIds = DeviceIdStore.onDevice();
    return HatchApiClient(
      baseUrl: baseUrl,
      deviceIdProvider: deviceIds.loadOrCreate,
    );
  }

  final Uri baseUrl;
  final DeviceIdProvider _deviceIdProvider;
  final HttpClientFactory _httpClientFactory;
  final DirectoryProvider _temporaryDirectoryProvider;
  final Random _random = Random.secure();

  @override
  Future<HatchSubmission> submitHatch({
    required List<File> photos,
    required String petName,
  }) async {
    if (photos.isEmpty || photos.length > 3) throw const HatchInvalidPhotos();
    final photoTypes = <String>[];
    for (final photo in photos) {
      if (!await photo.exists()) throw const HatchInvalidPhotos();
      final type = _imageContentType(photo.path);
      if (type == null) throw const HatchInvalidPhotos();
      photoTypes.add(type);
    }
    final boundary = 'pettodo-${_random.nextInt(0x7fffffff)}';
    final client = _httpClientFactory();
    try {
      final request = await client.postUrl(_endpoint('/v1/hatch'));
      await _addDeviceHeader(request);
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: <String, String>{'boundary': boundary},
      );
      final normalizedName = petName.trim();
      if (normalizedName.isNotEmpty) {
        _writeMultipartText(request, boundary, 'petName', normalizedName);
      }
      for (var index = 0; index < photos.length; index++) {
        await _writeMultipartFile(
          request,
          boundary,
          photos[index],
          photoTypes[index],
        );
      }
      request.write('--$boundary--\r\n');
      final response = await request.close();
      final payload = await _readJson(response);
      if (response.statusCode == HttpStatus.created) {
        final hatchId = payload['hatchId'];
        final status = payload['status'];
        if (hatchId is String && hatchId.isNotEmpty && status == 'incubating') {
          return HatchSubmission(hatchId: hatchId);
        }
        throw const HatchServiceIssue();
      }
      if (response.statusCode == HttpStatus.paymentRequired &&
          payload['code'] == 'quota_exhausted') {
        throw const HatchQuotaExhausted();
      }
      if (response.statusCode == HttpStatus.unprocessableEntity &&
          payload['code'] == 'species_unsupported') {
        final detected = payload['detectedSpecies'];
        throw HatchSpeciesUnsupported(
          detected is String && detected.trim().isNotEmpty
              ? detected.trim()
              : 'another species',
        );
      }
      throw const HatchServiceIssue();
    } on HatchApiException {
      rethrow;
    } on Object {
      throw const HatchConnectionIssue();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<HatchStatusResponse> getHatchStatus(String hatchId) async {
    final client = _httpClientFactory();
    try {
      final safeId = Uri.encodeComponent(hatchId);
      final request = await client.getUrl(_endpoint('/v1/hatch/$safeId'));
      await _addDeviceHeader(request);
      final response = await request.close();
      final payload = await _readJson(response);
      if (response.statusCode != HttpStatus.ok) {
        throw const HatchServiceIssue();
      }
      switch (payload['status']) {
        case 'incubating':
          return const HatchStatusResponse(
            status: HatchRemoteStatus.incubating,
          );
        case 'ready':
          final value = payload['packUrl'];
          final packUrl = value is String ? Uri.tryParse(value) : null;
          if (packUrl == null ||
              (packUrl.scheme != 'https' && packUrl.scheme != 'http')) {
            throw const HatchServiceIssue();
          }
          return HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: packUrl,
          );
        case 'failed':
          return const HatchStatusResponse(status: HatchRemoteStatus.failed);
        default:
          throw const HatchServiceIssue();
      }
    } on HatchApiException {
      rethrow;
    } on Object {
      throw const HatchConnectionIssue();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> submitSpeciesWish(String speciesText) async {
    final wish = speciesText.trim();
    if (wish.isEmpty) return;
    final client = _httpClientFactory();
    try {
      final request = await client.postUrl(_endpoint('/v1/species-wish'));
      await _addDeviceHeader(request);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(<String, Object?>{'speciesText': wish}));
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != HttpStatus.noContent) {
        throw const HatchServiceIssue();
      }
    } on HatchApiException {
      rethrow;
    } on Object {
      throw const HatchConnectionIssue();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<File> downloadPack(Uri url) async {
    if (url.scheme != 'https' && url.scheme != 'http') {
      throw const HatchServiceIssue();
    }
    final client = _httpClientFactory();
    File? output;
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw const HatchServiceIssue();
      }
      final directory = await _temporaryDirectoryProvider();
      await directory.create(recursive: true);
      output = File(
        '${directory.path}/hatch-${DateTime.now().microsecondsSinceEpoch}.pettodopet',
      );
      final sink = output.openWrite();
      await response.pipe(sink);
      return output;
    } on HatchApiException {
      rethrow;
    } on Object {
      if (output != null && await output.exists()) await output.delete();
      throw const HatchConnectionIssue();
    } finally {
      client.close(force: true);
    }
  }

  Uri _endpoint(String path) => baseUrl.replace(path: path, query: null);

  Future<void> _addDeviceHeader(HttpClientRequest request) async {
    request.headers.set(
      'X-Device-Id',
      (await _deviceIdProvider()).toLowerCase(),
    );
  }

  static Future<Map<String, Object?>> _readJson(
    HttpClientResponse response,
  ) async {
    final body = await utf8.decoder.bind(response).join();
    if (body.isEmpty) return const <String, Object?>{};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, Object?>
          ? decoded
          : const <String, Object?>{};
    } on FormatException {
      return const <String, Object?>{};
    }
  }

  static void _writeMultipartText(
    HttpClientRequest request,
    String boundary,
    String name,
    String value,
  ) {
    request.write('--$boundary\r\n');
    request.write('Content-Disposition: form-data; name="$name"\r\n\r\n');
    request.write(value);
    request.write('\r\n');
  }

  static Future<void> _writeMultipartFile(
    HttpClientRequest request,
    String boundary,
    File file,
    String contentType,
  ) async {
    final filename = file.uri.pathSegments.last.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    request.write('--$boundary\r\n');
    request.write(
      'Content-Disposition: form-data; name="photos[]"; filename="$filename"\r\n',
    );
    request.write('Content-Type: $contentType\r\n\r\n');
    await request.addStream(file.openRead());
    request.write('\r\n');
  }

  static String? _imageContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    return null;
  }
}
