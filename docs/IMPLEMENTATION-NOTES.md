# PetTodo v1 Implementation Notes

## Architecture

- `lib/domain/` is pure Dart. It owns the one-to-seven active-task invariant, local-day rollover, positive-history aggregation, cumulative unlock thresholds, persisted state shape, and JSONL event encoding. It has no Flutter imports.
- `lib/data/` owns the atomic single-JSON state file, append-and-flush JSONL event file, local notification scheduling, and share-sheet export.
- `lib/sprite/` owns pet discovery, atlas metadata parsing, decoded image lifetime, frame math, and rendering.
- `lib/application/` is the presentation-independent `ChangeNotifier` coordinator. It is intentionally outside `lib/ui/`, so a designer reskin does not move persistence, task, notification, animation sequencing, or event behavior.
- `lib/ui/` contains all screens, placeholder theme, task cards, banner, decoration placement, and particles. A visual reskin should stay in this folder unless it introduces a new product behavior.

## Sprite renderer decision

The app uses a small custom `CustomPainter` plus Flutter `Ticker`, not Flame. At roughly 8 fps the painter selects a source rectangle from the decoded WebP and calls `canvas.drawImageRect` with `FilterQuality.none`. This keeps pixel edges crisp, avoids a game-engine dependency for one animated actor, and leaves animation state under the application coordinator. The tradeoff is that batching, scene graphs, and richer game effects would need to be built if the product later becomes substantially more game-like.

Frame counts, row indexes, cell size, and image dimensions are parsed at runtime from `pet_request.json`; only safe product state names (`idle`, `jumping`, `waving`, `review`) are selected by v1 behavior. The `failed` row is never selected.

## Rig layer baking must stay on the CPU (2026-08-28)

Every pixel operation in rig pack composition — head/tail cutouts, part masks,
and the pixelScale downscale — runs as plain Dart pixel arithmetic in
`lib/sprite/rig_pet.dart`, never through `Picture.toImage`. GPU-backend
rasterization is not trustworthy for this: Impeller silently no-ops
`BlendMode.clear`/`dstIn` (+`MaskFilter`) erases (the moving head ghosted over
its baked-in twin) and its `drawImageRect` filtering of transparent pixels
shifted layer colours — while the software Skia used by `flutter test` renders
both correctly, so tests can never catch a regression that reintroduces GPU
baking. If you touch layer composition, keep it CPU-side and verify on an
Android emulator, not just in tests.

## Adding pet #2

Add the new pet folder beneath `assets/pets/`, declare its metadata and atlas files under Flutter assets, and append one descriptor to `assets/pets/manifest.json`. No Dart code change is needed. The manifest supplies pet id, display name, metadata path, and spritesheet path; the metadata supplies the atlas grid and sequences.

## Notifications

Permission is requested only from an explicit opt-in action. A system denial is persisted; the toggle then stays off and cannot trigger another request. Skipping onboarding leaves permission unrequested, so a later explicit Settings toggle remains a valid first opt-in.

The service schedules 32 one-shot invitations in advance, rotating four warm copy variants. Each future fire time is first constructed as a device-local `DateTime` (so known DST transitions are reflected) and then converted to the UTC `TZDateTime` required by `flutter_local_notifications`. Launch/resume and setting changes refill the window. Android uses inexact-while-idle alarms, avoiding exact-alarm permission and its additional prompt/store-policy burden. Boot receivers restore scheduled entries after restart.

`timezone` is promoted from `flutter_local_notifications`' existing transitive dependency to a direct dependency because its public scheduling API requires `TZDateTime`; no additional package download is introduced.

## Persistence and export

State is a versioned JSON object in application support storage. Writes use a flushed temporary file followed by rename. Events are appended and flushed as newline-delimited JSON in application documents storage. Export shares that `.jsonl` file directly with MIME type `application/x-ndjson`; no network or analytics service is involved.

## Review flags

- The v1 app version is displayed from the committed `pubspec.yaml` value (`1.0.0+1`) without adding a package-info dependency. Keep the Settings string in sync when changing that version.
- UI is deliberately a warm, accessible placeholder. Product logic and sprite behavior do not depend on its layout.

## Build status

