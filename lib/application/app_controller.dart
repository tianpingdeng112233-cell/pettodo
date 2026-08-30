import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/app_state_store.dart';
import '../data/event_log_store.dart';
import '../data/feature_gate.dart';
import '../data/hatch_api_client.dart';
import '../data/hatch_request_store.dart';
import '../data/notification_service.dart';
import '../data/overlay_service.dart';
import '../data/pet_pack_service.dart';
import '../data/room_asset_manifest.dart';
import '../domain/app_state.dart';
import '../domain/day_rollover.dart';
import '../domain/event_log.dart';
import '../domain/furniture.dart';
import '../domain/furniture_economy.dart' as furniture_economy;
import '../domain/furniture_placement.dart' as furniture_placement;
import '../domain/growth.dart';
import '../domain/onboarding_flow.dart';
import '../domain/pet_action.dart';
import '../domain/pet_schedule.dart';
import '../domain/treat_economy.dart';
import '../domain/unlocks.dart';
import '../sprite/overlay_frame_baker.dart';
import '../sprite/rig_driver.dart';
import '../sprite/rig_pet.dart';
import '../sprite/sprite_atlas.dart';
import 'focus_session_controller.dart';
import 'hatch_flow.dart';

class AppController extends ChangeNotifier {
  factory AppController({
    required AppStateStore stateStore,
    required EventLogStore eventLog,
    required NotificationService notifications,
    OverlayService? overlayService,
    SpriteAtlasLoader? spriteLoader,
    RigPetLoader? rigLoader,
    OverlayFrameBaker? overlayFrameBaker,
    HatchRequestStore? hatchRequestStore,
    PetPackService? petPackService,
    DateTime Function()? now,
    HatchApi? hatchApi,
    FeatureGate? featureGate,
    HatchDelay? hatchDelay,
  }) => AppController._(
    stateStore,
    eventLog,
    notifications,
    overlayService ?? OverlayService(),
    spriteLoader ?? SpriteAtlasLoader(),
    rigLoader ?? RigPetLoader(),
    overlayFrameBaker ??
        (Platform.isAndroid ? OverlayFrameBaker.onDevice() : null),
    hatchRequestStore ?? HatchRequestStore.onDevice(),
    petPackService ?? PetPackService.onDevice(),
    now ?? DateTime.now,
    hatchApi ?? HatchApiClient.onDevice(),
    featureGate ?? LocalFeatureGate.onDevice(),
    hatchDelay,
  );

  AppController._(
    this._stateStore,
    this._eventLog,
    this._notifications,
    this._overlayService,
    this._spriteLoader,
    this._rigLoader,
    this._overlayFrameBaker,
    this._hatchRequestStore,
    this._petPackService,
    this._now,
    HatchApi hatchApi,
    this._featureGate,
    HatchDelay? hatchDelay,
  ) {
    _hatchFlow = HatchFlowMachine(
      api: hatchApi,
      featureGate: _featureGate,
      importPack: _importHatchedPack,
      delay: hatchDelay,
      onAccepted: _rememberHatchId,
      onReady: () => _notifications.showHatchReady(petName: state.petName),
      onChanged: notifyListeners,
    );
  }

  final AppStateStore _stateStore;
  final EventLogStore _eventLog;
  final NotificationService _notifications;
  final OverlayService _overlayService;
  final SpriteAtlasLoader _spriteLoader;
  final RigPetLoader _rigLoader;
  final OverlayFrameBaker? _overlayFrameBaker;
  final HatchRequestStore _hatchRequestStore;
  final PetPackService _petPackService;
  final DateTime Function() _now;
  final FeatureGate _featureGate;
  late final HatchFlowMachine _hatchFlow;
  final Map<String, LoadedSpriteAtlas> _spriteCache =
      <String, LoadedSpriteAtlas>{};
  final Map<String, LoadedRigPet> _rigCache = <String, LoadedRigPet>{};
  final Map<String, Future<LoadedRigPet>> _rigLoads =
      <String, Future<LoadedRigPet>>{};
  // bumped on every replacement/dispose so an in-flight load can tell the
  // world changed under it and must not cache (and leak) its result
  int _rigEpoch = 0;
  bool _rigDisposed = false;
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
  late RoomAssetManifest roomAssets;
  LoadedSpriteAtlas? _spriteAtlas;
  LoadedRigPet? rigPet;
  BakedOverlayFrames? _bakedOverlayFrames;
  final OverlayBakeGeneration _overlayBakeGeneration = OverlayBakeGeneration();
  List<OverlayBubbleInvitation> _overlayBubbles =
      const <OverlayBubbleInvitation>[];
  late PetScheduleEntry currentSchedule;
  String petAnimation = 'idle';
  int? petAnimationFrame;
  RigPetAction rigAction = RigPetAction.breathing;
  RigTarget rigTarget = const RigTarget(0, 0);
  int rigAnimationNonce = 0;
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
  bool hatchUnlocked = false;
  String? hatchCeremonyPetName;
  bool eveningHelloVisible = false;
  int _taskIdNonce = 0;

