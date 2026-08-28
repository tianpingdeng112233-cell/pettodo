import 'accessory.dart';
import 'furniture_migration.dart';
import 'local_day.dart';
import 'unlocks.dart';

const int minimumTaskCount = 1;
const int maximumTaskCount = 7;

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
  });

  factory TaskReminder.fromJson(Map<Object?, Object?> json) => TaskReminder(
    hour: (json['hour'] as int? ?? 9).clamp(0, 23),
    minute: (json['minute'] as int? ?? 0).clamp(0, 59),
    enabled: json['enabled'] as bool? ?? true,
  );

  final int hour;
  final int minute;
  final bool enabled;

  TaskReminder copyWith({int? hour, int? minute, bool? enabled}) =>
      TaskReminder(
        hour: (hour ?? this.hour).clamp(0, 23),
        minute: (minute ?? this.minute).clamp(0, 59),
        enabled: enabled ?? this.enabled,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
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
    required List<TodoTask> tasks,
    required this.activeDay,
    required this.lifetimeCompletions,
    required List<String> unlockedDecorIds,
    required Set<String> ownedFurnitureIds,
    required Map<String, String> placedFurnitureBySlot,
    required Set<String> ownedAccessoryIds,
    required Map<String, String> equippedAccessoryByAnchor,
    required this.treats,
    required this.fedToday,
    required this.notificationPermission,
    required this.notificationEnabled,
    required this.notificationHour,
    required this.notificationMinute,
    required this.onboardingRewardGranted,
    required this.eveningHelloPending,
  }) : tasks = List<TodoTask>.unmodifiable(tasks),
       unlockedDecorIds = List<String>.unmodifiable(unlockedDecorIds),
       ownedFurnitureIds = Set<String>.unmodifiable(ownedFurnitureIds),
       placedFurnitureBySlot = Map<String, String>.unmodifiable(
         placedFurnitureBySlot,
       ),
       ownedAccessoryIds = Set<String>.unmodifiable(ownedAccessoryIds),
       equippedAccessoryByAnchor = Map<String, String>.unmodifiable(
         equippedAccessoryByAnchor,
       ) {
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
    tasks: _defaultTasks(),
    activeDay: localDayKey(now),
    lifetimeCompletions: 0,
    unlockedDecorIds: const <String>[],
    ownedFurnitureIds: const <String>{},
    placedFurnitureBySlot: const <String, String>{},
    ownedAccessoryIds: const <String>{},
    equippedAccessoryByAnchor: const <String, String>{},
    treats: 0,
    fedToday: null,
    notificationPermission: NotificationPermissionState.notRequested,
    notificationEnabled: false,
    notificationHour: 20,
    notificationMinute: 0,
    onboardingRewardGranted: false,
    eveningHelloPending: false,
  );

  factory AppState.fromJson(Map<String, Object?> json, DateTime now) {
    final permission = NotificationPermissionState.fromName(
      json['notificationPermission'] as String?,
    );
    final persistedTreats = json['treats'] as int? ?? 0;
    final lifetimeCompletions = json['lifetimeCompletions'] as int? ?? 0;
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
    final ownedAccessoryIds = <String>{
      ...(json['ownedAccessoryIds'] as List<Object?>? ?? const <Object?>[])
          .whereType<String>()
          .where((id) => accessoryById(id) != null),
    };
    final rawEquippedAccessories = json['equippedAccessoryByAnchor'];
    final equippedAccessoryByAnchor =
        rawEquippedAccessories is Map<Object?, Object?>
        ? <String, String>{
            for (final entry in rawEquippedAccessories.entries)
              if (entry.key is String &&
                  entry.value is String &&
                  AccessoryAnchor.fromName(entry.key! as String) != null &&
                  ownedAccessoryIds.contains(entry.value) &&
                  accessoryById(entry.value! as String)?.anchor.name ==
                      entry.key)
                entry.key! as String: entry.value! as String,
          }
        : const <String, String>{};
    return AppState(
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      selectedPetId: json['selectedPetId'] as String? ?? 'choco',
      petName: _nonEmpty(json['petName'] as String?, 'Choco'),
      tasks: _tasksFromJson(json),
      activeDay: json['activeDay'] as String? ?? localDayKey(now),
      lifetimeCompletions: lifetimeCompletions,
      unlockedDecorIds: unlockedDecorIds,
      ownedFurnitureIds: ownedFurnitureIds,
      placedFurnitureBySlot: migrateFurniturePlacements(
        ownedFurnitureIds: ownedFurnitureIds,
        placedFurnitureBySlot: persistedPlacements,
      ),
      ownedAccessoryIds: ownedAccessoryIds,
      equippedAccessoryByAnchor: equippedAccessoryByAnchor,
      treats: persistedTreats < 0 ? 0 : persistedTreats,
      fedToday: json['fedToday'] as String?,
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
  final List<TodoTask> tasks;
  final String activeDay;
  final int lifetimeCompletions;
  final List<String> unlockedDecorIds;
  final Set<String> ownedFurnitureIds;
  final Map<String, String> placedFurnitureBySlot;
  final Set<String> ownedAccessoryIds;
  final Map<String, String> equippedAccessoryByAnchor;
  final int treats;
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
    List<TodoTask>? tasks,
    String? activeDay,
    int? lifetimeCompletions,
    List<String>? unlockedDecorIds,
    Set<String>? ownedFurnitureIds,
    Map<String, String>? placedFurnitureBySlot,
    Set<String>? ownedAccessoryIds,
    Map<String, String>? equippedAccessoryByAnchor,
    int? treats,
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
    tasks: tasks ?? this.tasks,
    activeDay: activeDay ?? this.activeDay,
    lifetimeCompletions: lifetimeCompletions ?? this.lifetimeCompletions,
    unlockedDecorIds: unlockedDecorIds ?? this.unlockedDecorIds,
    ownedFurnitureIds: ownedFurnitureIds ?? this.ownedFurnitureIds,
    placedFurnitureBySlot: placedFurnitureBySlot ?? this.placedFurnitureBySlot,
    ownedAccessoryIds: ownedAccessoryIds ?? this.ownedAccessoryIds,
    equippedAccessoryByAnchor:
        equippedAccessoryByAnchor ?? this.equippedAccessoryByAnchor,
    treats: treats ?? this.treats,
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
    'schemaVersion': 5,
    'onboardingComplete': onboardingComplete,
    'selectedPetId': selectedPetId,
    'petName': petName,
    'tasks': tasks.map((task) => task.toJson()).toList(growable: false),
    'activeDay': activeDay,
    'lifetimeCompletions': lifetimeCompletions,
    'unlockedDecorIds': unlockedDecorIds,
    'ownedFurnitureIds': ownedFurnitureIds.toList(growable: false),
    'placedFurnitureBySlot': placedFurnitureBySlot,
    'ownedAccessoryIds': ownedAccessoryIds.toList(growable: false),
    'equippedAccessoryByAnchor': equippedAccessoryByAnchor,
    'treats': treats,
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
