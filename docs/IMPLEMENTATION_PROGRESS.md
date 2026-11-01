# Implementation Progress

Each phase records what actually ran. Older stage-by-stage notes are in
`docs/history/PROGRESS_TO_2026-11-01.md`.

## Where the project stands

Every phase is complete. **The app is not ready for real members yet**, because nothing has run on
a real Firebase project, a physical phone or real Play billing. The first release is Android
only. See Definition of Done at the end of this file.

## Status

| Phase | State |
|---|---|
| 0 Baseline | Done |
| 1 Audit and architecture | Done |
| 2 Architecture refactor | Done |
| 3 Authentication, onboarding, review | Done |
| 4 Discovery, proposals, matches, chat | Done |
| 5 Family, privacy, deletion | Done |
| 6 Trust and safety | Done |
| 7 Notifications and premium | Done |
| 8 Quality assurance | Done |
| 9 Release preparation | Done, up to what needs accounts |

## Phase 0 — Baseline

Run at commit `a202624` on 2026-11-01.

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 121 passed |
| `npm run build` (functions) | passed |
| `npm run test:unit` | 22 passed |
| `npm run test:emulator` | 34 passed |
| `flutter build apk --release --dart-define=BACKEND=firebase` | built, 64.9 MB |
| iOS build | not possible: Xcode is Command Line Tools only, CocoaPods missing |
| Secret scan of history and tracked files | nothing found |

Nothing was failing at the baseline. Emulator tests need
`JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`.

## Phase 1 — Audit and architecture

**Implemented:** an independent audit of the code at `a202624`, covering 11 architecture,
19 product flow and 26 security findings, each with severity, expected behaviour, files,
fix, acceptance criteria and tests.

**Files created:** `docs/ARCHITECTURE_AUDIT.md`, `docs/PRODUCT_FLOW_AUDIT.md`,
`docs/SECURITY_PRIVACY_AUDIT.md`, `docs/IMPLEMENTATION_ROADMAP.md`, `docs/ARCHITECTURE.md`,
`docs/DATABASE_SCHEMA.md`.

**Files moved:** `CODEBASE_AUDIT.md`, `GAP_ANALYSIS.md`, `IMPLEMENTATION_PLAN.md` and the old
progress log to `docs/history/`. They predate the Firebase backend and contradicted the code.

**Corrections to earlier documents:** the old progress log says server work had not
started, but a full backend exists. It also treats reports, deletion and purchases as
working; the audit found defects in each (SEC-07, SEC-08, SEC-09). Six Critical findings
were not in any earlier document.

**Tests added:** none; documentation only.

**Outstanding blockers:** X-1 to X-6 in `IMPLEMENTATION_ROADMAP.md`.

**Next priority:** Phase 2. Make the fake backend unreachable in release, and split the
store and the Cloud Functions file.

## Phase 2 — Architecture refactor

**Implemented**

- ARC-01: release builds are always Firebase. Debug builds default to the demo.
- ARC-02: `AppStore` is now an interface. The 1,700-line simulation moved to `DemoAppStore`,
  and production no longer inherits it.
- ARC-03: eight feature controllers now hold production state, behind the `RemoteAppStore`
  facade. Screens are unchanged and migrate as they are next edited, so this finding stays
  open until they do.
- ARC-04: the backend is split into 12 feature modules.
- ARC-06: `requireIdProof` and `graduatesOnly` come from `config/app`.
- ARC-08: `FailureKind` maps Firebase codes to the action a screen should take.
- ARC-09: `BACKEND=emulator` runs the real app against local emulators. Written, and first
  exercised in Phase 3.
- ARC-10: pledge, filters and read markers are scoped by uid, and member state clears on
  sign-out.

**Existing issues fixed:** `edit_profile_screen` fell back to the seeded demo persona when no
draft was loaded, so a failed draft load could show and save fake data. `showArabic` was
never restored in production.

**Files created:** `lib/features/{core,session,profiles,discovery,proposals,messaging,family,notifications,settings}/*`,
`lib/providers/demo_app_store.dart` (moved), `functions/src/{shared,profiles,review,invites,family,discovery,proposals,contacts,safety,account,messaging,purchases}.ts`,
`test/unit/architecture_test.dart`.

**Tests added:** 8, covering mode resolution, failure mapping, filter round trip, no seeded
data in production, server-driven eligibility, account isolation, and a check that only
`main.dart` imports the demo store.

**Commands and results**

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 129 passed |
| `npm run test:unit` | 22 passed |
| `npm run test:emulator` | 34 passed after the split |
| `flutter build apk --release` with no flags | built, 64.6 MB |
| `strings libapp.so` on that APK | `DemoAppStore`, "Introduction request forwarded" and "Chat audit complete" absent |

