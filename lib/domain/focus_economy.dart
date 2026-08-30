int treatDropForFocus(int minutes) {
  if (minutes <= 0) throw ArgumentError.value(minutes, 'minutes');
  return minutes ~/ 15;
}
