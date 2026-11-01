# Architecture Audit

**Audited:** 2026-11-01, branch `feature/trust-and-nikah-journey`, commit `a202624`.
**Method:** every finding comes from reading the code at that commit, not from earlier
documents. `CODEBASE_AUDIT.md` and `GAP_ANALYSIS.md` describe the app before Firebase was
added and are now historical. Where they disagree with this file, this file is correct.

## Baseline (Phase 0)

Commands were run on this machine at `a202624`.

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | 0 issues |
| Flutter tests | `flutter test` | 121 passed |
| Backend build | `npm run build` | passed |
| Backend logic tests | `npm run test:unit` | 22 passed |
| Emulator tests | `npm run test:emulator` | 34 passed (Auth, Firestore, Storage, Functions emulators) |
| Android release | `flutter build apk --release --dart-define=BACKEND=firebase` | built, 64.9 MB |
| iOS | not runnable | Xcode is Command Line Tools only; CocoaPods missing |
| Secrets in history | `git log --all -p -G…` and `git ls-files` | none found |

Not available on this machine: a Firebase project, `google-services.json`,
`GoogleService-Info.plist`, Xcode, Apple and Google store accounts, the GitHub CLI.
Available and previously unused: two Android virtual devices with an android-36 image.

## What already works

Keep these. None of them needs rebuilding.

- Firestore rules are deny-by-default, with server-only writes for accounts, profiles,
  proposals, matches and contact shares (`firebase/firestore.rules`).
- Proposal state machine with transactions, idempotent retries, gender and block checks,
  and server-side quotas (`functions/src/index.ts`, `functions/src/rules.ts`).
- Mutual-only match creation, including crossing proposals.
- `Backend` interface with a Firebase implementation, and `FakeBackend` for tests.
- GoRouter with `StatefulShellRoute` and a single testable guard function, `guardRoute`.
- Draft persistence and resume across devices.
- Free-tier view counting, re-checked in a transaction.
- Scam Shield, Nikah Journey, Important Questions, invite credits, biodata PDF, English
  and Hindi strings.
- Design tokens and the shared widget set (`lib/theme/app_theme.dart`, `lib/widgets/`).
- Firestore indexes match every query in the backend at this commit.

---

## Findings

### ARC-01 · Default build is a fake backend — Critical
- **Existing:** `AppConfig.isDemo` is true unless `BACKEND=firebase` is passed, including
  in release mode. A plain `flutter build apk --release` ships fake sign-in (code
  `123456`), seeded members and fabricated notifications.
- **Expected:** a release build can only talk to the real backend. Demo mode exists only
  in debug builds and only when asked for.
- **Files:** `lib/config/app_config.dart`, `lib/main.dart`.
- **Solution:** default to Firebase. Honour `BACKEND=demo` and `BACKEND=emulator` only when
  `kReleaseMode` is false.
- **Acceptance:** a release build with any `BACKEND` value uses Firebase, or shows the
  missing-configuration screen.
- **Tests:** unit test of the mode resolver for each input and build mode.

### ARC-02 · Production store inherits the fake one — Critical
- **Existing:** `RemoteAppStore extends AppStore`, and `AppStore` is 1,724 lines of local
  simulation. Anything the subclass does not override runs fake code in production:
  `guardian` returns the seeded "Khalid Al-Mansoor", `activityLog` is a local list,
  `meetings`, `privacy()` and `unreadCount()` are all local.
- **Expected:** one production code path. Demo behaviour sits behind the `Backend`
  interface and cannot leak into a real session.
- **Files:** `lib/providers/app_store.dart`, `lib/providers/remote_app_store.dart`.
- **Solution:** `AppStore` becomes the interface screens use. The local simulation moves to
  `DemoAppStore`, compiled out of release builds, and `RemoteAppStore` stops inheriting it.
  Demo-only guardian members return inert defaults in production.
- **Acceptance:** `AppStore` holds no seeded data. Fabricated strings such as
  "Khalid Al-Mansoor" appear in no production-reachable path.
- **Tests:** existing widget flows pass on `DemoAppStore`; a test asserts no seeded data
  appears in a signed-in `FakeBackend` session.

### ARC-03 · God object and global rebuilds — High
- **Existing:** one `ChangeNotifier` owns session, draft, discovery, proposals, contacts,
  chat, family, notifications, verification and settings. 35 screen and widget files
  depend on it, and any change rebuilds all of them, including each message arriving in
  any thread.
- **Expected:** feature-level state managers that can be tested alone and rebuild only
  their own listeners.
- **Files:** `lib/providers/*`, `lib/main.dart`, screens.
- **Solution:** extract `SessionController`, `ProfileController`, `DiscoveryController`,
  `ConnectionsController`, `ChatController`, `FamilyController`,
  `NotificationsController`, `SettingsController`. Keep `AppStore` as a thin facade during
  migration, and move each screen off it when that screen is next changed.
- **Acceptance:** no controller exceeds about 300 lines. New screens read controllers
  directly.
- **Tests:** a unit suite per controller on `FakeBackend`.