- `flutter analyze`: clean, no issues.
- `flutter test`: 9 tests passed, including day rollover, all unlock edges, file-backed JSONL ordering/round-trip, and bundled atlas frame math.
- iOS: `Runner` Debug simulator build succeeded with signing disabled on iPhone 17 / iOS 26.5 through XcodeBuildMCP; the built app also installed and launched successfully.
- Android: debug APK built successfully at `build/app/outputs/flutter-apk/app-debug.apk`. The runtime note's unversioned Homebrew JDK path now resolves to JDK 26, which is newer than Gradle 9.1 supports, so validation used the already-installed JDK 21 path (`/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`). The user's Flutter JDK setting was restored after the build.

## Orchestrator gotchas (2026-07-20)

- **Case-insensitive APFS + git**: `Assets/` and `assets/` are the SAME directory on macOS. A `git rm -r Assets` intended to drop "duplicate" old-case entries physically deleted the shared sprite files (restored in a follow-up commit from `~/Projects/choco-pet`). Never assume two case-variant paths are two directories; check `ls -di` inode first.
- **flutter_test zone traps**: (1) real async IO awaited OUTSIDE `tester.runAsync` never completes (fake-async zone) — e.g. `Directory.systemTemp.createTemp` hangs the test silently; use sync variants or move inside runAsync. (2) Objects whose constructors capture `Future.value()` chains (our stores) MUST be constructed inside `runAsync`, or their `.then` chains bind to the fake zone and deadlock. (3) Timers created under runAsync are real-zone timers — `tester.pump(duration)` won't fire them; wait real time inside runAsync instead.
- **JDK for gradle**: `flutter config --jdk-dir` overrides JAVA_HOME. Keep it pinned to `/opt/homebrew/opt/openjdk@21/...` — JDK 26 (bare `openjdk` formula) produces class file major 70 which Gradle 9.1 cannot parse.

## Task 005 — approved 1a UI (2026-07-20)

- The option-3b palette, type, radii, spacing, shadows, and motion values now live under `lib/ui/theme/`; Home, onboarding, and Settings consume those tokens instead of defining their own visual values.
- Home implements the option-1a stage and every option-2b moment: warm completed cards, the single-task hop, the delayed 3/3 Little Theater with its sole thank-you exit, and the 450 ms / 2.8 s keepsake banner. Settings edits write through to the same controller state, and collection language has no bars or deadlines.
- Notifications now rotate exactly the three canonical English title/body pairs from option 3a. The UI/default-task/export copy is English as well.
- Baloo 2 could not be downloaded because the runner had no DNS access to the Google Fonts GitHub source. Per the runtime fallback instruction, display styles request Baloo 2 first and use the bundled platform rounded/system stack (`Arial Rounded MT Bold`, then `sans-serif`) without any runtime fetch. Add `Baloo2[wght].ttf` plus its OFL license and a matching `pubspec.yaml` font declaration when network access is restored.
- Current validation: `flutter analyze --no-pub` is clean; XcodeBuildMCP built, installed, and launched `Runner` Debug on iPhone 17 Pro / iOS 26.5, and the onboarding screenshot was visually inspected without overflow. This managed sandbox rejects localhost sockets, so `flutter test` cannot start its test server and Gradle cannot start its file-lock contention service; Android compilation could not be re-run here. The in-app browser backend was also unavailable, so HTML comparison used the committed computed inline styles directly.

## Task 005-R — semantics boundaries and overflow (2026-07-20)

- Custom tap targets now own container semantics above their gesture handlers, with visible text supplying labels and decorative art excluded. Regression coverage verifies separate onboarding, task-card, and Settings button nodes.
- Onboarding page bodies retain the approved layout at the design viewport while becoming vertically scrollable when available height is too small.

## Task 006 — raising system 2.0 (2026-07-20)

