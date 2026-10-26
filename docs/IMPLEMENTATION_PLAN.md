# Implementation Plan — Nikah_App → Barkat-grade product

**Date:** 2026-10-27
**Inputs:** `CODEBASE_AUDIT.md` · `REFERENCE_ANALYSIS.md` · `GAP_ANALYSIS.md`
**Baseline to protect:** `flutter analyze` 0 issues · `flutter test` 11/11 passing

---

## Stage 0 — Decisions (RESOLVED 2026-10-27)

> **D1 = Firebase · D2 = keep as a superset · D3 = screenshots will be supplied.**
> Progress and external blockers are tracked in `IMPLEMENTATION_PROGRESS.md`.
> The original analysis behind each question is retained below.

## Stage 0 (original analysis)

Three questions change the shape of most of this plan. **Stages 1 and 2 do not depend on
them and can proceed immediately.** Stages 3+ largely cannot.

### D1 — Backend: what exists, and what do you want?
**Finding:** there is **no backend of any kind** in this repo (no HTTP client, no
Firebase, no Supabase, no auth, no storage, no realtime). Phases 6–9 of the brief are
~70% server-dependent.

The brief says: *"If the backend is missing or insufficient, document the proposed
requirements and architecture before implementing any new service."* So I will not create
one unilaterally. Options:

| Option | Fit | Effort to first working journey |
|---|---|---|
| **You already have an API** (not in this repo) | Best — I integrate against it | Low; I need the base URL, auth scheme, and schema |
| **Firebase** (Auth phone OTP + Firestore + Storage + FCM + Functions) | Good — covers auth, realtime chat, push, storage, server-side rules in one | Medium |
| **Supabase** (Postgres + RLS + Realtime + Storage) | Good — SQL schema, row-level security maps cleanly to the authorisation needs | Medium |
| **Custom backend** (e.g. Node/Postgres) | Most control; most work | High |
| **None — stay a demo** | Then G-01, G-03, G-13, G-14, G-15, G-05, G-21 **cannot be honestly fixed**; the app must be labelled a demo in-app | Low |

**My recommendation:** if there is no existing API, **Supabase**. Row-level security
enforces exactly the authorisation requirements the brief is strictest about (profile
edit ownership, conversation participants, guardian scoping, document access), which is
otherwise the hardest part to get right.

### D2 — The invented ~2,100 LOC: keep, remove, or flag?
Nine features have no public reference support (`GAP_ANALYSIS.md` §Invented), most
prominently the Wali SMS portal, chaperoned chat, and the family-meeting scheduler.
**Recommendation: Option B (superset)** — keep guardian/family as a differentiator, fix
its integrity defects, stop it gating flows the reference leaves ungated, and build the
missing documented features first.

### D3 — Visual reference: can you supply screenshots or a recording?
All visual fidelity work (G-40…G-45, Stage 2) is blocked. Store screenshots were not
retrievable as text and no recording exists. **Without this, Stage 2 can only harden the
existing Stitch-derived design system — it cannot make it match Barkat**, and I will not
guess colours or dimensions.

---

## Stage 1 — Stabilisation and honesty fixes
**No dependencies. Start immediately.** Removes false claims and release blockers.

| # | Change | Files | Gap |
|---|---|---|---|
| 1.1 | Add `INTERNET` to the release manifest | `android/app/src/main/AndroidManifest.xml` | G-06 |
| 1.2 | Implement the iOS `privacy_shield` handler, **or** correct the comment to Android-only | `ios/Runner/AppDelegate.swift`, `lib/services/privacy_shield.dart` | G-16 |
| 1.3 | Remove the false *"Session opened with 2-factor verification"* log string | `lib/providers/app_store.dart:103` | G-01 (partial) |
| 1.4 | Remove the hardcoded `'Renews 12 Nov 2026 · billed monthly'`; render an honest free-tier state | `lib/screens/premium_screen.dart:118` | G-05 (partial) |
| 1.5 | Correct the theme's disputed provenance comment | `lib/theme/app_theme.dart:3-10` | G-28 |
| 1.6 | Unify the product name across platforms; write a real pubspec description | `AndroidManifest.xml`, `ios/Runner/Info.plist`, `pubspec.yaml`, `android/app/build.gradle.kts` | G-27 |
| 1.7 | Delete the auto-accept / auto-reply / auto-chaperone `Timer`s that fabricate other users' actions | `lib/providers/app_store.dart` `requestContact`, `sendMessage` | G-13, G-15 |
| 1.8 | Replace unlicensed Unsplash seeds with original/licensed placeholders | `lib/models/match_profile.dart` | G-33 |
| 1.9 | Move `index.html` / `serve.py` under `tools/` or delete | repo root | G-32 |
| 1.10 | Split `test/widget_test.dart` into `test/widget/` + add `test/unit/` | `test/` | G-30 |

