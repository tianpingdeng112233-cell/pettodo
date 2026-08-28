import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/hatch_api_client.dart';

void main() {
  const deviceId = '123e4567-e89b-42d3-a456-426614174000';

  test('debug builds default hatch requests to the Android host bridge', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(defaultHatchApiBaseUrl, 'http://10.0.2.2:3000');
  });

  test('non-Android debug builds keep the placeholder hatch endpoint', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(defaultHatchApiBaseUrl, 'https://hatch-api.pawside.example');
  });

  test('submit sends the v1 multipart contract and reads 201', () async {
    final photo = await _temporaryPhoto('front.jpg');
    addTearDown(() => photo.parent.delete(recursive: true));
    late HttpRequest received;
    late String body;
    final server = await _server((request) async {
      received = request;
      body = utf8.decode(
        await request.fold<List<int>>(
          <int>[],
          (bytes, chunk) => bytes..addAll(chunk),
        ),
      );
      request.response
        ..statusCode = HttpStatus.created
        ..write('{"hatchId":"hatch-1","status":"incubating"}');
      await request.response.close();
    });
    addTearDown(server.close);

    final result = await _client(
      server,
      deviceId,
    ).submitHatch(photos: <File>[photo], petName: 'Pip');

    expect(result.hatchId, 'hatch-1');
    expect(received.method, 'POST');
    expect(received.uri.path, '/v1/hatch');
    expect(received.headers.value('X-Device-Id'), deviceId);
    expect(received.headers.contentType?.mimeType, 'multipart/form-data');
    expect(body, contains('name="photos[]"; filename="front.jpg"'));
    expect(body, contains('Content-Type: image/jpeg'));
    expect(body, contains('name="petName"'));
    expect(body, contains('Pip'));
  });

  test('submit maps quota and unsupported species responses', () async {
    final photo = await _temporaryPhoto('front.png');
    addTearDown(() => photo.parent.delete(recursive: true));
    var requestCount = 0;
    final server = await _server((request) async {
      await request.drain<void>();
      requestCount++;
      if (requestCount == 1) {
        request.response
          ..statusCode = HttpStatus.paymentRequired
          ..write('{"code":"quota_exhausted"}');
      } else {
        request.response
          ..statusCode = HttpStatus.unprocessableEntity
          ..write('{"code":"species_unsupported","detectedSpecies":"rabbit"}');
      }
      await request.response.close();
    });
    addTearDown(server.close);
    final client = _client(server, deviceId);

    await expectLater(
      client.submitHatch(photos: <File>[photo], petName: ''),
      throwsA(isA<HatchQuotaExhausted>()),
    );
    await expectLater(
      client.submitHatch(photos: <File>[photo], petName: ''),
      throwsA(
        isA<HatchSpeciesUnsupported>().having(
          (error) => error.detectedSpecies,
          'detected species',
          'rabbit',
        ),
      ),
    );
  });

  test('status reads incubating, ready, and failed payloads', () async {
    var requestCount = 0;
    final payloads = <String>[
      '{"status":"incubating"}',
      '{"status":"ready","packUrl":"https://cdn.example/pip.pettodopet"}',
      '{"status":"failed"}',
    ];
    final server = await _server((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/v1/hatch/hatch-1');
      expect(request.headers.value('X-Device-Id'), deviceId);
      request.response.write(payloads[requestCount++]);
      await request.response.close();
    });
    addTearDown(server.close);
    final client = _client(server, deviceId);

    expect(
      (await client.getHatchStatus('hatch-1')).status,
      HatchRemoteStatus.incubating,
    );
    final ready = await client.getHatchStatus('hatch-1');
    expect(ready.status, HatchRemoteStatus.ready);
    expect(ready.packUrl.toString(), 'https://cdn.example/pip.pettodopet');
    expect(
      (await client.getHatchStatus('hatch-1')).status,
      HatchRemoteStatus.failed,
    );
  });

  test('species wish posts JSON and accepts 204', () async {
    late Map<String, Object?> payload;
    final server = await _server((request) async {
      payload =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, Object?>;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1/species-wish');
      expect(request.headers.value('X-Device-Id'), deviceId);
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    });
    addTearDown(server.close);

    await _client(server, deviceId).submitSpeciesWish('rabbit');
    expect(payload, <String, Object?>{'speciesText': 'rabbit'});
  });
}

HatchApiClient _client(HttpServer server, String deviceId) => HatchApiClient(
  baseUrl: Uri.parse('http://${server.address.host}:${server.port}'),
  deviceIdProvider: () async => deviceId,
);

Future<HttpServer> _server(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

Future<File> _temporaryPhoto(String name) async {
  final directory = await Directory.systemTemp.createTemp('hatch-api-test');
  return File('${directory.path}/$name')..writeAsBytesSync(<int>[1, 2, 3]);
}
