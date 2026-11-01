# Implementation Progress

Each phase records what actually ran. Older stage-by-stage notes are in
`docs/history/PROGRESS_TO_2026-11-01.md`.

## Status

| Phase | State |
|---|---|
| 0 Baseline | Done |
| 1 Audit and architecture | Done |
| 2 Architecture refactor | Done |
| 3 Authentication, onboarding, review | Next |

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
