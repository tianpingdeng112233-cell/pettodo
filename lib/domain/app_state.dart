import 'bond_migration.dart';
import 'food.dart';
import 'furniture_migration.dart';
import 'local_day.dart';
import 'unlocks.dart';

const int minimumTaskCount = 1;
const int maximumTaskCount = 7;
const int currentAppStateSchemaVersion = 6;

const List<String> defaultTaskTitles = <String>[
  'Drink 8 cups of water',
  'Learn 20 new words',
  'Walk the dog',
];

enum TaskKind {
  daily,
  oneOff;

  static TaskKind fromName(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => TaskKind.daily,
  );
}

class TaskReminder {
  const TaskReminder({
    required this.hour,
    required this.minute,
    this.enabled = true,
  }) : scheduledAt = null,
       _enabledWasExplicit = true;

  factory TaskReminder.once({
    required DateTime scheduledAt,
    bool enabled = true,
  }) => TaskReminder._(
    hour: scheduledAt.hour,
    minute: scheduledAt.minute,
    enabled: enabled,
    scheduledAt: scheduledAt,
    enabledWasExplicit: true,
  );

  const TaskReminder._({
    required this.hour,
    required this.minute,
    required this.enabled,
    required this.scheduledAt,
    required this._enabledWasExplicit,
  });

  factory TaskReminder.fromJson(Map<Object?, Object?> json) {
    final scheduledAt = _tryDate(json['scheduledAt'] as String?);
    if (scheduledAt != null) {
      return TaskReminder.once(
        scheduledAt: scheduledAt,
        enabled: json['enabled'] as bool? ?? true,
      );
    }
    return TaskReminder._(
      hour: (json['hour'] as int? ?? 9).clamp(0, 23),
      minute: (json['minute'] as int? ?? 0).clamp(0, 59),
      enabled: json['enabled'] as bool? ?? true,
      scheduledAt: null,
      enabledWasExplicit: json.containsKey('enabled'),
    );
  }

  final int hour;
  final int minute;
  final DateTime? scheduledAt;
  final bool enabled;
  final bool _enabledWasExplicit;

  bool get isDaily => scheduledAt == null;
  bool get isTimed => scheduledAt != null;

  TaskReminder copyWith({
    int? hour,
    int? minute,
    DateTime? scheduledAt,
    bool? enabled,
  }) {
    final nextScheduledAt = scheduledAt ?? this.scheduledAt;
    if (nextScheduledAt != null) {
      return TaskReminder.once(
        scheduledAt: nextScheduledAt,
        enabled: enabled ?? this.enabled,
      );
    }
    return TaskReminder._(
      hour: (hour ?? this.hour).clamp(0, 23),
      minute: (minute ?? this.minute).clamp(0, 59),
      enabled: enabled ?? this.enabled,
      scheduledAt: null,
      enabledWasExplicit: enabled != null || _enabledWasExplicit,
    );
  }

  Map<String, Object?> toJson() => isTimed
      ? <String, Object?>{
          'scheduledAt': scheduledAt!.toIso8601String(),
          'enabled': enabled,
        }
      : <String, Object?>{
          'hour': hour,
          'minute': minute,
          if (_enabledWasExplicit) 'enabled': enabled,
        };
}

class TodoTask {
  const TodoTask({
    required this.id,
    required this.title,
    required this.kind,
    this.note,
    this.reminder,
    this.completedToday = false,
    this.completedAt,
  });

  factory TodoTask.fromJson(Map<Object?, Object?> json) {
    final title = (json['title'] as String? ?? '').trim();
    final note = (json['note'] as String?)?.trim();
    final rawReminder = json['reminder'];
    return TodoTask(
      id: (json['id'] as String? ?? '').trim(),
      title: title,
      kind: TaskKind.fromName(json['kind'] as String?),
      note: note == null || note.isEmpty ? null : note,
      reminder: rawReminder is Map<Object?, Object?>
          ? TaskReminder.fromJson(rawReminder)
          : null,
      completedToday: json['completedToday'] as bool? ?? false,
      completedAt: _tryDate(json['completedAt'] as String?),
    );
  }

