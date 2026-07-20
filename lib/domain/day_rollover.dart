import 'app_state.dart';
import 'local_day.dart';

AppState rollOverIfNeeded(AppState state, DateTime localNow) {
  final today = localDayKey(localNow);
  if (state.activeDay == today) return state;
  return state.copyWith(
    activeDay: today,
    completedToday: const <bool>[false, false, false],
    fedToday: null,
  );
}
