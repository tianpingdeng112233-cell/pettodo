import 'pet_schedule.dart';

enum RigPetAction {
  breathing,
  headFollow,
  nuzzle,
  happyJump,
  eatTreat,
  morningStretch,
  sleepTransition,
  running,
}

enum PetActionEvent { taskCompleted, treatFed, touched, longPressed }

RigPetAction rigActionForSchedule(PetScheduleEntry schedule) =>
    switch (schedule.id) {
      'morning_stretch' => RigPetAction.morningStretch,
      'midday_nap' => RigPetAction.sleepTransition,
      'afternoon_idle' || 'evening_window' => RigPetAction.breathing,
      _ => RigPetAction.breathing,
    };

RigPetAction rigActionForEvent(PetActionEvent event) => switch (event) {
  PetActionEvent.taskCompleted => RigPetAction.happyJump,
  PetActionEvent.treatFed => RigPetAction.eatTreat,
  PetActionEvent.touched => RigPetAction.headFollow,
  PetActionEvent.longPressed => RigPetAction.nuzzle,
};