### ARC-04 · One 867-line Cloud Functions file — Medium
- **Existing:** every callable sits in `functions/src/index.ts`.
- **Expected:** backend modules that match the feature boundaries.
- **Files:** `functions/src/index.ts`.
- **Solution:** split into `shared`, `profiles`, `review`, `family`, `discovery`,
  `proposals`, `contacts`, `safety`, `messaging`, `account`, `purchases`, re-exported from
  `index.ts`. Function names stay the same.
- **Acceptance:** deployed function names unchanged; all emulator tests pass.
- **Tests:** the existing emulator suite.

### ARC-05 · Mutations report success before the server answers — High
- **Existing:** `_send` is fire-and-forget. `sendProposal` returns `true` and removes the
  card before the call completes. `reportProfile` shows "Report sent" regardless of the
  result. `resetAll()` returns `void`, so Delete Account cannot show a result.
- **Expected:** success feedback follows a successful server response.
- **Files:** `lib/providers/remote_app_store.dart`, callers in `match_detail_screen.dart`,
  `discovery_screen.dart`, `settings_screen.dart`.
- **Solution:** consequential actions return `Future` and throw `BackendException`.
  Screens show progress, then the true outcome.
- **Acceptance:** with the backend failing, no success message appears and the card stays.
- **Tests:** widget tests with `FakeBackend.failNext` for proposal, report, block, delete.

### ARC-06 · Server configuration ignored by the client — Medium
- **Existing:** `requireIdProof` and `graduatesOnly` are hardcoded `true`. `AppLimits`
  repeats server defaults. Eligibility rules live in two places.
- **Expected:** `config/app` is the source of truth; the client displays it.
- **Files:** `lib/providers/app_store.dart`, `lib/data/firebase_backend.dart`,
  `functions/src/rules.ts`.
- **Solution:** extend `AppLimits` to carry every value the client needs, including
  eligibility.
- **Acceptance:** changing `config/app` changes behaviour with no client release.
- **Tests:** controller test with non-default limits.

### ARC-07 · Unbounded reads and listeners — High
- **Existing:** `watchProposals`, `watchContactRequests`, `watchMatches` and
  `fetchIntroductions` read every proposal and block a member has ever had. One
  200-document message listener stays open per active match for the whole session.
- **Expected:** bounded listeners; only the open conversation streams messages.
- **Files:** `lib/data/firebase_backend.dart`, `lib/providers/remote_app_store.dart`,
  `functions/src/index.ts`.
- **Solution:** add limits, listen to messages only while a chat is open, page history
  with a cursor, and use the match document for previews and counts.
- **Acceptance:** opening the app with 20 matches opens no message listeners.
- **Tests:** `FakeBackend` asserts `watchMessages` is called only on open, and is cancelled
  on close.

### ARC-08 · No typed failures — Medium
- **Existing:** everything is `BackendException(message, code)`, `SocketException` is
  rarely what mobile Firebase throws, and permission errors become a generic message.
- **Expected:** failures distinguish offline, not allowed, not found, limit reached and
  needs recent sign-in, so screens can respond properly.
- **Files:** `lib/data/backend.dart`, `lib/data/firebase_backend.dart`.
- **Solution:** add a `FailureKind` to `BackendException`, mapped from Firebase codes in
  one place.
- **Acceptance:** `unavailable` shows offline and retry; `requires-recent-login` leads to
  re-authentication.
- **Tests:** unit test of the mapping table.

### ARC-09 · No environment separation — Medium
- **Existing:** one implicit environment and no way to run the app against the emulators,
  so `FirebaseBackend` has never run.
- **Expected:** emulator, staging and production are explicit and cannot be confused.
- **Files:** `lib/config/app_config.dart`, `lib/main.dart`, `docs/DEPLOYMENT.md`.
- **Solution:** add `BACKEND=emulator` with a `demo-nikah` project, plus a seed script.
  Document one Firebase project per environment.
- **Acceptance:** the Android app runs real journeys against the emulators.
- **Tests:** `integration_test/` on an Android virtual device.

### ARC-10 · Device state leaks between accounts — Medium
- **Existing:** pledge, filters, read markers and the local blocked set live in shared
  preferences with no owner. A second account on the device inherits them.
  `_clearMemberState` does not clear `_readAt` or `_blocked`.
- **Expected:** member state is cleared or scoped on account change.
- **Files:** `lib/providers/app_store.dart`, `lib/providers/remote_app_store.dart`.
- **Solution:** scope preference keys by uid; move read state and blocks to the server.
- **Acceptance:** signing in as B after A shows none of A's state.
- **Tests:** controller test switching accounts.

### ARC-11 · Documentation contradicts the code — Low
- **Existing:** `README.md` documents screens that no longer exist.
  `IMPLEMENTATION_PROGRESS.md` still shows stages as blocked that were built. Earlier
  documents call the product Barkat Nikah.
- **Expected:** documents describe the code that exists.
- **Files:** `README.md`, `docs/*`.
- **Solution:** rewrite `README.md`, mark old documents historical, and maintain the
  document set in this roadmap.
- **Acceptance:** every claim in `README.md` holds at the commit that contains it.
- **Tests:** none; reviewed at each phase.
