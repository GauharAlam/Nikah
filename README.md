# Nikah

A privacy-first matrimony app for educated Muslims, built with Flutter and Firebase.

**Status:** feature-complete on Android against local Firebase emulators. It has not yet run on
a real Firebase project, a physical phone, iOS or real store billing. See
[docs/IMPLEMENTATION_PROGRESS.md](docs/IMPLEMENTATION_PROGRESS.md).

## What it does

- Phone sign-in, six-step onboarding, and human review of every profile.
- Search and discovery, proposals, matches only on mutual acceptance, and chat.
- Contact sharing only on an accepted request.
- Family access with per-person permissions the owner can revoke.
- Reports, blocks, moderation tools, data export and full account deletion.
- Subscriptions and credits, verified on the server.

## Run it

```sh
flutter pub get
flutter run                                  # Local demo, debug builds only
flutter run --dart-define=BACKEND=emulator   # The real app on local Firebase emulators
```

Release builds always use Firebase.

## Documents

| Document | Contents |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the system fits together |
| [DATABASE_SCHEMA.md](docs/DATABASE_SCHEMA.md) | Collections, owners and retention |
| [FIREBASE_SECURITY.md](docs/FIREBASE_SECURITY.md) | Data classes, rules and the retention table |
| [FAMILY_ACCESS_MODEL.md](docs/FAMILY_ACCESS_MODEL.md) | Family permissions and consent |
| [SAFETY_ESCALATION.md](docs/SAFETY_ESCALATION.md) | Handling reports |
| [TESTING.md](docs/TESTING.md) | Every test suite and how to run it |
| [SETUP.md](docs/SETUP.md), [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Firebase setup and release |
| [IMPLEMENTATION_PROGRESS.md](docs/IMPLEMENTATION_PROGRESS.md) | What was done and verified |

`docs/history` holds older documents that no longer match the code. `stitch/` holds the original
design references.
