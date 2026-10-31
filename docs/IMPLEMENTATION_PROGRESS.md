# Implementation Progress

**Last updated:** 2026-10-31

## Stage 0 — Decisions (RESOLVED)

| # | Question | Decision |
|---|---|---|
| D1 | Backend | **Firebase** — Auth (phone OTP), Firestore, Storage, FCM, Cloud Functions |
| D2 | The ~2,100 LOC of invented guardian/chaperone features | **Keep as a superset.** Fix their integrity defects; stop them gating flows the reference leaves ungated; build missing documented features first. No working code is deleted. |
| D3 | Visual reference material | Public store screenshots now cover six screens. A recording is still needed for login, OTP, onboarding, Proposals, Activities, Profile, chat and settings. |

### Open external dependencies (blocking)

| # | Blocker | Needed for | Owner |
|---|---|---|---|
| B-1 | **Firebase project** — `google-services.json` (Android) + `GoogleService-Info.plist` (iOS), or the FlutterFire CLI run against your project | Stages 3, 4, 5, 6, 7, 8, 9 — i.e. all backend work | User |
| B-2 | **Recording of the screens not in the store listings** | Fidelity of those screens | User |
| B-3 | **Xcode is not installed** on this machine (Command Line Tools only; CocoaPods also missing). `flutter build ios` fails with "Application not configured for iOS". | Compiling/verifying any iOS code, incl. the new `AppDelegate.swift` handler | User |
| B-4 | Apple Developer + Google Play Console accounts with IAP products configured | Stage 10 | User |
| B-5 | Decision on the two real quota values (daily intro limit, pending limit) — Barkat does not publish them | Stage 6 | User / product |

---

## Stage 1 — Stabilisation and honesty fixes · ⚠️ Mostly complete (iOS unverified; no device run)

**Goal:** remove false claims from the UI and code, fix release blockers, and
restructure the test suite — all without needing a backend.

**Verification actually run:**
- `flutter analyze` → **No issues found** (0 issues)
- `flutter test` → **All tests passed (19/19)**, up from 11
- `flutter build apk --release` → **built, 57.4 MB**; `aapt2 dump permissions` confirms
  `android.permission.INTERNET`; `aapt2 dump badging` confirms label `Barkat Nikah`
- `flutter build ios` → **NOT RUN — Xcode unavailable (B-3)**

| # | Task | Status | Files |
|---|---|---|---|
| 1.1 | `INTERNET` permission in the release manifest | ✅ Verified in the built APK | `android/app/src/main/AndroidManifest.xml` |
| 1.2 | iOS `privacy_shield` method-channel handler | ⚠️ **Rewritten 2026-10-31, never compiled.** The first version used an API that does not exist and would have failed to build | `ios/Runner/AppDelegate.swift`, `lib/services/privacy_shield.dart` |
| 1.3 | Removed the false *"Session opened with 2-factor verification"* log; documented `signIn()` as performing no authentication | ✅ | `lib/providers/app_store.dart` |
| 1.4 | Removed the fabricated `'Renews 12 Nov 2026 · billed monthly'`; renders "No active plan · you are on the free tier"; purchase-history copy no longer implies a disabled checkout exists | ✅ | `lib/screens/premium_screen.dart` |
| 1.5 | ❌ **Reverted.** The original comment was right; pixel sampling confirmed it | ↩️ | `lib/theme/app_theme.dart` |
| 1.6 | Unified the product name to **Barkat Nikah** across Android label, iOS `CFBundleDisplayName`/`CFBundleName`, and wrote a real pubspec description | ✅ | `AndroidManifest.xml`, `ios/Runner/Info.plist`, `pubspec.yaml` |
| 1.7 | **Deleted every timer that fabricated another member's actions:** the 2.4 s contact auto-accept, the 1.4 s canned match reply, the 3.2 s "chaperone" note, the 3-string `_matchReplies` pool, and the now-dead `reply()` / `appendChaperoneNote()` methods | ✅ | `lib/providers/app_store.dart` |
| 1.8 | Removed 7 uses of Unsplash stock photos (5 seed profiles, 2 heroes). "Unlicensed" was never checked, and the photos were distinct. Restoring them is an open decision; `AppNetworkImage` now renders its placeholder for an empty URL instead of throwing | ✅ | `lib/models/match_profile.dart`, `lib/widgets/app_images.dart`, `landing_front_screen.dart`, `welcome_intentions_screen.dart` |
| 1.9 | Moved stray artefacts out of the repo root → `tools/serve.py`, `tools/stitch_preview.html` | ✅ | repo root → `tools/` |
| 1.10 | Split the single 434-LOC test file into `test/helpers/test_app.dart`, `test/widget/app_flows_test.dart` (8 tests), `test/unit/app_store_test.dart` (11 tests) | ✅ | `test/` |

