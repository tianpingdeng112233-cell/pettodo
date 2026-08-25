import 'dart:async';
import 'dart:io';

import '../data/feature_gate.dart';
import '../data/hatch_api_client.dart';

enum HatchFlowPhase {
  idle,
  locked,
  submitting,
  incubating,
  downloading,
  ready,
  failed,
  quotaExhausted,
  speciesUnsupported,
  connectionIssue,
}

class HatchFlowState {
  const HatchFlowState({
    required this.phase,
    this.hatchId,
    this.detectedSpecies,
    this.message,
    this.wishSent = false,
  });

  const HatchFlowState.idle() : this(phase: HatchFlowPhase.idle);

  final HatchFlowPhase phase;
  final String? hatchId;
  final String? detectedSpecies;
  final String? message;
  final bool wishSent;
}

typedef HatchDelay = Future<void> Function(Duration duration);
typedef HatchPackImporter = Future<void> Function(File file);
typedef HatchAccepted = Future<void> Function(String hatchId);
typedef HatchReadyNotifier = Future<void> Function();

class HatchFlowMachine {
  HatchFlowMachine({
    required HatchApi api,
    required FeatureGate featureGate,
    required HatchPackImporter importPack,
    HatchDelay? delay,
    HatchAccepted? onAccepted,
    HatchReadyNotifier? onReady,
    void Function()? onChanged,
  }) : // Named public parameters keep injection readable at call sites.
       // ignore: prefer_initializing_formals
       _api = api,
       // ignore: prefer_initializing_formals
       _featureGate = featureGate,
       // ignore: prefer_initializing_formals
       _importPack = importPack,
       _delayOverride = delay,
       // ignore: prefer_initializing_formals
       _onAccepted = onAccepted,
       // ignore: prefer_initializing_formals
       _onReady = onReady,
       // ignore: prefer_initializing_formals
       _onChanged = onChanged;

  final HatchApi _api;
  final FeatureGate _featureGate;
  final HatchPackImporter _importPack;
  final HatchDelay? _delayOverride;
  Timer? _activeTimer;
  final HatchAccepted? _onAccepted;
  final HatchReadyNotifier? _onReady;
  final void Function()? _onChanged;

  HatchFlowState state = const HatchFlowState.idle();
  int _run = 0;
  // the run that owns the currently live submit/poll loop; pause() bumps
  // _run, so a mismatch means "no live loop" even if the phase looks busy
  int _loopRun = -1;
  bool _foreground = true;
  bool _disposed = false;
  // an import is uncancellable work: while it runs, no new loop may start
  // even if pause() has orphaned the owning run
  bool _importing = false;
  // the run that currently owns the uncancellable download/import section;
  // only the owner (or the current run) may write a terminal outcome
  int _downloadOwner = -1;
  Completer<void>? _wakeUp;

  Future<void> submit({
    required List<File> photos,
    required String petName,
  }) async {
    // a hatch is already in flight: a second tap must not spend a second
    // quota slot or race the first onAccepted
    if (_inFlight) return;
    final run = ++_run;
    _loopRun = run;
    _downloadOwner = -1; // a new live run revokes any stale ownership
    _foreground = true;
    _cancelWait();
    // mark in-flight synchronously — the double-tap guard reads this phase
    // and must not race the async gate check below
    _setState(const HatchFlowState(phase: HatchFlowPhase.submitting));
    if (!await _featureGate.isUnlocked()) {
      if (_mayReport(run)) {
        _downloadOwner = -1;
        _setState(const HatchFlowState(phase: HatchFlowPhase.locked));
      }
      return;
    }
    try {
      final submission = await _api.submitHatch(
        photos: photos,
        petName: petName,
      );
      // persist the accepted hatchId even if the app was backgrounded while
      // the POST was in flight — losing it would strand the quota slot
      await _onAccepted?.call(submission.hatchId);
      if (_disposed) return;
      if (!_isActive(run)) {
        if (_foreground) {
          // paused and already resumed while the POST was in flight: nobody
          // else knows this hatch exists yet, so pick it up under a new run
          unawaited(resume(submission.hatchId));
        }
        return;
      }
      _setState(
        HatchFlowState(
          phase: HatchFlowPhase.incubating,
          hatchId: submission.hatchId,
        ),
      );
      await _poll(submission.hatchId, run);
    } on HatchApiException catch (error) {
      if (_mayReport(run)) {
        _downloadOwner = -1;
        _setApiError(error);
      }
    } on Object {
      if (_mayReport(run)) {
        _downloadOwner = -1;
        _setState(
          const HatchFlowState(
            phase: HatchFlowPhase.connectionIssue,
            message:
                'The adoption center is quiet right now. Your request is safe here to try again.',
          ),
        );
      }
    }
  }

  Future<void> resume(String hatchId) async {
    // idempotent per hatch: the mid-submit self-heal and onResume() may both
    // ask for the same hatch — one polling loop is enough
    if (_inFlight && state.hatchId == hatchId) return;
    final run = ++_run;
    _loopRun = run;
    _downloadOwner = -1; // a new live run revokes any stale ownership
    _foreground = true;
    _cancelWait();
    _setState(
      HatchFlowState(phase: HatchFlowPhase.incubating, hatchId: hatchId),
    );
    try {
      await _poll(hatchId, run);
    } on HatchApiException catch (error) {
      if (_mayReport(run)) {
        _downloadOwner = -1;
        _setApiError(error);
      }
    } on Object {
      if (_mayReport(run)) {
        _downloadOwner = -1;
        _setState(
          HatchFlowState(
            phase: HatchFlowPhase.connectionIssue,
            hatchId: hatchId,
            message:
                'The adoption center is quiet right now. Your request is safe here to try again.',
          ),
        );
      }
    }
  }

