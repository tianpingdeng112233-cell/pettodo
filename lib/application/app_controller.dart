import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/app_state_store.dart';
import '../data/event_log_store.dart';
import '../data/notification_service.dart';
import '../domain/app_state.dart';
import '../domain/day_rollover.dart';
import '../domain/event_log.dart';
import '../domain/growth.dart';
import '../domain/pet_schedule.dart';
import '../domain/treat_economy.dart';
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
  Timer? _theaterTimer;
  Timer? _dayBoundaryTimer;
  Timer? _scheduleTimer;
  final math.Random _random = math.Random();

  late AppState state;
  late List<PetAssetDescriptor> pets;
  late List<DecorAssetDescriptor> decorations;
  late LoadedSpriteAtlas spriteAtlas;
  late PetScheduleEntry currentSchedule;
  String petAnimation = 'idle';
  int? petAnimationFrame;
  String? affectionateMessage;
  String? momentStatus;
  String? momentParticle;
  DecorUnlock? activeUnlock;
  bool theaterVisible = false;
  int celebrationNonce = 0;
  int particleNonce = 0;
  int treatDropNonce = 0;
  int lastTreatDrop = 0;

  PetGrowthStage get growthStage => growthStageFor(state.lifetimeCompletions);

  PetAssetDescriptor get selectedPet => pets.firstWhere(
    (pet) => pet.id == state.selectedPetId,
    orElse: () => pets.first,
  );

  String get statusLine {
    if (momentStatus != null) return momentStatus!;
    if (affectionateMessage != null) return affectionateMessage!;
    if (state.isFedOn(DateTime.now())) {
      return '${state.petName} is happily full and feeling wonderful';
    }
    return currentSchedule.statusFor(state.petName);
  }

  bool get scheduleShowsZzz =>
      momentStatus == null &&
      _animationTimer?.isActive != true &&
      currentSchedule.effect == PetScheduleEffect.zzz;

  Future<void> initialize() async {
    final now = DateTime.now();
    state = rollOverIfNeeded(await _stateStore.load(now), now);
    pets = await _spriteLoader.loadManifest();
    decorations = await _spriteLoader.loadDecorManifest();
    currentSchedule = petScheduleAt(now);
    petAnimation = currentSchedule.animation;
    petAnimationFrame = currentSchedule.fixedFrame;
    spriteAtlas = await _spriteLoader.loadPet(
      selectedPet,
      growthStage: growthStage.name,
    );
    await _stateStore.save(state);
    await _log(PetEventType.appOpen);
    await _refreshNotificationSchedule();
    _scheduleDayBoundary();
    _scheduleScheduleBoundary();
  }

  Future<void> onResume() async {
    final rolled = rollOverIfNeeded(state, DateTime.now());
    if (!identical(rolled, state)) {
      _cancelMomentTimers();
      state = rolled;
      theaterVisible = false;
      activeUnlock = null;
      _applySchedule(DateTime.now());
      await _stateStore.save(state);
      notifyListeners();
    }
    await _log(PetEventType.appOpen);
    await _refreshNotificationSchedule();
    _scheduleDayBoundary();
    _applySchedule(DateTime.now());
    _scheduleScheduleBoundary();
    notifyListeners();
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
      spriteAtlas = await _spriteLoader.loadPet(
        descriptor,
        growthStage: growthStage.name,
      );
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
    final newStages = stagesCrossed(before, after);
    final unlocked = <String>{...state.unlockedDecorIds};
    unlocked.addAll(newUnlocks.map((item) => item.id));
    final allDoneAfter = checks.every((value) => value);
    final treatDrop = treatDropForCompletion(
      completesDailySet: allDoneAfter && !wasAllDone,
    );
    state = awardTreats(
      state.copyWith(
        completedToday: checks,
        lifetimeCompletions: after,
        unlockedDecorIds: unlocked.toList(growable: false),
      ),
      treatDrop,
    );
    lastTreatDrop = treatDrop;
    treatDropNonce++;
    await _stateStore.save(state);
    await _log(PetEventType.taskComplete, <String, Object?>{
      'taskIndex': index,
      'treatDrop': treatDrop,
    });
    if (!wasAllDone && state.allDone) {
      await _log(PetEventType.allDone);
      affectionateMessage =
          '${state.petName} nuzzles you happily — thank you for today';
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
    for (final stage in newStages) {
      await _log(PetEventType.stageUp, <String, Object?>{
        'stage': stage.name,
        'lifetimeCompletions': after,
      });
    }
    if (newStages.isNotEmpty && selectedPet.stageAssets.isNotEmpty) {
      final previous = spriteAtlas;
      spriteAtlas = await _spriteLoader.loadPet(
        selectedPet,
        growthStage: growthStage.name,
      );
      previous.image.dispose();
    }
    _playCompletionAnimation(newUnlocks);
    notifyListeners();
    return true;
  }

  Future<bool> feedTreat() async {
    final now = DateTime.now();
    state = rollOverIfNeeded(state, now);
    final next = spendTreatToFeed(state, now);
    if (next == null) return false;
    state = next;
    await _stateStore.save(state);
    await _log(PetEventType.treatFeed, <String, Object?>{
      'treat': selectedPet.treatName,
      'remaining': state.treats,
    });
    _playMoment(
      animation: 'waving',
      status:
          '${state.petName} savors the ${selectedPet.treatName.toLowerCase()}',
      particle: selectedPet.treatEmoji,
    );
    notifyListeners();
    return true;
  }

  Future<void> touchPet({required double dx, required double dy}) async {
    final degrees = (math.atan2(dx, -dy) * 180 / math.pi + 360) % 360;
    final direction = (degrees / 22.5).round() % 16;
    petAnimation = direction < 8 ? 'look-row-9' : 'look-row-10';
    petAnimationFrame = direction % 8;
    affectionateMessage =
        _affectionateLines[_random.nextInt(_affectionateLines.length)]
            .replaceAll('{petName}', state.petName);
    await _log(PetEventType.petTouch, <String, Object?>{
      'kind': 'tap',
      'direction': direction,
    });
    _holdTouchReaction();
    notifyListeners();
  }

  Future<void> nuzzlePet() async {
    affectionateMessage =
        '${state.petName} leans in close and gives you a gentle nuzzle';
    await _log(PetEventType.petTouch, const <String, Object?>{
      'kind': 'long_press',
    });
    _playMoment(animation: 'waving', particle: '♥');
    _holdMessage();
    notifyListeners();
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
    _theaterTimer?.cancel();
    if (newUnlocks.isNotEmpty) {
      _bannerTimer?.cancel();
      activeUnlock = newUnlocks.last;
      _bannerTimer = Timer(const Duration(milliseconds: 2800), () {
        activeUnlock = null;
        notifyListeners();
      });
    }
    petAnimation = 'jumping';
    petAnimationFrame = null;
    momentParticle = '+$lastTreatDrop ${selectedPet.treatEmoji}';
    particleNonce++;
    if (state.allDone) {
      _theaterTimer = Timer(const Duration(milliseconds: 900), () {
        theaterVisible = true;
        petAnimation = 'review';
        petAnimationFrame = null;
        notifyListeners();
      });
    } else {
      _animationTimer = Timer(
        const Duration(milliseconds: 2000),
        _returnToSchedule,
      );
    }
  }

  void dismissTheater() {
    theaterVisible = false;
    affectionateMessage = null;
    _returnToSchedule();
  }

  void _returnToSchedule() {
    momentStatus = null;
    momentParticle = null;
    _applySchedule(DateTime.now());
    notifyListeners();
  }

  void _scheduleDayBoundary() {
    _dayBoundaryTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _dayBoundaryTimer = Timer(tomorrow.difference(now), () async {
      _cancelMomentTimers();
      state = rollOverIfNeeded(state, DateTime.now());
      theaterVisible = false;
      activeUnlock = null;
      _applySchedule(DateTime.now());
      await _stateStore.save(state);
      notifyListeners();
      _scheduleDayBoundary();
      _scheduleScheduleBoundary();
    });
  }

  void _applySchedule(DateTime now) {
    currentSchedule = petScheduleAt(now);
    if (theaterVisible ||
        momentStatus != null ||
        _animationTimer?.isActive == true ||
        _theaterTimer?.isActive == true) {
      return;
    }
    petAnimation = currentSchedule.animation;
    petAnimationFrame = currentSchedule.fixedFrame;
  }

  void _scheduleScheduleBoundary() {
    _scheduleTimer?.cancel();
    final now = DateTime.now();
    final entry = petScheduleAt(now);
    var boundary = DateTime(now.year, now.month, now.day, entry.endHour);
    if (!boundary.isAfter(now)) {
      boundary = boundary.add(const Duration(days: 1));
    }
    _scheduleTimer = Timer(boundary.difference(now), () {
      _applySchedule(DateTime.now());
      notifyListeners();
      _scheduleScheduleBoundary();
    });
  }

  void _playMoment({
    required String animation,
    String? status,
    String? particle,
  }) {
    _animationTimer?.cancel();
    petAnimation = animation;
    petAnimationFrame = null;
    momentStatus = status;
    momentParticle = particle;
    if (particle != null) particleNonce++;
    _animationTimer = Timer(
      const Duration(milliseconds: 2000),
      _returnToSchedule,
    );
  }

  void _holdTouchReaction() {
    _animationTimer?.cancel();
    _animationTimer = Timer(
      const Duration(milliseconds: 1400),
      _returnToSchedule,
    );
    _holdMessage();
  }

  void _holdMessage() {
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 5), () {
      affectionateMessage = null;
      notifyListeners();
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

  void _cancelMomentTimers() {
    _animationTimer?.cancel();
    _messageTimer?.cancel();
    _bannerTimer?.cancel();
    _theaterTimer?.cancel();
    affectionateMessage = null;
    momentStatus = null;
    momentParticle = null;
  }

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
    _cancelMomentTimers();
    _dayBoundaryTimer?.cancel();
    _scheduleTimer?.cancel();
    spriteAtlas.image.dispose();
    super.dispose();
  }
}

const List<String> _affectionateLines = <String>[
  '{petName} noticed you right away',
  '{petName} is always glad when you visit',
  '{petName} scoots a little closer to you',
  '{petName} gives you the softest hello',
  '{petName} thinks this is a lovely moment together',
  '{petName} is listening with both ears',
  '{petName} has been saving this smile for you',
  '{petName} looks at you with bright, curious eyes',
  '{petName} would happily sit beside you awhile',
  '{petName} gives a tiny, delighted tail wag',
  '{petName} says your company makes home feel warm',
  '{petName} is very pleased to see your face',
  '{petName} settles nearby, content and cozy',
  '{petName} sends a little pocket of warmth your way',
];