- State JSON is now schema v2. Existing v1 files migrate in place with `treats: 0` and `fedToday: null`, and newly eligible decor is backfilled from the preserved lifetime count; growth stage remains derived from `lifetimeCompletions` and is never persisted. Local-day rollover clears the three checks and `fedToday` silently while preserving every cumulative value.
- `lib/domain/growth.dart`, `treat_economy.dart`, and `pet_schedule.dart` own the tuneable 0/40/120 stage thresholds, treat award/spend rules (including the +2 Little Theater bonus), and the full-day companion schedule. The schedule is Flutter-free so Task 002's iOS widget can consume the same table.
- The pet manifest now declares each pet's treat type plus six decoration descriptors and fixed slots. Pet descriptors accept optional per-stage metadata/spritesheet overrides; Choco currently falls back to the shared atlas at all stages. The 005 theme layer supplies stage scale/frame treatments.
- Home supports tap-direction look frames, a fourteen-line affectionate voice pool, long-press nuzzling, transient heart/treat particles, feeding, schedule-driven animation/status, stage badge, fixed-slot decor, and a collection entry. The gallery is a two-column unlocked/silhouette collection with no progress bars or pressure copy; only Settings retains the gentle next-unlock distance.
- New JSONL events are `treat_feed`, `pet_touch`, and `stage_up`. `task_complete` also records the treat drop amount.
- Added regression coverage for stage and unlock edges, uncapped treat award/spend and the 3/3 bonus, 24-hour schedule coverage, silent fed-day rollover, v1-to-v2 migration, new event round-trips, and the updated transient animation return-to-schedule behavior.
- Validation in this managed sandbox: formatting and `git diff --check` pass. The first post-change `flutter analyze --no-pub` completed with only two unused-symbol warnings, both fixed immediately; subsequent analyzer invocations stalled after printing `Analyzing pettodo...`, and a targeted run exposed the cause as denied creation of `~/.dartServer/.plugin_manager`. `flutter test --no-pub` cannot start `flutter_tester` because binding `127.0.0.1:0` is forbidden. Android reaches Gradle with JDK 21 and a writable copied cache, then Gradle's `FileLockContentionHandler` socket is forbidden. iOS reaches Xcode/SwiftPM, but home-cache writes and CoreSimulatorService are forbidden; redirecting caches to `/tmp` still leaves the simulator service unavailable. No source-level test failure or compiler diagnostic was emitted, but clean analyze/tests and platform builds require rerunning outside this sandbox.

## Task 007 — todo usability baseline (2026-07-20)

- State JSON is schema v3. Active tasks are ID-addressed objects with `daily` / `oneOff` kind, optional one-line note, optional reminder time/toggle, and kind-appropriate completion fields. v2's three titles/checks migrate to three stable daily task objects while lifetime completions, unlocks, treats, feeding state, pet identity, and notification preference are preserved. The active-list invariant is one to seven total tasks with at least one daily anchor; the eighth add and removal/conversion of the final daily task simply return `false`.
- Home keeps the task area bounded and scrollable so seven items do not become a wall. Normal mode has the one-tap 「记一件事」 capture dialog with only a title required and `oneOff` as the default. Edit mode and Settings both add, edit, and remove tasks; the fuller editor exposes kind, one-line note, and an optional single reminder. Onboarding still suggests three starter tasks without making three a domain constraint.
- Completing a daily task marks only that ID for the active local day. Completing a one-off awards the ordinary treat drop, writes `oneoff_complete` with task ID/title/kind, and removes it from the active list so the event log becomes its positive history record. Only the transition to all daily tasks complete awards the set bonus and opens Little Theater. Silent rollover resets daily checks and feeding only; one-offs are left untouched and never receive age/due/overdue data.
- `task_add`, `task_remove`, `task_edit`, and `oneoff_complete` join JSONL. Positive history derives only titled `task_complete` / `oneoff_complete` events, groups them by local Monday week and local day, and renders only weeks that contain completions. Copy contains no streak, missed-day, unfinished, gap, red, or zero state.
- Notification scheduling now builds one shared, time-sorted 32-slot one-shot window from the optional evening invitation plus enabled per-task times. Each source contributes at most once per local day; a completed daily skips its current-day reminder, one-off completion removes future reminder candidates, and launch/resume/settings changes refill the shared window. The persisted global permission state is shared, so a denial from either opt-in prevents every later flow from requesting again.
- Added regression coverage for v2→v3 migration and v3 task fields, one-off controller lifecycle/treat/history event, daily rollover isolation from one-offs, denied-permission no-reask, sorted/capped reminder windows, one-fire-per-task/day, local-week positive history, and the new JSONL event names. Existing animation and semantics tests now drive task IDs and assert domain list truth where Home intentionally renders lazily.
- Validation in this managed sandbox: `flutter analyze --no-pub` completed cleanly after directing analyzer state to `/private/tmp`, and a socket-free Dart harness executed the v2 migration, daily/one-off rollover separation, and local-week history aggregation successfully. XcodeBuildMCP built, signed, installed, and launched `Runner` Debug from `ios/Runner.xcworkspace` on iPhone 17 Pro Max / iOS 26.5; the first iPhone 17 Pro install attempt lost its simulator service after a successful compile, and the second simulator completed normally. The available XcodeBuildMCP workflow exposed semantic snapshots but no tap/type/swipe executors, so the launched onboarding screen could be inspected but the scripted interaction walkthrough could not be advanced. `flutter test --no-pub` remains blocked before test loading because this sandbox forbids `flutter_tester` binding `127.0.0.1:0`. Android with the required JDK 21 and `--no-pub` reaches Gradle but cannot write the sandboxed `~/.gradle` distribution lock; a no-`--no-pub` attempt is additionally blocked by DNS. These are environment-level failures, not emitted source/test/compiler failures.