  final String id;
  final String title;
  final TaskKind kind;
  final String? note;
  final TaskReminder? reminder;
  final bool completedToday;
  final DateTime? completedAt;

  bool get isComplete =>
      kind == TaskKind.daily ? completedToday : completedAt != null;

  TodoTask copyWith({
    String? id,
    String? title,
    TaskKind? kind,
    Object? note = _notProvided,
    Object? reminder = _notProvided,
    bool? completedToday,
    Object? completedAt = _notProvided,
  }) => TodoTask(
    id: id ?? this.id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    note: identical(note, _notProvided) ? this.note : note as String?,
    reminder: identical(reminder, _notProvided)
        ? this.reminder
        : reminder as TaskReminder?,
    completedToday: completedToday ?? this.completedToday,
    completedAt: identical(completedAt, _notProvided)
        ? this.completedAt
        : completedAt as DateTime?,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'kind': kind.name,
    if (note != null) 'note': note,
    if (reminder != null) 'reminder': reminder!.toJson(),
    'completedToday': completedToday,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };
}

enum NotificationPermissionState {
  notRequested,
  granted,
  denied;

  static NotificationPermissionState fromName(String? value) {
    return values.where((item) => item.name == value).firstOrNull ??
        NotificationPermissionState.notRequested;
  }
}

class AppState {
  AppState({
    required this.onboardingComplete,
    required this.selectedPetId,
    required this.petName,
    Set<String> adoptedPresetPetIds = const <String>{},
    this.needsPresetAdoptionMigration = false,
    required List<TodoTask> tasks,
    required this.activeDay,
    required this.lifetimeCompletions,
    required List<String> unlockedDecorIds,
    required Set<String> ownedFurnitureIds,
    required Map<String, String> placedFurnitureBySlot,
    required this.treats,
    required Map<String, int> foodInventory,
    required this.bondXp,
    required this.feedingCountToday,
    required this.lastCompanionDay,
    required this.fedToday,
    required this.notificationPermission,
    required this.notificationEnabled,
    required this.notificationHour,
    required this.notificationMinute,
    required this.onboardingRewardGranted,
    required this.eveningHelloPending,
  }) : adoptedPresetPetIds = Set<String>.unmodifiable(adoptedPresetPetIds),
       tasks = List<TodoTask>.unmodifiable(tasks),
       unlockedDecorIds = List<String>.unmodifiable(unlockedDecorIds),
       ownedFurnitureIds = Set<String>.unmodifiable(ownedFurnitureIds),
       placedFurnitureBySlot = Map<String, String>.unmodifiable(
         placedFurnitureBySlot,
       ),
       foodInventory = Map<String, int>.unmodifiable(foodInventory) {
    if (this.tasks.length < minimumTaskCount ||
        this.tasks.length > maximumTaskCount) {
      throw ArgumentError('Pawside supports between 1 and 7 active tasks.');
    }
    if (!this.tasks.any((task) => task.kind == TaskKind.daily)) {
      throw ArgumentError('Pawside keeps at least one gentle daily task.');
    }
    if (this.tasks.map((task) => task.id).toSet().length != this.tasks.length) {
      throw ArgumentError('Task ids must be unique.');
    }
  }

  factory AppState.initial(DateTime now) => AppState(
    onboardingComplete: false,
    selectedPetId: 'choco',
    petName: 'Choco',
    adoptedPresetPetIds: const <String>{'choco'},
    tasks: _defaultTasks(),
    activeDay: localDayKey(now),
    lifetimeCompletions: 0,
    unlockedDecorIds: const <String>[],
    ownedFurnitureIds: const <String>{},
    placedFurnitureBySlot: const <String, String>{},
    treats: 0,
    foodInventory: const <String, int>{},
    bondXp: 0,
    feedingCountToday: 0,
    lastCompanionDay: null,
    fedToday: null,
    notificationPermission: NotificationPermissionState.notRequested,
    notificationEnabled: false,
    notificationHour: 20,
    notificationMinute: 0,
    onboardingRewardGranted: false,
    eveningHelloPending: false,
  );

