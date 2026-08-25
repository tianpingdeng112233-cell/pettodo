import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/overlay_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(overlayChannelName);
  final calls = <MethodCall>[];
  var permissionGranted = false;
  var permissionRequestResult = true;
  var nativeEnabled = false;
  var failDisable = false;
  var failIsEnabled = false;

  setUp(() {
    calls.clear();
    permissionGranted = false;
    permissionRequestResult = true;
    nativeEnabled = false;
    failDisable = false;
    failIsEnabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'isSupported':
              return true;
            case 'isEnabled':
              if (failIsEnabled) {
                throw PlatformException(code: 'query_failed');
              }
              return nativeEnabled;
            case 'hasPermission':
              return permissionGranted;
            case 'requestPermission':
              permissionGranted = permissionRequestResult;
              return permissionRequestResult;
            case 'enable':
              nativeEnabled = true;
              return null;
            case 'disable':
              if (failDisable) {
                throw PlatformException(code: 'disable_failed');
              }
              nativeEnabled = false;
              return null;
            case 'celebrate':
              return null;
          }
          throw PlatformException(code: 'unexpected_method');
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('explicit enable asks permission once then starts overlay', () async {
    final service = OverlayService(channel: channel);
    await service.initialize(petName: 'Choco');
    calls.clear();

    expect(await service.setEnabled(true, petName: 'Pip'), isTrue);
    expect(service.enabled, isTrue);
    expect(calls.map((call) => call.method), <String>[
      'hasPermission',
      'requestPermission',
      'enable',
    ]);
    expect(calls.last.arguments, <String, Object?>{'petName': 'Pip'});
  });

  test('permission denial reverts toggle and does not start overlay', () async {
    permissionRequestResult = false;
    final service = OverlayService(channel: channel);
    await service.initialize(petName: 'Choco');
    calls.clear();

    expect(await service.setEnabled(true, petName: 'Choco'), isFalse);
    expect(service.enabled, isFalse);
    expect(calls.map((call) => call.method), <String>[
      'hasPermission',
      'requestPermission',
    ]);

    calls.clear();
    await service.refresh(petName: 'Choco');
    expect(calls.map((call) => call.method), <String>['isEnabled']);
    expect(service.enabled, isFalse);
  });

  test('disable sends stop invocation and leaves toggle off', () async {
    nativeEnabled = true;
    permissionGranted = true;
    final service = OverlayService(channel: channel);
    await service.initialize(petName: 'Choco');
    calls.clear();

    expect(await service.setEnabled(false, petName: 'Choco'), isFalse);
    expect(service.enabled, isFalse);
    expect(calls.map((call) => call.method), <String>['disable']);
  });

  test('failed disable re-syncs the toggle from the native truth', () async {
    nativeEnabled = true;
    permissionGranted = true;
    final service = OverlayService(channel: channel);
    await service.initialize(petName: 'Choco');
    expect(service.enabled, isTrue);
    failDisable = true;
    calls.clear();

    expect(await service.setEnabled(false, petName: 'Choco'), isTrue);
    expect(service.enabled, isTrue);
    expect(calls.map((call) => call.method), <String>['disable', 'isEnabled']);
  });

  test('transient refresh failure keeps the last-known state', () async {
    nativeEnabled = true;
    permissionGranted = true;
    final service = OverlayService(channel: channel);
    await service.initialize(petName: 'Choco');
    expect(service.enabled, isTrue);
    failIsEnabled = true;

    await service.refresh(petName: 'Choco');
    expect(service.enabled, isTrue);
  });

  test('completion celebration maps to native event', () async {
    nativeEnabled = true;
    final service = OverlayService(channel: channel);
    await service.initialize(petName: 'Choco');
    calls.clear();

    await service.celebrate();

    expect(calls.map((call) => call.method), <String>['celebrate']);
  });
}