### Test suite: 11 → 19

Two pre-existing tests **asserted the fabricated behaviour** and therefore had to
change. They were not deleted — they were inverted into guarantees:

| Was | Now |
|---|---|
| `contact request spends a gold credit and auto-approves` | `spends a credit and leaves the request pending` + `a pending request does not create a match` — both assert, after a 3 s wait, that nothing on the device granted the other member's consent |
| `sends a message and receives the chaperoned reply flow` | `sends a message without fabricating a reply` (widget) + `a sent message is stored once and no reply is fabricated` (unit) — assert, after a 4–5 s wait, that no incoming message appears |

Six genuinely new unit tests were added: re-proposing doesn't spend a second slot;
declining an absent request is a no-op; an empty message is ignored; submitting a
document does not by itself approve it; an incompatible profile leaves the deck; an
unmatched profile leaves both decks.

### ⚠️ Note on 1.2 — the iOS handler is unverified

`AppDelegate.swift` now registers the `com.barkat.nikah/privacy_shield` channel (it
previously registered nothing, so every iOS call was swallowed by `catch (_)` while the
Dart doc claimed iOS support). The implementation uses the documented
`UITextField.isSecureTextEntry` layer technique, since iOS has no `FLAG_SECURE`.

**It has not been compiled or run** — Xcode is not installed on this machine (B-3). It
should be treated as unproven until someone builds and tests it on a device. The layer
re-parenting it performs is a known-fragile technique; if it misbehaves, the safer
fallback is to observe `UIApplication.userDidTakeScreenshotNotification` and overlay a
blur, which protects less but cannot break the view hierarchy. The Dart doc comment now
describes the real behaviour and limits on both platforms.

---

## Stage 6a — Proposal state machine (offline portion) · ✅ COMPLETE

**Goal:** replace the untyped boolean sets with a typed, validated proposal
lifecycle, and make the incoming-proposal path reachable. No backend needed.

**Verification actually run:**
- `flutter analyze` → **0 issues**
- `flutter test` → **All tests passed (50/50)**, up from 19
- `flutter build apk --release` → **built, 57.5 MB**

### What changed

| Area | Change |
|---|---|
| New model | `lib/models/proposal.dart` — `Proposal`, `ProposalStatus {pending, accepted, declined, withdrawn, expired}`, `ProposalDirection {outgoing, incoming}`, an explicit `allowedTransitions` table, `isActorAllowed`, and `tryTransition` (returns `null` on an illegal move rather than throwing) |
| Store | `_proposals` and `_incomingRequests` (two `Set<String>`) replaced by `List<Proposal> _proposalRecords`. New: `proposalFor`, `outgoingProposal`, `incomingProposal`, `sentProposals`, `pendingIncomingProposals`, `acceptProposal`, `declineProposal`, `withdrawProposal` |
| Persistence | Proposals now serialize as JSON records under `bk_proposal_records`, with a one-time migration off the legacy comma-separated `bk_proposals` key |
| UI | `proposals_screen.dart` — the Received tab now lists real incoming proposals with working accept/decline; the Sent tab shows each proposal's own status instead of reusing "contact shared". `match_detail_screen.dart` — accept/decline now move the typed proposal |

### Integrity rules now enforced and tested

1. **Sending a proposal never creates a match.** Only `acceptProposal` does — the
   sender declared interest and the recipient accepted, so consent is mutual.
2. **Only the recipient may accept or decline; only the sender may withdraw.** A sender
   cannot accept their own proposal.
3. **Every terminal status is final.** A declined proposal can never become accepted.
4. Re-sending to a profile with a live proposal is a no-op and spends no quota slot.
5. Withdrawing frees the heart but does **not** refund the spent daily slot.

**Gaps closed:** **G-02** (incoming proposals were unreachable dead code) and **G-04**
(untyped boolean proposal state) — both P0. Server-side enforcement of these same rules
remains part of Stage 6's backend half (blocked on B-1).

---

## Two launch-crash bugs found and fixed (not previously in the audit)

Both were found by writing the first tests that reload a store over **populated**
preferences. Every pre-existing test started from empty prefs, which is why a clean
`flutter test` had never exercised either path. Both throw inside `AppStore._load()`,
which runs from the constructor in `main()` — so both crash the app **before the first
frame**, on the second launch.

### C-1 · Chat history crashed the app on relaunch — P0

`_saveChats` wrote each thread with `ChatMessage.encodeList(...)`, i.e. a JSON
**string**, nested inside a map that was then `jsonEncode`d. `_decodeChatMap` read the
same values back as `value as List?`, throwing
`type 'String' is not a subtype of type 'List<dynamic>?'`.

