String localDayKey(DateTime localTime) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${localTime.year}-${twoDigits(localTime.month)}-'
      '${twoDigits(localTime.day)}';
}