## Task 008 — own-pet hatch loop, wave 1 (2026-08-12)

- Pet packs are `.pettodopet` zips (`pack.json` formatVersion 1 + `pet_request.json` + `spritesheet-extended.webp`) installed atomically (staging → backup → rename) to `<documents>/pets/<id>/`; the runtime registry merges bundled manifest pets with installed packs, and `SpriteAtlasLoader` reads absolute paths from the filesystem while bundle-relative paths stay on rootBundle. Hatch requests live in `<documents>/hatch_request/` (1–5 photos + request.json, one pending max) and export as a zip via the share sheet.
- **Gotcha (caught in acceptance walkthrough): a custom file extension is unpickable in the iOS document picker unless the app declares it.** `file_picker`'s `UTType(filenameExtension:)` produces a dynamic UTI, and Files greys the file out. Fix: `UTExportedTypeDeclarations` in Info.plist declaring `com.davidshi.pettodo.pettodopet` conforming to `com.pkware.zip-archive`. Verified selectable + importable after the declaration. Android SAF import has NOT been UI-verified yet — verify before relying on `.pettodopet` there.
- **Gotcha: dispose ordering on same-id pack re-import.** The originally submitted code disposed the cached atlas before `await`-loading the replacement; if that pet is currently selected the UI can paint a disposed `ui.Image` during the async gap. Always load the new atlas first, swap `spriteAtlas`/cache, then dispose the old one (`unlockStages` already did this correctly). Verified by re-importing the selected pet's pack through the real picker.
- Known limits (wave 1): onboarding's pet list is still the hardcoded single Choco card, so a pet imported mid-onboarding only appears in Collection (and the deferred ceremony fires on first Home entry with `state.petName` possibly differing from the hatched name); exported request zips accumulate in `<documents>` (no cleanup on cancel); the invalid-pack snackbar path is covered by tests but was not visually confirmed in the walkthrough.

## Task 008 follow-ups — onboarding choice, export cleanup (2026-08-13)

Three of the wave-1 known limits above are now closed.

- **Onboarding lists the live registry.** `_ChoosePetPage` renders every entry of
  `controller.pets` (bundled + installed) as a selectable card instead of one
  hardcoded Choco, and `_finish` passes `state.selectedPetId` instead of the
  literal `'choco'`. The greeting, the name step's placeholder, and the hero
  sprite all follow the selection. Returning from the hatchery pre-fills the name
  field with the hatched name **only when the user has not typed one** — never
  overwrite their input. Single-pet onboarding is visually unchanged.
- **Exported request zips are cleaned up.** `export()` deletes every other
  `request-<digits>.zip` in documents and `cancel()` (which import also reaches
  via `clearIfMatchingPack`) deletes them all. Previously one zip per request the
  user ever sent stayed in documents forever — a real 139 KB leftover from the
  08-12 walkthrough was still on the simulator when this was found.
- **Invalid-pack snackbar visually confirmed**: importing a hatch-request zip as
  a pack shows the calm "This pack doesn't fit — ask for a fresh one." with no
  pet reaction. Zero-punishment line holds.

