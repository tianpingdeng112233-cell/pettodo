import 'app_state.dart';
import 'local_day.dart';

AppState rollOverIfNeeded(AppState state, DateTime localNow) {
  final today = localDayKey(localNow);
  if (state.activeDay == today) return state;
  return state.copyWith(
    activeDay: today,
    tasks: state.tasks
        .map(
          (task) => task.kind == TaskKind.daily
              ? task.copyWith(completedToday: false)
              : task,
        )
        .toList(growable: false),
    feedingCountToday: 0,
    fedToday: null,
  );
}
