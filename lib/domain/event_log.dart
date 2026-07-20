import 'dart:convert';

enum PetEventType {
  appOpen('app_open'),
  taskComplete('task_complete'),
  taskAdd('task_add'),
  taskRemove('task_remove'),
  taskEdit('task_edit'),
  oneoffComplete('oneoff_complete'),
  allDone('all_done'),
  notificationTap('notification_tap'),
  unlock('unlock'),
  treatFeed('treat_feed'),
  petTouch('pet_touch'),
  stageUp('stage_up');

  const PetEventType(this.wireName);
  final String wireName;

  static PetEventType fromWireName(String value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => throw FormatException('Unknown event type: $value'),
  );
}

class PetEvent {
  const PetEvent({required this.type, required this.timestamp, this.data});

  final PetEventType type;
  final DateTime timestamp;
  final Map<String, Object?>? data;

  factory PetEvent.fromJson(Map<String, Object?> json) => PetEvent(
    type: PetEventType.fromWireName(json['type']! as String),
    timestamp: DateTime.parse(json['timestamp']! as String),
    data: (json['data'] as Map<Object?, Object?>?)?.map(
      (key, value) => MapEntry(key! as String, value),
    ),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.wireName,
    'timestamp': timestamp.toIso8601String(),
    if (data != null && data!.isNotEmpty) 'data': data,
  };
}

String encodeEventLine(PetEvent event) => jsonEncode(event.toJson());

PetEvent decodeEventLine(String line) =>
    PetEvent.fromJson(jsonDecode(line) as Map<String, Object?>);

String encodeEventJsonl(Iterable<PetEvent> events) =>
    events.map(encodeEventLine).join('\n');

List<PetEvent> decodeEventJsonl(String jsonl) => jsonl
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .map(decodeEventLine)
    .toList(growable: false);
