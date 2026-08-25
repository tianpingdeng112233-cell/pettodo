import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/pet_action.dart';
import 'package:pettodo/domain/pet_schedule.dart';

void main() {
  test('rig schedule routes each time period to a rig action', () {
    expect(
      rigActionForSchedule(petScheduleAt(DateTime(2026, 8, 25, 8))),
      RigPetAction.morningStretch,
    );
    expect(
      rigActionForSchedule(petScheduleAt(DateTime(2026, 8, 25, 12))),
      RigPetAction.sleepTransition,
    );
    expect(
      rigActionForSchedule(petScheduleAt(DateTime(2026, 8, 25, 15))),
      RigPetAction.breathing,
    );
    expect(
      rigActionForSchedule(petScheduleAt(DateTime(2026, 8, 25, 20))),
      RigPetAction.breathing,
    );
  });

  test('positive events route to rig actions without a failed reaction', () {
    expect(
      rigActionForEvent(PetActionEvent.taskCompleted),
      RigPetAction.happyJump,
    );
    expect(rigActionForEvent(PetActionEvent.treatFed), RigPetAction.eatTreat);
    expect(rigActionForEvent(PetActionEvent.touched), RigPetAction.headFollow);
    expect(rigActionForEvent(PetActionEvent.longPressed), RigPetAction.nuzzle);
    expect(
      RigPetAction.values.map((action) => action.name),
      isNot(contains('failed')),
    );
  });
}