**Corrections to the plan:** D-3 first said the wali, chaperone and meeting screens would be
deleted. That contradicted the user's earlier decision to keep them as a superset, so they
stay, gated to demo builds. ARC-05 moved to Phase 4, because it touches screens with
uncommitted work from another session.

**Known leftovers**

- `Guardian.seed` and the wali onboarding hint still compile into release. Those routes
  redirect in production, so they are unreachable.
- `lib/screens/profile_screen.dart` still falls back to `WardProfile.demoWard`. That file has
  uncommitted work from another session, so it is left until that lands.

**Outstanding blockers:** X-1 to X-6.

**Next priority:** Phase 3.

## Phase 3 — Authentication, onboarding and review

**Security findings proved first.** 17 emulator tests were written before any fix and all
failed on the old code, including a reviewer approving themselves (SEC-03), a post-review
swap to an under-18 birth date being published (SEC-04), an unverified phone being stored
(SEC-06), and an approved stranger reading and listing private photos (SEC-01). All pass now.

**Implemented**

- SEC-03: no self-review, and only waiting submissions or documents can be decided.
- SEC-04: submission freezes a versioned snapshot in `submissions/{uid}`. Approval publishes
  that snapshot, re-validates it, and refuses a stale version.
- SEC-06: submission needs a verified phone on the auth token. Only that number can be shared.
- SEC-01, SEC-02: originals are owner-only and cannot be replaced. Approval copies them to
  `published/`, which no client can reach. Members still receive token URLs until Phase 5.
- SEC-14, SEC-15: draft field allow-list with sizes, no SVG, and uploads checked by real bytes.
- SEC-17, SEC-18: consent records with policy version, and the six document states. Viewing a
  document moves it to under review. Badge copy no longer implies more than a document review.
- Request-changes decision, with photos the reviewer flags. `auditLogs` for review actions.
- Eligibility is configurable (`minAge`, never below 18, and `firstMarriageOnly`).
- FLOW-01, FLOW-02: six steps with family, language, education and employment fields. Saved
  seven-step drafts resume at the matching step.
- FLOW-03: shared `PhotoManager` with primary photo, reorder, camera, upload progress and
  reviewer flags. Used in onboarding; Edit Profile has no photo editing yet.
- FLOW-04: camera, gallery and PDF picker, preview, size check, reason and resubmit.
- FLOW-05: reviewer console with full preview, photos, and approve, ask for changes, reject.
  Reports and held profiles follow in Phase 6.
- FLOW-06: one verified number per account. Google users link a phone through the same OTP
  screen. `sendOtp` handles auto-verification, a timeout and resend tokens.
- FLOW-16: branded splash with retry when the draft or auth stream fails.

**Existing issues fixed:** `publishPhotos` relied on a download token that server-copied
files do not have. The onboarding form kept its scroll position between steps, so Next landed
mid-page.

**Files created:** `lib/widgets/photo_manager.dart`, `test/unit/phase3_test.dart`,
`functions/test/helpers.ts`, `functions/test/review.emulator.test.ts`.

**Tests added:** 9 Flutter, 3 logic, 18 emulator.

**Commands and results**

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 138 passed |
| `npm run test:unit` | 25 passed |
| `npm run test:emulator` | 52 passed |

**Not verified:** real SMS, Google linking and the picker on a device. `readUrl` signed URLs
need the runtime service account to hold Service Account Token Creator; the emulator cannot
sign, so that path has not run.

**Environment note:** the project folder sits in iCloud-synced Documents, and iCloud evicted
files, which made `git status` and `tsc` hang. Work continues in a clone outside iCloud.

**Outstanding blockers:** X-1 to X-6.

**Next priority:** Phase 4.

## Phase 4 — Discovery, proposals, matches and chat

**Security findings proved first.** 14 emulator and rules tests failed on the old code,
including a blocked pair still able to exchange phone numbers (SEC-05), held profiles served
to anyone who had viewed them (SEC-10), and messaging after losing approval (SEC-13). All pass.

**Implemented**

- SEC-05: blocks close pending contact requests with a refund, and `respondContact` checks
  blocks in its transaction.
- SEC-10: one `canViewProfile` rule for every read.
- SEC-13: messages need an active match and approval, for reading and writing.
- SEC-20: discovery cards carry a first name. Full name, employer and family details are for
  active matches.
- SEC-21: expiry runs per document in a draining loop. SEC-25: a decline stays declined.
- ARC-05: refused proposals and contact requests restore the card and report why. Report and
  block complete only on server success.