  factory AppState.fromJson(Map<String, Object?> json, DateTime now) {
    final schemaVersion = json['schemaVersion'] as int? ?? 0;
    final permission = NotificationPermissionState.fromName(
      json['notificationPermission'] as String?,
    );
    final persistedTreats = json['treats'] as int? ?? 0;
    final lifetimeCompletions = json['lifetimeCompletions'] as int? ?? 0;
    final activeDay = json['activeDay'] as String? ?? localDayKey(now);
    final fedToday = json['fedToday'] as String?;
    final persistedBondXp = (json['bondXp'] as int? ?? 0).clamp(0, 1 << 53);
    final legacyBondXp = legacyBondXpForCompletions(lifetimeCompletions);
    final bondXp = schemaVersion < 5 && persistedBondXp < legacyBondXp
        ? legacyBondXp
        : persistedBondXp;
    final persistedFeedingCount = (json['feedingCountToday'] as int? ?? 0)
        .clamp(0, 1 << 31);
    final feedingCountToday =
        schemaVersion < 5 && fedToday == activeDay && persistedFeedingCount == 0
        ? 1
        : persistedFeedingCount;
    final persistedFoodInventory = _foodInventoryFromJson(
      json['foodInventory'],
    );
    // Any pre-v5 save with history gets the one-time greeting biscuit, so a
    // migrated user with 1-4 treats can still feed on their first screen.
    final foodInventory =
        schemaVersion < 5 &&
            (lifetimeCompletions > 0 ||
                persistedTreats > 0 ||
                json['fedToday'] != null) &&
            persistedFoodInventory.isEmpty
        ? const <String, int>{'biscuit': 1}
        : persistedFoodInventory;
    final unlockedDecorIds = <String>{
      ...(json['unlockedDecorIds'] as List<Object?>? ?? const <Object?>[])
          .whereType<String>(),
      ...unlocksEarnedAt(lifetimeCompletions).map((unlock) => unlock.id),
    }.toList(growable: false);
    final ownedFurnitureIds = migrateLegacyDecorToFurniture(
      unlockedDecorIds: unlockedDecorIds,
      lifetimeCompletions: lifetimeCompletions,
      ownedFurnitureIds:
          (json['ownedFurnitureIds'] as List<Object?>? ?? const <Object?>[])
              .whereType<String>(),
    );
    final rawPlacements = json['placedFurnitureBySlot'];
    final persistedPlacements = rawPlacements is Map<Object?, Object?>
        ? <String, String>{
            for (final entry in rawPlacements.entries)
              if (entry.key is String && entry.value is String)
                entry.key! as String: entry.value! as String,
          }
        : const <String, String>{};
    final selectedPetId = json['selectedPetId'] as String? ?? 'choco';
    final needsPresetAdoptionMigration = !json.containsKey(
      'adoptedPresetPetIds',
    );
    final adoptedPresetPetIds = !needsPresetAdoptionMigration
        ? (json['adoptedPresetPetIds'] as List<Object?>? ?? const <Object?>[])
              .whereType<String>()
              .toSet()
        : const <String>{};
    return AppState(
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      selectedPetId: selectedPetId,
      petName: _nonEmpty(json['petName'] as String?, 'Choco'),
      adoptedPresetPetIds: adoptedPresetPetIds,
      needsPresetAdoptionMigration: needsPresetAdoptionMigration,
      tasks: _tasksFromJson(json),
      activeDay: activeDay,
      lifetimeCompletions: lifetimeCompletions,
      unlockedDecorIds: unlockedDecorIds,
      ownedFurnitureIds: ownedFurnitureIds,
      placedFurnitureBySlot: migrateFurniturePlacements(
        ownedFurnitureIds: ownedFurnitureIds,
        placedFurnitureBySlot: persistedPlacements,
      ),
      treats: persistedTreats < 0 ? 0 : persistedTreats,
      foodInventory: foodInventory,
      bondXp: bondXp,
      feedingCountToday: feedingCountToday,
      lastCompanionDay: json['lastCompanionDay'] as String?,
      fedToday: fedToday,
      notificationPermission: permission,
      notificationEnabled:
          permission == NotificationPermissionState.granted &&
          (json['notificationEnabled'] as bool? ?? false),
      notificationHour: (json['notificationHour'] as int? ?? 20).clamp(0, 23),
      notificationMinute: (json['notificationMinute'] as int? ?? 0).clamp(
        0,
        59,
      ),
      onboardingRewardGranted:
          json['onboardingRewardGranted'] as bool? ?? false,
      // Legacy completed states stay exactly as they were. Only v2 onboarding
      // explicitly creates a pending first-evening invitation.
      eveningHelloPending: json['eveningHelloPending'] as bool? ?? false,
    );
  }

