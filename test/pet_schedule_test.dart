import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/pet_schedule.dart';

void main() {
  test('daily schedule covers every local hour with one positive state', () {
    for (var hour = 0; hour < 24; hour++) {
      final matches = petDailySchedule.where(
        (entry) => entry.includesHour(hour),
      );
      expect(matches, hasLength(1), reason: 'hour $hour');
      expect(matches.single.statusFor('Choco'), contains('Choco'));
    }
  });

  test('schedule exposes the four companion moments', () {
    expect(petScheduleAt(DateTime(2026, 7, 20, 8)).animation, 'waving');
    expect(
      petScheduleAt(DateTime(2026, 7, 20, 12)).effect,
      PetScheduleEffect.zzz,
    );
    expect(petScheduleAt(DateTime(2026, 7, 20, 15)).animation, 'idle');
    expect(petScheduleAt(DateTime(2026, 7, 20, 20)).animation, 'look-row-10');
  });
}
