# Testing

| Layer | Location | Proves | Command |
|---|---|---|---|
| Static | `analysis_options.yaml` | Lints and types | `flutter analyze` |
| Flutter unit and widget | `test/` | Controllers on a fake server, screens on the production store, the demo | `flutter test` |
| Server logic | `functions/test/rules.test.ts` | Pure decision rules | `cd functions && npm run test:unit` |
| Rules and callables | `functions/test/*.emulator.test.ts` | Security rules and functions, as real users on the emulators | `cd functions && npm run test:emulator` |
| Device | `integration_test/` | The real Firebase SDK on Android, rules and functions together | `tool/integration_test.sh integration_test -d emulator-5554` |

All Firebase tests use the isolated `demo-nikah` project. Nothing touches a real project.

## Setup

The emulators need Java:

```sh
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
```

For device tests, start an Android emulator first:

```sh
~/Library/Android/sdk/emulator/emulator -avd flutter_emulator -no-window -no-audio
```

`BACKEND=emulator` then points the app at the host machine through `10.0.2.2`.

`tool/screenshots.sh <dir>` captures the screen every two seconds, for reviewing
`integration_test/app_ui_test.dart` by eye.

## Journeys

| Journey | Where it runs |
|---|---|
| 1 Register to discovery | Device, except that sign-in uses a token instead of a real SMS |
| 2 Proposal, match, chat | Device |
| 3 Decline, no match | Device |
| 4 Family invite, use, revoke | Device, and every denial in `family.emulator.test.ts` |
| 5 Block | Device, and `connections.emulator.test.ts` |
| 6 Contact request | Device |
| 7 Account deletion | Device, and every record in `account.emulator.test.ts` |
| 8 Purchase | `purchases.emulator.test.ts`, with the store simulated |

## Rules for new tests

- A security fix starts with a test that fails on the old code.
- A test on the demo store proves nothing about production. Use `RemoteAppStore` with `FakeBackend`.
- A change to a query needs its index in `firebase/firestore.indexes.json`. Emulators do not
  enforce indexes, so a missing one fails only in production.

## What no test here can prove

Real SMS, real push, real App Check, signed URLs on real Storage, real Google sign-in, real Play
purchases, and whether composite indexes are complete.
