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

  // Resting hours must hold a single frame. Looping a generated row reads as
  // twitching (neighbouring frames differ by 37-46% of their pixels), and the
  // v2 contract calls idle "low-distraction" for the same reason. The pet moves
  // on events — completions, treats, touches — not continuously.
  test('every resting hour holds a still frame instead of looping', () {
    for (final entry in petDailySchedule) {
      expect(
        entry.fixedFrame,
        isNotNull,
        reason: '${entry.id} would loop its row all day',
      );
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
