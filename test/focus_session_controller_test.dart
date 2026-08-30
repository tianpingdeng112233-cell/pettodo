import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/focus_session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pause and resume count only foreground elapsed time', () async {
    var now = DateTime(2026, 8, 30, 9);
    final completions = <FocusSessionCompletion>[];
    final controller = FocusSessionController(
      durationMinutes: 5,
      taskId: 'daily-1',
      now: () => now,
      tickInterval: null,
      onComplete: (completion) async => completions.add(completion),
    );
    addTearDown(controller.dispose);

    controller.start();
    now = now.add(const Duration(minutes: 2));
    controller.pause();
    expect(controller.state, FocusSessionState.paused);
    expect(controller.elapsed, const Duration(minutes: 2));

    now = now.add(const Duration(minutes: 20));
    controller.resume();
    now = now.add(const Duration(minutes: 3));
    await controller.tick();

    expect(controller.state, FocusSessionState.completed);
    expect(controller.elapsed, const Duration(minutes: 5));
    expect(completions, hasLength(1));
    expect(completions.single.minutes, 5);
    expect(completions.single.treats, 0);
    expect(completions.single.taskId, 'daily-1');

    await controller.tick();
    expect(completions, hasLength(1));
  });

  test('abandoning leaves no completion to settle', () async {
    var completionCount = 0;
    final controller = FocusSessionController(
      durationMinutes: 15,
      tickInterval: null,
      onComplete: (_) async => completionCount++,
    );
    addTearDown(controller.dispose);

    controller.start();
    controller.abandon();
    await controller.tick();

    expect(controller.state, FocusSessionState.abandoned);
    expect(completionCount, 0);
  });
}