- ARC-07: reads and listeners are bounded. Messages stream only while a chat is open.
- FLOW-07: Search Rishtey with text search, Suggestions and Nearby. Nearby is opt-in on both
  sides, compares home city only, and never uses GPS. It is reached from Filters for now,
  because `discovery_screen.dart` has uncommitted work from another session.
- FLOW-08: removed the fake online dot and fake "seen". Seen now follows the other member's
  real read time, and unread counts live on the match document.
- FLOW-09: sending, failed and retry states with client-chosen ids, older-message paging,
  an ended-conversation state, and report from the conversation.
- FLOW-10: Pending and Closed views. FLOW-11: the timeline shows real notifications.
- FLOW-14: block copy no longer says "on this device".

**Existing issues fixed:** the Location filter offered countries but the server compared them
with city strings, so it could never match. Unread counts only ever rose, and a reinstall
marked every message unread.

**Files created:** `lib/screens/search_screen.dart`, `functions/src/expiry.ts`,
`functions/test/connections.emulator.test.ts`, `test/unit/phase4_test.dart`.

**Tests added:** 16 Flutter, 3 logic, 17 emulator and rules.

**Commands and results**

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 154 passed |
| `npm run test:unit` | 28 passed |
| `npm run test:emulator` | 69 passed |

**Not done here:** skeleton loaders and pull-to-refresh on the Discover deck, and Filters
copy for premium rows, all in `discovery_screen.dart` or Phase 8. Photos are still token URLs
until Phase 5.

**Outstanding blockers:** X-1 to X-6.

**Next priority:** Phase 5.

## Phase 5 — Family, privacy and deletion

**Implemented**

- SEC-11: phone-bound invitations, hashed codes and numbers, relationship and permissions on
  each membership, an owner-only history, resend limits and attempt limits. Permissions name
  only features that exist. See `FAMILY_ACCESS_MODEL.md`.
- FLOW-19: a family-made profile needs the subject's confirmation from their own phone, and
  the subject can refuse or withdraw at any time.
- SEC-08, FLOW-13: deletion needs a recent sign-in, ends access at once, and runs named,
  resumable, paged steps with hourly retries. It has its own screen explaining what is deleted
  and what is kept. Report and payment records follow the table in `FIREBASE_SECURITY.md`.
- SEC-01: cards hold no URLs. Each viewer gets one-hour signed links for permitted photos, so a
  privacy change stops new links at once.
- SEC-24: data export. FLOW-12: pause, blocked list and unblock, contact-request switch, nearby
  switch. SEC-22: optional app lock using the phone's own lock.
- SEC-16, in part: a shared transactional rate limiter, used for family codes.

**Existing issues fixed:** removal from one circle cleared a guardian's link to another.
Leaving a circle targeted the wrong member. App lock did not ask again on returning to the app.

**Files created:** `functions/src/family.ts` (rewritten), `functions/src/account.ts` (rewritten),
`lib/screens/account_screens.dart`, `lib/services/app_lock.dart`,
`functions/test/family.emulator.test.ts`, `functions/test/account.emulator.test.ts`,
`test/unit/phase5_test.dart`, `docs/FAMILY_ACCESS_MODEL.md`, `docs/FIREBASE_SECURITY.md`.

**Tests added:** 13 Flutter, 3 logic, 19 emulator and rules, including Journey 4, Journey 7 and
every guardian denial. The old guardian test was replaced by the new suite.

**Commands and results**

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 167 passed |
| `npm run test:unit` | 31 passed |
| `npm run test:emulator` | 88 passed |
| `flutter build apk --release` | built, after moving to `FlutterFragmentActivity` |

**Not verified:** signed URLs on real Storage, re-authentication, and the biometric prompt on a
device. The iOS privacy shield remains uncompiled (X-2).

**Decision for the user:** retention periods and the choice to delete conversations for both
sides are engineering defaults that need legal review (X-4).

**Outstanding blockers:** X-1 to X-6.

**Next priority:** Phase 6.

## Phase 6 — Trust and safety

**Security findings proved first.** 10 emulator tests failed on the old code, including three
fresh accounts able to take any profile down (SEC-09). All pass now.

**Implemented**

- SEC-09: only approved members can report, a member cannot report themselves, and a repeat
  never reopens a closed report. Reasons are structured, with optional details and context.
- Reviewers get a Reports tab, without the reporter's identity. They can dismiss, uphold and
  release a hold, never about themselves. Every decision is audited (SEC-12).
- A hold now takes the approved claim as well, so a held member loses messaging (SEC-13). The
  claim reaches the device on its next token refresh, within an hour.
