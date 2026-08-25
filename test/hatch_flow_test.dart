import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/application/hatch_flow.dart';
import 'package:pettodo/data/feature_gate.dart';
import 'package:pettodo/data/hatch_api_client.dart';

void main() {
  test('submit polls with backoff then imports a ready pack', () async {
    final api = _FakeHatchApi(
      statuses: <HatchStatusResponse>[
        const HatchStatusResponse(status: HatchRemoteStatus.incubating),
        const HatchStatusResponse(status: HatchRemoteStatus.incubating),
        HatchStatusResponse(
          status: HatchRemoteStatus.ready,
          packUrl: Uri.parse('https://cdn.example/pip.pettodopet'),
        ),
      ],
    );
    final delays = <Duration>[];
    var imports = 0;
    final machine = HatchFlowMachine(
      api: api,
      featureGate: _MemoryFeatureGate(unlocked: true),
      delay: (duration) async => delays.add(duration),
      importPack: (file) async => imports++,
    );

    await machine.submit(photos: <File>[File('front.jpg')], petName: 'Pip');

    expect(machine.state.phase, HatchFlowPhase.ready);
    expect(api.submitCalls, 1);
    expect(api.statusCalls, 3);
    expect(imports, 1);
    expect(delays, <Duration>[
      const Duration(seconds: 15),
      const Duration(seconds: 30),
    ]);
  });

  test('polling backs off to 60 seconds and exposes failed gently', () async {
    final api = _FakeHatchApi(
      statuses: <HatchStatusResponse>[
        const HatchStatusResponse(status: HatchRemoteStatus.incubating),
        const HatchStatusResponse(status: HatchRemoteStatus.incubating),
        const HatchStatusResponse(status: HatchRemoteStatus.incubating),
        const HatchStatusResponse(status: HatchRemoteStatus.failed),
      ],
    );
    final delays = <Duration>[];
    final machine = HatchFlowMachine(
      api: api,
      featureGate: _MemoryFeatureGate(unlocked: true),
      delay: (duration) async => delays.add(duration),
      importPack: (_) async => fail('failed hatch must not import'),
    );

    await machine.submit(photos: <File>[File('front.jpg')], petName: 'Pip');

    expect(machine.state.phase, HatchFlowPhase.failed);
    expect(machine.state.message, isNot(contains('your fault')));
    expect(delays, <Duration>[
      const Duration(seconds: 15),
      const Duration(seconds: 30),
      const Duration(seconds: 60),
    ]);
  });

  test('locked gate prevents any submission', () async {
    final api = _FakeHatchApi(statuses: const <HatchStatusResponse>[]);
    final machine = HatchFlowMachine(
      api: api,
      featureGate: _MemoryFeatureGate(unlocked: false),
      delay: (_) async {},
      importPack: (_) async {},
    );

    await machine.submit(photos: <File>[File('front.jpg')], petName: 'Pip');

    expect(machine.state.phase, HatchFlowPhase.locked);
    expect(api.submitCalls, 0);
  });

  test('the accepted hatchId is persisted even if paused mid-submit', () async {
    final api = _GatedSubmitApi(
      statuses: <HatchStatusResponse>[
        const HatchStatusResponse(status: HatchRemoteStatus.incubating),
      ],
    );
    String? persisted;
    final machine = HatchFlowMachine(
      api: api,
      featureGate: _MemoryFeatureGate(unlocked: true),
      delay: (_) async {},
      importPack: (_) async {},
      onAccepted: (hatchId) async => persisted = hatchId,
    );
    final pending = machine.submit(
      photos: <File>[File('front.jpg')],
      petName: 'Pip',
    );
    machine.pause(); // app backgrounded while the POST is in flight
    api.submitGate.complete();
    await pending;

    expect(persisted, 'hatch-1'); // quota slot must never be stranded
  });

  test('a ready hatch fires the adoption-ready notifier', () async {
    final api = _FakeHatchApi(
      statuses: <HatchStatusResponse>[
        HatchStatusResponse(
          status: HatchRemoteStatus.ready,
          packUrl: Uri.parse('https://cdn.example/pip.pettodopet'),
        ),
      ],
    );
    var notified = 0;
    final machine = HatchFlowMachine(
      api: api,
      featureGate: _MemoryFeatureGate(unlocked: true),
      delay: (_) async {},
      importPack: (_) async {},
      onReady: () async => notified++,
    );
    await machine.submit(photos: <File>[File('front.jpg')], petName: 'Pip');
    expect(notified, 1);
  });

  test(
    'pause then resume before the POST lands still continues the hatch',
    () async {
      final api = _GatedSubmitApi(
        statuses: <HatchStatusResponse>[
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/pip.pettodopet'),
          ),
        ],
      );
      var imports = 0;
      final machine = HatchFlowMachine(
        api: api,
        featureGate: _MemoryFeatureGate(unlocked: true),
        delay: (_) async {},
        importPack: (_) async => imports++,
        onAccepted: (_) async {},
      );
      final pending = machine.submit(
        photos: <File>[File('front.jpg')],
        petName: 'Pip',
      );
      machine.pause();
      machine.resumeForeground();
      api.submitGate.complete();
      await pending;
      // give the self-healed resume a chance to run to completion
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(api.statusCalls, greaterThan(0)); // never stuck on submitting
      expect(imports, 1);
    },
  );

  test(
    'a POST landing after dispose persists the id but never notifies',
    () async {
      final api = _GatedSubmitApi(statuses: const <HatchStatusResponse>[]);
      String? persisted;
      var changes = 0;
      final machine = HatchFlowMachine(
        api: api,
        featureGate: _MemoryFeatureGate(unlocked: true),
        delay: (_) async {},
        importPack: (_) async {},
        onAccepted: (hatchId) async => persisted = hatchId,
        onChanged: () => changes++,
      );
      final pending = machine.submit(
        photos: <File>[File('front.jpg')],
        petName: 'Pip',
      );
      final before = changes;
      machine.dispose();
      api.submitGate.complete();
      await pending;

      expect(persisted, 'hatch-1'); // the quota slot survives the shutdown
      expect(changes, before); // but a dead listener is never notified
    },
  );

  test('a second submit while one is in flight is ignored', () async {
    final api = _GatedSubmitApi(
      statuses: <HatchStatusResponse>[
        HatchStatusResponse(
          status: HatchRemoteStatus.ready,
          packUrl: Uri.parse('https://cdn.example/pip.pettodopet'),
        ),
      ],
    );
    final machine = HatchFlowMachine(
      api: api,
      featureGate: _MemoryFeatureGate(unlocked: true),
      delay: (_) async {},
      importPack: (_) async {},
    );
    final first = machine.submit(
      photos: <File>[File('front.jpg')],
      petName: 'Pip',
    );
    final second = machine.submit(
      photos: <File>[File('front.jpg')],
      petName: 'Pip',
    );
    api.submitGate.complete();
    await first;
    await second;
    expect(api.submitCalls, 1); // one quota slot, not two
  });

  test(
    'duplicate resume for the same hatch keeps a single polling loop',
    () async {
      final gate = Completer<void>();
      final api = _FakeHatchApi(
        statuses: <HatchStatusResponse>[
          const HatchStatusResponse(status: HatchRemoteStatus.incubating),
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/pip.pettodopet'),
          ),
        ],
      );
      var imports = 0;
      final machine = HatchFlowMachine(
        api: api,
        featureGate: _MemoryFeatureGate(unlocked: true),
        delay: (_) => gate.future,
        importPack: (_) async => imports++,
      );
      final first = machine.resume('hatch-1');
      await Future<void>.delayed(Duration.zero);
      final second = machine.resume('hatch-1'); // e.g. onResume after self-heal
      gate.complete();
      await first;
      await second;
      expect(imports, 1); // never a double import / double ceremony
    },
  );

  test(
    'pause then resumeForeground still restarts polling on resume',
    () async {
      final api = _FakeHatchApi(
        statuses: <HatchStatusResponse>[
          const HatchStatusResponse(status: HatchRemoteStatus.incubating),
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/pip.pettodopet'),
          ),
        ],
      );
      var imports = 0;
      final machine = HatchFlowMachine(
        api: api,
        featureGate: _MemoryFeatureGate(unlocked: true),
        delay: (_) async {},
        importPack: (_) async => imports++,
      );
      final first = machine.resume('hatch-1');
      await Future<void>.delayed(Duration.zero);
      machine.pause(); // backgrounded mid-incubation
      machine.resumeForeground(); // app back — controller then calls resume()
      final second = machine.resume('hatch-1');
      await first;
      await second;
      expect(imports, 1); // the dead loop was really restarted
    },
  );

  test('pause during an import never double-imports on resume', () async {
    final importGate = Completer<void>();
    final api = _FakeHatchApi(
      statuses: <HatchStatusResponse>[
        HatchStatusResponse(
          status: HatchRemoteStatus.ready,
          packUrl: Uri.parse('https://cdn.example/pip.pettodopet'),
        ),
        HatchStatusResponse(
          status: HatchRemoteStatus.ready,
          packUrl: Uri.parse('https://cdn.example/pip.pettodopet'),
        ),
      ],
    );
    var imports = 0;
    final machine = HatchFlowMachine(
      api: api,
      featureGate: _MemoryFeatureGate(unlocked: true),
      delay: (_) async {},
      importPack: (_) async {
        imports++;
        await importGate.future;
      },
    );
    final first = machine.resume('hatch-1');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    machine.pause(); // backgrounded while the pack installs
    machine.resumeForeground();
    final second = machine.resume('hatch-1'); // must wait out the import
    importGate.complete();
    await first;
    await second;

    expect(imports, 1);
    expect(machine.state.phase, HatchFlowPhase.ready);
  });

  test(
    'an import failing after pause still surfaces a gentle failed state',
    () async {
      final importGate = Completer<void>();
      final api = _FakeHatchApi(
        statuses: <HatchStatusResponse>[
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/pip.pettodopet'),
          ),
        ],
      );
      final machine = HatchFlowMachine(
        api: api,
        featureGate: _MemoryFeatureGate(unlocked: true),
        delay: (_) async {},
        importPack: (_) async {
          await importGate.future;
          throw const FormatException('broken pack');
        },
      );
      final first = machine.resume('hatch-1');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      machine.pause();
      machine.resumeForeground();
      importGate.complete();
      await first;

      // never stuck on downloading with no live loop
      expect(machine.state.phase, isNot(HatchFlowPhase.downloading));
      expect(machine.state.message, isNot(contains('your fault')));
    },
  );

  test(
    'a stale run failing its late download never clobbers the live run',
    () async {
      final firstDownload = Completer<File>();
      final api = _PerCallDownloadApi(
        statuses: <HatchStatusResponse>[
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/a.pettodopet'),
          ),
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/b.pettodopet'),
          ),
        ],
        downloads: <Future<File>>[
          firstDownload.future,
          Future<File>.value(File('ready.pettodopet')),
        ],
      );
      var imports = 0;
      final machine = HatchFlowMachine(
        api: api,
        featureGate: _MemoryFeatureGate(unlocked: true),
        delay: (_) async {},
        importPack: (_) async => imports++,
      );
      final first = machine.resume('hatch-1'); // run A blocks on download
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      machine.pause();
      machine.resumeForeground();
      final second = machine.resume('hatch-1'); // run B downloads + imports
      await second;
      expect(machine.state.phase, HatchFlowPhase.ready);
      firstDownload.completeError(const HatchConnectionIssue()); // A fails late
      await first;

      expect(machine.state.phase, HatchFlowPhase.ready); // B's outcome stands
      expect(imports, 1);
    },
  );

  test(
    'a stale download failure cannot clobber a live incubating run',
    () async {
      final firstDownload = Completer<File>();
      final pollGate = Completer<void>();
      final api = _PerCallDownloadApi(
        statuses: <HatchStatusResponse>[
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/a.pettodopet'),
          ),
          const HatchStatusResponse(status: HatchRemoteStatus.incubating),
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/b.pettodopet'),
          ),
        ],
        downloads: <Future<File>>[
          firstDownload.future,
          Future<File>.value(File('ready.pettodopet')),
        ],
      );
      var imports = 0;
      final machine = HatchFlowMachine(
        api: api,
        featureGate: _MemoryFeatureGate(unlocked: true),
        delay: (_) => pollGate.future,
        importPack: (_) async => imports++,
      );
      final first = machine.resume('hatch-1'); // run A blocks on download
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      machine.pause();
      machine.resumeForeground();
      final second = machine.resume('hatch-1'); // run B: incubating wait
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      firstDownload.completeError(const HatchConnectionIssue()); // A fails NOW
      await first;

      expect(machine.state.phase, HatchFlowPhase.incubating); // B untouched
      pollGate.complete();
      await second;
      expect(machine.state.phase, HatchFlowPhase.ready);
      expect(imports, 1);
    },
  );

  test(
    'a stale successful download cannot release the live import lock',
    () async {
      final firstDownload = Completer<File>();
      final importGate = Completer<void>();
      final api = _PerCallDownloadApi(
        statuses: <HatchStatusResponse>[
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/a.pettodopet'),
          ),
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/b.pettodopet'),
          ),
          HatchStatusResponse(
            status: HatchRemoteStatus.ready,
            packUrl: Uri.parse('https://cdn.example/c.pettodopet'),
          ),
        ],
        downloads: <Future<File>>[
          firstDownload.future,
          Future<File>.value(File('ready.pettodopet')),
          Future<File>.value(File('ready.pettodopet')),
        ],
      );
      var imports = 0;
      final machine = HatchFlowMachine(
        api: api,
        featureGate: _MemoryFeatureGate(unlocked: true),
        delay: (_) async {},
        importPack: (_) async {
          imports++;
          await importGate.future;
        },
      );
      final first = machine.resume('hatch-1'); // A blocks on download
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      machine.pause();
      machine.resumeForeground();
      final second = machine.resume('hatch-1'); // B downloads, starts import
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      firstDownload.complete(File('late.pettodopet')); // A returns inactive
      await first;
      machine.pause();
      machine.resumeForeground();
      final third = machine.resume('hatch-1'); // must be blocked by B's import
      await third;
      expect(imports, 1); // C never started a concurrent import
      importGate.complete();
      await second;
      expect(imports, 1);
      expect(machine.state.phase, HatchFlowPhase.ready);
    },
  );

  test('a species wish completing after dispose never notifies', () async {
    final api = _GatedSubmitApi(statuses: const <HatchStatusResponse>[]);
    var changes = 0;
    final machine = HatchFlowMachine(
      api: api,
      featureGate: _MemoryFeatureGate(unlocked: true),
      delay: (_) async {},
      importPack: (_) async {},
      onChanged: () => changes++,
    );
    final wish = machine.submitSpeciesWish('rabbit');
    machine.dispose();
    await wish;
    final after = changes;
    expect(machine.state.wishSent, isFalse);
    expect(changes, after); // no late notifications into a disposed listener
  });
}

