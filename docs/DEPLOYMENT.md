# Deployment

None of this has been run: there is no Firebase project or store account yet. Follow it in order.
First-time Firebase setup is in `SETUP.md`.

## Environments

Use one Firebase project per environment, and never share data between them.

| Environment | Project | Build |
|---|---|---|
| Local | `demo-nikah` emulators | `flutter run --dart-define=BACKEND=emulator` |
| Staging | `nikah-staging` | Separate config files, internal testers only |
| Production | `nikah-prod` | `tool/build_release.sh` |

## Before the first deploy

| Item | Status | Owner |
|---|---|---|
| Firebase project on Blaze, config files added | Not done | You |
| Final name and id. The app is `Nikah`, id `com.gauharalam.nikah`, which cannot change after first publish | Please confirm | You |
| Terms, privacy policy, retention periods reviewed by a lawyer | Not done | You |
| Real launcher icon and landing artwork | Not done | You |
| Reviewers named, and a real support address | Not done | You |
| Real institution list and quota decisions | Not done | You |

## Backend

```sh
npm install -g firebase-tools
firebase login
firebase use <project-id>
(cd functions && npm ci)
firebase deploy --only firestore,storage,functions
```

Then, in the Google Cloud console:

1. Give the Functions service account **Service Account Token Creator**. Without it, signed photo
   and document links fail.
2. Give it Play Developer API access, for purchase checks.
3. Turn on a **TTL policy** for `rateLimits` on the field `expiresAt`.
4. Create the Pub/Sub topic `play-notifications`, and select it in Play Console under Real-time
   developer notifications.

Check that every query works on the real project. Emulators do not enforce composite indexes.

## Configuration

Create `config/app` in Firestore. Anything left out uses the default in `functions/src/rules.ts`.

```json
{
  "appId": "com.gauharalam.nikah",
  "policyVersion": "2026-11-01",
  "limits": {
    "proposalsPerDay": 5, "decisionsPerDay": 10, "pendingLimit": 15, "monthlyContactCredits": 30,
    "hideDays": 7, "proposalExpiryDays": 30, "minPhotos": 1, "requireIdProof": true,
    "graduatesOnly": true, "firstMarriageOnly": false, "minAge": 18, "staleDays": 45,
    "reportHoldThreshold": 3, "contactExpiryDays": 14, "freeProfileLimit": 15,
    "freeProfileWindow": "total", "inviteRewardCredits": 2, "inviteRewardCap": 10,
    "suspiciousMessagesPerDay": 300
  },
  "products": {
    "nikah_monthly": { "kind": "subscription" },
    "nikah_weekly": { "kind": "subscription" },
    "nikah_credit_single": { "kind": "credits", "credits": 1 },
    "nikah_credits_small": { "kind": "credits", "credits": 5 }
  }
}
```

5, 10 and 15 were seen in the reference app. Every other value is a placeholder for you to decide.
Prices live in the stores, never here.

## Reviewers

```sh
cd functions && GOOGLE_APPLICATION_CREDENTIALS=/secure/path/key.json npx ts-node scripts/grant-reviewer.ts <uid>
```

Keep that key outside the repo. The reviewer signs out and back in. Follow
`SAFETY_ESCALATION.md` for reports.

## App Check

Register both apps, then deploy with `ENFORCE_APP_CHECK=true` once real builds are sending tokens.
Turning it on sooner blocks every client.

## Android release

Create a key once, and back it up. Losing it means you cannot update the app.

```sh
keytool -genkey -v -keystore ~/nikah-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nikah
```

Create `android/key.properties`, which git ignores:

```
storePassword=...
keyPassword=...
keyAlias=nikah
storeFile=/absolute/path/to/nikah-release.jks
```

Add its SHA-1 and SHA-256 to Firebase, then:

```sh
APP_LINK=... SUPPORT_EMAIL=... TERMS_URL=... PRIVACY_URL=... tool/build_release.sh
```

## iOS (not planned for now)

The first release is Android only. iOS code stays in the repo but has never been compiled, and
Apple billing is off. If iOS starts later:

1. Install full Xcode and CocoaPods, run `pod install`, and add `GoogleService-Info.plist`.
2. Add the reversed client id URL scheme, an APNs key, and the Push capability.
3. Set the three Apple secrets, then follow the note at the top of `functions/src/purchases.ts`.
4. Set the App Store Server Notifications URL to `onAppStoreNotification`, version 2.
5. Test the screenshot protection in `AppDelegate.swift` on a device. It has never run.

## Privacy disclosures

Declare these in Play Data safety, and have them checked against the final privacy policy.

| Data | Purpose | Linked to the person | Shared with other members |
|---|---|---|---|
| Name, gender, date of birth, marital status, location at city level | Profile, matching | Yes | Partly, by viewer |
| Religious and caste details, optional | Matching | Yes | Yes, if the member allows |
| Phone number | Sign-in, contact sharing | Yes | Only on an accepted request |
| Photos | Profile | Yes | By the member's setting |
| Government ID, degree and work documents | Review | Yes | Never |
| Messages | Conversations | Yes | With the match only |
| Purchase history | Entitlement | Yes | Never |
| Device token | Notifications | Yes | Never |

Data is encrypted in transit. The app offers in-app account deletion, and a public deletion web
page is also required by Google Play.

## Permissions

| Permission | Why |
|---|---|
| Internet | Everything |
| Camera, photos | Profile photos and documents |
| Coarse location, while in use | Suggesting a home city, only when the member taps it |
| Notifications | Push |
| Biometric | Optional app lock |

## Release checklist

- [ ] All of `TESTING.md` passes, including device tests
- [ ] Real SMS sign-in, Google linking and push on a physical phone
- [ ] Real purchase, renewal, restore and refund with Play test accounts
- [ ] Signed photo and document links work on real Storage
- [ ] A full deletion on staging, checked by hand
- [ ] Performance on a mid-range Android phone

## Rollback

Firestore and Storage rules: redeploy the previous commit. Functions: redeploy the previous
commit. The app: halt the staged rollout. Keep schema changes additive, so old apps keep working.