  PetGrowthStage get growthStage => growthStageFor(state.lifetimeCompletions);

  PetAssetDescriptor get selectedPet => pets.firstWhere(
    (pet) => pet.id == state.selectedPetId,
    orElse: () => pets.first,
  );

  LoadedSpriteAtlas get spriteAtlas => _spriteAtlas!;

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

  bool get overlaySupported => _overlayService.supported;
  bool get overlayEnabled => _overlayService.enabled;
  bool get overlayBusy => _overlayService.busy;
  HatchFlowState get hatchFlow => _hatchFlow.state;
  String get hatchPriceLabel => _featureGate.priceLabel;

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
    try {
      hatchUnlocked = await _featureGate.isUnlocked();
    } on Object {
      hatchUnlocked = false;
    }
    pets = mergePetRegistry(bundledPets, installedPets);
    if (!pets.any((pet) => pet.id == state.selectedPetId)) {
      state = state.copyWith(selectedPetId: pets.first.id);
    }
    decorations = await _spriteLoader.loadDecorManifest();
    roomAssets = await RoomAssetManifestLoader().load();
    currentSchedule = petScheduleAt(now);
    await _loadSelectedPet(selectedPet);
    _applySchedule(now);
    await _stateStore.save(state);
    await _log(PetEventType.appOpen);
    await _refreshNotificationSchedule();
    await _overlayService.initialize(
      petName: state.petName,
      frames: null,
      bubbles: _overlayBubbles,
    );
    if (_overlayService.enabled) {
      await _bakeSelectedOverlayFrames();
      await _overlayService.updateConfiguration(
        petName: state.petName,
        frames: _bakedOverlayFrames,
        bubbles: _overlayBubbles,
      );
    }
    _refreshEveningHelloOffer();
    _scheduleDayBoundary();
    _scheduleScheduleBoundary();
    final hatchId = pendingHatchRequest?.hatchId;
    if (hatchUnlocked && hatchId != null) {
      unawaited(_hatchFlow.resume(hatchId));
    }
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

  Future<void> unlockHatching() async {
    await _featureGate.unlock();
    hatchUnlocked = true;
    notifyListeners();
  }

  Future<void> startHatch({
    required List<File> photos,
    required String petName,
  }) async {
    if (!hatchUnlocked) {
      await _hatchFlow.submit(photos: photos, petName: petName);
      return;
    }
    pendingHatchRequest = await _hatchRequestStore.create(
      photos: photos,
      petName: petName,
    );
    notifyListeners();
    final savedPhotos = await _hatchRequestStore.photosFor(
      pendingHatchRequest!,
    );
    unawaited(_hatchFlow.submit(photos: savedPhotos, petName: petName));
  }

  Future<void> retryHatch() async {
    final request = pendingHatchRequest;
    if (!hatchUnlocked || request == null) return;
    if (request.hatchId != null) {
      unawaited(_hatchFlow.resume(request.hatchId!));
      return;
    }
    final photos = await _hatchRequestStore.photosFor(request);
    unawaited(_hatchFlow.submit(photos: photos, petName: request.petName));
  }

  Future<void> submitSpeciesWish(String speciesText) =>
      _hatchFlow.submitSpeciesWish(speciesText);

  Future<void> _rememberHatchId(String hatchId) async {
    pendingHatchRequest = await _hatchRequestStore.attachHatchId(hatchId);
    if (!_rigDisposed) notifyListeners();
  }

  Future<void> _importHatchedPack(File file) async {
    await importPetPack(file);
    if (pendingHatchRequest != null) {
      await _hatchRequestStore.cancel();
      pendingHatchRequest = null;
      notifyListeners();
    }
  }