- SEC-16: limits on reports, submissions and exports. App Check is wired in the app and off on
  the server until `ENFORCE_APP_CHECK=true`.
- Unusual message volume raises a flag for reviewers. Nothing happens to the member
  automatically.
- FLOW-17: notification links pass an allow-list. Report sheet shared by profile and chat.

**Existing issues fixed**

- **The production FAQ told members every conversation was visible to guardians and archived,
  that every account has a Wali overseeing it, and that a scholar-supervised team answers in 24
  hours. None of this was true, and the first contradicts the rule against sharing conversations
  with guardians.** It now describes the real behaviour.
- The photo viewer claimed photos were checked by both Walis, and showed disabled like buttons.

**Files created:** `lib/widgets/report_sheet.dart`, `functions/test/safety.emulator.test.ts`,
`test/unit/phase6_test.dart`, `docs/SAFETY_ESCALATION.md`.

**Tests added:** 6 Flutter, 10 emulator.

**Commands and results**

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 173 passed |
| `npm run test:unit` | 31 passed |
| `npm run test:emulator` | 98 passed |
| `flutter build apk --release` | built |

**Not verified:** App Check needs a real Firebase project. Reviewer screens have widget tests,
but no real device run yet.

**Outstanding blockers:** X-1 to X-6.

**Next priority:** Phase 7.

## Phase 7 — Notifications and premium

**Implemented**

- SEC-07: purchases rewritten. Each store transaction has one record, keyed by a hash of the
  transaction id. The product and expiry come from the store. Credits move through a ledger.
  Refunds reverse exactly what was granted. Product ids and the app id come from `config/app`.
- Apple now uses the App Store Server API, replacing the deprecated `verifyReceipt`.
- Play and App Store notifications are handled. A notification is only a hint: the purchase is
  read back from the store, so a forged request changes nothing.
- A purchase finishes on the device only after the server verifies it, so a failed check is
  retried by the store rather than lost.
- SEC-19: push preferences per category, enforced on the server. Account notices always send,
  and the in-app record stays. One device belongs to one account, and token rotation is handled.
- FLOW-18: renewal terms before buying, purchase history, and a pending state.

**Existing issues fixed:** every Android purchase failed, because the app never sent
`packageName`. A cheap token could claim a more expensive product. An expired Apple receipt
granted a new period. Different Apple purchases could collide on one key. The app finished
purchases even when verification failed, so the buyer could pay and receive nothing.

**Files created:** `functions/src/stores.ts`, `functions/test/purchases.emulator.test.ts`,
`test/unit/phase7_test.dart`.

**Tests added:** 8 Flutter, 2 logic, 14 emulator and rules, including all of Journey 8.

**Commands and results**

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 181 passed |
| `npm run test:unit` | 33 passed |
| `npm run test:emulator` | 112 passed |
| `flutter build apk --release` | built |

**Test seam:** the emulator reads store answers from `emulatorStore/{token}`. That path needs
`FUNCTIONS_EMULATOR=true`, which a deployed function never has.

**Not verified, and cannot be from here:** any real Apple or Google call, store notification,
real FCM delivery, or real product. The verifiers in `stores.ts` have never run against a store.
Journey 8 proves the logic around them, not the stores themselves.

**Outstanding blockers:** X-1, X-3.

**Next priority:** Phase 8.

## Phase 8 — Quality assurance

**The first real run.** Until this phase `FirebaseBackend` had never executed. Every earlier test
used a fake, or called functions from Node. It now runs on an Android emulator against the
Firebase emulators: real Firestore rules, real Storage rules, real Cloud Functions.

**Device results (android-36 emulator)**

| Suite | Result |
|---|---|
| `integration_test/backend_journeys_test.dart`: Journeys 1 to 7 on the real client | 10 passed |
| `integration_test/app_ui_test.dart`: 12 main screens with real data, no exceptions | 1 passed |

Journey 8 runs in the emulator suite, because no store is reachable from here.

**Bugs only a real run could find**

- **`setState() called during build` on the production path.** `DiscoveryScreen.initState`
  reached a synchronous `notifyListeners`. It fired on entry to Discover in every session, and
  no test saw it because nothing had run the real store with the real router.
  `session_transition_test.dart` now fails if the store notifies during a build. My first fix
  was wrong (I moved a provider selection), and was reverted once a stack trace showed the cause.
- **One member's matches shown to the next member on the same phone.** Firestore's disk cache
  outlives sign-out. Disk persistence is now off, so no private data rests on the device either.
  The cost is a slower first load and no reading offline after a restart.
