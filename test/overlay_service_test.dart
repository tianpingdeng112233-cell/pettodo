import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/notification_service.dart';
import 'package:pettodo/data/overlay_service.dart';
import 'package:pettodo/sprite/overlay_frame_baker.dart';

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
    expect(calls.last.arguments, <String, Object?>{
      'petName': 'Pip',
      'frameFilesChanged': true,
      'frameFiles': null,
      'bubbles': <Object?>[],
    });
  });

  test('refresh resends bubbles without unchanged frame paths', () async {
    nativeEnabled = true;
    final service = OverlayService(channel: channel);
    final frames = BakedOverlayFrames(
      idleFiles: <File>[File('/support/pip/idle_0.png')],
      jumpingFiles: <File>[File('/support/pip/jumping_0.png')],
    );
    final bubbles = <OverlayBubbleInvitation>[
      OverlayBubbleInvitation(
        scheduledAt: DateTime.fromMillisecondsSinceEpoch(1787936400000),
        copy: overlayInvitationCopy,
      ),
    ];
    await service.initialize(petName: 'Pip', frames: frames, bubbles: bubbles);
    calls.clear();

    await service.refresh(petName: 'Pip', frames: frames, bubbles: bubbles);

    expect(calls.map((call) => call.method), <String>['isEnabled', 'enable']);
    expect(calls.last.arguments, <String, Object?>{
      ...buildOverlayChannelPayload(
        petName: 'Pip',
        frames: frames,
        bubbles: bubbles,
        includeFrameFiles: false,
      ),
    });
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

  test('channel payload carries frame files and bubble schedule', () {
    final payload = buildOverlayChannelPayload(
      petName: 'Pip',
      frames: BakedOverlayFrames(
        idleFiles: <File>[
          File('/support/overlay_frames/pip/idle_0.png'),
          File('/support/overlay_frames/pip/idle_1.png'),
        ],
        jumpingFiles: <File>[File('/support/overlay_frames/pip/jumping_0.png')],
      ),
      bubbles: <OverlayBubbleInvitation>[
        OverlayBubbleInvitation(
          scheduledAt: DateTime.fromMillisecondsSinceEpoch(
            1787936400000,
            isUtc: true,
          ),
          copy: overlayInvitationCopy,
        ),
      ],
    );

    expect(payload, <String, Object?>{
      'petName': 'Pip',
      'frameFilesChanged': true,
      'frameFiles': <String, Object?>{
        'idle': <String>[
          '/support/overlay_frames/pip/idle_0.png',
          '/support/overlay_frames/pip/idle_1.png',
        ],
        'jumping': <String>['/support/overlay_frames/pip/jumping_0.png'],
      },
      'bubbles': <Map<String, Object?>>[
        <String, Object?>{
          'scheduledAtEpochMillis': 1787936400000,
          'copy': overlayInvitationCopy,
        },
      ],
    });
  });

  test('channel payload requests bundled fallback without complete files', () {
    final payload = buildOverlayChannelPayload(
      petName: 'Choco',
      frames: BakedOverlayFrames(
        idleFiles: <File>[File('/support/idle.png')],
        jumpingFiles: const <File>[],
      ),
      bubbles: const <OverlayBubbleInvitation>[],
    );

    expect(payload['frameFiles'], isNull);
    expect(payload['frameFilesChanged'], isTrue);
    expect(payload['bubbles'], isEmpty);
  });
}