**Reuse:** everything. **Refactor:** none. **From scratch:** iOS channel handler.
**Completion:** `flutter analyze` 0 issues; 11/11 baseline tests still pass; a release APK
builds and renders remote images (**verified on a device, not assumed**); no UI string
asserts an unimplemented security or payment property.

---

## Stage 2 — Design system hardening
**Depends on: D3 for fidelity.** The non-fidelity half can proceed now.

| # | Change | Files |
|---|---|---|
| 2.1 | Add skeleton/shimmer placeholder widget | `lib/widgets/app_skeleton.dart` (new) |
| 2.2 | Add error-state widget with retry | `lib/widgets/error_state.dart` (new) |
| 2.3 | Add confirmation dialog + reusable bottom sheet | `lib/widgets/app_dialogs.dart`, `app_sheets.dart` (new) |
| 2.4 | Add filter chip + pagination footer | `lib/widgets/app_chips.dart` (new) |
| 2.5 | Add `cached_network_image`; route all remote images through `app_images.dart` | `pubspec.yaml`, `lib/widgets/app_images.dart` | G-35 |
| 2.6 | Accessibility pass: touch targets ≥48dp, text scaling to 2.0, semantics labels | all screens | G-37 |
| 2.7 | **Only with D3 evidence:** reconcile tokens against real screenshots | `lib/theme/app_theme.dart` | G-40…G-45 |

**Reuse:** all 11 existing widgets and the token file — these are good.
**Completion:** every new widget has a widget test; no screen hand-rolls a loading or
error state; layouts verified at 320 dp and 430 dp widths with no overflow.

---

## Stage 3 — Authentication *(requires D1)*
Files: `lib/services/api_client.dart`, `lib/repositories/auth_repository.dart` (new),
`lib/providers/auth_store.dart` (new, extracted from `AppStore`),
`lib/screens/signin_screen.dart`, new OTP screen, `lib/app_router.dart` (route guards),
`pubspec.yaml` (`flutter_secure_storage`, HTTP client).

Work: real sign-in; OTP entry with resend cooldown, expiry and incorrect-code handling;
token in secure storage; refresh; route guards on authenticated paths; logout with
server-side invalidation; double-submit prevention; network-failure retry.

**Completion:** a release build cannot authenticate without a server; session restores on
relaunch; no token in `shared_preferences`. Unit tests for every failure path.
**Gaps closed:** G-01, G-31.

## Stage 4 — Onboarding, profile, verification *(requires D1)*
Files: the six onboarding screens, `lib/models/ward_profile.dart`,
`lib/models/verification_doc.dart`, new `profile_repository.dart`,
`verification_repository.dart`, `lib/screens/verification_screen.dart`.

Work: re-sequence to the reference's six steps (basic info → personal details → education
and profession → photos → verification → review and submit); add family type/members/
summary; graduate-only eligibility gate; real `image_picker` upload with progress and
retry; per-photo visibility; **delete `approveVerificationDoc` from the client**;
server-owned verification status with rejection reasons and resubmission; documents to
access-controlled storage with signed URLs, never logged.

**Preserve:** the existing draft-persistence/resume mechanism — it already works.
**Completion:** no client path sets `approved`; profile is not discoverable until the
server marks it live; onboarding resumes after a kill at any step.
**Gaps closed:** G-03, G-12, G-18, G-19.

## Stage 5 — Discovery, search, filters *(requires D1)*
Files: `lib/screens/discovery_screen.dart`, new search screen, `lib/screens/filters_screen.dart`,
`lib/models/filters.dart`, new `discovery_repository.dart`.

Work: paginated server-side discovery; "Search Rishtey" screen with keyword + filters;
Suggestions/Nearby toggle with coarse-location permission and graceful denial; add
`country` and `sect` filters; server-driven alma mater option list; `RefreshIndicator`,
skeletons, error+retry, empty states; filter state restoration; result dedupe.

**Completion:** no full-corpus client fetch; all [D] filters present and combinable;
every state renders. **Gaps closed:** G-09, G-10, G-11, G-14, G-22.

## Stage 6 — Proposals and matches *(G-04 modelling can start before D1)*
Files: `lib/models/proposal.dart`, `lib/models/match.dart` (new),
`lib/screens/proposals_screen.dart`, `lib/screens/matches_hub_screen.dart`,
`lib/screens/match_detail_screen.dart`, new `proposal_repository.dart`.

Work: replace the nine `Set<String>`s with `Proposal`/`ProposalStatus` and an explicit
transition table; **populate inbound proposals** (fixes the dead code); accept (✓) /
decline; mutual-only match creation, server-side; two server-configured quotas (daily
intro, pending) enforced server-side; withdraw/expiry; real report **and** block.

