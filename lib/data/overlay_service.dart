import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../sprite/overlay_frame_baker.dart';
import 'notification_service.dart';

const String overlayChannelName = 'com.davidshi.pettodo/overlay';

Map<String, Object?> buildOverlayChannelPayload({
  required String petName,
  required BakedOverlayFrames? frames,
  required List<OverlayBubbleInvitation> bubbles,
  bool includeFrameFiles = true,
}) {
  final hasCompleteFrames =
      frames != null &&
      frames.idleFiles.isNotEmpty &&
      frames.jumpingFiles.isNotEmpty;
  return <String, Object?>{
    'petName': petName,
    'frameFilesChanged': includeFrameFiles,
    'frameFiles': includeFrameFiles && hasCompleteFrames
        ? <String, Object?>{
            'idle': frames.idleFiles
                .map((file) => file.absolute.path)
                .toList(growable: false),
            'jumping': frames.jumpingFiles
                .map((file) => file.absolute.path)
                .toList(growable: false),
          }
        : null,
    'bubbles': bubbles
        .map(
          (bubble) => <String, Object?>{
            'scheduledAtEpochMillis': bubble.scheduledAt.millisecondsSinceEpoch,
            'copy': bubble.copy,
          },
        )
        .toList(growable: false),
  };
}

/// Owns the small Dart/native contract for Android's floating pet.
///
/// Permission is only requested from [setEnabled] after an explicit user
/// action. Initialization and resume checks never open system settings.
class OverlayService extends ChangeNotifier {
  OverlayService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(overlayChannelName);

  final MethodChannel _channel;

  bool supported = false;
  bool enabled = false;
  bool busy = false;
  String? _lastFrameSignature;
  bool _hasSentFrameConfiguration = false;

  Future<void> initialize({
    required String petName,
    BakedOverlayFrames? frames,
    List<OverlayBubbleInvitation> bubbles = const <OverlayBubbleInvitation>[],
  }) async {
    try {
      supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
      if (!supported) return;
      enabled = await _channel.invokeMethod<bool>('isEnabled') ?? false;
      if (enabled) {
        await _sendConfiguration(
          petName: petName,
          frames: frames,
          bubbles: bubbles,
          forceFrameFiles: true,
        );
      }
    } on MissingPluginException {
      supported = false;
      enabled = false;
    } on PlatformException {
      supported = false;
      enabled = false;
    } on Object {
      // The optional ambient layer must never hold up runApp().
      supported = false;
      enabled = false;
    } finally {
      notifyListeners();
    }
  }

  /// Returns the final toggle value. A denial always resolves to `false`.
  Future<bool> setEnabled(
    bool value, {
    required String petName,
    BakedOverlayFrames? frames,
    List<OverlayBubbleInvitation> bubbles = const <OverlayBubbleInvitation>[],
  }) async {
    if (!supported || busy) return enabled;
    busy = true;
    notifyListeners();
    try {
      if (!value) {
        await _channel.invokeMethod<void>('disable');
        enabled = false;
        _hasSentFrameConfiguration = false;
        return false;
      }

      var granted = await _channel.invokeMethod<bool>('hasPermission') ?? false;
      if (!granted) {
        granted =
            await _channel.invokeMethod<bool>('requestPermission') ?? false;
      }
      if (!granted) {
        enabled = false;
        return false;
      }

      await _sendConfiguration(
        petName: petName,
        frames: frames,
        bubbles: bubbles,
        forceFrameFiles: true,
      );
      enabled = true;
      return true;
    } on MissingPluginException {
      supported = false;
      enabled = false;
      return false;
    } on Object {
      // The channel call failed mid-flight: the Dart flag may no longer
      // match the native overlay (e.g. a failed 'disable' leaves it
      // running). Re-sync from the native truth instead of guessing.
      await _syncEnabledFromNative();
      return enabled;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _syncEnabledFromNative() async {
    try {
      enabled = await _channel.invokeMethod<bool>('isEnabled') ?? enabled;
    } on Object {
      // Keep the last-known state when even the query fails.
    }
  }

  Future<void> refresh({
    required String petName,
    BakedOverlayFrames? frames,
    List<OverlayBubbleInvitation> bubbles = const <OverlayBubbleInvitation>[],
  }) async {
    if (!supported) return;
    try {
      enabled = await _channel.invokeMethod<bool>('isEnabled') ?? false;
      if (enabled) {
        await _sendConfiguration(
          petName: petName,
          frames: frames,
          bubbles: bubbles,
        );
      }
      notifyListeners();
    } on MissingPluginException {
      supported = false;
      enabled = false;
      notifyListeners();
    } on Object {
      // Transient query failure: keep the last-known state rather than
      // faking "off" while the native overlay may still be running.
      notifyListeners();
    }
  }

  Future<void> updatePetName(
    String petName, {
    BakedOverlayFrames? frames,
    List<OverlayBubbleInvitation> bubbles = const <OverlayBubbleInvitation>[],
  }) => updateConfiguration(petName: petName, frames: frames, bubbles: bubbles);

  Future<void> updateConfiguration({
    required String petName,
    BakedOverlayFrames? frames,
    List<OverlayBubbleInvitation> bubbles = const <OverlayBubbleInvitation>[],
  }) async {
    if (!supported || !enabled) return;
    try {
      await _sendConfiguration(
        petName: petName,
        frames: frames,
        bubbles: bubbles,
      );
    } on PlatformException {
      // The companion layer must never make an in-app edit fail.
    } on MissingPluginException {
      supported = false;
      enabled = false;
      notifyListeners();
    } on Object {
      // Renaming the pet remains successful if the service disappeared.
    }
  }

  Future<void> _sendConfiguration({
    required String petName,
    required BakedOverlayFrames? frames,
    required List<OverlayBubbleInvitation> bubbles,
    bool forceFrameFiles = false,
  }) async {
    final signature = _frameSignature(frames);
    final includeFrameFiles =
        forceFrameFiles ||
        !_hasSentFrameConfiguration ||
        signature != _lastFrameSignature;
    await _channel.invokeMethod<void>(
      'enable',
      buildOverlayChannelPayload(
        petName: petName,
        frames: frames,
        bubbles: bubbles,
        includeFrameFiles: includeFrameFiles,
      ),
    );
    if (includeFrameFiles) {
      _lastFrameSignature = signature;
      _hasSentFrameConfiguration = true;
    }
  }

  String _frameSignature(BakedOverlayFrames? frames) {
    if (frames == null ||
        frames.idleFiles.isEmpty ||
        frames.jumpingFiles.isEmpty) {
      return 'fallback';
    }
    return <String>[
      ...frames.idleFiles.map((file) => file.absolute.path),
      '--jumping--',
      ...frames.jumpingFiles.map((file) => file.absolute.path),
    ].join('\n');
  }

  Future<void> celebrate() async {
    if (!supported || !enabled) return;
    try {
      await _channel.invokeMethod<void>('celebrate');
    } on PlatformException {
      // Completing a task remains successful if a vendor kills the overlay.
    } on MissingPluginException {
      supported = false;
      enabled = false;
      notifyListeners();
    } on Object {
      // Completing a task remains successful if the service disappeared.
    }
  }
}