  Future<File> exportHatchRequest() => _hatchRequestStore.export();

  Future<void> cancelHatchRequest() async {
    _hatchFlow.pause();
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
    await _replaceLoadedPet(descriptor);
    state = state.copyWith(
      selectedPetId: descriptor.id,
      petName: descriptor.displayName,
    );
    _overlayBakeGeneration.invalidate();
    await _bakeSelectedOverlayFrames();
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
    if (descriptor.isRig) {
      rigAction = RigPetAction.happyJump;
      rigAnimationNonce++;
    } else {
      petAnimation = 'review';
      petAnimationFrame = null;
    }
    celebrationNonce++;
    await _refreshNotificationSchedule();
    notifyListeners();
    return descriptor;
  }

  final Map<String, Future<LoadedSpriteAtlas>> _spriteLoads =
      <String, Future<LoadedSpriteAtlas>>{};

  Future<LoadedSpriteAtlas> petAtlas(PetAssetDescriptor descriptor) {
    if (descriptor.isRig) {
      throw ArgumentError.value(descriptor.id, 'descriptor', 'Not v2');
    }
    final cached = _spriteCache[descriptor.id];
    if (cached != null) return Future<LoadedSpriteAtlas>.value(cached);
    // Memoize the in-flight load: concurrent callers (grid tiles, selection)
    // must share one decode, or the later completion would drop the earlier
    // ui.Image without anyone left to dispose it.
    return _spriteLoads.putIfAbsent(descriptor.id, () async {
      try {
        final loaded = await _spriteLoader.loadPet(
          descriptor,
          growthStage: growthStage.name,
        );
        _spriteCache[descriptor.id] = loaded;
        return loaded;
      } finally {
        _spriteLoads.remove(descriptor.id);
      }
    });
  }

  Future<LoadedRigPet> petRig(PetAssetDescriptor descriptor) {
    if (!descriptor.isRig) {
      throw ArgumentError.value(descriptor.id, 'descriptor', 'Not v3');
    }
    final cached = _rigCache[descriptor.id];
    if (cached != null) return Future<LoadedRigPet>.value(cached);
    // dedupe concurrent loads: without this, parallel FutureBuilder rebuilds
    // would each load a full image set and leak all but the last one
    final pending = _rigLoads[descriptor.id];
    if (pending != null) return pending;
    final epoch = _rigEpoch;
    final load = () async {
      final loaded = await _rigLoader.load(descriptor);
      if (_rigDisposed) {
        loaded.dispose();
        throw StateError('AppController was disposed during a rig load');
      }
      if (epoch != _rigEpoch) {
        // a replacement (possibly rig->v2) happened mid-load: this request is
        // answering a question about a world that no longer exists. Dropping
        // the images and failing terminally is the only safe option — the
        // descriptor may not even be a rig any more, and retrying here would
        // await the very future we are inside (self-referential deadlock).
        loaded.dispose();
        throw StateError('The pet registry changed during a rig load');
      }
      final existing = _rigCache[descriptor.id];
      if (existing != null) {
        // an install/replacement won the race; keep its images, drop ours
        loaded.dispose();
        return existing;
      }
      _rigCache[descriptor.id] = loaded;
      return loaded;
    }();
    // the callback must not RETURN the removed future — whenComplete awaits a
    // returned future, and _rigLoads holds this very chain (self-deadlock)
    final tracked = load.whenComplete(() {
      _rigLoads.remove(descriptor.id);
    });
    _rigLoads[descriptor.id] = tracked;
    return tracked;
  }

  Future<void> _loadSelectedPet(PetAssetDescriptor descriptor) async {
    if (descriptor.isRig) {
      rigPet = await petRig(descriptor);
      _spriteAtlas = null;
    } else {
      _spriteAtlas = await petAtlas(descriptor);
      rigPet = null;
    }
  }

