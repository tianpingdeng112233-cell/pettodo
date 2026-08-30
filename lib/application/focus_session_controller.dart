import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/focus_economy.dart';

enum FocusSessionState { idle, running, paused, completed, abandoned }

class FocusSessionCompletion {
  const FocusSessionCompletion({
    required this.minutes,
    required this.treats,
    required this.taskId,
  });

  final int minutes;
  final int treats;
  final String? taskId;
}

typedef FocusCompletionCallback =
    Future<void> Function(FocusSessionCompletion completion);

class FocusSessionController extends ChangeNotifier
    with WidgetsBindingObserver {
  FocusSessionController({
    required this.durationMinutes,
    required this.onComplete,
    this.taskId,
    DateTime Function()? now,
    this.tickInterval = const Duration(seconds: 1),
  }) : _now = now ?? DateTime.now {
    if (durationMinutes < 5 ||
        durationMinutes > 45 ||
        durationMinutes % 5 != 0) {
      throw ArgumentError.value(durationMinutes, 'durationMinutes');
    }
    WidgetsBinding.instance.addObserver(this);
  }

  final int durationMinutes;
  final String? taskId;
  final Duration? tickInterval;
  final FocusCompletionCallback onComplete;
  final DateTime Function() _now;

  FocusSessionState _state = FocusSessionState.idle;
  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;
  Timer? _timer;
  FocusSessionCompletion? _completion;
  bool _settling = false;
  bool _disposed = false;

  FocusSessionState get state => _state;
  FocusSessionCompletion? get completion => _completion;
  Duration get duration => Duration(minutes: durationMinutes);

  Duration get elapsed {
    var value = _accumulated;
    if (_state == FocusSessionState.running && _runningSince != null) {
      final foreground = _now().difference(_runningSince!);
      if (!foreground.isNegative) value += foreground;
    }
    return value > duration ? duration : value;
  }

  Duration get remaining => duration - elapsed;

  void start() {
    if (_state != FocusSessionState.idle) return;
    _state = FocusSessionState.running;
    _runningSince = _now();
    final interval = tickInterval;
    if (interval != null) {
      _timer = Timer.periodic(interval, (_) => unawaited(tick()));
    }
    notifyListeners();
  }

  void pause() {
    if (_state != FocusSessionState.running || _settling) return;
    _captureElapsed();
    if (_accumulated >= duration) {
      unawaited(_settleCompletion());
      return;
    }
    _state = FocusSessionState.paused;
    notifyListeners();
  }

  void resume() {
    if (_state != FocusSessionState.paused) return;
    _state = FocusSessionState.running;
    _runningSince = _now();
    notifyListeners();
  }

  void abandon() {
    if (_state != FocusSessionState.running &&
        _state != FocusSessionState.paused) {
      return;
    }
    if (_state == FocusSessionState.running) _captureElapsed();
    _timer?.cancel();
    _state = FocusSessionState.abandoned;
    notifyListeners();
  }

  Future<void> tick() async {
    if (_state != FocusSessionState.running || _settling) return;
    if (elapsed >= duration) {
      _captureElapsed();
      await _settleCompletion();
      return;
    }
    notifyListeners();
  }

  void _captureElapsed() {
    final runningSince = _runningSince;
    if (runningSince == null) return;
    final foreground = _now().difference(runningSince);
    if (!foreground.isNegative) _accumulated += foreground;
    if (_accumulated > duration) _accumulated = duration;
    _runningSince = null;
  }

  Future<void> _settleCompletion() async {
    if (_settling ||
        _state == FocusSessionState.completed ||
        _state == FocusSessionState.abandoned) {
      return;
    }
    _settling = true;
    _timer?.cancel();
    final completion = FocusSessionCompletion(
      minutes: durationMinutes,
      treats: treatDropForFocus(durationMinutes),
      taskId: taskId,
    );
    _completion = completion;
    try {
      await onComplete(completion);
      _accumulated = duration;
      _state = FocusSessionState.completed;
      if (!_disposed) notifyListeners();
    } finally {
      _settling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        pause();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
