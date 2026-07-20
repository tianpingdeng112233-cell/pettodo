# PetTodo v1 Implementation Notes

## Architecture

- `lib/domain/` is pure Dart. It owns the exactly-three-task invariant, local-day rollover, cumulative unlock thresholds, persisted state shape, and JSONL event encoding. It has no Flutter imports.
- `lib/data/` owns the atomic single-JSON state file, append-and-flush JSONL event file, local notification scheduling, and share-sheet export.
- `lib/sprite/` owns pet discovery, atlas metadata parsing, decoded image lifetime, frame math, and rendering.
- `lib/application/` is the presentation-independent `ChangeNotifier` coordinator. It is intentionally outside `lib/ui/`, so a designer reskin does not move persistence, task, notification, animation sequencing, or event behavior.
- `lib/ui/` contains all screens, placeholder theme, task cards, banner, decoration placement, and particles. A visual reskin should stay in this folder unless it introduces a new product behavior.

## Sprite renderer decision

The app uses a small custom `CustomPainter` plus Flutter `Ticker`, not Flame. At roughly 8 fps the painter selects a source rectangle from the decoded WebP and calls `canvas.drawImageRect` with `FilterQuality.none`. This keeps pixel edges crisp, avoids a game-engine dependency for one animated actor, and leaves animation state under the application coordinator. The tradeoff is that batching, scene graphs, and richer game effects would need to be built if the product later becomes substantially more game-like.

Frame counts, row indexes, cell size, and image dimensions are parsed at runtime from `pet_request.json`; only safe product state names (`idle`, `jumping`, `waving`, `review`) are selected by v1 behavior. The `failed` row is never selected.

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