Walkthrough evidence (iPhone 17 Pro, clean install): onboarding → hatchery →
photo → export (ZIP 139 KB) → import `choco2.pettodopet` through the real picker
→ both cards listed with Choco Two selected → switch back and forth → finish →
Home shows Choco Two with the hatch ceremony. Documents held zero zips
afterwards. The `.pettodopet` file was selectable in the picker, so the 08-12
`UTExportedTypeDeclarations` fix still holds.

- **Gotcha: XcodeBuildMCP UI actions go to its own session default simulator.**
  Its `key_sequence` / `tap` / `type_text` take no simulator argument — a key
  sequence meant for PetTodo landed on a different booted simulator running
  another app. Call `session_set_defaults({simulatorId})` before any UI action,
  and re-check when more than one simulator is booted.
- **Gotcha: test fixtures must give each pet its own `ui.Image`.** The controller
  disposes every cached atlas image on teardown, deduplicating by atlas, not by
  image — a fake loader that hands the same image to two pets double-disposes it
  and fails in teardown. Real packs each decode their own file, so per-pet images
  are also the truthful fixture.

## Task 002-A — Android floating companion (2026-08-25)

- The Android overlay is a native `TYPE_APPLICATION_OVERLAY` window owned by a
  foreground service. The Dart `OverlayService` is the only platform-channel
  seam: it checks support/state without prompting, requests the special overlay
  permission only after an explicit Settings toggle, starts/stops the service,
  and sends the completion celebration event before task persistence/log IO.
  A denial returns `false` immediately so the toggle falls back; resume and
  startup only inspect state and never reopen permission Settings.
- **Foreground-service type decision (Android 14/15): `specialUse`.** Android 14
  (target API 34+) requires every foreground service to declare an applicable
  type and its type-specific permission. A persistent user-enabled floating
  companion does not fit camera, connected-device, data-sync, health, location,
  media, projection, microphone, phone-call, remote-messaging, or short-service
  semantics, so the manifest declares `specialUse`,
  `FOREGROUND_SERVICE_SPECIAL_USE`, and a free-form
  `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` explanation. This follows the official
  foreground-service type table:
  https://developer.android.com/develop/background-work/services/fgs/service-types#special-use
- Android 15 narrows the `SYSTEM_ALERT_WINDOW` exemption for *background* FGS
  starts: a visible `TYPE_APPLICATION_OVERLAY` window must already exist. The
  service is therefore first started only by the foreground Settings action;
  it creates its overlay in `onCreate` before promotion and uses `START_STICKY`
  for system recreation. There is deliberately no boot receiver or other
  background launch path. Basis:
  https://developer.android.com/about/versions/15/behavior-changes-15#fgs-saw-restrictions
- `tool/slice_overlay_frames.dart` reads the same bundled 8×11 metadata used by
  the in-app renderer and deterministically crops only the required calm-idle
  and jumping frames from the canonical WebP. Generated `drawable-nodpi` PNGs
  remain exactly 192×208; the native view scales by an integer 2× with bitmap
  filtering, anti-aliasing, and dithering disabled. The service ticks at 8 fps
  and removes callbacks while the screen is off.
- The overlay contains only the pet. Drag end persists native pixel coordinates
  in private preferences; a tap opens Pawside. The ongoing notification says
  “{pet} is keeping you company” / “Tap to visit Pawside” and contains no task
  state or pressure copy.
- **07-22 release-resource lesson applied:** every generated overlay frame is
  referenced statically from Kotlin and `res/raw/keep.xml` additionally keeps
  `overlay_*`. The notification uses the statically referenced
  `R.drawable.ic_notification`, while the existing keep rule remains in place.
  No resource lookup is allowed to become a pre-`runApp` Dart dependency.
- Validation in this managed sandbox: `flutter analyze --no-pub` is clean and
  `flutter build bundle --release --no-pub` succeeds. API-36 `aapt2` compiled
  all Android resources, then both Kotlin files compiled against Android 36,
  the real Flutter embedding, and the generated current-project `R` class.
  Running the slicer twice produced byte-identical SHA-256 hashes for all 11
  frames. Full `flutter test` still cannot start because the sandbox denies its
  required `127.0.0.1:0` harness socket; Gradle likewise cannot create its local
  file-lock socket, and ADB cannot create its localhost smart-socket listener.
  Therefore the three live suite passes, APK/release launch, emulator overlay
  walkthrough, and screenshot capture must be rerun outside this sandbox.
