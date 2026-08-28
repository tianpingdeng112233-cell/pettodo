# pettodo

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local hatch backend on an Android emulator

The debug Android build talks to the host machine at
`http://10.0.2.2:3000` by default. Start the backend from this repository with
Node 22 and a Gemini API key:

```sh
cd backend
npm ci
PORT=3000 GEMINI_API_KEY=your-server-side-key npm run dev
```

In another terminal, launch Pawside on an Android emulator:

```sh
flutter run
```

Open Collection, choose the own-pet hatch flow, use the existing local Unlock
button, select 1–3 JPEG/PNG photos, and start hatching. Keep the backend process
running until the app downloads and imports the ready `.pettodopet` pack. Then
enable the floating pet in Settings to verify that the imported pet appears in
the Android overlay.

To use a different host or port, override the compile-time URL explicitly:

```sh
flutter run --dart-define=HATCH_API_BASE_URL=http://10.0.2.2:4000
```

Release builds continue to use the production placeholder unless
`HATCH_API_BASE_URL` is supplied at build time. The cleartext HTTP allowance is
debug-only; the release Android manifest is unchanged.