- `BACKEND=emulator` could not start, because the SDK rejects a badly shaped API key.

**Found by the small-screen test:** overflows at 320dp and 1.5x text on review status,
verification and search, all fixed.

**Correction:** commit `af5c1ce` went out with one failing test and a blank test count. The
machine had run out of disk, which hid the result, and the commit step did not stop on failure.
The next commit fixed the test and the count. Commit steps now stop if tests fail.

**Reviewed by eye on the device:** landing, Discover, Profile, Family Circle, Search, Delete
Account. They render correctly with real data.

**Tests added:** 17 widget tests on the production store, one session test, 8 accessibility tests,
and 11 device tests. See `TESTING.md`.

**Commands and results**

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 206 passed |
| `npm run test:unit` | 33 passed |
| `npm run test:emulator` | 112 passed |
| `tool/integration_test.sh integration_test -d emulator-5554` | 11 passed |

Four defects were left here because another session held the files. All were closed in Phase 9.

**Not verified:** performance on a mid-range device, a real SMS, real FCM, real store purchases,
and any iOS build.

**Next priority:** Phase 9.

## Phase 9 — Release preparation

**Implemented**

- SEC-23: the product is now Nikah, with app id `com.gauharalam.nikah` on every platform. The
  built APK reports that id and label, and holds no reference-app name. A test keeps it that way.
- Release signing from a `key.properties` that git ignores. `tool/build_release.sh` refuses
  placeholder links, or a missing key or Firebase file.
- The landing page scrolls on small screens and gained a How it works sheet.
- Discover gained a Search entry, a skeleton and pull to refresh on its empty state. The
  self-managed label no longer overlaps the avatar. The landing page is back in the small-screen test.
- The seven files from `41bdf8f` were brought in under their original author, without that
  commit's older test copies.
- ARC-11: `README.md` rewritten. `DEPLOYMENT.md` covers environments, secrets, configuration,
  signing, iOS, privacy disclosures, permissions, a release checklist and rollback.

**Files created:** `docs/DEPLOYMENT.md`, `tool/build_release.sh`.

**Commands and results**

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 208 passed |
| `npm run test:unit` | 33 passed |
| `npm run test:emulator` | 113 passed |
| Device tests on the android-36 emulator | 11 passed |
| `flutter build apk --release` | built, 66.2 MB |
| APK inspection | id `com.gauharalam.nikah`, label `Nikah`, no `DemoAppStore`, no `Barkat` |

**Left in the binary on purpose:** a seeded name in the wali screens, which stay gated to demo
builds under the user's earlier decision. Production redirects those routes.

## Definition of Done

Status is what was run. Emulator means local Firebase emulators, on an Android virtual device
where the client is involved.

| Requirement | Status |
|---|---|
| A real account can be created | Logic verified on emulator. Real SMS not run |
| Real Firebase Authentication | Not run on a real project |
| Full onboarding works, and data persists | Verified on emulator |
| Photos and documents upload securely | Verified on emulator, rules and byte checks included |
| Approval is server-controlled | Verified on emulator |
| Only approved profiles in discovery | Verified on emulator |
| Search and filters on real data | Verified on emulator |
| Proposals reliable, and only mutual acceptance matches | Verified on emulator |
| Chat for authorised matches | Verified on emulator |
| Contact sharing needs consent | Verified on emulator |
| Family invitations, permissions, revocation | Verified on emulator |
| Blocking and reporting | Verified on emulator |
| Push notifications | Written and unit tested. Never delivered |
| Privacy settings enforced by the backend | Verified on emulator |
| Purchase verification | Logic verified with a simulated store. Google Play never called |
| Deletion complete and retryable | Verified on emulator |
| Rules pass security tests | Yes |
| Flutter tests pass; functions compile and pass | Yes |
| Android build | Yes, unsigned for stores |
| iOS build | Out of scope for now: Android only |
| No fake backend in production | Yes, proved from the built APK |
| Documentation reflects the implementation | Yes |

## Open items that need a person

| Id | Item |
|---|---|
| X-1 | Firebase project and config files |
| X-3 | Google Play account and products |
| X-4 | Legal review: terms, privacy, retention, safety procedure |
| X-5 | Confirm the name and app id before first publish |
| X-6 | Real institution data, quota decisions, app icon and artwork |

## Known engineering gaps

- ARC-03 is partial: controllers exist, but most screens still read them through `AppStore`.
- Discover has no skeleton while paging, and its deck has no pull to refresh.
- Fonts load at runtime through `google_fonts`, and should be bundled for release.
- Most new text has no Hindi translation yet.
- No performance measurement on a mid-range device.
