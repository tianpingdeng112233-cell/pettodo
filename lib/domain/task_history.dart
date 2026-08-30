import 'event_log.dart';

enum HistoryItemKind { task, focus }

class HistoryItem {
  const HistoryItem({
    required this.kind,
    required this.taskId,
    required this.title,
    required this.completedAt,
    this.minutes,
  });

  final HistoryItemKind kind;
  final String taskId;
  final String title;
  final DateTime completedAt;
  final int? minutes;
}

class HistoryDay {
  const HistoryDay({required this.date, required this.items});

  final DateTime date;
  final List<HistoryItem> items;
}

class HistoryWeek {
  const HistoryWeek({
    required this.weekStart,
    required this.days,
    required this.total,
  });

  final DateTime weekStart;
  final List<HistoryDay> days;
  final int total;
}

List<HistoryWeek> aggregatePositiveHistory(Iterable<PetEvent> events) {
  final completions =
      events
          .where(
            (event) =>
                event.type == PetEventType.taskComplete ||
                event.type == PetEventType.oneoffComplete ||
                event.type == PetEventType.focusComplete,
          )
          .map((event) {
            final data = event.data;
            final local = event.timestamp.toLocal();
            if (event.type == PetEventType.focusComplete) {
              final minutes = data?['minutes'] as int? ?? 0;
              if (minutes <= 0) return null;
              return HistoryItem(
                kind: HistoryItemKind.focus,
                taskId: data?['taskId'] as String? ?? '',
                title: '',
                completedAt: local,
                minutes: minutes,
              );
            }
            final title = (data?['title'] as String? ?? '').trim();
            if (title.isEmpty) return null;
            return HistoryItem(
              kind: HistoryItemKind.task,
              taskId: data?['taskId'] as String? ?? '',
              title: title,
              completedAt: local,
            );
          })
          .whereType<HistoryItem>()
          .toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  final byWeek = <DateTime, List<HistoryItem>>{};
  for (final item in completions) {
    final day = DateTime(
      item.completedAt.year,
      item.completedAt.month,
      item.completedAt.day,
    );
    final week = day.subtract(Duration(days: day.weekday - DateTime.monday));
    byWeek.putIfAbsent(week, () => <HistoryItem>[]).add(item);
  }

  final weeks = byWeek.entries.map((entry) {
    final byDay = <DateTime, List<HistoryItem>>{};
    for (final item in entry.value) {
      final day = DateTime(
        item.completedAt.year,
        item.completedAt.month,
        item.completedAt.day,
      );
      byDay.putIfAbsent(day, () => <HistoryItem>[]).add(item);
    }
    final days =
        byDay.entries
            .map(
              (day) => HistoryDay(
                date: day.key,
                items: List<HistoryItem>.unmodifiable(day.value),
              ),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return HistoryWeek(
      weekStart: entry.key,
      days: List<HistoryDay>.unmodifiable(days),
      total: entry.value.length,
    );
  }).toList()..sort((a, b) => b.weekStart.compareTo(a.weekStart));
  return List<HistoryWeek>.unmodifiable(weeks);
}