**Completion:** exhaustive transition-matrix unit tests including every illegal
transition; no single-sided action can produce a match; Journey D completes end to end.
**Gaps closed:** G-02, G-04, G-08, G-20, G-29.

## Stage 7 — Messaging and contact sharing *(requires D1 realtime)*
Files: `lib/screens/chat_tab_screen.dart`, `chat_screen.dart`, `chat_screen_parts.dart`,
`lib/app_router.dart` (**Messages into the shell**), new `chat_repository.dart`.

Work: Messages as a bottom-nav tab with unread badge, state preserved; real transport;
history pagination; send-failure retry; delivery/read status where supported;
blocked-user restriction; contact sharing requiring genuine recipient consent (no timer).

**If no realtime infra is approved:** the demo path must be **labelled in-app as a demo**
and the required infrastructure documented — not silently faked.
**Completion:** messages persist server-side; blocked users cannot send.
**Gaps closed:** G-07, G-13, G-15.

## Stage 8 — Family and guardian access *(requires D1 + D2)*
**Design the authorisation model before writing any UI.**

Files: `lib/models/wali.dart` → `guardian.dart`, `wali_hub_screen.dart`,
`wali_onboarding_screen.dart`, `wali_sms_portal_screen.dart` (fate depends on D2),
new `guardian_repository.dart`.

Work: enumerate scoped permissions (view profile / view proposals / receive
notifications — explicitly **not** conversations, documents or credentials);
server-issued invite tokens; server-enforced scoping; immediate revocation.

**Completion:** permission matrix unit-tested including every denial; an integration test
proves a guardian cannot read a conversation or a document.
**Gaps closed:** G-21.

## Stage 9 — Notifications, settings, privacy, account *(requires D1)*
Work: push infrastructure (token registration, permissions, tap deep links, logout
de-registration, invalid-token cleanup, no sensitive content in payloads); **account
deletion**; privacy controls backed by the server rather than a hardcoded list; real
About links via `url_launcher`; share or remove the decorative share control.
**Gaps closed:** G-17, G-24, G-25, G-38.

## Stage 10 — Premium and subscriptions *(requires D1 + Stage 3)*
Work: `in_app_purchase`; plans from server config (never hardcoded prices); purchase
initiation and status; restore purchases; **server-side receipt validation**;
entitlement-gated access; expiry and grace handling.
**No price or renewal date in Dart.** Reference SKUs are recorded in
`REFERENCE_ANALYSIS.md` §4 for mapping, not for hardcoding.
**Gaps closed:** G-05.

## Stage 11 — Testing, accessibility, performance, release
Work: split and expand the test suite (unit: models, validators, state machines, filters,
repository error handling, entitlements; widget: every state of every major screen;
integration: the eight journeys where infrastructure permits); device QA on small and
large phones, Android and iOS; keyboard, safe areas, text scaling, network interruption,
slow API, offline, repeated taps, restart/session restore; stricter lints; final QA
report with **actually-run** results and honest limitations.
**Gaps closed:** G-23, G-30, G-34, G-37.

---

## Stage ordering summary

| Stage | Blocked by | Can start now? |
|---|---|---|
| 1 Stabilisation | — | **Yes** |
| 2 Design system | D3 for fidelity only | **Yes, partially** |
| 6 (modelling only: G-04 entities + transition table) | — | **Yes** |
| 3 Auth | D1 | No |
| 4 Profile/verification | D1, Stage 3 | No |
| 5 Discovery/search | D1, Stage 3 | No |
| 6 Proposals (full) | D1, Stage 4 | No |
| 7 Messaging | D1 + realtime | No |
| 8 Guardian | D1, D2 | No |
| 9 Notifications/account | D1 | No |
| 10 Premium | D1, Stage 3 | No |
| 11 Testing/release | all | Continuous |

## Reuse / refactor / rebuild

**Reuse as-is:** `go_router` config + `AppRoutes`, `StatefulShellRoute`, all 11 widgets,
`theme/app_theme.dart` tokens, all 9 models (as DTOs), `PrivacyShield` + Android native,
onboarding draft persistence, the 11 baseline tests.

**Refactor:** `AppStore` → focused stores behind repositories (keep `provider`; no state
library migration — the audit gives no justification); proposal sets → typed state
machine; onboarding step order; Messages into the shell.

**Build from scratch:** API client, every repository, OTP screen, Search Rishtey screen,
report/block, account deletion, photo upload, push, IAP, iOS `privacy_shield` handler,
guardian authorisation model.

**Do not:** create a new Flutter project, replace `lib/main.dart` wholesale, swap the
state library, or add dependencies beyond those named per stage.