class _MemoryFeatureGate implements FeatureGate {
  _MemoryFeatureGate({required this.unlocked});

  bool unlocked;

  @override
  String get priceLabel => 'One-time price coming soon';

  @override
  Future<bool> isUnlocked() async => unlocked;

  @override
  Future<void> unlock() async => unlocked = true;
}

class _FakeHatchApi implements HatchApi {
  _FakeHatchApi({required this.statuses});

  final List<HatchStatusResponse> statuses;
  int submitCalls = 0;
  int statusCalls = 0;

  @override
  Future<File> downloadPack(Uri url) async => File('ready.pettodopet');

  @override
  Future<HatchStatusResponse> getHatchStatus(String hatchId) async {
    final response = statuses[statusCalls];
    statusCalls++;
    return response;
  }

  @override
  Future<HatchSubmission> submitHatch({
    required List<File> photos,
    required String petName,
  }) async {
    submitCalls++;
    return const HatchSubmission(hatchId: 'hatch-1');
  }

  @override
  Future<void> submitSpeciesWish(String speciesText) async {}
}

class _GatedSubmitApi extends _FakeHatchApi {
  _GatedSubmitApi({required super.statuses});

  final Completer<void> submitGate = Completer<void>();

  @override
  Future<HatchSubmission> submitHatch({
    required List<File> photos,
    required String petName,
  }) async {
    await submitGate.future;
    return super.submitHatch(photos: photos, petName: petName);
  }
}

class _PerCallDownloadApi extends _FakeHatchApi {
  _PerCallDownloadApi({required super.statuses, required this.downloads});

  final List<Future<File>> downloads;
  int downloadCalls = 0;

  @override
  Future<File> downloadPack(Uri url) => downloads[downloadCalls++];
}