  final bool onboardingComplete;
  final String selectedPetId;
  final String petName;
  final Set<String> adoptedPresetPetIds;
  final bool needsPresetAdoptionMigration;
  final List<TodoTask> tasks;
  final String activeDay;
  final int lifetimeCompletions;
  final List<String> unlockedDecorIds;
  final Set<String> ownedFurnitureIds;
  final Map<String, String> placedFurnitureBySlot;
  final int treats;
  final Map<String, int> foodInventory;
  final int bondXp;
  final int feedingCountToday;
  final String? lastCompanionDay;
  final String? fedToday;
  final NotificationPermissionState notificationPermission;
  final bool notificationEnabled;
  final int notificationHour;
  final int notificationMinute;
  final bool onboardingRewardGranted;
  final bool eveningHelloPending;

  List<TodoTask> get dailyTasks => tasks
      .where((task) => task.kind == TaskKind.daily)
      .toList(growable: false);
  List<TodoTask> get oneOffTasks => tasks
      .where((task) => task.kind == TaskKind.oneOff)
      .toList(growable: false);
  bool get allDailyDone =>
      dailyTasks.isNotEmpty && dailyTasks.every((task) => task.completedToday);
  bool get allDone => allDailyDone;
  bool get canAddTask => tasks.length < maximumTaskCount;
  bool get canRemoveTask => tasks.length > minimumTaskCount;

  // Read-only compatibility helpers for code that only needs a projection.
  List<String> get taskTitles => tasks.map((task) => task.title).toList();
  List<bool> get completedToday =>
      tasks.map((task) => task.completedToday).toList();

  TodoTask? taskById(String id) =>
      tasks.where((task) => task.id == id).firstOrNull;

  bool isFedOn(DateTime localDate) => fedToday == localDayKey(localDate);

