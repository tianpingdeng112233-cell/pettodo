import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String overlayChannelName = 'com.davidshi.pettodo/overlay';

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

  Future<void> initialize({required String petName}) async {
    try {
      supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
      if (!supported) return;
      enabled = await _channel.invokeMethod<bool>('isEnabled') ?? false;
      if (enabled) {
        await _channel.invokeMethod<void>('enable', <String, Object?>{
          'petName': petName,
        });
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
  Future<bool> setEnabled(bool value, {required String petName}) async {
    if (!supported || busy) return enabled;
    busy = true;
    notifyListeners();
    try {
      if (!value) {
        await _channel.invokeMethod<void>('disable');
        enabled = false;
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

      await _channel.invokeMethod<void>('enable', <String, Object?>{
        'petName': petName,
      });
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

  Future<void> refresh({required String petName}) async {
    if (!supported) return;
    try {
      enabled = await _channel.invokeMethod<bool>('isEnabled') ?? false;
      if (enabled) {
        await _channel.invokeMethod<void>('enable', <String, Object?>{
          'petName': petName,
        });
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

  Future<void> updatePetName(String petName) async {
    if (!supported || !enabled) return;
    try {
      await _channel.invokeMethod<void>('enable', <String, Object?>{
        'petName': petName,
      });
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
