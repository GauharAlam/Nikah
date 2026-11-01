# Setup and release

The backend is chosen at build time. Release builds always use Firebase, whatever is passed.

| Mode | Command | Data |
|---|---|---|
| Demo (debug default) | `flutter run` | Seeded sample data on the device, with a DEMO banner. The sign-in code is `123456`. Compiled out of release builds. |
| Emulator | `flutter run --dart-define=BACKEND=emulator` | The real app against local Firebase emulators, project `demo-nikah`. Set `EMULATOR_HOST` if not on an Android emulator. |
| Firebase | `flutter run --dart-define=BACKEND=firebase`, or any release build | Firebase only. No sample data, no demo sign-in, no guardian screens. |

A Firebase build without its config files opens a "missing configuration" screen.

## 1. Firebase project

Use a new project for this app. Do not share one with another product.

1. Create the project in the Firebase console, on the Blaze plan (Cloud Functions need it).
2. Turn on **Authentication**: Phone and Google.
3. Create **Firestore** and **Storage**, choosing a region near your members. Functions are set to `asia-south1` in `functions/src/index.ts`, and `lib/data/firebase_backend.dart` must match it.
4. Register the Android and iOS apps as `com.gauharalam.nikah`.
5. Add these files. They are safe to ship in the app:
   - `android/app/google-services.json`
   - `GoogleService-Info.plist`, added to `ios/Runner` through Xcode
6. Add your Android SHA-1 and SHA-256 fingerprints to Firebase. Phone and Google sign-in need them.
7. For iOS, add the reversed client ID URL scheme and an APNs key for push.

Never put a service account key in the app, in this repo, or in a chat. Cloud Functions do not need one.

## 2. Everything else

Deployment, secrets, limits, products, signing and release steps are in
[DEPLOYMENT.md](DEPLOYMENT.md). Tests are in [TESTING.md](TESTING.md).