  AppState copyWith({
    bool? onboardingComplete,
    String? selectedPetId,
    String? petName,
    Set<String>? adoptedPresetPetIds,
    bool? needsPresetAdoptionMigration,
    List<TodoTask>? tasks,
    String? activeDay,
    int? lifetimeCompletions,
    List<String>? unlockedDecorIds,
    Set<String>? ownedFurnitureIds,
    Map<String, String>? placedFurnitureBySlot,
    int? treats,
    Map<String, int>? foodInventory,
    int? bondXp,
    int? feedingCountToday,
    Object? lastCompanionDay = _notProvided,
    Object? fedToday = _notProvided,
    NotificationPermissionState? notificationPermission,
    bool? notificationEnabled,
    int? notificationHour,
    int? notificationMinute,
    bool? onboardingRewardGranted,
    bool? eveningHelloPending,
  }) => AppState(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    selectedPetId: selectedPetId ?? this.selectedPetId,
    petName: petName ?? this.petName,
    adoptedPresetPetIds: adoptedPresetPetIds ?? this.adoptedPresetPetIds,
    needsPresetAdoptionMigration:
        needsPresetAdoptionMigration ?? this.needsPresetAdoptionMigration,
    tasks: tasks ?? this.tasks,
    activeDay: activeDay ?? this.activeDay,
    lifetimeCompletions: lifetimeCompletions ?? this.lifetimeCompletions,
    unlockedDecorIds: unlockedDecorIds ?? this.unlockedDecorIds,
    ownedFurnitureIds: ownedFurnitureIds ?? this.ownedFurnitureIds,
    placedFurnitureBySlot: placedFurnitureBySlot ?? this.placedFurnitureBySlot,
    treats: treats ?? this.treats,
    foodInventory: foodInventory ?? this.foodInventory,
    bondXp: bondXp ?? this.bondXp,
    feedingCountToday: feedingCountToday ?? this.feedingCountToday,
    lastCompanionDay: identical(lastCompanionDay, _notProvided)
        ? this.lastCompanionDay
        : lastCompanionDay as String?,
    fedToday: identical(fedToday, _notProvided)
        ? this.fedToday
        : fedToday as String?,
    notificationPermission:
        notificationPermission ?? this.notificationPermission,
    notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    notificationHour: notificationHour ?? this.notificationHour,
    notificationMinute: notificationMinute ?? this.notificationMinute,
    onboardingRewardGranted:
        onboardingRewardGranted ?? this.onboardingRewardGranted,
    eveningHelloPending: eveningHelloPending ?? this.eveningHelloPending,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': currentAppStateSchemaVersion,
    'onboardingComplete': onboardingComplete,
    'selectedPetId': selectedPetId,
    'petName': petName,
    if (!needsPresetAdoptionMigration)
      'adoptedPresetPetIds': adoptedPresetPetIds.toList(growable: false),
    'tasks': tasks.map((task) => task.toJson()).toList(growable: false),
    'activeDay': activeDay,
    'lifetimeCompletions': lifetimeCompletions,
    'unlockedDecorIds': unlockedDecorIds,
    'ownedFurnitureIds': ownedFurnitureIds.toList(growable: false),
    'placedFurnitureBySlot': placedFurnitureBySlot,
    'treats': treats,
    'foodInventory': foodInventory,
    'bondXp': bondXp,
    'feedingCountToday': feedingCountToday,
    'lastCompanionDay': lastCompanionDay,
    'fedToday': fedToday,
    'notificationPermission': notificationPermission.name,
    'notificationEnabled': notificationEnabled,
    'notificationHour': notificationHour,
    'notificationMinute': notificationMinute,
    'onboardingRewardGranted': onboardingRewardGranted,
    'eveningHelloPending': eveningHelloPending,
  };

  static List<TodoTask> _tasksFromJson(Map<String, Object?> json) {
    final rawTasks = json['tasks'];
    if (rawTasks is List<Object?>) {
      final result = <TodoTask>[];
      final ids = <String>{};
      for (final value in rawTasks) {
        if (value is! Map<Object?, Object?>) continue;
        final parsed = TodoTask.fromJson(value);
        if (parsed.id.isEmpty || parsed.title.isEmpty || !ids.add(parsed.id)) {
          continue;
        }
        result.add(parsed);
        if (result.length == maximumTaskCount) break;
      }
      if (result.any((task) => task.kind == TaskKind.daily)) return result;
    }

    final titles = (json['taskTitles'] as List<Object?>? ?? const <Object?>[])
        .whereType<String>()
        .toList(growable: false);
    final checks =
        (json['completedToday'] as List<Object?>? ?? const <Object?>[])
            .whereType<bool>()
            .toList(growable: false);
    if (titles.length == 3 && checks.length == 3) {
      return List<TodoTask>.generate(
        3,
        (index) => TodoTask(
          id: 'daily-${index + 1}',
          title: _nonEmpty(titles[index], defaultTaskTitles[index]),
          kind: TaskKind.daily,
          completedToday: checks[index],
        ),
        growable: false,
      );
    }
    return _defaultTasks();
  }

  static String _nonEmpty(String? value, String fallback) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  static Map<String, int> _foodInventoryFromJson(Object? value) {
    if (value is! Map<Object?, Object?>) return const <String, int>{};
    final result = <String, int>{};
    for (final entry in value.entries) {
      final id = entry.key;
      final count = entry.value;
      if (id is String && count is int && count > 0 && foodById(id) != null) {
        result[id] = count;
      }
    }
    return result;
  }
}

List<TodoTask> _defaultTasks() => List<TodoTask>.generate(
  defaultTaskTitles.length,
  (index) => TodoTask(
    id: 'daily-${index + 1}',
    title: defaultTaskTitles[index],
    kind: TaskKind.daily,
  ),
  growable: false,
);

DateTime? _tryDate(String? value) {
  if (value == null) return null;
  return DateTime.tryParse(value);
}

const Object _notProvided = Object();

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
