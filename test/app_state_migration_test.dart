import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/domain/app_state.dart';

void main() {
  test('v1 JSON migrates to v2 with neutral treat defaults', () {
    final state = AppState.fromJson(<String, Object?>{
      'schemaVersion': 1,
      'onboardingComplete': true,
      'selectedPetId': 'choco',
      'petName': 'Cocoa',
      'taskTitles': const <String>['One', 'Two', 'Three'],
      'completedToday': const <bool>[true, false, false],
      'activeDay': '2026-07-20',
      'lifetimeCompletions': 39,
      'unlockedDecorIds': const <String>['soft_ball'],
      'notificationPermission': 'notRequested',
      'notificationEnabled': false,
      'notificationHour': 20,
      'notificationMinute': 0,
    }, DateTime(2026, 7, 20));

    expect(state.petName, 'Cocoa');
    expect(state.lifetimeCompletions, 39);
    expect(state.unlockedDecorIds, <String>['soft_ball', 'flower', 'home']);
    expect(state.treats, 0);
    expect(state.fedToday, isNull);
    expect(state.toJson()['schemaVersion'], 2);
  });
}