**Effect:** open a chat → close the app → relaunch → crash, permanently, because the bad
blob stays in preferences.

**Fix:** `_saveChats` now stores a real JSON array. `_decodeChatMap` accepts both shapes,
so existing installs keep their history, and is wrapped so a corrupt blob can never
brick start-up.

### C-2 · Any saved string set crashed the app on relaunch — P0

Ten writers persist their sets with `.join(',')` (e.g. `"zayd-1,farhan-2"`), but
`_decodeSet` called `jsonDecode` on that, throwing
`FormatException: Unexpected character (at character 1)`.

**Effect:** like a profile, request an intro, skip a card, share a contact or unmatch —
any of these → relaunch → crash. This affected `bk_likes`, `bk_intros`, `bk_approved`,
`bk_skipped`, `bk_contact_requests`, `bk_shared_contacts`, `bk_unmatched` and more.

**Fix:** `_decodeSet` now parses the comma form the writers actually produce, still
tolerates a JSON array, and never throws.

**Regression tests added:** chat history survives a reload; a corrupt chat blob does not
break construction; a legacy double-encoded thread is still readable; populated
comma-separated sets reload without crashing; proposal records survive a reload.

> `CODEBASE_AUDIT.md` reported persistence as working on the strength of reading the code
> and a passing test run, neither of which exercised a reload. That was wrong.

### Test suite growth

| Milestone | Tests |
|---|---|
| Baseline (commit `00a9180`) | 11 |
| After Stage 1 | 19 |
| After Stage 6a | 50 |
| After 2026-10-31 repairs | **56** |

`test/unit/proposal_test.dart` includes an exhaustive 5x5 transition matrix and
actor-permission checks; `test/widget/app_flows_test.dart` now covers Journey D
(receive → accept → matched, and receive → decline → not matched) through the real UI.

---

## 2026-10-31 — Screenshot comparison and repairs

Verified: `flutter analyze` 0 issues, `flutter test` 56/56, release APK and web builds
succeed. Not run on any device or simulator.

- Matches now open only through `acceptProposal`. `_openMatch` is private.
- Contact sharing can no longer create a match.
- A new match starts with an empty chat. Accepting used to insert seeded messages,
  including text attributed to the member.
- Verification screen can no longer approve documents. `approveVerificationDoc` is deleted.
- `resetAll` now clears `bk_proposal_records`, which the earlier refactor had missed.
- Added block and report on the profile menu, and Delete Account in Settings.
- Premium no longer shows "Barkat Premium · Monthly" over "No active plan".
- "Accept Request" copy restored from the real app.

Known demo data still ships in every build: 5 seed profiles, 2 seeded incoming proposals,
a seeded Zayd match and conversation, and the demo sign-in.

---

## Stages 2–11 — remaining

Stage 2 (design-system widgets, caching, accessibility) and the Stage 6 modelling work
(typed `Proposal` + transition table) are the only remaining items that do not need
Firebase credentials. Everything else is blocked on **B-1**.

See `IMPLEMENTATION_PLAN.md` for per-stage files, acceptance criteria and tests.

| Stage | Status | Blocked by |
|---|---|---|
| 2 Design system (non-fidelity half) | Not started | — |
| 2 Design system (fidelity) | Not started | B-2 |
| 6a Proposal modelling | ✅ Complete | — |
| 3 Auth | Not started | B-1 |
| 4 Profile / verification | Not started | B-1 |
| 5 Discovery / search | Not started | B-1 |
| 6b Proposals server enforcement | Not started | B-1 |
| 7 Messaging | Not started | B-1 |
| 8 Guardian access | Not started | B-1 |
| 9 Notifications / account | Not started | B-1 |
| 10 Premium / IAP | Not started | B-1, B-4 |
| 11 Testing / release | Continuous | — |

## Gaps closed so far

Fully closed: **G-02**, **G-27**, **G-32**, **C-1**, **C-2**. **G-06** is verified in the
APK manifest only, not on a device. **G-28** was not a real gap.

Partially closed: **G-01** (false 2FA claim removed; real auth needs B-1), **G-05** (fake
renewal removed; IAP needs B-1/B-4), **G-13** and **G-15** (fabrication removed; real
transport needs B-1), **G-16** (iOS handler written, unverified — B-3), **G-30** (suite
split and expanded; broader coverage ongoing).

Partially closed also: **G-04** (seven untyped sets remain), **G-08** (block is local, reports stay on the device), **G-17** (deletion is local), **G-29** (`Proposal` entity added; `Match`, `Conversation`,
`Subscription`, `User` still missing).

Withdrawn: **G-07**. Deprioritised: **G-09**, **G-10**.

Open: G-03 (client self-approval removed, but "upload" still sends no file), G-11, G-12, G-14, G-18…G-26, G-31, G-34…G-39.