  /// The app is foreground again; an in-flight POST from before the pause
  /// may still land and will self-heal into a fresh polling run.
  void resumeForeground() {
    _foreground = true;
  }

  void pause() {
    _foreground = false;
    _run++;
    _cancelWait();
  }

  void dispose() {
    _disposed = true;
    _run++;
    _cancelWait();
  }

  void _cancelWait() {
    _cancelTimer();
    final wakeUp = _wakeUp;
    if (wakeUp != null && !wakeUp.isCompleted) wakeUp.complete();
  }

  HatchDelay get _delay => _delayOverride ?? _timerDelay;

  Future<void> _wait(Duration duration) {
    final wakeUp = _wakeUp = Completer<void>();
    return Future.any(<Future<void>>[_delay(duration), wakeUp.future]);
  }

  // default delay backed by a real cancellable Timer so pause/dispose does
  // not leave a stray timer alive for up to 60 seconds
  Future<void> _timerDelay(Duration duration) {
    final completer = Completer<void>();
    final timer = Timer(duration, completer.complete);
    _activeTimer = timer;
    return completer.future;
  }

  void _cancelTimer() {
    _activeTimer?.cancel();
    _activeTimer = null;
  }

  Future<void> submitSpeciesWish(String speciesText) async {
    try {
      await _api.submitSpeciesWish(speciesText);
      _setState(
        HatchFlowState(
          phase: state.phase,
          hatchId: state.hatchId,
          detectedSpecies: state.detectedSpecies,
          message: state.message,
          wishSent: true,
        ),
      );
    } on HatchApiException catch (error) {
      _setState(
        HatchFlowState(
          phase: state.phase,
          hatchId: state.hatchId,
          detectedSpecies: state.detectedSpecies,
          message: error.userMessage,
        ),
      );
    }
  }

  Future<void> _poll(String hatchId, int run) async {
    var interval = const Duration(seconds: 15);
    while (_isActive(run)) {
      final response = await _api.getHatchStatus(hatchId);
      if (!_isActive(run)) return;
      switch (response.status) {
        case HatchRemoteStatus.incubating:
          await _wait(interval);
          final nextSeconds = interval.inSeconds * 2;
          interval = Duration(seconds: nextSeconds.clamp(15, 60));
          continue;
        case HatchRemoteStatus.ready:
          final packUrl = response.packUrl;
          if (packUrl == null) throw const HatchServiceIssue();
          _downloadOwner = run;
          _setState(
            HatchFlowState(phase: HatchFlowPhase.downloading, hatchId: hatchId),
          );
          final pack = await _api.downloadPack(packUrl);
          // only the run that set _importing may clear it — a stale run's
          // finally must never release a live run's import lock
          var importStarted = false;
          try {
            if (!_isActive(run)) return;
            _importing = true;
            importStarted = true;
            await _importPack(pack);
          } finally {
            if (importStarted) _importing = false;
            if (_downloadOwner == run && !importStarted) _downloadOwner = -1;
            if (await pack.exists()) await pack.delete();
          }
          // the import genuinely finished: the terminal state and the
          // notification are truthful even if a pause orphaned this run
          if (_downloadOwner == run) _downloadOwner = -1;
          if (_disposed) return;
          await _onReady?.call();
          _setState(
            HatchFlowState(phase: HatchFlowPhase.ready, hatchId: hatchId),
          );
          return;
        case HatchRemoteStatus.failed:
          _setState(
            HatchFlowState(
              phase: HatchFlowPhase.failed,
              hatchId: hatchId,
              message:
                  'This hatch could not finish. Your saved photos can be tried again whenever you like.',
            ),
          );
          return;
      }
    }
  }

  bool get _inFlight =>
      _importing ||
      (_foreground &&
          _loopRun == _run &&
          (state.phase == HatchFlowPhase.submitting ||
              state.phase == HatchFlowPhase.incubating ||
              state.phase == HatchFlowPhase.downloading));

  bool _isActive(int run) => _foreground && _isCurrent(run);

  // a loop that reached uncancellable work (visible as downloading) must be
  // allowed to write its terminal outcome even if pause orphaned its run —
  // otherwise the UI would stay on "downloading" forever
  bool _mayReport(int run) =>
      !_disposed && (_isCurrent(run) || _downloadOwner == run);

  bool _isCurrent(int run) => run == _run;

  void _setApiError(HatchApiException error) {
    switch (error) {
      case HatchQuotaExhausted():
        _setState(
          HatchFlowState(
            phase: HatchFlowPhase.quotaExhausted,
            message: error.userMessage,
          ),
        );
        return;
      case HatchSpeciesUnsupported(:final detectedSpecies):
        _setState(
          HatchFlowState(
            phase: HatchFlowPhase.speciesUnsupported,
            detectedSpecies: detectedSpecies,
            message: error.userMessage,
          ),
        );
        return;
      case HatchInvalidPhotos():
        _setState(
          HatchFlowState(
            phase: HatchFlowPhase.failed,
            message: error.userMessage,
          ),
        );
        return;
      case HatchConnectionIssue():
        _setState(
          HatchFlowState(
            phase: HatchFlowPhase.connectionIssue,
            hatchId: state.hatchId,
            message: error.userMessage,
          ),
        );
        return;
      case HatchServiceIssue():
        _setState(
          HatchFlowState(
            phase: HatchFlowPhase.failed,
            hatchId: state.hatchId,
            message: error.userMessage,
          ),
        );
        return;
    }
  }

  void _setState(HatchFlowState value) {
    if (_disposed) return; // never notify a disposed listener
    state = value;
    _onChanged?.call();
  }
}
