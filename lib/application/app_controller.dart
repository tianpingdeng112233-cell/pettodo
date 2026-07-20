import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_state_store.dart';
import '../data/event_log_store.dart';
import '../data/notification_service.dart';
import '../domain/app_state.dart';
import '../domain/day_rollover.dart';
import '../domain/event_log.dart';
import '../domain/unlocks.dart';
import '../sprite/sprite_atlas.dart';

class AppController extends ChangeNotifier {
  factory AppController({
    required AppStateStore stateStore,
    required EventLogStore eventLog,
    required NotificationService notifications,
    SpriteAtlasLoader? spriteLoader,
  }) => AppController._(
    stateStore,
    eventLog,
    notifications,
    spriteLoader ?? SpriteAtlasLoader(),
  );

  AppController._(
    this._stateStore,
    this._eventLog,
    this._notifications,
    this._spriteLoader,
  );

  final AppStateStore _stateStore;
  final EventLogStore _eventLog;
  final NotificationService _notifications;
  final SpriteAtlasLoader _spriteLoader;
  Timer? _animationTimer;
  Timer? _messageTimer;
  Timer? _bannerTimer;
  Timer? _dayBoundaryTimer;

  late AppState state;
  late List<PetAssetDescriptor> pets;
  late LoadedSpriteAtlas spriteAtlas;
  String petAnimation = 'idle';
  String? affectionateMessage;
  String? unlockBanner;
  int celebrationNonce = 0;

  Future<void> initialize() async {
    final now = DateTime.now();
    state = rollOverIfNeeded(await _stateStore.load(now), now);
    pets = await _spriteLoader.loadManifest();
    final descriptor = pets.firstWhere(
      (pet) => pet.id == state.selectedPetId,
      orElse: () => pets.first,
    );
    spriteAtlas = await _spriteLoader.loadPet(descriptor);
    await _stateStore.save(state);
    await _log(PetEventType.appOpen);
    await _refreshNotificationSchedule();
    _scheduleDayBoundary();
  }

  Future<void> onResume() async {
    final rolled = rollOverIfNeeded(state, DateTime.now());
    if (!identical(rolled, state)) {
      state = rolled;
      await _stateStore.save(state);
      notifyListeners();
    }
    await _log(PetEventType.appOpen);
    await _refreshNotificationSchedule();
    _scheduleDayBoundary();
  }

  Future<void> completeOnboarding({
    required String selectedPetId,
    required String petName,
    required List<String> taskTitles,
    required bool enableNotifications,
    required int notificationHour,
    required int notificationMinute,
  }) async {
    if (taskTitles.length != 3) throw ArgumentError('Exactly 3 tasks required');
    var permission = state.notificationPermission;
    var enabled = false;
    if (enableNotifications &&
        permission != NotificationPermissionState.denied) {
      final granted = await _notifications.requestPermission();
      permission = granted
          ? NotificationPermissionState.granted
          : NotificationPermissionState.denied;
      enabled = granted;
    }
    state = state.copyWith(
      onboardingComplete: true,
      selectedPetId: selectedPetId,
      petName: _normalized(petName, 'Choco'),
      taskTitles: _normalizedTasks(taskTitles),
      notificationPermission: permission,
      notificationEnabled: enabled,
      notificationHour: notificationHour,
      notificationMinute: notificationMinute,
    );
    if (spriteAtlas.descriptor.id != selectedPetId) {
      final descriptor = pets.firstWhere((pet) => pet.id == selectedPetId);
      final previous = spriteAtlas;
      spriteAtlas = await _spriteLoader.loadPet(descriptor);
      previous.image.dispose();
    }
    await _stateStore.save(state);
    await _refreshNotificationSchedule();
    notifyListeners();
  }

  Future<bool> completeTask(int index) async {
    state = rollOverIfNeeded(state, DateTime.now());
    if (index < 0 || index >= 3 || state.completedToday[index]) return false;
    final wasAllDone = state.allDone;
    final checks = List<bool>.of(state.completedToday)..[index] = true;
    final before = state.lifetimeCompletions;
    final after = before + 1;
    final newUnlocks = unlocksCrossed(before, after);
    final unlocked = <String>{...state.unlockedDecorIds};
    unlocked.addAll(newUnlocks.map((item) => item.id));
    state = state.copyWith(
      completedToday: checks,
      lifetimeCompletions: after,
      unlockedDecorIds: unlocked.toList(growable: false),
    );
    await _stateStore.save(state);
    await _log(PetEventType.taskComplete, <String, Object?>{
      'taskIndex': index,
    });
    if (!wasAllDone && state.allDone) {
      await _log(PetEventType.allDone);
      affectionateMessage = '${state.petName} 满足地蹭了蹭你';
      celebrationNonce++;
      _messageTimer?.cancel();
      _messageTimer = Timer(const Duration(seconds: 5), () {
        affectionateMessage = null;
        notifyListeners();
      });
    }
    for (final unlock in newUnlocks) {
      await _log(PetEventType.unlock, <String, Object?>{
        'decorId': unlock.id,
        'threshold': unlock.threshold,
      });
    }
    _playCompletionAnimation(newUnlocks);
    notifyListeners();
    return true;
  }

