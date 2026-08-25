import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/data/device_id_store.dart';
import 'package:pettodo/data/feature_gate.dart';

void main() {
  test('device id is a persistent lowercase UUID', () async {
    final directory = await Directory.systemTemp.createTemp(
      'hatch-device-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final firstStore = DeviceIdStore(() async => directory, random: Random(7));

    final first = await firstStore.loadOrCreate();
    final second = await DeviceIdStore(
      () async => directory,
      random: Random(9),
    ).loadOrCreate();

    expect(first, second);
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('local feature gate stays locked until unlock is stored', () async {
    final directory = await Directory.systemTemp.createTemp('hatch-gate-test');
    addTearDown(() => directory.delete(recursive: true));
    final gate = LocalFeatureGate(() async => directory);

    expect(await gate.isUnlocked(), isFalse);
    await gate.unlock();
    expect(await LocalFeatureGate(() async => directory).isUnlocked(), isTrue);
  });
}
