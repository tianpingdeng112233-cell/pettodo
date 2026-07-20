import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/event_log_store.dart';
import 'package:pettodo/domain/event_log.dart';

void main() {
  test('event JSONL round-trips all fields and ignores blank lines', () {
    final events = <PetEvent>[
      PetEvent(
        type: PetEventType.appOpen,
        timestamp: DateTime.parse('2026-07-20T08:10:00.000+01:00'),
      ),
      PetEvent(
        type: PetEventType.taskComplete,
        timestamp: DateTime.parse('2026-07-20T08:12:03.456+01:00'),
        data: const <String, Object?>{'taskIndex': 2},
      ),
      PetEvent(
        type: PetEventType.unlock,
        timestamp: DateTime.utc(2026, 7, 20, 7, 12, 4),
        data: const <String, Object?>{'decorId': 'soft_ball', 'threshold': 5},
      ),
      PetEvent(
        type: PetEventType.treatFeed,
        timestamp: DateTime.utc(2026, 7, 20, 7, 13),
      ),
      PetEvent(
        type: PetEventType.petTouch,
        timestamp: DateTime.utc(2026, 7, 20, 7, 14),
      ),
      PetEvent(
        type: PetEventType.stageUp,
        timestamp: DateTime.utc(2026, 7, 20, 7, 15),
      ),
    ];

    final decoded = decodeEventJsonl('${encodeEventJsonl(events)}\n\n');
    expect(
      decoded.map((event) => event.type),
      events.map((event) => event.type),
    );
    expect(
      decoded.map((event) => event.timestamp.toIso8601String()),
      events.map((event) => event.timestamp.toIso8601String()),
    );
    expect(decoded[1].data, <String, Object?>{'taskIndex': 2});
    expect(decoded[2].data?['decorId'], 'soft_ball');
  });

  test('event store appends and reads JSONL in order', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pettodo-event-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = EventLogStore(() async => directory);
    final first = PetEvent(
      type: PetEventType.appOpen,
      timestamp: DateTime.utc(2026, 7, 20),
    );
    final second = PetEvent(
      type: PetEventType.allDone,
      timestamp: DateTime.utc(2026, 7, 20, 1),
    );

    await Future.wait(<Future<void>>[
      store.append(first),
      store.append(second),
    ]);

    final decoded = await store.readAll();
    expect(decoded.map((event) => event.type), <PetEventType>[
      PetEventType.appOpen,
      PetEventType.allDone,
    ]);
    expect((await store.file).path, endsWith('pettodo-events.jsonl'));
  });
}