  Future<void> _bakeSelectedOverlayFrames() async {
    final generation = _overlayBakeGeneration.begin();
    final baker = _overlayFrameBaker;
    if (baker == null ||
        !_overlayService.supported ||
        !_overlayService.enabled) {
      if (_overlayBakeGeneration.isCurrent(generation)) {
        _bakedOverlayFrames = null;
      }
      return;
    }
    final descriptor = selectedPet;
    try {
      final BakedOverlayFrames baked;
      if (descriptor.isRig) {
        final pet = rigPet;
        if (pet == null || pet.descriptor.id != descriptor.id) {
          throw StateError('The selected rig pet is not loaded.');
        }
        baked = await baker.bakeRig(pet);
      } else {
        final atlas = _spriteAtlas;
        if (atlas == null || atlas.descriptor.id != descriptor.id) {
          throw StateError('The selected atlas pet is not loaded.');
        }
        baked = await baker.bakeAtlas(atlas);
      }
      if (_overlayBakeGeneration.isCurrent(generation) &&
          state.selectedPetId == descriptor.id) {
        _bakedOverlayFrames = baked;
      }
    } catch (error, stackTrace) {
      if (!_overlayBakeGeneration.isCurrent(generation)) return;
      _bakedOverlayFrames = null;
      debugPrint('Overlay frame baking failed; using Choco fallback: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _replaceLoadedPet(PetAssetDescriptor descriptor) async {
    _rigEpoch++;
    if (descriptor.isRig) {
      final loaded = await _rigLoader.load(descriptor);
      if (_rigDisposed) {
        // dispose() ran while the images loaded; caching them now would leak
        // them forever into a dead controller
        loaded.dispose();
        throw StateError('AppController was disposed during a pet replacement');
      }
      final oldAtlas = _spriteCache.remove(descriptor.id);
      final oldRig = _rigCache.remove(descriptor.id);
      _rigCache[descriptor.id] = loaded;
      rigPet = loaded;
      _spriteAtlas = null;
      oldAtlas?.image.dispose();
      oldRig?.dispose();
    } else {
      final loaded = await _spriteLoader.loadPet(
        descriptor,
        growthStage: growthStage.name,
      );
      if (_rigDisposed) {
        loaded.image.dispose();
        throw StateError('AppController was disposed during a pet replacement');
      }
      final oldAtlas = _spriteCache.remove(descriptor.id);
      final oldRig = _rigCache.remove(descriptor.id);
      _spriteCache[descriptor.id] = loaded;
      _spriteAtlas = loaded;
      rigPet = null;
      oldAtlas?.image.dispose();
      oldRig?.dispose();
    }
  }

  Future<void> selectPet(String id) async {
    final descriptor = pets.firstWhere((pet) => pet.id == id);
    // Selection is UI intent: commit it before the atlas IO so the tap wins
    // immediately, and guard the swap so a slower load for an earlier tap
    // can never clobber the pet the user settled on.
    state = state.copyWith(
      selectedPetId: descriptor.id,
      petName: descriptor.displayName,
    );
    _overlayBakeGeneration.invalidate();
    notifyListeners();
    if (descriptor.isRig) {
      final loaded = await petRig(descriptor);
      if (state.selectedPetId != descriptor.id) return;
      rigPet = loaded;
      _spriteAtlas = null;
    } else {
      final loaded = await petAtlas(descriptor);
      if (state.selectedPetId != descriptor.id) return;
      _spriteAtlas = loaded;
      rigPet = null;
    }
    await _bakeSelectedOverlayFrames();
    await _stateStore.save(state);
    await _refreshNotificationSchedule();
    _applySchedule(DateTime.now());
    notifyListeners();
  }

  Future<void> onResume() async {
    _hatchFlow.resumeForeground();
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
    await _overlayService.refresh(
      petName: state.petName,
      frames: _bakedOverlayFrames,
      bubbles: _overlayBubbles,
    );
    _refreshEveningHelloOffer();
    _scheduleDayBoundary();
    _applySchedule(DateTime.now());
    _scheduleScheduleBoundary();
    notifyListeners();
    final hatchId = pendingHatchRequest?.hatchId;
    if (hatchUnlocked && hatchId != null) {
      unawaited(_hatchFlow.resume(hatchId));
    }
  }

  void onPause() => _hatchFlow.pause();

  Future<void> prepareOnboarding({
    required String selectedPetId,
    required String petName,
    required List<String> taskTitles,
  }) async {
    final descriptor = pets.firstWhere((pet) => pet.id == selectedPetId);
    final normalizedName = _normalized(petName, descriptor.displayName);
    final reward = state.onboardingRewardGranted ? 0 : 1;
    state = state.copyWith(
      selectedPetId: selectedPetId,
      petName: normalizedName,
      tasks: buildOnboardingTasks(
        petName: normalizedName,
        littleThings: taskTitles,
      ),
      treats: state.treats + reward,
      onboardingRewardGranted: true,
    );
    _overlayBakeGeneration.invalidate();
    if ((_spriteAtlas?.descriptor.id ?? rigPet?.descriptor.id) !=
        selectedPetId) {
      final descriptor = pets.firstWhere((pet) => pet.id == selectedPetId);
      await _loadSelectedPet(descriptor);
      await _bakeSelectedOverlayFrames();
    }
    await _stateStore.save(state);
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    state = state.copyWith(onboardingComplete: true, eveningHelloPending: true);
    _refreshEveningHelloOffer();
    await _stateStore.save(state);
    await _refreshNotificationSchedule();
    notifyListeners();
  }

  Future<void> respondToEveningHello(bool accepted) async {
    if (!state.eveningHelloPending) return;
    eveningHelloVisible = false;
    state = state.copyWith(eveningHelloPending: false);
    await _stateStore.save(state);
    if (accepted) await setNotificationEnabled(true);
    notifyListeners();
  }

  FocusSessionController createFocusSession({
    required int durationMinutes,
    String? taskId,
    DateTime Function()? now,
    Duration? tickInterval = const Duration(seconds: 1),
  }) => FocusSessionController(
    durationMinutes: durationMinutes,
    taskId: taskId,
    now: now,
    tickInterval: tickInterval,
    onComplete: _completeFocus,
  );

  Future<void> _completeFocus(FocusSessionCompletion completion) async {
    state = awardTreats(state, completion.treats);
    lastTreatDrop = completion.treats;
    if (completion.treats > 0) treatDropNonce++;
    await _stateStore.save(state);
    await _log(PetEventType.focusComplete, <String, Object?>{
      'minutes': completion.minutes,
      'treats': completion.treats,
      if (completion.taskId != null) 'taskId': completion.taskId,
    });
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
    final completedState = state.copyWith(
      tasks: tasks,
      lifetimeCompletions: after,
      unlockedDecorIds: unlocked.toList(growable: false),
    );
    state = awardTreats(
      furniture_economy.awardEarnedMilestoneFurniture(completedState),
      treatDrop,
    );
    lastTreatDrop = treatDrop;
    treatDropNonce++;
    // Send the native event before persistence/logging so a visible companion
    // starts celebrating comfortably inside the one-second product budget.
    await _overlayService.celebrate();
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
    if (!selectedPet.isRig &&
        newStages.isNotEmpty &&
        selectedPet.stageAssets.isNotEmpty) {
      final previous = _spriteCache.remove(selectedPet.id);
      _spriteAtlas = await _spriteLoader.loadPet(
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
      rigAnimation: RigPetAction.eatTreat,
      status:
          '${state.petName} savors the ${selectedPet.treatName.toLowerCase()}',
      particle: selectedPet.treatEmoji,
    );
    notifyListeners();
    return true;
  }

  Future<bool> buyFurniture(String furnitureId) async {
    final item = furnitureById(furnitureId);
    if (item == null || item.source != FurnitureSource.price) return false;
    final next = furniture_economy.purchaseFurniture(state, item);
    if (next == null) return false;
    state = next;
    await _stateStore.save(state);
    notifyListeners();
    return true;
  }

  Future<bool> placeFurniture(String furnitureId) async {
    final next = furniture_placement.placeFurniture(state, furnitureId);
    if (next == null) return false;
    state = next;
    await _stateStore.save(state);
    notifyListeners();
    return true;
  }

  Future<void> touchPet({required double dx, required double dy}) async {
    final degrees = (math.atan2(dx, -dy) * 180 / math.pi + 360) % 360;
    final direction = (degrees / 22.5).round() % 16;
    if (selectedPet.isRig) {
      rigAction = rigActionForEvent(PetActionEvent.touched);
      rigTarget = RigTarget(
        (dx / 96).clamp(-1.0, 1.0),
        (dy / 104).clamp(-1.0, 1.0),
      );
    } else {
      petAnimation = direction < 8 ? 'look-row-9' : 'look-row-10';
      petAnimationFrame = direction % 8;
    }
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

  Future<void> nuzzlePet({double dx = 0, double dy = 0}) async {
    affectionateMessage =
        '${state.petName} leans in close and gives you a gentle nuzzle';
    await _log(PetEventType.petTouch, const <String, Object?>{
      'kind': 'long_press',
    });
    rigTarget = RigTarget(
      (dx / 96).clamp(-1.0, 1.0),
      (dy / 104).clamp(-1.0, 1.0),
    );
    _playMoment(
      animation: 'waving',
      rigAnimation: RigPetAction.nuzzle,
      particle: '♥',
    );
    _holdMessage();
    notifyListeners();
  }

  Future<void> updatePetName(String value) async {
    state = state.copyWith(petName: _normalized(value, state.petName));
    await _stateStore.save(state);
    await _refreshNotificationSchedule();
    notifyListeners();
  }

  Future<bool> setOverlayEnabled(bool enabled) async {
    final result = await _overlayService.setEnabled(
      enabled,
      petName: state.petName,
      frames: enabled ? null : _bakedOverlayFrames,
      bubbles: _overlayBubbles,
    );
    if (result && enabled) {
      await _bakeSelectedOverlayFrames();
      await _overlayService.updateConfiguration(
        petName: state.petName,
        frames: _bakedOverlayFrames,
        bubbles: _overlayBubbles,
      );
    } else if (!result) {
      _overlayBakeGeneration.invalidate();
      _bakedOverlayFrames = null;
    }
    notifyListeners();
    return result;
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
    if (selectedPet.isRig) {
      rigAction = rigActionForEvent(PetActionEvent.taskCompleted);
      rigAnimationNonce++;
    } else {
      petAnimation = 'jumping';
      petAnimationFrame = null;
    }
    momentParticle = '+$lastTreatDrop ${selectedPet.treatEmoji}';
    particleNonce++;
    if (showTheater) {
      _theaterTimer = Timer(const Duration(milliseconds: 900), () {
        theaterVisible = true;
        if (selectedPet.isRig) {
          rigAction = RigPetAction.breathing;
        } else {
          petAnimation = 'review';
          petAnimationFrame = null;
        }
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
    if (selectedPet.isRig) {
      rigAction = rigActionForSchedule(currentSchedule);
      rigTarget = const RigTarget(0, 0);
    } else {
      petAnimation = currentSchedule.animation;
      petAnimationFrame = currentSchedule.fixedFrame;
    }
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
    RigPetAction? rigAnimation,
    String? status,
    String? particle,
  }) {
    _animationTimer?.cancel();
    if (selectedPet.isRig) {
      rigAction = rigAnimation ?? RigPetAction.breathing;
      rigAnimationNonce++;
    } else {
      petAnimation = animation;
      petAnimationFrame = null;
    }
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

  void _refreshEveningHelloOffer() {
    eveningHelloVisible = shouldOfferEveningHello(
      pending: state.onboardingComplete && state.eveningHelloPending,
      now: _now(),
    );
  }

  /// Reminders are a nice-to-have layered on top of the real work. A platform
  /// failure here (missing resource, vendor ROM quirk, revoked permission)
  /// must never break completing a task or opening the app, so failures are
  /// swallowed deliberately — the pet and the list always keep working.
  Future<void> _refreshNotificationSchedule() async {
    final now = _now();
    var window = const <ScheduledPetNotification>[];
    try {
      if (state.notificationPermission == NotificationPermissionState.granted) {
        window = await _notifications.scheduleWindow(
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
          now: now,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Reminder scheduling failed (continuing): $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    _overlayBubbles = buildOverlayBubbleSchedule(window, now: now);
    await _overlayService.updateConfiguration(
      petName: state.petName,
      frames: _bakedOverlayFrames,
      bubbles: _overlayBubbles,
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

  String _newTaskId() {
    _taskIdNonce++;
    return 'task-${DateTime.now().microsecondsSinceEpoch}-$_taskIdNonce';
  }

  @override
  void dispose() {
    _overlayBakeGeneration.invalidate();
    _hatchFlow.pause();
    _cancelMomentTimers();
    _dayBoundaryTimer?.cancel();
    _scheduleTimer?.cancel();
    _overlayService.dispose();
    for (final atlas in _spriteCache.values.toSet()) {
      atlas.image.dispose();
    }
    for (final rig in _rigCache.values.toSet()) {
      rig.dispose();
    }
    _rigCache.clear();
    _rigDisposed = true;
    _rigEpoch++;
    _hatchFlow.dispose();
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
