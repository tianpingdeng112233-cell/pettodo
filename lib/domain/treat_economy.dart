import 'app_state.dart';

int treatDropForCompletion({required bool completesDailySet}) =>
    completesDailySet ? 3 : 1;

AppState awardTreats(AppState state, int amount) {
  if (amount < 0) throw ArgumentError.value(amount, 'amount');
  return state.copyWith(treats: state.treats + amount);
}
