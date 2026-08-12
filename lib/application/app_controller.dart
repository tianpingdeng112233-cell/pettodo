import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/app_state_store.dart';
import '../data/event_log_store.dart';
import '../data/hatch_request_store.dart';
import '../data/notification_service.dart';
import '../data/pet_pack_service.dart';
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
    HatchRequestStore? hatchRequestStore,
    PetPackService? petPackService,
  }) => AppController._(
    stateStore,
    eventLog,
    notifications,
    spriteLoader ?? SpriteAtlasLoader(),
    hatchRequestStore ?? HatchRequestStore.onDevice(),
    petPackService ?? PetPackService.onDevice(),
  );

  AppController._(
    this._stateStore,
    this._eventLog,
    this._notifications,
    this._spriteLoader,
    this._hatchRequestStore,
    this._petPackService,
  );

  final AppStateStore _stateStore;
  final EventLogStore _eventLog;
  final NotificationService _notifications;
  final SpriteAtlasLoader _spriteLoader;
  final HatchRequestStore _hatchRequestStore;
  final PetPackService _petPackService;
  final Map<String, LoadedSpriteAtlas> _spriteCache =
      <String, LoadedSpriteAtlas>{};
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
  HatchRequest? pendingHatchRequest;
  String? hatchCeremonyPetName;
  int _taskIdNonce = 0;

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
    final bundledPets = await _spriteLoader.loadManifest();
    List<PetAssetDescriptor> installedPets;
    try {
      installedPets = await _petPackService.loadInstalledPets();
      pendingHatchRequest = await _hatchRequestStore.load();
    } on Object {
      installedPets = const <PetAssetDescriptor>[];
      pendingHatchRequest = null;
    }
    pets = mergePetRegistry(bundledPets, installedPets);
    if (!pets.any((pet) => pet.id == state.selectedPetId)) {
      state = state.copyWith(selectedPetId: pets.first.id);
    }
    decorations = await _spriteLoader.loadDecorManifest();
    currentSchedule = petScheduleAt(now);
    petAnimation = currentSchedule.animation;
    petAnimationFrame = currentSchedule.fixedFrame;
    spriteAtlas = await _spriteLoader.loadPet(
      selectedPet,
      growthStage: growthStage.name,
    );
    _spriteCache[selectedPet.id] = spriteAtlas;
    await _stateStore.save(state);
    await _log(PetEventType.appOpen);
    await _refreshNotificationSchedule();
    _scheduleDayBoundary();
    _scheduleScheduleBoundary();
  }

  Future<HatchRequest> createHatchRequest({
    required List<File> photos,
    required String petName,
  }) async {
    pendingHatchRequest = await _hatchRequestStore.create(
      photos: photos,
      petName: petName,
    );
    notifyListeners();
    return pendingHatchRequest!;
  }

  Future<File> exportHatchRequest() => _hatchRequestStore.export();

  Future<void> cancelHatchRequest() async {
    await _hatchRequestStore.cancel();
    pendingHatchRequest = null;
    notifyListeners();
  }

  Future<PetAssetDescriptor> importPetPack(File file) async {
    final installed = await _petPackService.install(file);
    final descriptor = installed.descriptor;
    final existingIndex = pets.indexWhere((pet) => pet.id == descriptor.id);
    if (existingIndex < 0) {
      pets = <PetAssetDescriptor>[...pets, descriptor];
    } else {
      pets = <PetAssetDescriptor>[
        ...pets.take(existingIndex),
        descriptor,
        ...pets.skip(existingIndex + 1),
      ];
    }
    final loaded = await _spriteLoader.loadPet(
      descriptor,
      growthStage: growthStage.name,
    );
    // Swap before disposing: the old atlas may be the one on screen right now.
    final cached = _spriteCache.remove(descriptor.id);
    _spriteCache[descriptor.id] = loaded;
    spriteAtlas = loaded;
    cached?.image.dispose();
    state = state.copyWith(
      selectedPetId: descriptor.id,
      petName: descriptor.displayName,
    );
    await _stateStore.save(state);
    if (await _hatchRequestStore.clearIfMatchingPack(
      requestId: installed.requestId,
      displayName: descriptor.displayName,
    )) {
      pendingHatchRequest = null;
    }
    _cancelMomentTimers();
    hatchCeremonyPetName = descriptor.displayName;
    theaterVisible = true;
    petAnimation = 'review';
    petAnimationFrame = null;
    celebrationNonce++;
    await _refreshNotificationSchedule();
    notifyListeners();
    return descriptor;
  }

  Future<LoadedSpriteAtlas> petAtlas(PetAssetDescriptor descriptor) async {
    final cached = _spriteCache[descriptor.id];
    if (cached != null) return cached;
    final loaded = await _spriteLoader.loadPet(
      descriptor,
      growthStage: growthStage.name,
    );
    _spriteCache[descriptor.id] = loaded;
    return loaded;
  }

  Future<void> selectPet(String id) async {
    final descriptor = pets.firstWhere((pet) => pet.id == id);
    spriteAtlas = await petAtlas(descriptor);
    state = state.copyWith(
      selectedPetId: descriptor.id,
      petName: descriptor.displayName,
    );
    await _stateStore.save(state);
    await _refreshNotificationSchedule();
    _applySchedule(DateTime.now());
    notifyListeners();
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
    if (taskTitles.length < minimumTaskCount ||
        taskTitles.length > maximumTaskCount) {
      throw ArgumentError('Choose between 1 and 7 little things.');
    }
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
      petName: _normalized(
        petName,
        pets.firstWhere((pet) => pet.id == selectedPetId).displayName,
      ),
      tasks: List<TodoTask>.generate(
        taskTitles.length,
        (index) => TodoTask(
          id: 'daily-${index + 1}',
          title: _normalized(
            taskTitles[index],
            defaultTaskTitles[index % defaultTaskTitles.length],
          ),
          kind: TaskKind.daily,
        ),
        growable: false,
      ),
      notificationPermission: permission,
      notificationEnabled: enabled,
      notificationHour: notificationHour,
      notificationMinute: notificationMinute,
    );
    if (spriteAtlas.descriptor.id != selectedPetId) {
      final descriptor = pets.firstWhere((pet) => pet.id == selectedPetId);
      spriteAtlas = await petAtlas(descriptor);
    }
    await _stateStore.save(state);
    await _refreshNotificationSchedule();
    notifyListeners();
  }

  Future<bool> completeTask(String taskId) async {
    state = rollOverIfNeeded(state, DateTime.now());
    final task = state.taskById(taskId);
    if (task == null || task.isComplete) return false;
    final isDaily = task.kind == TaskKind.daily;
    final wasAllDailyDone = state.allDailyDone;
    final completedAt = DateTime.now();
    var tasks = state.tasks
        .map(
          (item) => item.id != taskId
              ? item
              : isDaily
              ? item.copyWith(completedToday: true)
              : item.copyWith(completedAt: completedAt),
        )
        .toList(growable: false);
    final before = state.lifetimeCompletions;
    final after = before + 1;
    final newUnlocks = unlocksCrossed(before, after);
    final newStages = stagesCrossed(before, after);
    final unlocked = <String>{...state.unlockedDecorIds};
    unlocked.addAll(newUnlocks.map((item) => item.id));
    final allDailyDoneAfter = tasks
        .where((item) => item.kind == TaskKind.daily)
        .every((item) => item.completedToday);
    final hasDailyTasks = tasks.any((item) => item.kind == TaskKind.daily);
    final completesDailySet =
        isDaily && hasDailyTasks && allDailyDoneAfter && !wasAllDailyDone;
    final treatDrop = treatDropForCompletion(
      completesDailySet: completesDailySet,
    );
    if (!isDaily) {
      tasks = tasks.where((item) => item.id != taskId).toList(growable: false);
    }
    state = awardTreats(
      state.copyWith(
        tasks: tasks,
        lifetimeCompletions: after,
        unlockedDecorIds: unlocked.toList(growable: false),
      ),
      treatDrop,
    );
    lastTreatDrop = treatDrop;
    treatDropNonce++;
    await _stateStore.save(state);
    await _log(
      isDaily ? PetEventType.taskComplete : PetEventType.oneoffComplete,
      <String, Object?>{
        'taskId': task.id,
        'title': task.title,
        'kind': task.kind.name,
        'treatDrop': treatDrop,
      },
    );
    if (completesDailySet) {
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
      final previous = _spriteCache.remove(selectedPet.id);
      spriteAtlas = await _spriteLoader.loadPet(
        selectedPet,
        growthStage: growthStage.name,
      );
      _spriteCache[selectedPet.id] = spriteAtlas;
      previous?.image.dispose();
    }
    await _refreshNotificationSchedule();
    _playCompletionAnimation(newUnlocks, showTheater: completesDailySet);
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

  Future<bool> addTask({
    required String title,
    TaskKind kind = TaskKind.oneOff,
    String? note,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty || !state.canAddTask) return false;
    final normalizedNote = note?.trim();
    final task = TodoTask(
      id: _newTaskId(),
      title: normalizedTitle,
      kind: kind,
      note: normalizedNote == null || normalizedNote.isEmpty
          ? null
          : normalizedNote,
    );
    state = state.copyWith(tasks: <TodoTask>[...state.tasks, task]);
    await _stateStore.save(state);
    await _log(PetEventType.taskAdd, <String, Object?>{
      'taskId': task.id,
      'title': task.title,
      'kind': task.kind.name,
    });
    notifyListeners();
    return true;
  }

  Future<bool> removeTask(String taskId) async {
    final task = state.taskById(taskId);
    if (task == null || !state.canRemoveTask) return false;
    if (task.kind == TaskKind.daily && state.dailyTasks.length == 1) {
      return false;
    }
    state = state.copyWith(
      tasks: state.tasks
          .where((item) => item.id != taskId)
          .toList(growable: false),
    );
    await _stateStore.save(state);
    await _log(PetEventType.taskRemove, <String, Object?>{
      'taskId': task.id,
      'title': task.title,
      'kind': task.kind.name,
    });
    await _refreshNotificationSchedule();
    notifyListeners();
    return true;
  }

  Future<bool> editTask({
    required String taskId,
    required String title,
    required TaskKind kind,
    String? note,
  }) async {
    final current = state.taskById(taskId);
    final normalizedTitle = title.trim();
    if (current == null || normalizedTitle.isEmpty) return false;
    if (current.kind == TaskKind.daily &&
        kind == TaskKind.oneOff &&
        state.dailyTasks.length == 1) {
      return false;
    }
    final normalizedNote = note?.trim();
    final changedKind = current.kind != kind;
    final replacement = current.copyWith(
      title: normalizedTitle,
      kind: kind,
      note: normalizedNote == null || normalizedNote.isEmpty
          ? null
          : normalizedNote,
      completedToday: changedKind ? false : current.completedToday,
      completedAt: changedKind ? null : current.completedAt,
    );
    state = state.copyWith(
      tasks: state.tasks
          .map((item) => item.id == taskId ? replacement : item)
          .toList(growable: false),
    );
    await _stateStore.save(state);
    await _log(PetEventType.taskEdit, <String, Object?>{
      'taskId': replacement.id,
      'title': replacement.title,
      'kind': replacement.kind.name,
      'hasNote': replacement.note != null,
    });
    await _refreshNotificationSchedule();
    notifyListeners();
    return true;
  }

  Future<bool> setTaskReminder({
    required String taskId,
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final task = state.taskById(taskId);
    if (task == null) return false;
    var permission = state.notificationPermission;
    if (enabled && permission == NotificationPermissionState.denied) {
      return false;
    }
    if (enabled && permission == NotificationPermissionState.notRequested) {
      final granted = await _notifications.requestPermission();
      permission = granted
          ? NotificationPermissionState.granted
          : NotificationPermissionState.denied;
    }
    final canEnable =
        enabled && permission == NotificationPermissionState.granted;
    final existing = task.reminder;
    final reminder = TaskReminder(
      hour: hour,
      minute: minute,
      enabled: canEnable,
    );
    state = state.copyWith(
      notificationPermission: permission,
      tasks: state.tasks
          .map(
            (item) => item.id == taskId
                ? item.copyWith(
                    reminder: enabled || existing != null ? reminder : null,
                  )
                : item,
          )
          .toList(growable: false),
    );
    await _stateStore.save(state);
    await _refreshNotificationSchedule();
    notifyListeners();
    return canEnable || !enabled;
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
      await _refreshNotificationSchedule();
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

  void _playCompletionAnimation(
    List<DecorUnlock> newUnlocks, {
    required bool showTheater,
  }) {
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
    if (showTheater) {
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
    hatchCeremonyPetName = null;
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

  /// Reminders are a nice-to-have layered on top of the real work. A platform
  /// failure here (missing resource, vendor ROM quirk, revoked permission)
  /// must never break completing a task or opening the app, so failures are
  /// swallowed deliberately — the pet and the list always keep working.
  Future<void> _refreshNotificationSchedule() async {
    if (state.notificationPermission != NotificationPermissionState.granted) {
      return;
    }
    try {
      await _notifications.scheduleWindow(
        petName: state.petName,
        includeDailyInvitation: state.notificationEnabled,
        invitationHour: state.notificationHour,
        invitationMinute: state.notificationMinute,
        taskReminders: state.tasks
            .where((task) => task.reminder?.enabled ?? false)
            .map(
              (task) => TaskReminderSchedule(
                taskId: task.id,
                title: task.title,
                hour: task.reminder!.hour,
                minute: task.reminder!.minute,
                skipToday: task.kind == TaskKind.daily && task.completedToday,
              ),
            )
            .toList(growable: false),
      );
    } catch (error, stackTrace) {
      debugPrint('Reminder scheduling failed (continuing): $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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

  String _newTaskId() {
    _taskIdNonce++;
    return 'task-${DateTime.now().microsecondsSinceEpoch}-$_taskIdNonce';
  }

  @override
  void dispose() {
    _cancelMomentTimers();
    _dayBoundaryTimer?.cancel();
    _scheduleTimer?.cancel();
    for (final atlas in _spriteCache.values.toSet()) {
      atlas.image.dispose();
    }
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
