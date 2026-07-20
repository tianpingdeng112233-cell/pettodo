import 'app_state.dart';
import 'local_day.dart';

int treatDropForCompletion({required bool completesDailySet}) =>
    completesDailySet ? 3 : 1;

AppState awardTreats(AppState state, int amount) {
  if (amount < 0) throw ArgumentError.value(amount, 'amount');
  return state.copyWith(treats: state.treats + amount);
}

AppState? spendTreatToFeed(AppState state, DateTime localNow) {
  if (state.treats == 0) return null;
  return state.copyWith(
    treats: state.treats - 1,
    fedToday: localDayKey(localNow),
  );
}
