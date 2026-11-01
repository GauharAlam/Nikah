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
4. Register the Android and iOS apps with your final package and bundle IDs.
5. Add these files. They are safe to ship in the app:
   - `android/app/google-services.json`
   - `GoogleService-Info.plist`, added to `ios/Runner` through Xcode
6. Add your Android SHA-1 and SHA-256 fingerprints to Firebase. Phone and Google sign-in need them.
7. For iOS, add the reversed client ID URL scheme and an APNs key for push.

Never put a service account key in the app, in this repo, or in a chat. Cloud Functions do not need one.

## 2. Deploy the backend

```sh
npm install -g firebase-tools
firebase login
firebase use <project-id>
(cd functions && npm install)
firebase functions:secrets:set APPLE_SHARED_SECRET
firebase deploy --only firestore,storage,functions
```

`APPLE_SHARED_SECRET` comes from App Store Connect.

## 3. Limits

Create `config/app` in Firestore. Anything you leave out uses the default.

```json
{ "limits": { "proposalsPerDay": 5, "decisionsPerDay": 10, "pendingLimit": 15,
              "monthlyContactCredits": 30, "hideDays": 7, "proposalExpiryDays": 30, "minPhotos": 1,
              "requireIdProof": true, "graduatesOnly": true, "staleDays": 45,
              "reportHoldThreshold": 3, "contactExpiryDays": 14,
              "freeProfileLimit": 15, "freeProfileWindow": "total",
              "inviteRewardCredits": 2, "inviteRewardCap": 10 } }
```

`freeProfileWindow` can be `total`, `month` or `day`.

5, 10 and 15 were seen in the Barkat app. The others are placeholders for you to decide.

## 4. Reviewers

Profiles stay in the queue until a reviewer decides. To make someone a reviewer, run this
from a trusted machine, with a credential kept outside the repo:

```sh
cd functions && GOOGLE_APPLICATION_CREDENTIALS=/secure/path/key.json npx ts-node scripts/grant-reviewer.ts <uid>
```

They then sign out and back in, and **Review queue** appears on their Profile tab.

## 5. Store products

Create these product IDs in Play Console and App Store Connect, and set the prices there.

| Product ID | Type | Grants |
|---|---|---|
| `barkat_monthly` | Subscription | 30 days premium |
| `barkat_weekly` | Subscription | 7 days premium |
| `barkat_credit_single` | Consumable | 1 credit |
| `barkat_credits_small` | Consumable | 5 credits |

The credits per pack are placeholders, set in `functions/src/index.ts`. The Functions
service account also needs Play Developer API access.

## 6. Before release

- Replace `support@example.com` and the example URLs: `--dart-define=SUPPORT_EMAIL=… TERMS_URL=… PRIVACY_URL=…`
- Set `APP_LINK` to the Play Store link. It appears in invites and on every biodata.
- Choose the final name in `AppBrand`, the platform labels and the app IDs.
- Add a release signing config. `android/app/build.gradle.kts` still signs with debug keys.
- Replace the landing artwork and the default launcher icon.

## Tests

```sh
flutter analyze && flutter test
cd functions && npm run test:unit
# Emulators need Java. Android Studio's works: export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
npm run test:emulator
```
