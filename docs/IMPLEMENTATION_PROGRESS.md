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
| 4 Discovery, proposals, matches, chat | Next |

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