  Future<void> updatePetName(String value) async {
    state = state.copyWith(petName: _normalized(value, state.petName));
    await _stateStore.save(state);
    await _refreshNotificationSchedule();
    notifyListeners();
  }

  Future<void> updateTaskTitle(int index, String value) async {
    if (index < 0 || index >= 3) return;
    final tasks = List<String>.of(state.taskTitles);
    tasks[index] = _normalized(value, tasks[index]);
    state = state.copyWith(taskTitles: tasks);
    await _stateStore.save(state);
    notifyListeners();
  }

  Future<void> updateNotificationTime(int hour, int minute) async {
    state = state.copyWith(notificationHour: hour, notificationMinute: minute);
    await _stateStore.save(state);
    await _refreshNotificationSchedule();
    notifyListeners();
  }

  Future<void> setNotificationEnabled(bool enabled) async {
    if (!enabled) {
      state = state.copyWith(notificationEnabled: false);
      await _stateStore.save(state);
      await _notifications.cancelDaily();
      notifyListeners();
      return;
    }
    if (state.notificationPermission == NotificationPermissionState.denied) {
      return;
    }
    var permission = state.notificationPermission;
    if (permission == NotificationPermissionState.notRequested) {
      final granted = await _notifications.requestPermission();
      permission = granted
          ? NotificationPermissionState.granted
          : NotificationPermissionState.denied;
    }
    final canEnable = permission == NotificationPermissionState.granted;
    state = state.copyWith(
      notificationPermission: permission,
      notificationEnabled: canEnable,
    );
    await _stateStore.save(state);
    if (canEnable) await _refreshNotificationSchedule();
    notifyListeners();
  }

  void _playCompletionAnimation(List<DecorUnlock> newUnlocks) {
    _animationTimer?.cancel();
    _bannerTimer?.cancel();
    if (newUnlocks.isNotEmpty) {
      final unlock = newUnlocks.last;
      unlockBanner = '解锁了「${unlock.name}」${unlock.emoji}';
      petAnimation = 'waving';
      _bannerTimer = Timer(const Duration(seconds: 4), () {
        unlockBanner = null;
        notifyListeners();
      });
      _animationTimer = Timer(const Duration(milliseconds: 2200), () {
        if (state.allDone) {
          petAnimation = 'review';
          notifyListeners();
          _animationTimer = Timer(const Duration(seconds: 3), _returnToIdle);
        } else {
          _returnToIdle();
        }
      });
      return;
    }
    petAnimation = state.allDone ? 'review' : 'jumping';
    _animationTimer = Timer(
      Duration(milliseconds: state.allDone ? 3200 : 2000),
      _returnToIdle,
    );
  }

  void _returnToIdle() {
    petAnimation = 'idle';
    notifyListeners();
  }

  void _scheduleDayBoundary() {
    _dayBoundaryTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _dayBoundaryTimer = Timer(tomorrow.difference(now), () async {
      state = rollOverIfNeeded(state, DateTime.now());
      await _stateStore.save(state);
      notifyListeners();
      _scheduleDayBoundary();
    });
  }

  Future<void> _refreshNotificationSchedule() async {
    if (!state.notificationEnabled ||
        state.notificationPermission != NotificationPermissionState.granted) {
      return;
    }
    await _notifications.scheduleDaily(
      petName: state.petName,
      hour: state.notificationHour,
      minute: state.notificationMinute,
    );
  }

  Future<void> _log(PetEventType type, [Map<String, Object?>? data]) =>
      _eventLog.append(
        PetEvent(type: type, timestamp: DateTime.now(), data: data),
      );

  static String _normalized(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static List<String> _normalizedTasks(List<String> values) => List.generate(
    3,
    (index) => _normalized(values[index], defaultTaskTitles[index]),
    growable: false,
  );

  @override
  void dispose() {
    _animationTimer?.cancel();
    _messageTimer?.cancel();
    _bannerTimer?.cancel();
    _dayBoundaryTimer?.cancel();
    spriteAtlas.image.dispose();
    super.dispose();
  }
}
