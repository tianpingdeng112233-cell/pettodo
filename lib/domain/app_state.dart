import 'local_day.dart';

const List<String> defaultTaskTitles = <String>['喝水 8 杯', '背 20 个单词', '遛狗'];

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
    required List<String> taskTitles,
    required List<bool> completedToday,
    required this.activeDay,
    required this.lifetimeCompletions,
    required List<String> unlockedDecorIds,
    required this.notificationPermission,
    required this.notificationEnabled,
    required this.notificationHour,
    required this.notificationMinute,
  }) : taskTitles = List<String>.unmodifiable(taskTitles),
       completedToday = List<bool>.unmodifiable(completedToday),
       unlockedDecorIds = List<String>.unmodifiable(unlockedDecorIds) {
    if (this.taskTitles.length != 3 || this.completedToday.length != 3) {
      throw ArgumentError('PetTodo always requires exactly three tasks.');
    }
  }

  factory AppState.initial(DateTime now) => AppState(
    onboardingComplete: false,
    selectedPetId: 'choco',
    petName: 'Choco',
    taskTitles: defaultTaskTitles,
    completedToday: const <bool>[false, false, false],
    activeDay: localDayKey(now),
    lifetimeCompletions: 0,
    unlockedDecorIds: const <String>[],
    notificationPermission: NotificationPermissionState.notRequested,
    notificationEnabled: false,
    notificationHour: 20,
    notificationMinute: 0,
  );

  factory AppState.fromJson(Map<String, Object?> json, DateTime now) {
    List<String> strings(Object? value, List<String> fallback) {
      if (value is! List<Object?>) return fallback;
      final result = value.whereType<String>().toList();
      return result.length == fallback.length ? result : fallback;
    }

    List<bool> booleans(Object? value) {
      if (value is! List<Object?>) return const <bool>[false, false, false];
      final result = value.whereType<bool>().toList();
      return result.length == 3 ? result : const <bool>[false, false, false];
    }

    final permission = NotificationPermissionState.fromName(
      json['notificationPermission'] as String?,
    );
    return AppState(
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      selectedPetId: json['selectedPetId'] as String? ?? 'choco',
      petName: _nonEmpty(json['petName'] as String?, 'Choco'),
      taskTitles: strings(json['taskTitles'], defaultTaskTitles),
      completedToday: booleans(json['completedToday']),
      activeDay: json['activeDay'] as String? ?? localDayKey(now),
      lifetimeCompletions: json['lifetimeCompletions'] as int? ?? 0,
      unlockedDecorIds:
          (json['unlockedDecorIds'] as List<Object?>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      notificationPermission: permission,
      notificationEnabled:
          permission == NotificationPermissionState.granted &&
          (json['notificationEnabled'] as bool? ?? false),
      notificationHour: (json['notificationHour'] as int? ?? 20).clamp(0, 23),
      notificationMinute: (json['notificationMinute'] as int? ?? 0).clamp(
        0,
        59,
      ),
    );
  }

  final bool onboardingComplete;
  final String selectedPetId;
  final String petName;
  final List<String> taskTitles;
  final List<bool> completedToday;
  final String activeDay;
  final int lifetimeCompletions;
  final List<String> unlockedDecorIds;
  final NotificationPermissionState notificationPermission;
  final bool notificationEnabled;
  final int notificationHour;
  final int notificationMinute;

  bool get allDone => completedToday.every((value) => value);

  AppState copyWith({
    bool? onboardingComplete,
    String? selectedPetId,
    String? petName,
    List<String>? taskTitles,
    List<bool>? completedToday,
    String? activeDay,
    int? lifetimeCompletions,
    List<String>? unlockedDecorIds,
    NotificationPermissionState? notificationPermission,
    bool? notificationEnabled,
    int? notificationHour,
    int? notificationMinute,
  }) => AppState(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    selectedPetId: selectedPetId ?? this.selectedPetId,
    petName: petName ?? this.petName,
    taskTitles: taskTitles ?? this.taskTitles,
    completedToday: completedToday ?? this.completedToday,
    activeDay: activeDay ?? this.activeDay,
    lifetimeCompletions: lifetimeCompletions ?? this.lifetimeCompletions,
    unlockedDecorIds: unlockedDecorIds ?? this.unlockedDecorIds,
    notificationPermission:
        notificationPermission ?? this.notificationPermission,
    notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    notificationHour: notificationHour ?? this.notificationHour,
    notificationMinute: notificationMinute ?? this.notificationMinute,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'onboardingComplete': onboardingComplete,
    'selectedPetId': selectedPetId,
    'petName': petName,
    'taskTitles': taskTitles,
    'completedToday': completedToday,
    'activeDay': activeDay,
    'lifetimeCompletions': lifetimeCompletions,
    'unlockedDecorIds': unlockedDecorIds,
    'notificationPermission': notificationPermission.name,
    'notificationEnabled': notificationEnabled,
    'notificationHour': notificationHour,
    'notificationMinute': notificationMinute,
  };

  static String _nonEmpty(String? value, String fallback) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
