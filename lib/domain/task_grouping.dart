import 'app_state.dart';

class HomeTaskGroups {
  HomeTaskGroups({
    required List<TodoTask> regular,
    required List<TodoTask> comingUp,
  }) : regular = List<TodoTask>.unmodifiable(regular),
       comingUp = List<TodoTask>.unmodifiable(comingUp);

  final List<TodoTask> regular;
  final List<TodoTask> comingUp;
}

HomeTaskGroups groupTasksForHome(
  List<TodoTask> tasks, {
  required DateTime now,
}) {
  final regular = <TodoTask>[];
  final comingUp = <({int index, TodoTask task})>[];
  for (final (index, task) in tasks.indexed) {
    final reminder = task.reminder;
    final scheduledAt = reminder?.scheduledAt;
    final belongsInComingUp =
        task.kind == TaskKind.oneOff &&
        reminder?.enabled == true &&
        scheduledAt != null &&
        scheduledAt.isAfter(now);
    if (belongsInComingUp) {
      comingUp.add((index: index, task: task));
    } else {
      regular.add(task);
    }
  }
  comingUp.sort((a, b) {
    final byTime = a.task.reminder!.scheduledAt!.compareTo(
      b.task.reminder!.scheduledAt!,
    );
    return byTime != 0 ? byTime : a.index.compareTo(b.index);
  });
  return HomeTaskGroups(
    regular: regular,
    comingUp: comingUp.map((entry) => entry.task).toList(growable: false),
  );
}
