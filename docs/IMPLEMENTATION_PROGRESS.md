# Implementation Progress

Each phase records what actually ran. Older stage-by-stage notes are in
`docs/history/PROGRESS_TO_2026-11-01.md`.

## Status

| Phase | State |
|---|---|
| 0 Baseline | Done |
| 1 Audit and architecture | Done |
| 2 Architecture refactor | Done |
| 3 Authentication, onboarding, review | Done |
| 4 Discovery, proposals, matches, chat | Done |
| 5 Family, privacy, deletion | Done |
| 6 Trust and safety | Next |

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
